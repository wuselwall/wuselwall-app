// Loads the week's meal plan entries and the household's meal settings through the
// caller's client, so RLS applies to every read (ADR-010). The meal zone itself is pure
// (board.ts `fillMeals`). Settings are read from `api.settings` as household-level rows
// only; a missing row falls back to the curated default of specs/21.
import type { userClient } from "./client.ts";
import type { MealEntryRow, MealSettings, MealSlotName } from "./board.ts";

type Client = ReturnType<typeof userClient>;

/** The curated defaults of specs/21 "Meals (M1.4)". */
export const DEFAULT_MEAL_SETTINGS: MealSettings = {
  schoolDaySlot: "dinner",
  freeDaySlot: "lunch",
  awayMeansNotEating: true,
  careLunchCutoff: "14:00",
};

const KEYS = {
  schoolDaySlot: "meals.warm_meal.school_day",
  freeDaySlot: "meals.warm_meal.free_day",
  awayMeansNotEating: "meals.away_means_not_eating",
  careLunchCutoff: "meals.care_lunch_cutoff",
} as const;

/**
 * The week's meal entries (`from`..`to`, inclusive local dates) and the four household
 * meal settings. An unreadable or unexpected value falls back to its default.
 */
export async function loadMeals(
  client: Client,
  from: string,
  to: string,
): Promise<{ entries: MealEntryRow[]; settings: MealSettings }> {
  const [entriesResult, settingsResult] = await Promise.all([
    client.from("meal_plan_entries").select("*")
      .gte("on_date", from).lte("on_date", to),
    client.from("settings").select("key, value")
      .in("key", Object.values(KEYS))
      .is("profile_id", null)
      .is("device_id", null),
  ]);
  if (entriesResult.error) throw entriesResult.error;
  if (settingsResult.error) throw settingsResult.error;

  const values = new Map<string, unknown>(
    ((settingsResult.data ?? []) as { key: string; value: unknown }[])
      .map((row) => [row.key, row.value]),
  );
  return {
    entries: (entriesResult.data ?? []) as MealEntryRow[],
    settings: {
      schoolDaySlot: slotOf(values.get(KEYS.schoolDaySlot), "schoolDaySlot"),
      freeDaySlot: slotOf(values.get(KEYS.freeDaySlot), "freeDaySlot"),
      awayMeansNotEating: typeof values.get(KEYS.awayMeansNotEating) ===
          "boolean"
        ? values.get(KEYS.awayMeansNotEating) as boolean
        : DEFAULT_MEAL_SETTINGS.awayMeansNotEating,
      careLunchCutoff: timeOf(values.get(KEYS.careLunchCutoff)),
    },
  };
}

function slotOf(
  value: unknown,
  which: "schoolDaySlot" | "freeDaySlot",
): MealSlotName {
  return value === "lunch" || value === "dinner"
    ? value
    : DEFAULT_MEAL_SETTINGS[which];
}

/** A stored "HH:MM" (or "HH:MM:SS"), normalised to "HH:MM"; else the default. */
function timeOf(value: unknown): string {
  return typeof value === "string" && /^\d{2}:\d{2}(:\d{2})?$/.test(value)
    ? value.slice(0, 5)
    : DEFAULT_MEAL_SETTINGS.careLunchCutoff;
}

// Loads the school rows a window of local dates needs, through the caller's client, so
// RLS applies to every read (ADR-010). The projection itself is pure (school.ts).
//
// Only what can touch the window is read: timetables whose term overlaps it and whose
// validity overlaps it, their lessons, the exceptions dated inside it, and the holidays
// that overlap it. Schools, periods and subjects are small and read whole.
//
// Public holidays are not imported: the cache (api.holiday_feed) is read for the regions
// of the schools and of the household, and a school's region holidays join its holidays
// here (publicHolidayRows), so the projection reads one list.
import type { userClient } from "./client.ts";
import type { HolidayFeedRow } from "./openholidays.ts";
import { countriesFromRegions } from "./openholidays.ts";
import {
  type ExceptionRow,
  type HolidayRow,
  type LessonRow,
  type PeriodRow,
  publicHolidayRows,
  type SchoolData,
  type SchoolRow,
  type SubjectRow,
  type TermRow,
  type TimetableRow,
} from "./school.ts";

type Client = ReturnType<typeof userClient>;

/** The school data of a window plus what the week board needs of the household. */
export type SchoolLoad = SchoolData & {
  /** The household's region (setting household.region), or null. */
  householdRegion: string | null;
  /** The household's locale ("de-DE"): the language of holiday names. */
  locale: string;
  /** The public holiday cache rows that overlap the window and cover a region in use. */
  publicFeed: HolidayFeedRow[];
};

/** The rows of one query, or its error thrown. */
async function rows<T>(
  query: PromiseLike<{ data: unknown[] | null; error: unknown }>,
): Promise<T[]> {
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as T[];
}

/** The school data that can touch the local dates `from`..`to` (inclusive). */
export async function loadSchoolData(
  client: Client,
  from: string,
  to: string,
): Promise<SchoolLoad> {
  const terms = await rows<TermRow>(
    client.from("school_terms").select("*")
      .lte("starts_on", to).gte("ends_on", from),
  );
  const timetables = terms.length === 0 ? [] : await rows<TimetableRow>(
    client.from("timetables").select("*")
      .in("term_id", terms.map((t) => t.id))
      .lte("valid_from", to)
      .or(`valid_to.is.null,valid_to.gte.${from}`),
  );
  const timetableIds = timetables.map((t) => t.id);

  const [schools, periods, subjects, lessons, exceptions, ownHolidays, household] =
    await Promise.all([
      rows<SchoolRow>(client.from("schools").select("*")),
      rows<PeriodRow>(client.from("school_periods").select("*")),
      rows<SubjectRow>(client.from("subjects").select("*")),
      timetableIds.length === 0 ? [] : rows<LessonRow>(
        client.from("timetable_lessons").select("*")
          .in("timetable_id", timetableIds),
      ),
      timetableIds.length === 0 ? [] : rows<ExceptionRow>(
        client.from("timetable_exceptions").select("*")
          .in("timetable_id", timetableIds)
          .gte("on_date", from).lte("on_date", to),
      ),
      rows<HolidayRow>(
        client.from("school_holidays").select("*")
          .lte("starts_on", to).gte("ends_on", from),
      ),
      loadHousehold(client),
    ]);

  const regions = [
    ...schools.map((s) => s.region_code),
    household.region,
  ].filter((r): r is string => r !== null);
  const publicFeed = await loadPublicFeed(client, from, to, regions);
  const holidays = [
    ...ownHolidays,
    ...publicHolidayRows(schools, publicFeed, ownHolidays, household.locale),
  ];

  return {
    schools,
    periods,
    terms,
    subjects,
    timetables,
    lessons,
    exceptions,
    holidays,
    householdRegion: household.region,
    locale: household.locale,
    publicFeed,
  };
}

/** The household's locale and its region setting (household-level values only). */
export async function loadHousehold(
  client: Client,
): Promise<{ locale: string; region: string | null }> {
  const [households, settings] = await Promise.all([
    rows<{ locale: string }>(client.from("household").select("locale")),
    rows<{ value: unknown }>(
      client.from("settings").select("value")
        .eq("key", "household.region")
        .is("profile_id", null)
        .is("device_id", null),
    ),
  ]);
  const value = settings[0]?.value;
  return {
    locale: households[0]?.locale ?? "de-DE",
    region: typeof value === "string" && value !== "" ? value : null,
  };
}

/**
 * The public holiday cache rows of the countries the regions belong to, overlapping the
 * window. No region, no request.
 */
async function loadPublicFeed(
  client: Client,
  from: string,
  to: string,
  regions: string[],
): Promise<HolidayFeedRow[]> {
  const countries = countriesFromRegions(regions);
  if (countries.length === 0) return [];
  return await rows<HolidayFeedRow>(
    client.from("holiday_feed").select("*")
      .eq("kind", "public")
      .in("country", countries)
      .lte("starts_on", to).gte("ends_on", from),
  );
}

// A member's usual week (issue #81, specs/15 "The baseline"), resolved per day: the
// weekday's places of week A or B, nothing on a public holiday. Pure: the caller loads
// `api.usual_weeks` (one row per profile) and the day's holiday.
import { addDays } from "./occurrences.ts";

/** One element of `api.usual_weeks.slots`. Times are "HH:MM", both null for the whole day. */
export type UsualSlotRow = {
  week: number;
  weekday: number;
  position: number;
  state: string;
  label: string | null;
  starts: string | null;
  ends: string | null;
};

/** A row of `api.usual_weeks`: the anchor is the Monday of a week A, null when every week is the same. */
export type UsualWeekRow = {
  profile_id: string;
  anchor: string | null;
  slots: UsualSlotRow[];
};

/** `days[i].usual` of the board: one entry per place, in member order, then time order. */
export type UsualJson = {
  member_id: string;
  state: string;
  label: string | null;
  starts: string | null;
  ends: string | null;
};

/** ISO weekday of a "YYYY-MM-DD" date: 1 = Monday … 7 = Sunday. */
export function isoWeekday(date: string): number {
  const d = new Date(`${date}T00:00:00Z`).getUTCDay();
  return d === 0 ? 7 : d;
}

/**
 * 0 for week A (or every week without an anchor, when a kept week B is unused), 1 for
 * week B. Weeks alternate from the anchor in both directions, whatever the calendar week
 * numbers do around a week 53.
 */
export function abWeekOf(anchor: string | null, date: string): 0 | 1 {
  if (anchor === null) return 0;
  const monday = addDays(date, 1 - isoWeekday(date));
  const days = (Date.parse(`${monday}T00:00:00Z`) - Date.parse(`${anchor}T00:00:00Z`)) / 86_400_000;
  return Math.round(days / 7) % 2 === 0 ? 0 : 1;
}

/** The places of one member's usual week on a date, in time order (a whole day first). */
export function usualOn(week: UsualWeekRow, date: string): UsualSlotRow[] {
  const ab = abWeekOf(week.anchor, date);
  const weekday = isoWeekday(date);
  return week.slots
    .filter((s) => s.week === ab && s.weekday === weekday)
    .sort((a, b) => a.position - b.position);
}

/**
 * The board's `usual` list for one day: every member's places, in the order of
 * `memberIds`. Empty on a public holiday: the usual week says nothing about a day off.
 */
export function usualDay(
  weeks: UsualWeekRow[],
  memberIds: string[],
  date: string,
  holiday: boolean,
): UsualJson[] {
  if (holiday) return [];
  const out: UsualJson[] = [];
  for (const id of memberIds) {
    const week = weeks.find((w) => w.profile_id === id);
    if (!week) continue;
    for (const s of usualOn(week, date)) {
      out.push({ member_id: id, state: s.state, label: s.label, starts: s.starts, ends: s.ends });
    }
  }
  return out;
}

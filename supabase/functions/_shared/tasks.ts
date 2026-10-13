// Due dates of recurring task definitions over the 14-day materialisation horizon
// (specs/06 "Definitions vs instances", contract "Materialising").
//
// A definition's rrule is expanded by the calendar's own RRULE code: each definition
// becomes an all-day series starting on `starts_on`, so the same rules apply to chores
// as to calendar events, and a definition is never expanded differently in two places.
//
// Pure module: no I/O. The input is the JSON of api.tasks_schedule(); the output is what
// api.tasks_materialise() takes as p_due.
import { addDays, type EventRow, expand } from "./occurrences.ts";

/** The horizon: today plus this many days after today, both ends inclusive. */
export const HORIZON_DAYS = 13;

export type TaskSchedule = {
  household_id: string;
  timezone: string;
  today: string;
  definitions: {
    id: string;
    rrule: string | null;
    starts_on: string;
    window_days: number;
  }[];
};

export type DueDate = { definition_id: string; due_on: string };

/**
 * Every due date in [today, today + 13] for the schedule's recurring definitions,
 * sorted by due date and then definition id. Dates before a definition's `starts_on`
 * are dropped even when the rule would produce them (DTSTART is always emitted by
 * RFC 5545, and a series must not start before it was created).
 */
export function dueDates(schedule: TaskSchedule): DueDate[] {
  const from = schedule.today;
  const to = addDays(from, HORIZON_DAYS);
  const out: DueDate[] = [];

  for (const def of schedule.definitions) {
    const series: EventRow = {
      id: def.id,
      calendar_id: "",
      title: "",
      description: null,
      location: null,
      kind: "appointment",
      presence_state: null,
      status: "confirmed",
      importance: "normal",
      is_all_day: true,
      starts_at: null,
      ends_at: null,
      start_date: def.starts_on,
      end_date: def.starts_on,
      timezone: schedule.timezone,
      rrule: def.rrule,
      rdates: null,
      exdates: null,
      attendee_ids: [],
    };
    const occurrences = expand([series], [], from, to, schedule.timezone);
    for (const occ of occurrences) {
      if (occ.local_start_date < def.starts_on) continue;
      // A calendar series always includes its DTSTART (RFC 5545); a chore does not: a
      // "Saturdays" chore created on a Tuesday is first due on Saturday.
      if (
        occ.local_start_date === def.starts_on && def.rrule &&
        !matchesRule(def.starts_on, def.rrule)
      ) continue;
      out.push({ definition_id: def.id, due_on: occ.local_start_date });
    }
  }

  return out.sort((a, b) =>
    a.due_on < b.due_on
      ? -1
      : a.due_on > b.due_on
      ? 1
      : a.definition_id < b.definition_id
      ? -1
      : a.definition_id > b.definition_id
      ? 1
      : 0
  );
}

const WEEKDAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];

/**
 * Whether [date] ('YYYY-MM-DD') satisfies the rule's BYDAY, BYMONTHDAY and BYMONTH
 * parts — the parts that can exclude a series' first day. A rule without them matches.
 */
export function matchesRule(date: string, rrule: string): boolean {
  const [y, m, d] = date.split("-").map(Number);
  const utc = new Date(Date.UTC(y, m - 1, d));
  const weekday = WEEKDAYS[(utc.getUTCDay() + 6) % 7];
  const daysInMonth = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const parts = new Map(
    rrule.split(";").map((p) => p.split("=") as [string, string]),
  );

  const byMonth = parts.get("BYMONTH");
  if (byMonth && !byMonth.split(",").map(Number).includes(m)) return false;

  const byMonthDay = parts.get("BYMONTHDAY");
  if (
    byMonthDay &&
    !byMonthDay.split(",").map(Number).some((n) =>
      n > 0 ? n === d : daysInMonth + n + 1 === d
    )
  ) return false;

  const byDay = parts.get("BYDAY");
  if (byDay) {
    const monthly = parts.get("FREQ") === "MONTHLY";
    const ok = byDay.split(",").some((entry) => {
      const match = /^([+-]?\d)?(MO|TU|WE|TH|FR|SA|SU)$/.exec(entry);
      if (!match || match[2] !== weekday) return false;
      if (!match[1] || !monthly) return true;
      const n = Number(match[1]);
      const nth = Math.floor((d - 1) / 7) + 1; // 2 = the second such weekday
      const nthFromEnd = Math.floor((daysInMonth - d) / 7) + 1; // 1 = the last
      return n > 0 ? n === nth : -n === nthFromEnd;
    });
    if (!ok) return false;
  }
  return true;
}

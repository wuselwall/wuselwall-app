// Loads the school rows a window of local dates needs, through the caller's client, so
// RLS applies to every read (ADR-010). The projection itself is pure (school.ts).
//
// Only what can touch the window is read: timetables whose term overlaps it and whose
// validity overlaps it, their lessons, the exceptions dated inside it, and the holidays
// that overlap it. Schools, periods and subjects are small and read whole.
import type { userClient } from "./client.ts";
import type {
  ExceptionRow,
  HolidayRow,
  LessonRow,
  PeriodRow,
  SchoolData,
  SchoolRow,
  SubjectRow,
  TermRow,
  TimetableRow,
} from "./school.ts";

type Client = ReturnType<typeof userClient>;

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
): Promise<SchoolData> {
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

  const [schools, periods, subjects, lessons, exceptions, holidays] =
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
    ]);

  return {
    schools,
    periods,
    terms,
    subjects,
    timetables,
    lessons,
    exceptions,
    holidays,
  };
}

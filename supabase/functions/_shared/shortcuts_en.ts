// English wording of the shortcut answers (shortcuts.ts). Keys mirror shortcuts_de.ts; the
// ShortcutMessages type makes a missing or extra key a compile error. Sentences are spoken by
// Siri as well as shown, so they are short and name no one by pronoun.
import type { ShortcutMessages } from "./shortcuts.ts";

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

function join(items: string[], word = "and"): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} ${word} ${items[items.length - 1]}`;
}

const points = (n: number) => (n === 1 ? "1 point" : `${n} points`);

export const SHORTCUTS_EN: ShortcutMessages = {
  locale: "en-GB",
  today: "today",
  tomorrow: "tomorrow",
  dayAfterTomorrow: "the day after tomorrow",
  onDate: (date) => `on ${date}`,
  joinList: (items) => join(items),

  tokenInvalid:
    "This shortcut is no longer valid. Create a new key in WuselWall under Settings → Siri and Shortcuts.",
  rateLimited:
    "This shortcut has added enough for today. It works again tomorrow.",
  unknownAction: "WuselWall does not know this shortcut.",
  failed: "That did not work. Please try again later.",
  textRequired: "The shortcut sent no text.",
  memberRequired: "For whom? Please name someone in the family.",
  memberUnknown: (name) => `Nobody in the family is called “${name}”.`,
  listUnknown: (name) => `There is no list called “${name}”.`,
  dayInvalid: (value) => `“${value}” is not a day WuselWall understands.`,

  shoppingAdded: (names, list) =>
    `${join(names)} ${names.length === 1 ? "is" : "are"} on the ${
      list ? `“${list}” ` : ""
    }list.`,

  noEvents: (when) => `Nothing on the calendar ${when}.`,
  events: (when, items) => `${cap(when)}: ${join(items)}.`,
  allDay: "all day",
  slot: {
    breakfast: "Breakfast",
    lunch: "Lunch",
    dinner: "Dinner",
    snack: "Snack",
  },
  noMeals: (when) => `No meal is planned ${when} yet.`,
  meals: (when, items) => `Meals ${when}: ${join(items)}.`,
  cooks: (name) => `${name} is cooking.`,
  yourChores: (titles) => `Your tasks: ${join(titles)}.`,

  points: (n) => `You have ${points(n)}.`,

  choreDone: (
    title,
    n,
  ) => (n > 0 ? `Done: ${title}. ${points(n)} added.` : `Done: ${title}.`),
  choreAwaitsCheck: (title) =>
    `Done: ${title}. The points come once it is confirmed.`,
  choreNoneOpen: "No task is left open today.",
  choreOpen: (titles) => `Still open: ${join(titles)}.`,
  choreNoMatch: (text, open) =>
    `No open task matches “${text}”.${
      open.length > 0 ? ` Still open: ${join(open)}.` : ""
    }`,
  choreAmbiguous: (text, candidates) =>
    `“${text}” matches several tasks: ${
      join(candidates, "or")
    }. Please say which one.`,

  noTimetable: (name) => `No timetable is set up for ${name}.`,
  weekend: (name, when) => `${name} has no school ${when}, it is the weekend.`,
  holiday: (name, when, holiday) =>
    `${name} has no school ${when}${holiday ? ` (${holiday})` : ""}.`,
  schoolDay: (name, when, from, to, subjects) =>
    `${name} has school ${when} from ${from} to ${to}: ${join(subjects)}.`,
  noLessons: (name, when) => `${name} has no lessons ${when}.`,
  equipment: (items) => `Pack: ${join(items)}.`,
  hasSubject: (name, when, subject, period, time) =>
    `Yes, ${name} has ${subject} ${when}${
      period !== null ? `, period ${period}` : ""
    } (${time}).`,
  hasNotSubject: (name, when, subject) =>
    `No, ${name} has no ${subject} ${when}.`,
  subjectCancelled: (name, when, subject) =>
    `${subject} is cancelled for ${name} ${when}.`,

  state: {
    working: "at work",
    home_office: "working from home",
    travel: "travelling",
    away: "away",
    off: "off",
    childcare: "in childcare",
  },
  presenceHere: (name) => `${name} is here, according to the calendar.`,
  presenceAwayDays: (name, state, lastDay, back) =>
    `${name} is ${state} until ${lastDay} and back ${back}.`,
  presenceAwayUntil: (name, state, when, time) =>
    `${name} is ${state} and back ${when} at ${time}.`,
  presenceToday: (name, state) => `${name} is ${state} today.`,
  presenceNext: (state, from, to) =>
    from === to
      ? `Next: ${state} on ${from}.`
      : `Next: ${state} from ${from} to ${to}.`,
};

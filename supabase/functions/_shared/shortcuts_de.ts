// German wording of the shortcut answers (shortcuts.ts). Keys mirror shortcuts_en.ts; the
// ShortcutMessages type makes a missing or extra key a compile error. Sentences are spoken by
// Siri as well as shown, so they are short and name no one by pronoun.
import type { ShortcutMessages } from "./shortcuts.ts";

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

function join(items: string[], word = "und"): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} ${word} ${items[items.length - 1]}`;
}

const points = (n: number) => (n === 1 ? "1 Punkt" : `${n} Punkte`);

export const SHORTCUTS_DE: ShortcutMessages = {
  locale: "de-DE",
  today: "heute",
  tomorrow: "morgen",
  dayAfterTomorrow: "übermorgen",
  onDate: (date) => `am ${date}`,
  joinList: (items) => join(items),

  tokenInvalid:
    "Dieser Kurzbefehl gilt nicht mehr. In WuselWall unter Einstellungen → Siri und Kurzbefehle lässt sich ein neuer Schlüssel erstellen.",
  rateLimited: "Für heute hat dieser Kurzbefehl genug eingetragen. Morgen geht es wieder.",
  unknownAction: "Diesen Kurzbefehl kennt WuselWall nicht.",
  failed: "Das hat nicht geklappt. Bitte später noch einmal versuchen.",
  textRequired: "Der Kurzbefehl hat keinen Text geschickt.",
  memberRequired: "Für wen? Bitte einen Namen aus der Familie nennen.",
  memberUnknown: (name) => `Niemand in der Familie heißt „${name}“.`,
  listUnknown: (name) => `Eine Liste „${name}“ gibt es nicht.`,
  dayInvalid: (value) => `„${value}“ ist kein Tag, den WuselWall versteht.`,

  shoppingAdded: (names, list) =>
    `${join(names)} ${names.length === 1 ? "ist" : "sind"} auf der Liste${list ? ` „${list}“` : ""}.`,

  noEvents: (when) => `${cap(when)} stehen keine Termine an.`,
  events: (when, items) => `${cap(when)}: ${join(items)}.`,
  allDay: "ganztägig",
  slot: {
    breakfast: "Frühstück",
    lunch: "Mittagessen",
    dinner: "Abendessen",
    snack: "Snack",
  },
  noMeals: (when) => `${cap(when)} ist noch kein Essen geplant.`,
  meals: (when, items) => `Essen ${when}: ${join(items)}.`,
  cooks: (name) => `${name} kocht.`,
  yourChores: (titles) => `Deine Aufgaben: ${join(titles)}.`,

  points: (n) => `Du hast ${points(n)}.`,

  choreDone: (title, n) => (n > 0 ? `Erledigt: ${title}. ${points(n)} dazu.` : `Erledigt: ${title}.`),
  choreAwaitsCheck: (title) => `Erledigt: ${title}. Die Punkte gibt es, sobald es bestätigt ist.`,
  choreNoneOpen: "Heute ist keine Aufgabe mehr offen.",
  choreOpen: (titles) => `Noch offen: ${join(titles)}.`,
  choreNoMatch: (text, open) =>
    `Keine offene Aufgabe passt zu „${text}“.${open.length > 0 ? ` Noch offen: ${join(open)}.` : ""}`,
  choreAmbiguous: (text, candidates) =>
    `„${text}“ passt zu mehreren Aufgaben: ${join(candidates, "oder")}. Bitte genauer sagen, welche.`,

  noTimetable: (name) => `Für ${name} ist kein Stundenplan eingetragen.`,
  weekend: (name, when) => `${name} hat ${when} keine Schule, es ist Wochenende.`,
  holiday: (name, when, holiday) => `${name} hat ${when} schulfrei${holiday ? ` (${holiday})` : ""}.`,
  schoolDay: (name, when, from, to, subjects) =>
    `${name} hat ${when} von ${from} bis ${to} Schule: ${join(subjects)}.`,
  noLessons: (name, when) => `${name} hat ${when} keinen Unterricht.`,
  equipment: (items) => `Einpacken: ${join(items)}.`,
  hasSubject: (name, when, subject, period, time) =>
    `Ja, ${name} hat ${when} ${subject}${period !== null ? ` in der ${period}. Stunde` : ""} (${time}).`,
  hasNotSubject: (name, when, subject) => `Nein, ${name} hat ${when} kein ${subject}.`,
  subjectCancelled: (name, when, subject) => `${subject} fällt ${when} für ${name} aus.`,

  state: {
    working: "bei der Arbeit",
    home_office: "im Homeoffice",
    travel: "auf Reise",
    away: "weg",
    off: "frei",
    childcare: "in der Betreuung",
  },
  presenceHere: (name) => `${name} ist laut Kalender da.`,
  presenceAwayDays: (name, state, lastDay, back) =>
    `${name} ist ${state} bis ${lastDay} und ${back} wieder da.`,
  presenceAwayUntil: (name, state, when, time) => `${name} ist ${state} und ${when} um ${time} wieder da.`,
  presenceToday: (name, state) => `${name} ist heute ${state}.`,
  presenceNext: (state, from, to) =>
    from === to ? `Als Nächstes: ${state} am ${from}.` : `Als Nächstes: ${state} von ${from} bis ${to}.`,
};

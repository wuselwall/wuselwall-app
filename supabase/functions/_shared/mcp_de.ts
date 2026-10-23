// German wording of the MCP summaries (mcp_family.ts). Keys mirror mcp_en.ts; the McpMessages type
// makes a missing or extra key a compile error. Category names follow the app (app_de.arb).
import type { McpMessages } from "./mcp_family.ts";

const points = (n: number) => (n === 1 ? "1 Punkt" : `${n} Punkte`);

export const MCP_DE: McpMessages = {
  day: (date) =>
    new Date(`${date}T12:00:00Z`).toLocaleDateString("de-DE", {
      weekday: "short",
      day: "numeric",
      month: "numeric",
      timeZone: "UTC",
    }),
  noAppointments: "keine Termine",
  tasks: "Aufgaben",
  anyone: "für alle",
  taskStatus: {
    open: "offen",
    done: "erledigt",
    verified: "bestätigt",
    skipped: "übersprungen",
    expired: "verfallen",
  },
  points,
  due: (date) => `fällig ${date}`,
  noTasks: "Keine Aufgaben.",
  noMeals: "Kein Essen geplant.",
  guests: (n) => (n === 1 ? "+1 Gast" : `+${n} Gäste`),
  shopping: (
    list,
    n,
  ) => (n === 0 ? `${list}: nichts offen.` : `${list}: ${n} offen`),
  noList: "Noch keine Einkaufsliste: sie entsteht mit dem ersten Artikel.",
  category: {
    produce: "Obst & Gemüse",
    bakery: "Brot & Backwaren",
    dairy: "Milch & Käse",
    meat_fish: "Fleisch & Fisch",
    pantry: "Vorrat",
    frozen: "Tiefkühl",
    drinks: "Getränke",
    household: "Haushalt",
    other: "Sonstiges",
    care: "Körperpflege",
    baby: "Baby & Kind",
    cleaning: "Reinigung",
    health: "Gesundheit",
    tools: "Werkzeug",
    screws: "Schrauben & Befestigung",
    electrical: "Elektro",
    garden: "Garten",
  },
  balance: (name, n) => `${name} hat ${points(n)}.`,
  ledgerReason: {
    task: "Aufgabe",
    redemption: "Belohnung",
    adjustment: "Korrektur",
    badge: "Abzeichen",
    bonus: "Bonus",
  },
  streak: (title, n) => `${title}: ${n}-mal in Folge`,
  recipes: (n) => (n === 1 ? "1 Rezept:" : `${n} Rezepte:`),
  noRecipe: (query) => `Kein Rezept passt zu „${query}“.`,
  lessonStatus: {
    cancelled: "fällt aus",
    substituted: "Vertretung",
    room_change: "Raumwechsel",
    extra: "zusätzlich",
  },
  weekend: "Wochenende",
  schoolFree: (holiday) => (holiday ? `schulfrei (${holiday})` : "schulfrei"),
  baseline: "üblicherweise",
  nobodyAway: "alle wie üblich",
  week: (from) => `Woche ab ${from}`,
  windowInvalid:
    "Bitte einen Zeitraum von höchstens 62 Tagen angeben, frühestens ab vor 7 Tagen, from nicht nach to, als YYYY-MM-DD.",
  memberRequired: "Bitte den Namen eines Kindes angeben (member).",
  dateInvalid: (key, value) =>
    `${key} muss ein Datum als YYYY-MM-DD sein, nicht ${value}.`,
  notText: (key) => `${key} muss ein Text sein.`,
  statusInvalid: "status ist open, done oder all.",
  queryRequired: "Bitte angeben, wonach gesucht wird (query).",
  proposed: (name, n) =>
    `Vorschlag gespeichert: Stundenplan für ${name}, ${
      n === 1 ? "1 Stunde" : `${n} Stunden`
    }. Eine erziehungsberechtigte Person prüft ihn in WuselWall unter Stundenplan und übernimmt oder verwirft ihn.`,
  proposeInvalid:
    "Der Vorschlag hat ein ungültiges Format: lessons braucht je Eintrag day, period (oder starts und ends) und subject, höchstens 200 Einträge.",
  proposeLimit:
    "Es warten schon fünf Vorschläge. Bitte erst in WuselWall prüfen oder verwerfen.",
  proposeUnavailable: "Dieser Server nimmt noch keine Vorschläge an.",
  lessonsRequired: "lessons fehlt oder ist leer.",
};

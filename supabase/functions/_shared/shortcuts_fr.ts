// French shortcut answers, shown and spoken. Keep every ShortcutMessages key translated.
import type { ShortcutMessages } from "./shortcuts.ts";

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
function join(items: string[], word = "et"): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} ${word} ${items[items.length - 1]}`;
}
const points = (n: number) => `${n} point${n > 1 ? "s" : ""}`;

export const SHORTCUTS_FR: ShortcutMessages = {
  locale: "fr-FR",
  today: "aujourd’hui",
  tomorrow: "demain",
  dayAfterTomorrow: "après-demain",
  onDate: (date) => `le ${date}`,
  joinList: (items) => join(items),
  tokenInvalid:
    "Ce raccourci n’est plus valide. Crée une nouvelle clé dans WuselWall, sous Réglages → Siri et raccourcis.",
  rateLimited:
    "Ce raccourci a ajouté assez d’éléments pour aujourd’hui. Il fonctionnera à nouveau demain.",
  unknownAction: "WuselWall ne connaît pas ce raccourci.",
  failed: "Ça n’a pas fonctionné. Réessaie plus tard.",
  textRequired: "Le raccourci n’a envoyé aucun texte.",
  memberRequired: "Pour qui ? Indique une personne de la famille.",
  memberUnknown: (name) => `Personne dans la famille ne s’appelle « ${name} ».`,
  listUnknown: (name) => `Il n’y a pas de liste appelée « ${name} ».`,
  dayInvalid: (value) => `WuselWall ne comprend pas le jour « ${value} ».`,
  shoppingAdded: (names, list) =>
    `${join(names)} ${names.length === 1 ? "est" : "sont"} sur la liste${
      list ? ` « ${list} »` : ""
    }.`,
  noEvents: (when) => `Rien au calendrier ${when}.`,
  events: (when, items) => `${cap(when)} : ${join(items)}.`,
  allDay: "toute la journée",
  slot: {
    breakfast: "Petit-déjeuner",
    lunch: "Déjeuner",
    dinner: "Dîner",
    snack: "Goûter",
  },
  noMeals: (when) => `Aucun repas prévu ${when} pour le moment.`,
  meals: (when, items) => `Repas ${when} : ${join(items)}.`,
  cooks: (name) => `${name} prépare le repas.`,
  yourChores: (titles) => `Tes tâches : ${join(titles)}.`,
  points: (n) => `Tu as ${points(n)}.`,
  choreDone: (title, n) =>
    n > 0 ? `Terminé : ${title}. ${points(n)} en plus.` : `Terminé : ${title}.`,
  choreAwaitsCheck: (title) =>
    `Terminé : ${title}. Les points seront ajoutés après confirmation.`,
  choreNoneOpen: "Il ne reste aucune tâche à faire aujourd’hui.",
  choreOpen: (titles) => `Il reste à faire : ${join(titles)}.`,
  choreNoMatch: (text, open) =>
    `Aucune tâche à faire ne correspond à « ${text} ».${
      open.length > 0 ? ` Il reste à faire : ${join(open)}.` : ""
    }`,
  choreAmbiguous: (text, candidates) =>
    `« ${text} » correspond à plusieurs tâches : ${
      join(candidates, "ou")
    }. Précise laquelle.`,
  noTimetable: (name) => `Aucun emploi du temps n’est configuré pour ${name}.`,
  weekend: (name, when) => `${name} n’a pas école ${when}, c’est le week-end.`,
  holiday: (name, when, holiday) =>
    `${name} n’a pas école ${when}${holiday ? ` (${holiday})` : ""}.`,
  schoolDay: (name, when, from, to, subjects) =>
    `${name} a école ${when} de ${from} à ${to} : ${join(subjects)}.`,
  noLessons: (name, when) => `${name} n’a pas cours ${when}.`,
  equipment: (items) => `À emporter : ${join(items)}.`,
  hasSubject: (name, when, subject, period, time) =>
    `Oui, ${name} a ${subject} ${when}${
      period !== null ? `, cours ${period}` : ""
    } (${time}).`,
  hasNotSubject: (name, when, subject) =>
    `Non, ${name} n’a pas ${subject} ${when}.`,
  subjectCancelled: (name, when, subject) =>
    `Le cours ${subject} de ${name} est annulé ${when}.`,
  state: {
    working: "au travail",
    home_office: "en télétravail",
    travel: "en déplacement",
    away: "en sortie",
    off: "en congé",
    childcare: "en garde",
  },
  presenceHere: (name) => `${name} est à la maison, d’après le calendrier.`,
  presenceAwayDays: (name, state, lastDay, back) =>
    `${name} est ${state} jusqu’au ${lastDay} et revient ${
      ["aujourd’hui", "demain", "après-demain"].includes(back)
        ? back
        : back.startsWith("le ")
        ? back
        : `le ${back}`
    }.`,
  presenceAwayUntil: (name, state, when, time) =>
    `${name} est ${state} et revient ${when} à ${time}.`,
  presenceToday: (name, state) => `${name} est ${state} aujourd’hui.`,
  presenceNext: (state, from, to) =>
    from === to
      ? `Ensuite : ${state} le ${from}.`
      : `Ensuite : ${state} du ${from} au ${to}.`,
};

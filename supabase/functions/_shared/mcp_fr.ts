// French MCP summaries and actionable tool errors. User-authored names are never translated.
import type { McpMessages } from "./mcp_family.ts";

const points = (n: number) => `${n} point${n > 1 ? "s" : ""}`;
export const MCP_FR: McpMessages = {
  day: (date) =>
    new Date(`${date}T12:00:00Z`).toLocaleDateString("fr-FR", {
      weekday: "short",
      day: "numeric",
      month: "short",
      timeZone: "UTC",
    }),
  noAppointments: "rien de prévu",
  tasks: "Tâches",
  anyone: "n’importe qui",
  taskStatus: {
    open: "à faire",
    done: "terminée",
    verified: "confirmée",
    skipped: "ignorée",
    expired: "expirée",
  },
  points,
  due: (date) => `à faire avant le ${date}`,
  noTasks: "Aucune tâche.",
  noMeals: "Aucun repas prévu.",
  guests: (n) => `+${n} invité${n > 1 ? "s" : ""}`,
  shopping: (list, n) =>
    n === 0 ? `${list} : rien à acheter.` : `${list} : ${n} à acheter`,
  noList:
    "Pas encore de liste de courses : elle sera créée avec le premier article.",
  category: {
    produce: "Fruits et légumes",
    bakery: "Pain et boulangerie",
    dairy: "Produits laitiers et fromages",
    meat_fish: "Viande et poisson",
    pantry: "Épicerie",
    frozen: "Surgelés",
    drinks: "Boissons",
    household: "Maison",
    other: "Autres",
    care: "Hygiène et soins",
    baby: "Bébés et enfants",
    cleaning: "Entretien",
    health: "Santé",
    tools: "Outils",
    screws: "Vis et fixations",
    electrical: "Électricité",
    garden: "Jardin",
  },
  balance: (name, n) => `${name} a ${points(n)}.`,
  ledgerReason: {
    task: "tâche",
    redemption: "récompense",
    adjustment: "correction",
    badge: "badge",
    bonus: "bonus",
  },
  streak: (title, n) => `${title} : ${n} d’affilée`,
  recipes: (n) => `${n} recette${n > 1 ? "s" : ""} :`,
  noRecipe: (query) => `Aucune recette ne correspond à « ${query} ».`,
  lessonStatus: {
    cancelled: "annulé",
    substituted: "remplacement",
    room_change: "changement de salle",
    extra: "supplémentaire",
  },
  weekend: "week-end",
  schoolFree: (holiday) => holiday ? `pas école (${holiday})` : "pas école",
  baseline: "habituellement",
  nobodyAway: "tout le monde comme d’habitude",
  week: (from) => `Semaine du ${from}`,
  windowInvalid:
    "Indique une période de 62 jours maximum, commençant au plus tôt il y a 7 jours, avec from avant ou égal à to, au format AAAA-MM-JJ.",
  memberRequired: "Indique le nom d’un enfant (member).",
  dateInvalid: (key, value) =>
    `${key} doit être une date au format AAAA-MM-JJ, pas ${value}.`,
  notText: (key) => `${key} doit être du texte.`,
  statusInvalid: "status doit être open, done ou all.",
  queryRequired: "Indique ce que tu cherches (query).",
};

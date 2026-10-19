// Spanish shortcut answers, shown and spoken. Keep every ShortcutMessages key translated.
import type { ShortcutMessages } from "./shortcuts.ts";

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
function join(items: string[], word = "y"): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} ${word} ${items[items.length - 1]}`;
}
const points = (n: number) => n === 1 ? "1 punto" : `${n} puntos`;

export const SHORTCUTS_ES: ShortcutMessages = {
  locale: "es-ES",
  today: "hoy",
  tomorrow: "mañana",
  dayAfterTomorrow: "pasado mañana",
  onDate: (date) => `el ${date}`,
  joinList: (items) => join(items),
  tokenInvalid:
    "Este atajo ya no es válido. Crea una clave nueva en WuselWall, en Ajustes → Siri y atajos.",
  rateLimited:
    "Este atajo ya ha añadido suficientes elementos por hoy. Volverá a funcionar mañana.",
  unknownAction: "WuselWall no conoce este atajo.",
  failed: "No ha funcionado. Vuelve a intentarlo más tarde.",
  textRequired: "El atajo no ha enviado ningún texto.",
  memberRequired: "¿Para quién? Indica una persona de la familia.",
  memberUnknown: (name) => `Nadie en la familia se llama «${name}».`,
  listUnknown: (name) => `No hay ninguna lista llamada «${name}».`,
  dayInvalid: (value) => `WuselWall no entiende el día «${value}».`,
  shoppingAdded: (names, list) =>
    `${join(names)} ${names.length === 1 ? "está" : "están"} en la lista${
      list ? ` «${list}»` : ""
    }.`,
  noEvents: (when) => `No hay nada en el calendario ${when}.`,
  events: (when, items) => `${cap(when)}: ${join(items)}.`,
  allDay: "todo el día",
  slot: {
    breakfast: "Desayuno",
    lunch: "Comida",
    dinner: "Cena",
    snack: "Merienda",
  },
  noMeals: (when) => `Todavía no hay ninguna comida prevista ${when}.`,
  meals: (when, items) => `Comidas ${when}: ${join(items)}.`,
  cooks: (name) => `${name} cocina.`,
  yourChores: (titles) => `Tus tareas: ${join(titles)}.`,
  points: (n) => `Tienes ${points(n)}.`,
  choreDone: (title, n) =>
    n > 0 ? `Hecho: ${title}. ${points(n)} más.` : `Hecho: ${title}.`,
  choreAwaitsCheck: (title) =>
    `Hecho: ${title}. Los puntos se añadirán cuando se confirme.`,
  choreNoneOpen: "No queda ninguna tarea pendiente hoy.",
  choreOpen: (titles) => `Pendiente: ${join(titles)}.`,
  choreNoMatch: (text, open) =>
    `Ninguna tarea pendiente coincide con «${text}».${
      open.length > 0 ? ` Pendiente: ${join(open)}.` : ""
    }`,
  choreAmbiguous: (text, candidates) =>
    `«${text}» coincide con varias tareas: ${
      join(candidates, "o")
    }. Indica cuál.`,
  noTimetable: (name) =>
    `No hay ningún horario de clases configurado para ${name}.`,
  weekend: (name, when) =>
    `${name} no tiene colegio ${when}, es fin de semana.`,
  holiday: (name, when, holiday) =>
    `${name} no tiene colegio ${when}${holiday ? ` (${holiday})` : ""}.`,
  schoolDay: (name, when, from, to, subjects) =>
    `${name} tiene colegio ${when} de ${from} a ${to}: ${join(subjects)}.`,
  noLessons: (name, when) => `${name} no tiene clases ${when}.`,
  equipment: (items) => `Para llevar: ${join(items)}.`,
  hasSubject: (name, when, subject, period, time) =>
    `Sí, ${name} tiene ${subject} ${when}${
      period !== null ? `, clase ${period}` : ""
    } (${time}).`,
  hasNotSubject: (name, when, subject) =>
    `No, ${name} no tiene ${subject} ${when}.`,
  subjectCancelled: (name, when, subject) =>
    `La clase de ${subject} de ${name} está cancelada ${when}.`,
  state: {
    working: "en el trabajo",
    home_office: "teletrabajando",
    travel: "de viaje",
    away: "fuera",
    off: "de descanso",
    childcare: "en cuidado infantil",
  },
  presenceHere: (name) => `${name} está en casa, según el calendario.`,
  presenceAwayDays: (name, state, lastDay, back) =>
    `${name} está ${state} hasta el ${lastDay} y vuelve ${
      ["hoy", "mañana", "pasado mañana"].includes(back)
        ? back
        : back.startsWith("el ")
        ? back
        : `el ${back}`
    }.`,
  presenceAwayUntil: (name, state, when, time) =>
    `${name} está ${state} y vuelve ${when} a las ${time}.`,
  presenceToday: (name, state) => `${name} está ${state} hoy.`,
  presenceNext: (state, from, to) =>
    from === to
      ? `Después: ${state} el ${from}.`
      : `Después: ${state} del ${from} al ${to}.`,
};

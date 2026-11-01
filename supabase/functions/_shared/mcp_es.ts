// Spanish MCP summaries and actionable tool errors. User-authored names are never translated.
import type { McpMessages } from "./mcp_family.ts";

const points = (n: number) => n === 1 ? "1 punto" : `${n} puntos`;
export const MCP_ES: McpMessages = {
  day: (date) =>
    new Date(`${date}T12:00:00Z`).toLocaleDateString("es-ES", {
      weekday: "short",
      day: "numeric",
      month: "short",
      timeZone: "UTC",
    }),
  noAppointments: "nada previsto",
  tasks: "Tareas",
  anyone: "cualquiera",
  taskStatus: {
    open: "pendiente",
    done: "hecha",
    verified: "confirmada",
    skipped: "omitida",
    expired: "vencida",
  },
  points,
  due: (date) => `vence el ${date}`,
  noTasks: "No hay tareas.",
  noMeals: "No hay comidas previstas.",
  guests: (n) => n === 1 ? "+1 invitado" : `+${n} invitados`,
  shopping: (list, n) =>
    n === 0 ? `${list}: nada pendiente.` : `${list}: ${n} pendientes`,
  noList:
    "Todavía no hay lista de la compra: se creará con el primer artículo.",
  category: {
    produce: "Frutas y verduras",
    bakery: "Pan y bollería",
    dairy: "Lácteos y quesos",
    meat_fish: "Carne y pescado",
    pantry: "Despensa",
    snacks: "Snacks",
    frozen: "Congelados",
    drinks: "Bebidas",
    household: "Hogar",
    other: "Otros",
    care: "Cuidado personal",
    baby: "Bebés y niños",
    cleaning: "Limpieza",
    health: "Salud",
    tools: "Herramientas",
    screws: "Tornillos y fijaciones",
    electrical: "Electricidad",
    garden: "Jardín",
  },
  balance: (name, n) => `${name} tiene ${points(n)}.`,
  ledgerReason: {
    task: "tarea",
    redemption: "recompensa",
    adjustment: "corrección",
    badge: "insignia",
    bonus: "bonificación",
  },
  streak: (title, n) => `${title}: ${n} seguidas`,
  recipes: (n) => n === 1 ? "1 receta:" : `${n} recetas:`,
  noRecipe: (query) => `Ninguna receta coincide con «${query}».`,
  lessonStatus: {
    cancelled: "cancelada",
    substituted: "sustitución",
    room_change: "cambio de aula",
    extra: "adicional",
  },
  weekend: "fin de semana",
  schoolFree: (holiday) => holiday ? `sin colegio (${holiday})` : "sin colegio",
  baseline: "habitualmente",
  nobodyAway: "todo el mundo como de costumbre",
  week: (from) => `Semana del ${from}`,
  windowInvalid:
    "Indica un periodo de 62 días como máximo, que comience como pronto hace 7 días, con from anterior o igual a to, en formato AAAA-MM-DD.",
  memberRequired: "Indica el nombre de un niño o una niña (member).",
  dateInvalid: (key, value) =>
    `${key} debe ser una fecha en formato AAAA-MM-DD, no ${value}.`,
  notText: (key) => `${key} debe ser texto.`,
  statusInvalid: "status debe ser open, done o all.",
  queryRequired: "Indica qué quieres buscar (query).",
  proposed: (name, n) =>
    `Propuesta guardada: horario de ${name}, ${
      n === 1 ? "1 clase" : `${n} clases`
    }. Un adulto responsable la revisa en WuselWall en Horario escolar y la aplica o la descarta.`,
  proposeInvalid:
    "La propuesta tiene un formato no válido: cada entrada de lessons necesita day, period (o starts y ends) y subject, 200 entradas como máximo.",
  proposeLimit:
    "Ya hay cinco propuestas esperando. Que las revisen o descarten primero en WuselWall.",
  proposeUnavailable: "Este servidor aún no acepta propuestas.",
  lessonsRequired: "lessons falta o está vacío.",
};

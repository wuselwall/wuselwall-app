# Horario escolar

Los adultos mantienen el horario. Cada niño consulta su semana y los cambios, también en la pantalla de cocina.

<Shot name="school-week" alt="El horario de un niño con una clase cancelada y una suplencia" wide />

## Configurar el colegio {#setting-up}

La primera vez toca **Configurar colegio**, escribe el nombre y la **región** del colegio y toca **Crear colegio**. No hace falta más: se proponen horas de clase y una lista de asignaturas, y en **Siguientes pasos** aparece cada niño al que aún le falta el horario, con un botón para introducirlo o importarlo. Después, la página del colegio contiene:

- nombre y **región** del colegio;
- horas de inicio y fin de **clases y descansos**;
- **periodos**, con fechas; si el horario alterna cada semana, activa **Semanas A y B** e indica el **número de semana de una semana A**;
- **asignaturas**, abreviatura, color, material necesario y visibilidad en la pared; las sugerencias del país son editables;
- vacaciones y días sin clase.

**Guardar**, arriba a la derecha, aparece cuando hay cambios en nombre, región u horas y los guarda juntos. Las clases siguen el orden cronológico, con descansos entre ellas.

## Festivos y vacaciones {#public-and-school-holidays}

Elige país (**Alemania, Austria, Suiza o Liechtenstein**), cantón o estado y, si quieres, distrito o municipio.

<Shot name="region-picker" alt="La elección del país y del cantón o estado" />

Las regiones se ordenan de Z a A en el idioma de la app. Los cantones suizos incluyen su abreviatura, por ejemplo AG. Puedes buscar por nombre o abreviatura.

Puedes continuar sin región: no habrá festivos automáticos y tendrás que añadir las vacaciones a mano. La región del hogar también se cambia en los [ajustes](/es/settings/household).

Los **festivos** se aplican automáticamente. El día queda sin clases, su nombre aparece en la cabecera y las comidas lo tratan como día libre.

Para **vacaciones escolares**, usa **Importar vacaciones escolares** en vacaciones y días libres. La vista previa cubre los **próximos 18 meses**.

<Shot name="holiday-import" alt="Las vacaciones para importar y las ya importadas" />

Elige periodos. Los ya importados y los solapamientos quedan señalados. Después puedes modificarlos, borrarlos o añadir otros.

::: warning Suiza
Las vacaciones suelen depender del municipio. Contrasta las fechas con el calendario del colegio y corrige las diferencias.
:::

Los datos vienen de [OpenHolidays](https://www.openholidaysapi.org). Los consulta el servidor, no la app.

## Varios colegios {#several-schools}

Añade otro colegio cuando haga falta y elige arriba cuál editar. Cada horario indica a qué colegio pertenece.

## Introducir el horario {#entering-a-timetable}

Añade el horario de cada niño para un periodo. Si no hay periodo que cubra la semana visible, la app propone el curso escolar actual, del 1 de agosto al 31 de julio, con nombre y fechas ya rellenos. Si encaja, toca **Guardar periodo y continuar**; si tu colegio lo cuenta de otra forma, cambia antes el nombre o las fechas. Las fechas deben incluir la semana visible; si no, lo indica junto a la fecha.

Arriba aparecen niño, colegio, periodo y fechas. Toca una celda para elegir asignatura. Si falta una asignatura, escribe su abreviatura en la búsqueda y elige **Crear la asignatura «…»**: la asignatura existe al momento y rellena la celda; color, icono y cosas que llevar vienen después en **Editar colegio**. El botón de guardar permanece abajo mientras te desplazas.

Si aún no hay horario, la vista muestra un mensaje sobre el niño seleccionado y el botón **Introducir horario**.

<Shot name="school-editor" alt="El editor con colegio, periodo y botón Guardar visible" />

Elige ritmo semanal o semanas A/B, que se rellenan por separado. Añade cuidado extraescolar con días y horas. Copia de un hermano o del periodo anterior para ahorrar escritura. Guarda la cuadrícula.

## Importar un horario {#reading-in}

En vez de teclear cada clase, puedes hacer que se lea la hoja. Las tres vías terminan en la misma **vista previa**: muestra el niño, el colegio, el periodo, la cuadrícula tal como se guardaría, las asignaturas que se crearán y cada aviso, por ejemplo cuando se sustituye un horario o tiene más clases que las horas de clase. Solo **Aplicar** escribe algo; **Descartar** lo deja todo como estaba.

**Desde texto, con vuestro asistente de IA.** En un niño sin horario toca **Importar…** y luego **Pegar como texto** (o **Importar…** arriba en el horario). **Copiar las instrucciones para el asistente** deja un texto en el portapapeles: dáselo, junto con una foto del horario, al asistente en el que confiáis, por ejemplo en su app del móvil. Responde en un formato fijo que WuselWall sabe leer. Pega la respuesta en el campo y toca **Importar**. La foto solo va al asistente que elijáis; WuselWall no envía nada a nadie.

**Como propuesta de un asistente.** Un asistente conectado a WuselWall ([Apps y asistentes de IA](/es/settings/shortcuts)) puede dejar un horario como **propuesta**. No cambia nada: en **Hoy** y sobre el horario aparece una tarjeta «Propuesta de Claude» con **Revisar** y **Descartar**. **Revisar** abre la vista previa. Las propuestas caducan a los 14 días.

**Como foto o PDF, leído por vuestro servidor.** Si vuestro servidor tiene reconocimiento de texto ([Extras para el servidor](/es/server/extras#text-recognition)), toca **Importar…** y **Escanear una foto**, haz una foto de la hoja, elige una, o elige el PDF del colegio con **Elegir un archivo**. El archivo va a vuestro propio servidor y a ningún otro sitio; el servidor reconoce los días, las clases y las asignaturas y muestra la vista previa. El PDF es el más exacto, porque el servidor lee su texto directamente; en una foto, una imagen recta y luminosa de toda la hoja da el mejor resultado, y el servidor endereza por sí mismo una foto torcida. La vista previa nombra los fragmentos de texto que no encajan en ninguna casilla, para compararlos con la hoja. Sin reconocimiento de texto, la app lo dice y remite a importar desde texto.

## Editar días enteros {#editing-whole-days}

El menú del día permite **vaciarlo**, **copiarlo** a otros días o **intercambiarlo**. Solo cambia el borrador. Puedes deshacer la última operación; guarda para aplicarla.

## La semana {#the-week}

La elección del niño, el regreso a esta semana y las acciones de edición comparten una barra. En pantallas pequeñas, esta semana ocupa una línea centrada y las acciones pasan debajo. El colegio usa un icono de escuela; el engranaje abre los ajustes generales.

Las flechas están junto al lunes y el viernes. El niño seleccionado tiene fondo teñido, borde y marca de verificación. Las vacaciones aparecen encima de la semana y los festivos en cada cabecera.

Toca una clase para marcarla **cancelada**, con **suplencia** (docente y nota) o en **otra aula**. Restablecer recupera la clase prevista.

## Preparar la mochila {#pack-for-tomorrow}

La pared y la vista del día del niño muestran el material del día siguiente, como ropa de deporte. El móvil puede enviar un [recordatorio la víspera](/es/settings/reminders). Desactivar el aviso en los ajustes del hogar lo oculta en todas partes.

## Los niños informan de cambios {#children-report-changes}

Solo los adultos responsables mantienen el horario. Puedes permitir que un miembro comunique una cancelación para que un adulto la confirme, en los [ajustes del hogar](/es/settings/household).

# Horario escolar

Los adultos mantienen el horario. Cada niño consulta su semana y los cambios, también en la pantalla de cocina.

<Shot name="school-week" alt="El horario de un niño con una clase cancelada y una suplencia" wide />

## Configurar el colegio {#setting-up}

La primera vez toca **Configurar colegio**. El primer colegio solo necesita dos datos: el **nombre del colegio** y la **región**. Después toca **Crear colegio**.

<Shot name="school-first" alt="El primer colegio: solo nombre y región, con Crear colegio debajo" />

No hace falta más. Se proponen horas de clase y una lista de asignaturas: clases de 45 minutos desde las 8:00, un descanso de 20 minutos después de la 2.ª y la 4.ª clase, y de 5 minutos en las demás. Si vuestro hogar aún no tiene región, toma la del primer colegio. Después, en **Siguientes pasos** aparece cada niño al que aún le falta el horario. Toca la fila para introducirlo, o **Importar…** para leerlo de la hoja.

Después, la página del colegio contiene:

- nombre y **región** del colegio: país, luego cantón o estado, y si quieres distrito o municipio. La región decide los festivos, las vacaciones y las asignaturas propuestas, ver abajo;
- horas de inicio y fin de **clases y descansos**;
- **periodos**, con fechas; si el horario alterna cada semana, activa **Semanas A y B** e indica el **número de semana de una semana A**;
- **asignaturas**, abreviatura, color, material necesario y visibilidad en la pared;
- vacaciones y días sin clase.

**Guardar**, arriba a la derecha, aparece cuando hay cambios en nombre, región u horas y los guarda juntos. Las clases siguen el orden cronológico, con descansos entre ellas.

### Las asignaturas propuestas {#proposed-subjects}

La lista de asignaturas sigue la región del colegio. Usa los nombres y abreviaturas que imprimen los horarios de esa región. Así la importación los reconoce en la hoja.

- **Alemania**: por ejemplo Deutsch (D), Mathematik (Ma), Sachunterricht (SU), Sport (Sp) y Schwimmen (Sw);
- **Austria**: los nombres del plan de estudios 2023/24, por ejemplo Kunst und Gestaltung (KuG) y Bewegung und Sport (BS);
- **Suiza germanófona y Liechtenstein**: las áreas del Lehrplan 21, por ejemplo Natur, Mensch, Gesellschaft (NMG) y Textiles und Technisches Gestalten (TTG);
- **Romandía** (Ginebra, Vaud, Neuchâtel, Jura): en francés, por ejemplo Français (FRA) y Sciences de la nature (SCN);
- **Tesino**: en italiano, por ejemplo Italiano (ITA) y Studio d’ambiente (AMB).

En un cantón bilingüe, por ejemplo Friburgo o Valais, decide el idioma de la app: en francés llega la lista de la Romandía, en italiano la del Tesino y, si no, la de la Suiza germanófona. Si eliges **Otro país (sin región)**, también decide el idioma de la app: en francés la lista de Francia, en español la de España y, si no, la alemana.

La lista solo llega mientras no tengáis ninguna asignatura. Después es vuestra: cambia nombres, borra asignaturas o añade otras.

## Festivos y vacaciones {#public-and-school-holidays}

Elige país (**Alemania, Austria, Suiza o Liechtenstein**), cantón o estado y, si quieres, distrito o municipio.

<Shot name="region-picker" alt="La elección del país y del cantón o estado" />

Las regiones se ordenan de Z a A en el idioma de la app. Los cantones suizos incluyen su abreviatura, por ejemplo AG. Puedes buscar por nombre o abreviatura.

Puedes continuar sin región: no habrá festivos automáticos y tendrás que añadir las vacaciones a mano. La región del hogar también se cambia en [Ajustes → Familia](/es/settings/household).

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

En vez de teclear cada clase, puedes hacer que se lea la hoja. Hay dos caminos. Todos terminan en la misma [vista previa](#preview), y solo **Aplicar** escribe algo.

**Desde texto estructurado.** Toca **Importar…** y **Pegar como texto**. Pega un horario en JSON con el formato de WuselWall y toca **Importar** para abrir la vista previa. Un texto normal no se convierte automáticamente en un horario.

**Como foto o PDF, leído por vuestro servidor.** Si vuestro servidor tiene reconocimiento de texto ([Extras para el servidor](/es/server/extras#text-recognition)), toca **Importar…** y **Escanear una foto**. Después elige **Hacer una foto**, **Elegir una foto** o **Elegir un archivo (PDF o imagen)**, por ejemplo para el PDF que envió el colegio.

<Shot name="timetable-scan" alt="Escanear una foto: el aviso de que el archivo se queda en casa y los tres caminos Hacer una foto, Elegir una foto y Elegir un archivo" />

El archivo va a vuestro propio servidor y a ningún otro sitio. El servidor no lo guarda. Lee la hoja y muestra la vista previa. Para que reconozca vuestras asignaturas, la app envía también su idioma y los nombres y abreviaturas de vuestras asignaturas.

Lo que el servidor lee de la hoja:

- los días, las clases y sus horas, si están impresas en el margen;
- en cada casilla la asignatura, el aula y el profesor. Una palabra que la hoja parte al final de la línea se vuelve a unir;
- la **leyenda** debajo o al lado de la tabla, es decir, abreviaturas con su nombre, por ejemplo «NMG Natur, Mensch, Gesellschaft»;
- las **semanas A y B**, cuando una casilla lleva una «A» o una «B»;
- las filas de **cuidado** con sus horas, como las imprimen las hojas alemanas, francesas o españolas (Hort, Mittagstisch, cantine, comedor). Se convierten en filas de cuidado, no en clases.

Lo que mejor funciona:

- El **PDF del colegio** es lo más exacto, porque el servidor lee su texto directamente. Un PDF escaneado se lee como una foto.
- En una **foto**: recta, luminosa y la hoja entera. El servidor endereza por sí mismo una foto torcida o hecha de lado. Las fotos de iPhone (HEIC) también sirven.
- El archivo puede tener como máximo 6 MB.

El reconocimiento de texto apenas lee la **letra a mano**. De un horario escrito a mano solo llega una parte de las casillas; el resto lo completas después en el editor. Si el servidor no encuentra ningún horario, la app lo dice. Prueba entonces con una foto más recta y luminosa, o importa desde texto. Si vuestro servidor no tiene reconocimiento de texto, la app también lo dice y remite a importar desde texto.

### La vista previa {#preview}

La vista previa muestra lo que se guardaría. Todavía no ha cambiado nada.

<Shot name="timetable-import" alt="La vista previa: niño, colegio, periodo y la tabla con el nombre de cada asignatura bajo su abreviatura" wide />

- arriba el **niño** y, si hay varios, el **colegio**. Puedes cambiar ambos;
- el número de clases, la clase, el ritmo semanal y el **periodo**. Si el periodo aún no existe, pone «(se creará)». Si el niño ya tiene un horario en ese periodo, indica que se sustituirá;
- la **tabla**: cada clase con sus horas, en cada casilla la abreviatura y debajo el nombre de la asignatura. En un móvil no hay sitio: mantén pulsada una casilla para ver el nombre. Una clase solo en semanas A o B lleva una A o una B;
- el **cuidado extraescolar**, si la hoja lo tiene;
- cada **aviso**: una clase no encaja con ninguna hora, la hoja tiene más clases que vuestras horas (entonces se añaden), otras horas (entonces se quedan las vuestras) o nombra otro colegio. Después de un escaneo, la vista previa nombra también los fragmentos de texto que no encajan en ninguna casilla. Compáralos entonces con la hoja.

<Shot name="timetable-import-subjects" alt="Asignaturas nuevas en la vista previa: CM se toma como el Conocimiento del medio existente, Inglés se crea nueva" />

En **Asignaturas nuevas** aparece cada asignatura de la hoja que aún no tenéis. Al lado eliges:

- **Crear nueva**: la asignatura se crea con la abreviatura y el nombre de la hoja;
- una **asignatura existente**, si ya la tenéis con otra palabra, por ejemplo «CM» para vuestro Conocimiento del medio. WuselWall recuerda la palabra de la hoja para esa asignatura y la reconoce sola la próxima vez. Si el escaneo encuentra exactamente una asignatura que encaja, ya está elegida.

Si desactivas **Crear las asignaturas nuevas**, las clases con asignaturas nuevas se dejan fuera; la tabla las muestra tachadas.

**Aplicar** crea el periodo si falta, amplía las horas de clase, crea las asignaturas nuevas y guarda el horario. La flecha de volver cierra la vista previa sin guardar.

## Editar días enteros {#editing-whole-days}

El menú del día permite **vaciarlo**, **copiarlo** a otros días o **intercambiarlo**. Solo cambia el borrador. Puedes deshacer la última operación; guarda para aplicarla.

## La semana {#the-week}

La elección del niño, el regreso a esta semana y las acciones de edición comparten una barra. En pantallas pequeñas, esta semana ocupa una línea centrada y las acciones pasan debajo. El colegio usa un icono de escuela; el engranaje abre los ajustes generales.

Las flechas están junto al lunes y el viernes; en el móvil o la tableta, deslizar a la izquierda o a la derecha también cambia de semana. En la tableta infantil, el niño pasa así de un día a otro de su semana, de lunes a viernes. El niño seleccionado tiene fondo teñido, borde y marca de verificación. Las vacaciones aparecen encima de la semana y los festivos en cada cabecera.

Toca una clase para marcarla **cancelada**, con **suplencia** (docente y nota) o en **otra aula**. Restablecer recupera la clase prevista.

## Preparar la mochila {#pack-for-tomorrow}

La pared y la vista del día del niño muestran el material del día siguiente, como ropa de deporte. El móvil puede enviar un [recordatorio la víspera](/es/settings/reminders). Desactivar el aviso en los ajustes del hogar lo oculta en todas partes.

## Los niños informan de cambios {#children-report-changes}

Solo los adultos responsables mantienen el horario. Puedes permitir que un miembro comunique una cancelación para que un adulto la confirme, en [Ajustes → Calendario y colegio](/es/settings/household).

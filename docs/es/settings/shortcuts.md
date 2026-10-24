# Apps y automatizaciones

Una **clave** de WuselWall permite a otra app usar los datos familiares como una persona. Siri, Atajos y otras apps de automatización pueden leer y añadir elementos. Los ejemplos usan Atajos de Apple; las otras apps envían las mismas peticiones.

Con Siri: «Lista de la compra» → «¿Qué necesitas?» → «Leche y dos pepinos». Basta la app Atajos y una clave de WuselWall.

<Shot name="shortcuts" alt="Las claves de automatización en los ajustes" />

## Permisos de una clave {#what-a-key-may-do}

Pertenece a **una persona**. Lee día, comidas, colegio, presencia y puntos. Puede añadir productos y marcar tareas de esa persona. No elimina ni administra nada, ni siquiera con una clave de adulto. El límite de **100 añadidos diarios** detiene una automatización que entre en bucle.

## Crear una clave {#creating-a-key}

En **Ajustes → Avanzados → Apps y automatizaciones**, crea una clave y ponle nombre. Un adulto responsable puede elegir a la persona; los demás crean la propia en su móvil. Copia **clave y dirección del servidor**, que se muestran una vez.

Trátala como una contraseña. Atajos la sincroniza entre tus dispositivos Apple por iCloud.

## Primer atajo: la compra {#the-first-shortcut-shopping-list}

1. Abre **Atajos**, toca **+** y añade una acción para pedir texto: «¿Qué necesitas?».
2. Añade **Obtener contenido de URL**:
   - URL: la dirección de WuselWall terminada en `/shopping`, por ejemplo `https://api.example.org/functions/v1/shortcuts/shopping`.
   - Método: **POST**.
   - Cabecera: `Authorization`, valor `Bearer ` seguido de la clave, con el espacio.
   - Cuerpo: **JSON**, campo `text` con la entrada proporcionada.
3. Muestra el resultado o haz que Siri lo lea.
4. Llama al atajo «Lista de la compra» para invocarlo con Siri.

Reconoce cantidades como «2 litros de leche» o «3 manzanas». Separa productos con coma o «y». Si ya están en la lista, aumenta la cantidad.

## Todos los atajos {#every-shortcut}

Usa POST, la cabecera `Authorization` y un cuerpo JSON:

| Función | Final de dirección | Campos JSON |
|---|---|---|
| Compra | `/shopping` | `text`; `list` opcional para otra lista |
| Día | `/today` | `day` opcional: mañana, día de semana o fecha |
| Comidas | `/meals` | `day` opcional |
| Puntos | `/points` | Ninguno |
| Tarea hecha | `/chore` | `text`: nombre de la tarea |
| Colegio | `/school` | `text`: pregunta, como «¿Olivia tiene deporte mañana?» |
| Presencia | `/presence` | `text`: pregunta, como «¿Cuándo vuelve Sara?» |

Para colegio y presencia, pide una entrada y envía toda la pregunta en `text`. Se identifican persona, día y asignatura con el nombre usado en el horario. Sin día, colegio significa mañana; sin persona, se refiere a ti.

Una tarea hecha solo marca las tuyas o las abiertas sin asignar. Si hay varias coincidencias, pide aclaración. Sin `text`, enumera lo pendiente.

La respuesta sigue el idioma admitido del móvil o, en otro caso, el del hogar. El campo `lang` fuerza `de`, `en`, `fr` o `es`.

## Revocar una clave {#revoking-a-key}

Revócala si pierdes el móvil o deja de ser necesaria. El efecto es inmediato y la lista indica el último uso. Salir del hogar revoca tus claves automáticamente. Los adultos responsables gestionan todas; los miembros, las suyas. La [exportación](/es/settings/members-devices#export-data) incluye nombres y fechas, nunca secretos.

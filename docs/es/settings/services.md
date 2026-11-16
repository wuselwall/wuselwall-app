# Tiempo y mapas

Para los [Viajes](/es/trips/), WuselWall puede consultar servicios de otras empresas: qué temperatura hace típicamente en un sitio, qué tiempo hará en los próximos días, dónde está un lugar y cuánto dura el trayecto. Es **totalmente opcional**. Todo lo demás de los viajes funciona sin estos servicios, y sin ellos vuestro servidor no consulta a nadie.

Los servicios pueden añadir:

- **Clima típico**: lo cálido, lluvioso y soleado que suele ser un sitio en un mes y, junto al mar, la temperatura del agua. Lo muestra [¿Adónde?](/es/trips/#discover)
- **Previsión**: el tiempo en el destino en los días antes y durante el viaje
- **Búsqueda de lugares**: encontrar un destino o vuestro lugar de casa por el nombre
- **Tiempo de viaje**: cuánto dura el trayecto en coche desde casa
- **Imagen de mapa**: una pequeña imagen del destino en la página del viaje

Se activa en **Ajustes → Calendario y colegio → Compartir y conexiones → Tiempo y mapas**. Solo pueden hacerlo las madres y los padres. Los demás adultos ven la página y el aviso **Una madre o un padre puede cambiar esto**.

<Shot name="settings-services" alt="La página Tiempo y mapas con el lugar de casa y el proveedor Open-Meteo, activado, con el botón Probar" />

## Tres promesas {#promises}

1. **Todo está desactivado hasta que una madre o un padre lo activa.** Un servidor nuevo no consulta ningún servicio del tiempo ni de mapas. Si desactivas de nuevo un proveedor, cualquier llamada a él se detiene al instante.
2. **Solo el servidor de vuestra familia consulta al proveedor**, nunca un móvil ni la pared. Vuestro teléfono solo habla con vuestro servidor. El servidor va a buscar una imagen de mapa y la pasa.
3. **Un proveedor solo sabe lo que la pregunta necesita:**
   - el lugar que miráis o buscáis: sus coordenadas o el texto de la búsqueda
   - para un tiempo de viaje, también vuestro lugar de casa, redondeado a aproximadamente un kilómetro
   - y, inevitablemente, la dirección de internet de vuestro servidor

   **Nada sobre vuestra familia**: ni nombres, ni cuenta, ni eventos, ni fechas de viaje.

Vuestro servidor recuerda las respuestas para no hacer dos veces la misma pregunta: el clima típico cinco años, un lugar encontrado 90 días, un tiempo de viaje y una imagen de mapa 30 días, una previsión 3 horas. Esta memoria solo guarda datos públicos de lugares, nada de vuestra familia.

## Los proveedores {#providers}

Cada proveedor es una oferta aparte, con sus propias condiciones. La página indica de cada uno lo que sabe hacer, si necesita una clave y lo que recibe (**Recibe: …**).

| Proveedor | Clave | Sabe hacer |
|---|---|---|
| **Open-Meteo** | no, gratis | Clima típico, previsión, búsqueda de lugares |
| **MET Norway** | no, gratis | Previsión |
| **OpenStreetMap Nominatim** | no, gratis | Búsqueda de lugares |
| **OpenWeather** | sí, clave propia, puede haber plan gratuito | Previsión (para unos cinco días), búsqueda de lugares |
| **Meteostat** | sí, clave propia, puede haber plan gratuito | Clima típico |
| **openrouteservice** | sí, clave propia, puede haber plan gratuito | Tiempo de viaje, búsqueda de lugares |
| **Google Maps Platform** | sí, clave propia, puede costar | Búsqueda de lugares, tiempo de viaje, imagen de mapa |

- **Sin clave** podéis empezar enseguida. Con **Open-Meteo** tenéis clima, previsión y búsqueda de lugares en un solo proveedor.
- **Con clave propia** te registras en el proveedor y escribes la clave en WuselWall (ver [más abajo](#keys)). En la ficha del proveedor, **Conseguir una clave** lleva a la página correcta.
- Un **tiempo de viaje** solo existe con **openrouteservice** o **Google Maps Platform**, una **imagen de mapa** solo con **Google Maps Platform**; los dos necesitan una clave. Solo para el tiempo de viaje recibe el proveedor también vuestro lugar de casa, redondeado.
- **Las condiciones las aceptáis vosotros.** Algunas ofertas gratuitas son solo para uso privado; Open-Meteo, por ejemplo, según el proveedor, es solo para uso no comercial. Una oferta con clave puede costar dinero; WuselWall no promete nada sobre los precios. Un pequeño tope diario protege vuestra clave de un bucle, pero no protege de los costes.
- Bajo cada imagen de mapa y cada previsión figura la mención de la fuente del proveedor.

::: warning Con franqueza
Los proveedores con clave se han hecho según su documentación, no se han probado con vuestra clave. Si uno no funciona con vuestra clave, el botón **Probar** lo dice (ver [más abajo](#test)).
:::

## Fijar el lugar de casa {#home}

Arriba en la página está **Casa**. Ese lugar sirve para las distancias en **¿Adónde?** y para el tiempo de viaje. Toca **Indicar**, escribe el **Nombre del lugar** y toca **Buscar**; un resultado fija el lugar. Para ello tiene que estar activado un proveedor con **Búsqueda de lugares**. Sin él escribes a mano la **Latitud** y la **Longitud**, con dos decimales.

El lugar se guarda redondeado a aproximadamente un kilómetro. **Cambiar** fija uno nuevo; **Olvidar** hace desaparecer las distancias hasta que se fije uno nuevo.

## Escribir una clave {#keys}

Un proveedor con clave muestra primero **Primero necesita una clave**. Consigue la clave en el proveedor, escríbela en el campo **Clave** y elige **Guardar la clave y activar**.

- **Una clave se escribe, nunca se lee.** Se escribe una vez y se guarda en vuestro servidor. Después la página solo muestra sus últimos cuatro caracteres: **Clave guardada …1234**. Ningún dispositivo puede leerla, ni siquiera el vuestro.
- **No está en la exportación de datos** de la familia ni en ningún registro. Una copia de seguridad de vuestro servidor la contiene, como los demás secretos del servidor.
- **Sustituir** la cambia. **Quitar** la borra y desactiva el proveedor.

## Orden y prueba {#test}

Bajo **Activado** está el botón **Probar**. Hace una pequeña llamada real y responde **Funciona** o indica el motivo. Pruébalo justo después de escribir una clave.

En la vista **Avanzados** (arriba a la derecha) hay más:

- **Se usa para**: casillas para lo que el proveedor debe hacer en vuestra casa. Un proveedor puede, por ejemplo, dar solo la previsión.
- **Consultar antes** y **Consultar después**: cuando varios proveedores ofrecen lo mismo, **gana el primero de este orden que responda**. Si no responde, se consulta el siguiente.
- Cuántas **llamadas hoy** ha habido ya.

## Por qué tarda la primera vez {#slow}

El servicio gratuito de Open-Meteo solo permite pocas consultas de clima: aproximadamente **tres lugares por minuto**, veinte por hora y cuarenta y ocho por día. Vuestro servidor se atiene a ello. Por eso la lista de **¿Adónde?** se llena despacio la primera vez: arriba pone «Cargando los valores de clima: quedan 12 lugares», y la página vuelve a preguntar cada medio minuto. Si durante un rato no llega nada nuevo, se detiene y dice «Llegarán más valores más tarde».

Todo está bien. Mira otra vez más tarde. Con menos lugares va más rápido: con uno o dos **deseos** (por ejemplo **Mar**) hay que consultar menos lugares. Después es rápido: los valores son **promedios** y se quedan guardados cinco años, para todas las familias de vuestro servidor.

## Cuando el servicio no responde {#no-answer}

Si una llamada no funcionó, un proveedor muestra el motivo bajo **Última llamada**:

- **El proveedor rechazó la clave.** La clave es incorrecta o ha caducado. Con **Sustituir** escribes una nueva.
- **La cuota del proveedor se ha agotado por ahora.** Espera a que se renueve, o añade otro proveedor.
- **El proveedor no respondió a tiempo** y **El proveedor no funcionó esta vez.** Ocurre. Inténtalo de nuevo más tarde con **Probar**.
- **Este proveedor necesita una clave.** Escribe una primero.

Si hay varios proveedores activados, el servidor consulta el siguiente. La página de un viaje nunca muestra un error: lo que un servicio no da simplemente falta, y todo lo demás sigue.

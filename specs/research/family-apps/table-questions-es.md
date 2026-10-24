# Tischfrage, Spanish deck: research notes (2026-10-24)

Draft deck: [table-questions-es-draft.json](table-questions-es-draft.json). Validated: 150 questions, ids q-0001..q-0150, same (category, deck, has-answer) sequence as de.json, no duplicate texts.
Method note: about 10 standard web searches and 6 page fetches. Several sites refused or timed out (cervantesvirtual.com 403, biblioteca.org.ar and curriculumnacional.cl unreachable), so no folklore collection could be read directly. Source quality below is marked.

## 1. Meal times: the window defaults are wrong for Spain

Spec defaults: `rituals.table_question.lunch` 11:30-13:30, `.dinner` 17:30-19:30.

Findings:
- Comida (the main, warm meal) is 14:00-16:00 for adults, 14:00-15:30 in most sources. The Ministry of Education teaching material places it between "las dos y las tres". Cena is 21:00-22:30, lighter than the comida. The Spanish merienda (a snack for children) falls at about 17:15-19:00. Sources: https://academy.europa.eu/mod/forum/discuss.php?d=18646 ; https://libreria.educacion.gob.es/ebook/183751/free_download (Ministry material, as reported by the search tool, not opened by me) ; https://www.spain.info/es/consejos-viaje/horarios-dias-festivos-espana/ (restaurants: comida 13:00-16:00, cena 20:00-22:30).
- Children are somewhat earlier. Consumer (OCU-adjacent consumer magazine) article on a Murcia study: pediatric advice is lunch before 14:00 and dinner before 21:00; children's dinner "rarely" happens around 20:00; a Universidad de Murcia study (Garaulet, 2020, Nutrients) treats dinner after 20:45 as late; the VALORNUT study (Complutense) defines late dinner as 21:10 or later. https://www.consumer.es/?p=591288
- The family meal is often not lunch on school days: many children eat at the school comedor. A snippet-level figure (I could not open the original): only 37.3 % of Spanish parents habitually eat with their children (10 or more meals a week). Found via https://www.consumer.es/?p=509093 and https://revintsociologia.revistas.csic.es/ (not verified). Treat as indicative.
- Weekends: the long comida with sobremesa (about 14:30-17:00) is the real family-table moment.

Conclusion: with the current defaults the question would appear at 11:30-13:30 (children are in class or have just left; the Spanish school day usually ends 14:00 or 16:30) and 17:30-19:30 (merienda time, nobody at the table). Both windows would miss the actual meals.

Recommendation: region-dependent defaults, for ES lunch 13:30-15:30 and dinner 20:00-22:00. The setting is per household, so only the shipped default for a household whose region/locale is Spain needs changing. Also check the "warm meal" default: in Spain the warm meal is the midday comida, but on school days a child often eats it at school, so for many families the shared meal on school days is dinner. `rituals.table_question = every main meal` is probably the better default for ES, or the weekday logic needs a "school canteen" case. Latin America differs again (cena roughly 19:00-21:00 in much of Mexico/Colombia/Argentina varies), so key the default to the region (ES-ES), not to the language.

## 2. How Spanish families talk at the table

- La sobremesa: the unhurried time spent at the table after eating, talking. Culturally central, longer at weekends. Sources: https://en.wikipedia.org/wiki/Sobremesa ; https://www.thelocal.es/20200904/spanish-word-of-the-day-sobremesa ; https://www.mallorcadiario.com/tapas-sobremesa-y-siesta-asi-late-la-cultura-cotidiana-que-mas-seduce-y-resiste-en-espana (survey cited there ranks long sobremesas as the second most valued tradition after tapeo; I did not verify the survey itself). Design consequence: a Spanish Tischfrage fits best at the END of the meal or in the sobremesa; a card that is simply "there during the window" works, and no question should assume a hurry. Also mention in the UI copy "sobremesa" as a nice word (optional).
- What parenting sources recommend (Guiainfantil, a major Spanish parenting site): by age 5-10, funny school situations, imagination, playground games, friends and gratitude; examples "Si fueras superhéroe, ¿cuál sería tu superpoder?", "¿Con quién jugaste hoy?". Avoid: forcing topics, judging what children say, nagging about marks, family conflicts at the table, television and mobile phones. https://www.guiainfantil.com/familia/comunicacion/de-que-hablar-con-los-ninos-a-la-hora-de-la-comida-segun-su-edad/ and https://www.guiainfantil.com/familia/preguntas-poderosas-para-una-familia-feliz/
- Generic "¿cómo te ha ido hoy?" gets nothing; concrete, open questions work (Diario Las Américas piece, https://www.diariolasamericas.com/bienestar/animar-hablar-los-ninos-las-preguntas-correctas-n4116009 ; Minnesota Dept. of Health Spanish handout on happy mealtime talk, https://www.health.mn.gov/docs/people/wic/nutrition/spanish/genfamilymeals.pdf). The deck follows this: concrete, playful, nothing about marks.
- Spain-specific touchpoints used lightly in the deck: Ratoncito Pérez (q-0008), merienda (q-0045 and the dragon at q-0057), churro, tortilla de patatas, lentejas, cole, "un martes cualquiera" (Tuesday 13th is the unlucky day in Spain, a mild wink in q-0134 (older)), pueblo/playa not used literally. Deliberately NOT used: Reyes Magos, Navidad, Semana Santa, First Communion (see 5).

## 3. Traditional riddles (adivinanzas)

Adivinanzas are anonymous oral folklore, often rhymed; the underlying texts are in the public domain, but modern collections (e.g. Cerrillo, Susaeta books, Fundación Joaquín Díaz) can have rights in selection and wording. Rule used: only riddles circulating with near-identical wording in several free sources; where a wording is my own, it is marked.

Tier A, found with the same wording on at least one source I opened or a search snippet:
- Blanca por dentro, verde por fuera... "espera" (La pera): https://nuevaescuelamexicana.sep.gob.mx/contenido/coleccion/adivina-esta-adivinanza/ ; also es.wikipedia.org/wiki/Adivinanza quotes the "blanco por dentro, verde por fuera, si no lo sabes, espera" form.
- Oro parece, plata no es (El plátano; calambur "plata no es" = "plátano es"): SEP file https://nuevaescuelamexicana.sep.gob.mx/contenido/coleccion/4309/ (via search snippet; the second line "abre la cortina..." varies between sources: cortina / cortinas / "quítale la ropa").
- Tengo agujas y no sé coser, tengo números y no sé leer (El reloj): https://www.guiainfantil.com/jugar-y-aprender/adivinanzas/geografia/tengo-agujas-y-no-se-coser-tengo-numeros-y-no-se-le-33659/ ; https://www.curriculumnacional.cl/docente/629/articles-209156_recurso_1.pdf (snippet). The "Las horas te doy, ¿sabes quién soy?" ending is in the Chilean sheet (snippet).
- Tiene ojos y no ve... tiene barba y no es hombre (El coco): SEP page above.
- Bajo tierra fui nacida... (La cebolla): SEP page above.
- Este banco está ocupado por un padre y por un hijo... (Esteban, calambur): SEP page above. This is a pun riddle, ok for 8+.
- Tiene dientes y no come, tiene cabeza y no es hombre (El ajo): search snippet only (https://www.aicad.es/adivinanzas-dificiles-con-respuesta), wording reconstructed.

Tier B, widely known folk riddles that I wrote from memory/own wording; I found no source I could open that gives this exact text, so the wording is mine and a native reviewer should confirm each is a riddle they know:
- Vuelo sin alas, silbo sin boca, azoto sin manos y no me ves (El viento), "Chiquita como un ratón y guarda la casa como un león" (La llave), "Una cajita sin tapa ni cierre..." (El huevo), "Vuelo de noche, duermo de día..." (El murciélago), "Tiene hojas y no es árbol, tiene lomo y no es animal" (Un libro), "Agua pasa por mi casa, cate de mi corazón" (El aguacate; the pun is old and Spanish-speaking-world wide), "Todos pasan por mí..." (La calle), "Hablo sin tener boca..." (El eco), "cuanto más grande es, menos se ve" (La oscuridad; world-wide riddle type).
Tier C, own composition in the traditional style (no claim of tradition): the caracol, luna and pelota riddles (q-0107, q-0108, q-0112).

Nothing was taken from a commercial riddle book. If the project wants provenance for the deck, the cleanest sources to check are Cervantes Virtual, https://www.cervantesvirtual.com/obras/materia/acertijos-y-enigmas-espanoles-123 (Fernán Caballero, "Cuentos, adivinanzas y refranes populares", d. 1877; Demófilo/Machado y Álvarez; Rodríguez Marín), which I could not open (403). Those are pre-1930 and public domain, but the digital editions' notes may not be.

## 4. Commercial conversation card games (avoid copying their questions)

Found: "Desafío de Amor" (100 family questions, Hotmart); "Talking Point Cards Generations" (200 cards, US origin, sold in Latin America); "¿Me conoces?" (card game sold on Shein and other shops); "Langame" (conversation-starter cards, a Spanish brand; listed on aitoolly); "Conversaciones en familia" (free printable 33-card deck on emotions, Universidad Javeriana, Colombia: https://www.javeriana.edu.co/enmental/wp-content/uploads/2024/12/Cartas-Conversaciones-en-Famila-Imprimir-En-Casa-V3.pdf). Also the English-language The Family Dinner Project and Table Topics families have Spanish versions. I did not read their questions, which is the point: nothing in es.json was derived from them. The only formula overlap is generic ("si fueras un animal...", "superpoder"), which is also in Guiainfantil's free examples and in the folk repertoire.

## 5. Register and vocabulary

What the existing ES app does (app/l10n/app_es.arb): addressing one person is tú ("Toca tu nombre", "Comprueba tu conexión", "Que duermas bien, {name}", "Hoy empiezas con {subject}", "Invita a tu pareja"), the family as a group is vosotros ("vuestro propio servidor", "¿Aún no tenéis servidor?", "Todos los datos de vuestra familia", "Automático: según vuestra región"). Vocabulary is peninsular: "ordenador" (householdDeviceComputer), "móvil" (memberHasAccountHint), "colegio", "docente suplente". Wusel is named without pronouns ("Wusel", "La ropa de Wusel"), consistent with the spec ("no gender").

Choices in the deck:
- Questions to a child: tú ("¿Qué has aprendido hoy?"). Questions about the family: first person plural ("nuestra casa", "hemos hecho", "podríamos"). No question uses vosotros, because it is mostly shown to one child at a time; the first-person plural does the group job and works in both regions. Imperatives are tú ("Inventa", "Imagina", "Imítalo"); no usted.
- Vocabulary: peninsular where natural but chosen so a Latin American reader still understands: cole (colloquial, very Spanish; "escuela" would be the LatAm word), peque, nevera (LatAm: refrigerador/heladera), tortuga, tobogán, merienda, zapatillas, "estornuda". Avoided regionalisms with a different meaning elsewhere: coger, zumo, ordenador, bocadillo, chaval, "hacer ilusión", "vale", "guay", "pibe". "Cole" and "peque" are the most Spain-specific words; they are friendly and suit the register of the app's kid copy.
- Gender-neutral wording so the sentence works for any child: "cuando eras bebé", "más peque", "«te sientes orgulloso/a»" avoided, no "contento/a", "agradecido/a". The thanks questions use "dar las gracias".
- Trade-off for Latin American users: the spec's ES locale is aimed at Spain (es.md / es-regions.md), the app strings are peninsular, and a neutral "Latin American" deck would sound off next to the rest of the app. Recommendation: keep one ES deck in light peninsular Spanish with the neutral choices above; if LatAm becomes a target, add `es-419` as a separate small deck (or just a vocabulary patch list) rather than blending. The cost of this deck for a Mexican family is a handful of words (cole, peque, nevera, tortilla de patatas, churro, Ratoncito Pérez - which is also known in Mexico and Colombia).

## 6. Cultural fit: what lands badly

- Gratitude phrasing: "Wofür bist du dankbar?"-type prompts translate stiffly into "¿De qué estás agradecido/a?" which sounds like a church or a coaching session in Spain and is gendered. The deck uses "dar las gracias" and concrete "what made you happy today" forms, and the thanks category is 9 of 150 (6 %), under the spec's one-in-ten.
- Religion: no reference to Dios, bendecir la mesa, Navidad, Reyes, Semana Santa, Comunión, Primera Comunión, santos. In Spain these are very common but not universal; the Reyes Magos are widely celebrated yet a "what did you ask the Reyes?" question would assume a household. The Ratoncito Pérez is a secular tooth tradition and the one cultural reference I included (q-0008); a native reviewer should say whether to keep it.
- School pressure: no marks, exams, "deberes", "tareas", "¿cómo te fue en el cole?" The older deck mentions colegio only in jokes (q-0135 animals' timetable). q-0127 ("¿Qué te ha costado un poco hoy, y qué te ha ayudado?") is deliberately open, not about school.
- Food and body: no "¿te lo has comido todo?", no weight, clean-plate or "lo sano" language; food appears only as fun (lentejas, churro). Pediatric guidance in Spain focuses on late dinners and obesity, so mealtime is a charged topic for some parents; none of the questions ask what or how much anyone ate. q-0033 ("¿Qué es lo que más rico te ha sabido hoy?") and q-0045 ("¿Qué has merendado hoy...?") are the nearest; they ask for pleasure, not quantity. A reviewer might drop them.
- Family structure: no "papá y mamá" (use "alguien de la familia"), no grandparents as a given (an earlier draft of q-0079 mentioned grandparents and was rewritten), no "lo que hacía mi abuela"; nothing that assumes two parents, siblings or a pueblo.
- Screens/brands: none. No named football clubs, no characters (the "personaje de un libro" in q-0133 is generic).
- Humour: avoid sarcasm; Spanish family humour includes teasing ("vacilar"), which the spec forbids (nothing that could embarrass a child). q-0091 ("lo más gracioso de nuestra familia") is the nearest and stays about the family.

## 7. Co-official languages (brief, for later)

Catalan (Catalonia, Balearics, Valencian Community as valenciano), Galician and Basque (Euskadi, Navarra in the north) are co-official and are the school language in many areas; many children in those regions will read a table question in their regional language. The riddle tradition is strong in each (endevinalles, adivinanzas gallegas/adiviñas, asmakizunak: Antón Cortizas's Galaxia book collects 340 Galician adiviñas, per a search result). A future ca/gl/eu deck should NOT be translated from es.json: the rhymes and puns (plata no es / plátano es, este banco / Esteban, agua pasa / aguacate) do not carry over, and each language has its own folk riddles. The research on Spanish regions and the Basque/Catalan/Galician school registers is in specs/research/school-subjects/es-regions.md. The spec's "Noch nicht in deiner Sprache" fallback would apply to those locales; whether the ES deck is a sensible fallback for a ca/gl/eu device is a product decision (most such users read Spanish well).

## 8. Questions and riddles I am least sure about (for a native reviewer)

Wording and naturalness:
- q-0004 caracol in a hurry: fine, but close to the snail riddle q-0107.
- q-0013 "¿Qué superpoder tendría una tortilla de patatas?" intended as funny; check the register.
- q-0017 "¡Grita como ellas!" and q-0020 (voz de pirata / de robot): shouting at the table is a design choice; a reviewer may prefer "Dilo con voz de gota".
- q-0019 churro laughing; q-0023 "¿qué le pondríamos?" (peninsular informal for serving food).
- q-0033 and q-0045: food-adjacent (see 6); candidates to drop.
- q-0044 contains two questions in one (smallest and biggest thing); fine for a five-year-old?
- q-0046..q-0067: almost all "Imagina que..." openers (an echo of the DE deck's "Stell dir vor"). Spanish may sound repetitive; consider varying with "Si pudieras...". Tense is mixed on purpose: imperfect subjunctive for the hypothetical ("Imagina que un día pudieras volar", "hubiera una habitación secreta") and present for vivid scenes ("Imagina que puedes hablar con los animales"). A reviewer may want to unify.
- q-0055 "tobogán" (LatAm: resbaladilla/tobogán); q-0001 "nevera" (LatAm: refrigerador/heladera).
- q-0056 "echa a andar sola" (idiomatic in Spain, check).
- q-0074, q-0075, q-0136 and q-0044 use "cole"/"peque" (colloquial, very Spanish).
- q-0120 "huelga" joke: "strike" may carry political connotations for some adults; alternative "Si los objetos de casa se fueran de vacaciones...".
- q-0127 (older, "¿Qué te ha costado un poco hoy...?") is school-adjacent but open.
- q-0135 (animals' school timetable): school but light.
- q-0140 and q-0143: "tradición"/"hogar" for the older deck, check tone (hogar is slightly formal).

Riddles to confirm as traditional / acceptable wording:
- Tier A: q-0098 La pera, q-0099 El plátano, q-0100 El reloj, q-0101 El coco, q-0102 La cebolla, q-0146 Esteban. Confirm variants (coco: "carne" vs "pulpa"; plátano: "cortina" vs "cortinas" vs "quita la ropa").
- Tier A/B from snippet or memory: q-0103 El ajo.
- Tier B (wording from memory, no source opened with this exact text): q-0104 El viento, q-0105 La llave, q-0106 El huevo, q-0109 El murciélago, q-0110 Un libro, q-0111 El aguacate, q-0145 El eco, q-0147 La oscuridad, q-0148 La calle. Please say whether each is a riddle you know.
- Tier C, my own wording (not traditional): q-0107 El caracol, q-0108 La luna, q-0112 La pelota.
- q-0146 answer text includes a hint "(«este banco»: ya lo dije al empezar)": check it reads clearly; the riddle is a pun (este banco = Esteban).
- q-0111 aguacate: "cate" is an archaic imperative of "catar" (look/see); a five-year-old will not parse it, only enjoy the reveal. Consider moving it to the older deck.
- q-0147 (oscuridad): some versions answer "la oscuridad", some "la niebla"; both fine.

## 9. Files

- [table-questions-es-draft.json](table-questions-es-draft.json): the full draft of 150. The app ships the 50 chosen in [README](README.md#table-questions-fr-and-es).

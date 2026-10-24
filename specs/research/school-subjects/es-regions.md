# Spain, regional gap research: Basque Country, Navarra, Balearics, Catalonia, Galicia, Andalusia

Research date 2026-10-23. Complements specs/research/school-subjects/es.md (not repeated here).
Written only to the scratchpad; nothing in the repository was touched.

## 0. How this was done, and what was reachable

- "Fetched" = I downloaded the file myself (curl, because WebFetch cannot read PDF text layers) and parsed it
  (pdfplumber / an HTML parser). Every code in sections 2-3 comes from such a file. "Snippet only" = reported by a
  search-result summary.
- **Hosts that refused this machine** (ECONNREFUSED / reset / timeout, tried with WebFetch and curl):
  `redols.caib.es` (ALL Balearic public schools), `*.educacion.navarra.es` (ALL Navarrese public schools),
  `blogsaverroes.juntadeandalucia.es` (Andalusian public schools), `*.hezkuntza.net`, `curriculuma.euskadi.eus`.
  So public-school sheets of the Balearics, Navarra and Andalusia could not be opened even when a search found them.
  Reachable: `agora.xtec.cat`, `edu.xunta.gal`, `euskadi.eus` (BOPV), `portal.edu.gva.es`, and private-school or own-domain sites.
- About 30 searches (standard and extended) found NO real class timetable of a Basque, Navarrese or Balearic primary school
  on a reachable host. Reasons (section 5): Balearic public primary timetables are kept in GESTIB and not published;
  Navarrese and Basque schools publish entry/exit hours but not subject grids.
- Budget: about 28 file fetches plus about 30 searches.

## 1. Sources

IDs are used in sections 2-4. Region codes: PV Euskadi, NC Navarra, IB Balearics, CT Catalonia, GA Galicia, AN Andalusia.

| ID | URL | School | Region | Level | What it is | Status |
|---|---|---|---|---|---|---|
| ABAD | https://www.iesabadinobhi.com/es/curso/horarios/ (Basque twin: /ikasturtea/ordutegiak/) | IES Abadiño BHI (Bizkaia) | PV | DBH 1-4 (ESO), 2026-27 | Class timetables of 14 groups as HTML, in Basque, full subject names | fetched |
| ZARA | https://zaraobe.net/hezkuntza-eskaintza/dbh/ | Zaraobe Institutua, Amurrio (Araba) | PV | DBH 1-4, 2026-27 | School-published subject list per course with weekly hours, in Basque, incl. electives | fetched |
| ZARA-T | https://zaraobe.net/wp-content/uploads/Ordutegia_20horario_20_20DBH-ESO.pdf | same | PV | DBH | Bilingual period grid (no subjects) | fetched |
| ARIM | https://sites.google.com/arizmendikide.net/arimazubi/4-maila | Arimazubi (Arizmendi ikastola) | PV | LH 1-4 (primary) | School site menu: the area names a Basque primary school prints per grade | fetched (names, no grid) |
| ZURR | https://zurriolaikastola.eus/sites/default/files/inline-files/LH3%20txostena%20euskaraz%202022-23%20.docx.pdf | Zurriola Ikastola, Donostia | PV | LH3 | Parent report; section 6 headings = area names; the timetable annex is NOT in the file | fetched (names, no grid) |
| BOPV | https://www.euskadi.eus/bopv2/datos/2023/06/2302729e.pdf | Eusko Jaurlaritza | PV | LH + DBH | Decreto 77/2023 in Basque, art. 11 (primary areas) and art. 13 (DBH subjects table) | fetched |
| OREN | https://oreretaikastola.eus/app/uploads/2021/09/eskola-ordutegia.-21-22-gazt.pdf | Orereta ikastola | PV | all | School hours only (HH/LH/DBH) | fetched (no subjects) |
| MPLA4 | https://agora.xtec.cat/escolamestrepla/wp-content/uploads/usu2213/2025/09/HORARI-PRIMARIA-GRUP-4t-1.pdf-1.pdf | Escola Mestre Pla | CT | 4t primària 2025-26 | Weekly grid | fetched |
| MPLA6 | https://agora.xtec.cat/escolamestrepla/wp-content/uploads/usu2213/2025/09/6e-GRUP-HORARI-PRIMARIA-1.pdf-1.pdf | same school | CT | 6è primària 2025-26 | Weekly grid | fetched |
| MBOR | https://agora.xtec.cat/escolamariabores/wp-content/uploads/usu982/2017/09/HORARI-5%C3%A8B.pdf | Escola Maria Bores | CT | 5è B primària 2017-18 | Weekly grid, a different school | fetched |
| IMMH | https://immaculadahorta.com/wp-content/uploads/2026/09/Horari-1r-ESO-B-2026-27-web.pdf | Immaculada, Horta (Barcelona; inferred from the domain) | CT | 1r ESO B 2026-27 | Weekly grid, private school, full names, "Grup A/B/C" suffixes | fetched |
| CAVA | https://www.iescavaleri.es/wp-content/uploads/2025/10/HORARIOS-GRUPOS-2025-2026.pdf | IES Cavaleri, Mairena del Aljarafe (Sevilla) | AN | 1-2 ESO, 2025-26 | 39 pages of Séneca-style group sheets, each with a code-to-name legend | fetched |
| VINC | https://www.edu.xunta.gal/centros/ceipvalleinclanoleiros/system/files/SESIONS%20PRIMARIA-INFANTIL_0.pdf | CEIP Valle-Inclán, Oleiros | GA | primary | Session/break grid only | fetched (slots, no subjects) |
| STAI | https://www.colegiosantaisabel.net/wp-content/uploads/2024/09/HORARIO-PRIMARIA-4.pdf | Colegio Santa Isabel (location NOT verified) | unknown | 4º primaria 2024-25 | Weekly grid of a bilingual school with English subject names | fetched |
| SANT | https://redols.caib.es/c07008053/wp-content/uploads/sites/82/2025/09/HORARI-GRUPS.pdf | IES Santanyí (Mallorca) | IB | ESO, Untis 2025-26 | Group timetables | snippet only (host refused) |
| MADI | https://redols.caib.es/c07007371/wp-content/uploads/sites/99/2026/05/Horari-Grup-ESO-1C.pdf (also 2C, 3B, 3C) | IES Madina Mayurqa (Palma) | IB | ESO | Group timetables | snippet only (host refused) |
| BAL6 | https://redols.caib.es/c07012858/wp-content/uploads/sites/89/2021/11/Horari-6e-EP.pdf | a Balearic CEIP (c07012858) | IB | 6è EP | Class timetable; a search summary showed the labels "Català", "Castellà", "Socials", "Religió/Estudi", "Pati" | snippet only (host refused) |
| BALPGA | https://redols.caib.es/c07015781/docs/pga-curs-25-26/?bp-attachment=07015781_PGA-curs-25-26...docx.pdf | a Balearic CEIP | IB | primary | PGA: group timetables "estan reflectits al programa de gestió ... GESTIB" | snippet only |
| NAVPAMP | cpdonamayor.educacion.navarra.es/nuestra-oferta-educativa/pai-programa-de-aprendizaje-en-ingles/ or ermitaberriip.educacion.navarra.es/web/es/proyecto-educativo-de-centro/ (the search did not say which) | a Pamplona-area CEIP, model A | NC | primary | Text: "14 castellano (5 lengua castellana, 1 lectura, 5 matemáticas, 2 EF, 1 Religión/AE), 12 inglés (4 Ciencias naturales y sociales, 5 lengua inglesa, 1 plástica, 2 música), 4 Euskera/MG" | snippet only, attribution not confirmed |
| OF106 | https://www.lexnavarra.navarra.es/detalle.asp?r=56532 | Gobierno de Navarra | NC | primary | Orden Foral 106/2023: Oct-May 26 h/week including recreos, 50-minute periods; Sept/June 20 h | snippet only |
| ARES | https://gabrielarestilhi.hezkuntza.net/es/lehen-hezkuntza-5.-maila-ekaina-8-12 | CEIP Gabriel Aresti HLHI (Bilbao) | PV | LH5 | Daily work plan (not a grid); the summary named "euskara, matematika, Lengua (gaztelania), Gizarte" | snippet only (host refused) |
| ORTU | https://www.ortuellabhi.net/hezkuntza-eskaintza/dbh-1/ | Ortuella BHI | PV | DBH1 | Hours per subject; summary: Matematika 4, Gizarte 3, Biologia-Geologia 3, Teknologia 2, Heziketa Fisikoa 2, plastika/tutoretza/etika 1 | snippet only |
| ALHA | https://blogsaverroes.juntadeandalucia.es/iesalhadra/files/2026/02/OTROS-ANEXOS_TUTORIAL-HORARIOS_2025.pdf | IES Alhadra | AN | ESO | Séneca tutorial; bilingual non-linguistic list "Tecnología, EPVA, BYG, FYQ" | snippet only |
| STEIL | https://steilas.eus/wp-content/uploads/2025/11/Guia-docente-STEILAS-2025-26.pdf | union guide, Navarra public teaching | NC | teachers | Teacher template codes "TL" (tutoría ESO) and "DES" (desdoblamiento); not student subjects | snippet only |

## 2. Per region: code -> subject as printed

"cell" = printed in the timetable grid; "legend" = in a code table or subject list; "menu" = school site area list.

### 2.1 Basque Country (Euskadi), Basque-language sheets

Primary, school-published area names (no real primary grid was reachable; this stays the main gap).

| Printed | Meaning | Source | Where |
|---|---|---|---|
| EUSKARA 1-4 | Basque | ARIM | menu |
| GAZTELERA 1-4 | Spanish (note: not "Gaztelania") | ARIM | menu |
| INGELESA 1-4 | English | ARIM | menu |
| MATEMATIKA | Mathematics | ARIM, ZURR | menu |
| INGURUNEA 1-4; "INGURUNEA (NATUR ZIENTZIAK ETA GIZARTE ZIENTZIAK)" | Knowledge of the environment | ARIM; ZURR | menu |
| GORPUTZ HEZKUNTZA | PE | ARIM, ZURR, BOPV | menu |
| MUSIKA | Music | ARIM | menu |
| ARTISTIKA | Art (visual) | ARIM | menu |
| ARTE HEZKUNTZA (MUSIKA ETA PLASTIKA) ETA ANTZERKIA | Arts, with drama | ZURR | text |
| TUTORETZA/BALOREAK | Tutoring and values | ZURR | text |
| ERRONKAK; GURE TXOKOA | project blocks ("challenges", "our corner") | ARIM | menu |
| Official areas (Decreto 77/2023 art. 11): Euskara eta Literatura; Gaztelania eta Literatura; Atzerriko Lehen Hizkuntza; Matematika; Ingurune naturalaren, sozialaren eta kulturalaren ezagutza; Arte Hezkuntza (may split: Musika, Plastika); Gorputz Hezkuntza; Balio zibiko eta etikoak (6th grade only); Tutoretza 1 h/week | | BOPV | legend |

Secondary (DBH): real grids with full names (ABAD, 14 groups, 2026-27) and course lists (ZARA, weekly hours in brackets):

| Printed | Meaning | Source | Where |
|---|---|---|---|
| Euskara eta Literatura | Basque (ZARA 3 h) | ABAD, ZARA | cell, legend |
| Gaztelania eta Literatura | Spanish (3 h) | ABAD, ZARA | cell, legend |
| Ingelesa; "Lehen atzerritar hizkuntza (Ingelesa)" | English (3 h) | ABAD; ZARA | cell; legend |
| Matematika | Maths (DBH1 4 h) | ABAD, ZARA | cell |
| Natura Zientziak | Natural sciences (combined, DBH 1-2) | ABAD | cell |
| Biologia eta Geologia; Fisika eta Kimika | split subjects at ZARA (DBH1 / DBH2-3) | ZARA | legend |
| Geografia eta Historia | Geography and history (3 h) | ABAD, ZARA | cell |
| Heziketa Fisikoa (ABAD) / Gorputz Heziketa (ZARA) / Gorputz Hezkuntza (BOPV) | PE | ABAD, ZARA, BOPV | cell / legend |
| Musika | Music | ABAD | cell |
| PIIH | unexplained code in the art slot (1 slot in 1º, 2 in 2º, matching "Hezkuntza plastikoa eta ikusentzunezkoa" 1 h / 2 h at ZARA); meaning NOT printed | ABAD | cell |
| Hezkuntza plastikoa eta ikusentzunezkoa | Visual arts | ZARA | legend |
| Teknologia eta Digitalizazioa Hast. / Teknologia eta digitalizazioa | Technology | ABAD | cell |
| Balio Zibiko eta Etikoak | Civic and ethical values | ABAD, ZARA | cell |
| Komunitatearen zerbitzuak (proiektuak); full: "Erlijioa / Komunitateari zerbitzurako proiektua" | Alternative to religion: community-service project | ABAD, ZARA | cell, legend |
| Frantsesa | French | ABAD, ZARA | cell |
| Ongizate Fisikoa eta emozionala (also "Osasun fisiko eta emozionala") | Physical and emotional wellbeing (elective) | ABAD, ZARA | cell, legend |
| Pentsamendu kritikoa... | Critical thinking (elective) | ABAD | cell |
| Tutoretza | Tutoring | ABAD, ZARA | cell |
| ATSEDENALDIA (with "RECREO") | Break | ABAD, ZARA-T | cell |
| JANTOKIA (with "COMEDOR"); AUKERAK-TZEN / BIDELAGUNA | Lunch; after-lunch options | ZARA-T | cell |
| Kultura klasikoa, Adierazpen artistikoa, Kultura zientifikoa, Latina, Ekonomia, Digitalizazioa | 3º-4º electives and options | ZARA | legend |

Cell patterns: parallel options share one cell separated by " / " ("Frantsesa / Teknologia eta Digitalizazioa / Ongizate Fisiko eta emozionala"); a cell can be cut ("Komunitatearen zerbi.", "Pentsamendu kritikoa..."). Bilingual headers: "ASTELEHENA / LUNES", "SAIOAK / SESIONES". Weekdays in Basque: ASTELEHENA, ASTEARTEA, ASTEAZKENA, OSTEGUNA, OSTIRALA. Other Basque words in hours pages (snippets): "Eskola saioak", "Jolas-ordua", "Bazkalordua"; OREN (fetched): "Jardun jarraia / zatitua", "Eskolak / Clases".

No Basque abbreviation of any subject appears on any sheet. Basque secondary sheets print full names, so the vocabulary needs words, not codes.

### 2.2 Navarra

No real timetable (primary or ESO) could be opened. Evidence is limited to:
- NAVPAMP (snippet): per-week session split of a model A school with the area words "lengua castellana", "lectura", "matemáticas", "EF", "Religión/AE", "Ciencias naturales y sociales", "lengua inglesa", "plástica", "música", "Euskera/MG" (the meaning of "MG" is not given).
- OF106 (snippet): 50-minute periods; language models are named A, B, D, G.
- STEIL (snippet): teacher-template codes `TL`, `DES`; not student subject codes.
- Model D sheets are expected to use Basque names as in 2.1 (the BOPV decree applies to Euskadi only; Navarra's is Decreto Foral 67/2022, not read). NOT verified.

### 2.3 Balearic Islands

No sheet opened. The Balearic sheets found by search (SANT, MADI, BAL6) are on a refused host. Established:
- BALPGA (snippet): CEIP group timetables are kept in GESTIB, not published as documents; families see them in the GESTIB app, where each session shows the subject name. A printed Balearic public-primary sheet is therefore unlikely; a private school may differ.
- BAL6 (snippet): labels "Català", "Castellà", "Socials", "Religió/Estudi", "Pati" (Mallorca-area 6è EP, 2021). "Religió/Estudi" is a new label for the alternative to religion; "Socials" appears where Catalonia prints "Medi". Not fetched, so lower confidence.
- SANT (snippet): Untis export "Horari 2025-26 Untis 2026", periods 08:00-15:00 with a break between periods 3 and 4. No codes seen.
- Frame (BALPGA snippet): 25 h/week, 4 sessions of 60 min plus 1 of 30 min before the esbarjo.

### 2.4 Catalonia, primary

| Printed | Meaning | Source | Where |
|---|---|---|---|
| LECTURA (09:00-09:25 daily) | reading time | MPLA4, MPLA6, MBOR | cell |
| CATALÀ, CASTELLÀ, MATEMÀTIQUES, ANGLÈS | languages, maths | MPLA4, MPLA6, MBOR | cell |
| ANGLÈS ... Conversa | English conversation slot | MPLA4, MPLA6 | cell |
| MEDI | environment | MPLA4, MPLA6, MBOR | cell |
| MÚSICA; EDUCACIÓ FÍSICA (wrapped over two lines in MBOR); PLÀSTICA (MBOR); ART (MPLA4); ARTS ESCÈNIQUES (MPLA4, MPLA6) | arts, PE | all | cell |
| TALLERS (CICLE MITJÀ / CICLE SUPERIOR) | workshops by cycle | MPLA4, MPLA6, MBOR | cell |
| TUTORIA; Tutories Individuals | tutoring | all | cell |
| VALORS (stacked with RELIGIÓ in the same slot) | alternative to religion (values) | MBOR | cell |
| RELIGIÓ | religion | MBOR | cell |
| INFORMÀTICA | computing | MBOR | cell |
| Projecte | project slot | MPLA6 | cell |
| ANIMALLETRES, RACONS, Entrena-MENT | school-specific project names | MBOR | cell |
| ESMORZAR A L'AULA, ESBARJO / E S B A R J O (letter-spaced), DINAR / D I N A R, TARDA | break, breakfast in class, lunch | MPLA4, MPLA6, MBOR | cell |
| Teacher names in parentheses, "(Tutora 3r)", "(Lídia)", "(Estel R.)" | not subjects | MPLA4, MPLA6 | cell |

### 2.5 Catalonia, ESO (IMMH, private school, full names, no codes)

Català, Castellà, Matemàtiques, Anglès, Socials, Biologia i Geologia, Tecnologia i Digitalització, "E.V.P i Audiovisual", Educació Física, Música, Religió, Tutoria, Optativa, "Comp. Speak Out", "Comp. Taller d'escriptura", ESBARJO. Language and maths cells carry a group suffix ("Castellà Grup C", "Català Grup A", "Matemàtiques Grup B"), three stacked in one cell: the same slot is a different subject per group. The sheet runs into the afternoon (15:00-17:00).

### 2.6 Galicia, primary

Subject names and codes from the two CEIPs in es.md stay valid. New here (VINC, slots only): "1ª sesión ... 5ª sesión", RECREO, MERENDA (snack, Infantil), LECTURA, COMEDOR, TRANSPORTE, SAÍDAS. Sessions of 50 min from 09:00, five sessions, jornada continua. No new Galician subject word turned up in a reachable grid (Galician CEIPs mostly publish PXA documents instead).

### 2.7 Andalusia

Primary: no public sheet reachable. STAI (location unverified) and the Salesianos sheet of es.md print full Spanish names (MATEMÁTICAS, LENGUA, INGLÉS, EDUCACIÓN FÍSICA, EDUCACIÓN PLÁSTICA Y VISUAL, MÚSICA, RELIGIÓN, CIENCIAS SOCIALES). STAI is a bilingual school and prints English names for CLIL subjects: "NATURAL SCIENCE", "MUSIC AND DANCE".

ESO, CAVA (Séneca-style export; each cell is `CODE<level digit> TEACHERCODE / ROOM`; the legend at the bottom maps code to name, names cut at about 28 characters):

| Printed code | Legend name | Source |
|---|---|---|
| LCL1, LCL2 | Lengua 1ºESO (the name is "Lengua", not "Lengua Castellana y Literatura") | CAVA legend |
| MAT1, MAT2 | Matemáticas | CAVA |
| ING1, ING2 | Inglés | CAVA |
| FR1; FR2g1, FR2g2 | Francés (g1, g2 = two groups of the same subject) | CAVA |
| GeH1, GeH2 | Geografía e Historia | CAVA |
| ByG1 | Biología y Geología | CAVA |
| FyQ2 | Física y Química | CAVA |
| EPVA1 | EPVA 1ºESO | CAVA |
| MUS1, MUS2 | Música | CAVA |
| EF1, EF2 | Educación Física | CAVA |
| TECD2 | Tecnología y Digitalizac(ión) | CAVA |
| TUT1, TUT2 | Tutoría | CAVA |
| ATED1, ATED2 | Atención Educativa | CAVA |
| RCat1, RCat2 | Religión Católica | CAVA |
| RIsl1 | Religión Islámica | CAVA |
| REv1, REv2 | Religión Evangélica | CAVA |
| EVCE2 | Ed. Valores Cívicos y Ét(icos) | CAVA |
| CR1g1, CR1g2, CR2g1, CR2g2 | Computación y Robótica | CAVA |
| OD1g1, OD1g2, OyD2 | Oratoria y Debate | CAVA |
| ALCT1 | Área Lingüística transve(rsal) | CAVA |
| SOST1 | Sostenibilidad, Ed. Am. Eco(social) | CAVA |
| PEPA2 | Proy. Ed. Plástica Audiovi(sual) | CAVA |
| APOYO, LFyQ (in cells, no legend line) | support; "LFyQ" probably a FyQ lab, meaning NOT printed | CAVA cell |
| Room labels after the slash: A1..A25, GIM, PIST1/PIST2, PLAST, MUS, BIBL, CERAM, TEC1/TEC2, Inf2/Inf3, A10DC | not subjects | CAVA |

The Séneca code family of es.md section 5 (LCL, GeH, ByG, FyQ, EPVA, TEC...) is confirmed on a real 2025-26 sheet, and the level digit is glued to the code.

## 3. Additions proposed for supabase/functions/_shared/school_subjects.ts (`es` list)

Codes lowercase without accents, as `fold` makes them. "Existing" means checked against the current `es` list and `AMBIGUOUS.es`. The parser must strip a trailing level digit ("ing1" becomes "ing"), "g1/g2" suffixes ("fr2g1") and "Grup A/B/C" suffixes; README section 6 item 5 already lists level and group suffixes, but ES sheets glue the digit on (CAVA).

### 3.1 Basque (add to the shared `es` list)

| name | codes | group | note |
|---|---|---|---|
| Gaztelania eta Literatura | gaztelania, gaztelera | first-language | the existing Spanish-language entry has no Basque word; "gaztelera" is how ARIM writes it |
| Ingelesa | ingelesa | english | "ingles" is 2 edits away, so the 1-edit snap will not catch it |
| Natura Zientziak | natura zientziak, natura | science | DBH 1-2 combined science (ABAD) |
| Gizarte Zientziak | gizarte, gizarte zientziak | social | snippets ORTU, ARES |
| Ingurunea | ingurunea | primary-studies | ARIM, ZURR, BOPV |
| Geografia eta Historia | geografia eta historia | history | existing code "geografia" already maps to history; the full name is printed in ABAD and ZARA |
| Heziketa Fisikoa | heziketa fisikoa, gorputz heziketa | sport | existing "gorputz" covers "Gorputz Hezkuntza" by prefix only |
| Plastika | plastika, hezkuntza plastikoa, artistika, arte hezkuntza | arts | existing has "plastica", "artistica" with a c; add for safety |
| Balio Zibiko eta Etikoak | balio, balioak, balio zibikoak | civics | ABAD, ZARA, BOPV |
| Komunitatearen zerbitzuak | komunitatearen zerbitzuak, komunitatearen zerbi | religion | the Basque ESO alternative to religion, stacked beside Erlijioa; Spanish "Proyecto de servicio a la comunidad" |
| Frantsesa | frantsesa | french | ABAD, ZARA |
| Teknologia eta Digitalizazioa | teknologia, teknologia eta digitalizazioa | crafts | existing codes use "c" (tecnologia) |
| Ongizate Fisikoa eta Emozionala | ongizate, ongizate fisikoa eta emozionala, osasun fisikoa eta emozionala | other | no existing group fits (Spanish "Bienestar físico y emocional") |
| Tutoretza | tutoretza | class | existing "tutoria" is 3 edits away |
| PIIH | piih | `AMBIGUOUS.es` | meaning not printed; placement suggests the visual-arts slot (arts only if a school confirms) |
| Euskara eta Literatura | existing: eus, euskara, euskera | co-official | already covered |

Break and care words: `atsedenaldia` (break, printed by ABAD and ZARA-T), `jantokia` (lunch, care group), `bazkalordua` (snippet only), `jolas-ordua` (snippet only). The existing `jolastordua` is not confirmed by any fetched sheet; the printed forms are "Atsedenaldia" and "Jolas-ordua".

### 3.2 Catalan primary additions

| name | codes | group | note |
|---|---|---|---|
| Art | art, arts escenics | arts | MPLA4 "ART", MPLA4/6 "ARTS ESCÈNIQUES" |
| Tallers | tallers, taller | other | MPLA, MBOR; "TALLERS CICLE MITJÀ / SUPERIOR" |
| Conversa | conversa | english | MPLA4 (stacked inside the English slot) |
| Projecte | projecte, projectes | other | MPLA6; "PROJECTES INTER." of es.md is not in the vocabulary either |
| Tutories individuals | tutories, tutories individuals | class | MPLA6; "tutoria" is 2 edits from "tutories" |
| Valors as the alternative to religion | existing "valors" maps to Valores Cívicos y Éticos | civics | MBOR stacks RELIGIÓ with VALORS: in Catalonia "Valors" is the alternative, so a family may hold civics or Atención Educativa for the same slot |
| Esmorzar a l'aula | esmorzar a l'aula, esmorzar | BREAKS | MPLA4/6 |
| Tarda | tarda | BREAKS | MBOR prints "12 a 15 TARDA" over the lunch gap |

School-specific names with no vocabulary value: ANIMALLETRES, RACONS, Entrena-MENT (MBOR). They should come out as unknown words for the parent to name.

### 3.3 Catalan ESO words (IMMH)

Not in the current list: `optativa` (group elective), "E.V.P i Audiovisual" (arts; add "evp"), "Comp. Speak Out" and "Comp. Taller d'escriptura" (complementary subjects, group other; prefix "comp."), "tecnologia i digitalitzacio" and "digitalitzacio" (crafts). `socials` and `religio` exist.

### 3.4 Andalusian ESO codes (CAVA, real 2025-26 sheet)

| name | codes | group | existing? |
|---|---|---|---|
| Tecnología y Digitalización | tecd | crafts | "tec", "tid" exist; "tecd" missing |
| Atención Educativa | ated | religion | only "alternativa" exists; "ae" is in AMBIGUOUS.es (Atención Educativa vs Artes Escénicas). Printed forms: ATED1, ATED2. Add "ated" (unambiguous), keep "ae" ambiguous |
| Religión Católica | rcat | religion | missing |
| Religión Islámica | risl | religion | missing |
| Religión Evangélica | rev | religion | missing |
| Educación en Valores Cívicos y Éticos | evce | civics | missing (existing: vce, ve, valores) |
| Computación y Robótica | cr | computing | missing |
| Oratoria y Debate | od, oyd | other | missing |
| Área Lingüística transversal | alct | support | missing (stacked beside Francés) |
| Sostenibilidad y Educación Ambiental | sost | science | missing |
| Proyecto Educativo de Plástica y Audiovisual | pepa | arts | missing |

Already covered: lcl, mat, ing, fr, geh, byg, fyq, epva, mus, ef, tut, apoyo, lengua.

### 3.5 Bilingual-school English words (STAI, location unverified)

"natural science" (science) and "music and dance" (music) are printed; "social science" and "arts and crafts" are speculation beyond the one sheet and should not be added.

### 3.6 Conflicts and collisions found

- No Basque or Catalan word collides with a Spanish code on the fetched sheets.
- `rev`, `risl`, `rcat`: no existing code shares the prefix. `rev` is 3 letters, so exact match only.
- `od` (2 letters) would sit among short tokens that look like weekday abbreviations; it matches no weekday, but put it under the protected two-letter list.
- Basque "Gizarte" can mean social studies or Geografia eta Historia; propose group "social".
- The `ae` conflict stays: ATED is the Séneca code for the same subject.
- No new `val` conflict: BAL6 prints "Català" for the Balearic co-official language, not "VAL".

## 4. Starter-list check (the `es` block of 20261023105000_starter_subjects.sql)

Starter: Lengua Castellana y Literatura LCL, Matemáticas MAT, Inglés ING, Conocimiento del Medio CM, Educación Plástica y Visual PLAS, Música MUS, Religión REL, Atención Educativa AE, Valores Cívicos y Éticos VCE, Tutoría TUT, Educación Física EF; plus per region: CT/IB Llengua Catalana i Literatura CAT, VC Valencià VAL, GA Lingua Galega e Literatura LG, PV/NC Euskara eta Literatura EUS.

| Region | What the sheets print | Match / change |
|---|---|---|
| Catalonia, primary | CATALÀ, CASTELLÀ, MATEMÀTIQUES, ANGLÈS, MEDI, MÚSICA, EDUCACIÓ FÍSICA, PLÀSTICA / ART, RELIGIÓ with VALORS, TUTORIA, LECTURA, TALLERS (MPLA4, MPLA6, MBOR) | Contents match. A Catalan list would use Catalan names (Llengua Catalana, Llengua Castellana, Matemàtiques, Anglès, Medi, Música, Educació Física, Plàstica, Religió, Valors, Tutoria) and add Lectura and Tallers. Primary sheets print the full word (CATALÀ), never "CAT". "Atención Educativa" is printed as VALORS or "Alternativa" |
| Catalonia, ESO | Català, Castellà, Matemàtiques, Anglès, Socials, Biologia i Geologia, Tecnologia i Digitalització, Educació Física, Música, Religió, Tutoria, Optativa (IMMH) | The starter is a primary list; it has no ESO subjects |
| Balearics | no sheet; names are Catalan; BAL6 snippet: Català, Castellà, Socials, Religió/Estudi, Pati | Catalan list as above is consistent; "Socials" stands for Medi and "Estudi" for the alternative. Not verified |
| Euskadi, primary | Euskara, Gaztelera / Gaztelania, Ingelesa, Matematika, Ingurunea, Musika, Artistika / Plastika, Gorputz Hezkuntza, Tutoretza / Balioak (ARIM, ZURR, BOPV) | Meaning matches, but a Basque family sees Basque words: Euskara eta Literatura, Gaztelania eta Literatura, Ingelesa, Matematika, Ingurunea, Musika, Plastika, Gorputz Hezkuntza, Balio Zibiko eta Etikoak (6th grade only), Tutoretza. Religion is not in the Basque primary area list (BOPV), only through the additional provision. Starter "EUS" is not printed on any sheet: Basque sheets print the full name |
| Euskadi, ESO | full names in Basque (ABAD, ZARA) including Natura Zientziak, Balio Zibiko eta Etikoak, Komunitatearen zerbitzuak, Frantsesa, PIIH | no ESO entries in the starter; the wellbeing and community-service subjects are new |
| Navarra | no sheet; model A sheets would be Spanish with Euskera as a subject; model D Basque | EUS (Euskera) is reasonable for model A; model D would print Basque names. Not verified |
| Galicia | earlier research: L. GALEGA, LINGUA GALEGA, COÑECEMENTO DO MEDIO, RELIXIÓN/ALTERNATIVA, VALORES SOCIAIS E CÍVICOS | LG matches; Galician names would be Lingua Galega e Literatura, Lingua Castelá, Matemáticas, Inglés, Coñecemento do Medio, Educación Física, Música, Plástica, Relixión/Alternativa, Valores Sociais e Cívicos |
| Andalusia | primary: full Spanish names (Salesianos, STAI); ESO: Séneca codes (CAVA) | Starter matches for primary. ESO: "Lengua" (not "Lengua Castellana y Literatura"), ATED for Atención Educativa, RCat, EVCE |

Cross-region: the starter's "Valores Cívicos y Éticos VCE" is printed as VALORS (CT), "Balio Zibiko eta Etikoak" (PV), EVCE (AN), "Valores Sociais e Cívicos" (GA), "Educación en Valores" (VC). The words proposed in section 3 cover these.

Missing from the starter for ESO families in all regions: Biología y Geología, Física y Química, Geografía e Historia, Tecnología y Digitalización, Francés. The vocabulary knows them, the starter list does not.

## 5. Gaps I could not close

1. **Basque primary grid**: no CEIP or ikastola publishes a subject grid on a reachable host; searches returned only entry and exit hours (Asti Leku, Zarautz, Azpeitia, Anaitasuna, San Fidel, Eguzkibegi, Kueto, Zipiriñe). The ZURR annex has the grid but is not in the PDF. Area names are confirmed (ARIM, ZURR, BOPV); cell abbreviations are not.
2. **Navarra, any level**: all Navarrese public schools sit on `*.educacion.navarra.es`, which refused me; private Navarrese schools (Jesuitas Pamplona, Escolapios) publish hours only. The Orden Foral 63/2022 annex (sessions per area) and the NAVPAMP split are unverified snippets.
3. **Balearics**: all public sheets are on `redols.caib.es`, which refused me, and public primary timetables live in GESTIB anyway (BALPGA). Private schools (La Salle Palma, La Immaculada, Aula Balear) publish hours only.
4. **Andalusian primary**: public CEIP sheets (blogsaverroes) refused me; the only Andalusian primary sheet known is the Salesianos one (es.md). The Séneca ESO legend is now confirmed (CAVA).
5. **Galician primary**: no new subject grid beyond the two in es.md.
6. **Meaning of PIIH** (Abadiño) and LFyQ (Cavaleri) is not given on the sheets.
7. **STAI's region** was not determined; do not count it for any region.
8. Not checked: Valencian primary beyond es.md, Bachillerato, the Orden Foral and Decret annexes with weekly hours.

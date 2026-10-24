# School subjects and their abbreviations: Germany, Switzerland, Austria, France, Spain

Research summary for the timetable scan (specs/24 "The family's words") and for the starter
subject lists. Compiled 2026-10-23 from five research parts kept beside this file:

| Part | Scope |
|---|---|
| [de-states-a-m.md](de-states-a-m.md) | Baden-Württemberg, Bayern, Berlin, Brandenburg, Bremen, Hamburg, Hessen, Mecklenburg-Vorpommern |
| [de-states-n-t.md](de-states-n-t.md) | Niedersachsen, Nordrhein-Westfalen, Rheinland-Pfalz, Saarland, Sachsen, Sachsen-Anhalt, Schleswig-Holstein, Thüringen; timetable software |
| [ch-at.md](ch-at.md) | Switzerland (Lehrplan 21, PER, Ticino, Graubünden), Austria |
| [fr.md](fr.md) | France (école, collège, lycée, lycée professionnel) |
| [es.md](es.md) | Spain (Primaria, ESO, Bachillerato, co-official languages) |
| [de-rp-st-th-nrw.md](de-rp-st-th-nrw.md) | Second round (2026-10-23): real sheets for Sachsen-Anhalt and NRW primary; names only for Rheinland-Pfalz and Thüringen |
| [ch-romandie-ticino-be-lu.md](ch-romandie-ticino-be-lu.md) | Second round: real sheets for Vaud and Ticino, lists for Neuchâtel and Fribourg; nothing readable for Geneva, Valais, Jura, Belgium, Luxembourg |
| [es-regions.md](es-regions.md) | Second round: Basque ESO sheets and primary names, Catalan primary sheets, an Andalusian Séneca export; nothing for Navarra and the Balearics |

The parts carry per-state and per-level tables with a source for every row. This summary
merges them into one list per subject group and one collision table, and says what the
matcher should do with it. Nothing here was checked against the pilot household's own
sheets beyond what specs/24 records; those sheets stay the ground truth.

## 1. How to read the confidence marks

The five parts use different tag names; this file reduces them to four:

| Mark | Meaning |
|---|---|
| **official code** | A ministry, canton or administration publishes the abbreviation itself (curriculum code table, school-administration key, decree). It is a *curriculum or admin code*, not necessarily what the school prints. |
| **official name** | The full subject name from a Stundentafel, decree or curriculum portal. No abbreviation implied. |
| **seen** | Printed on one real school's timetable or legend that the researcher read. One school, not a standard. |
| **usual** | General knowledge of what schools type into their software. Not confirmed by any source in this research. Alias material only, never evidence. |

Short codes written in `code` style below are abbreviations; names in plain text are full
subject names. A code followed by a region in brackets was found there; a code without a
region is usual everywhere in that language.

## 2. Findings that hold across all regions

1. **There is no abbreviation standard anywhere.** Curricula (KMK Stundentafeln, Lehrplan 21,
   the French programmes, the Spanish Reales Decretos) define *names*; the short code on the
   sheet is chosen by the school or typed into the software. Untis, WebUntis, Indiware, IServ,
   Sdui, Schulmanager, DaVinci, Pronote, EDT, UnDeuxTemps, Séneca, Itaca, Raíces and the others
   document no default code table; the subject short name is free master data per school.
2. **Official code lists exist in a few places only:** Baden-Württemberg (Bildungsplan 2016
   abbreviation tables), Bayern (ASV school-administration keys and the Gymnasium Lehrplan
   table), Sachsen (VwV Stundentafeln Anlage 7, binding for all school types), Saarland (a
   ministry slide deck: De, Ma, FS, NW, GW, R/E, AL, BK, Mu, Sp), Graubünden (Lehrplan 21
   abbreviation list of 2017), Neuchâtel (cantonal decree), and the Austrian Akademisches
   Gymnasium list with an "offiziell" column. Everywhere else the codes come from school
   legends.
3. **Full names are well documented** per state, canton and country and are the safest
   matching material; the short codes are the fuzzy part.
4. **The same code means different subjects in different places** (section 5). Within one
   country the collisions are rare; across languages they are frequent, and several codes
   collide with weekday abbreviations. This is why the scan sends the family's language and
   its subject names (specs/24).
5. **Recent renamings** change what a sheet prints: Hessen 2025 (Erdkunde → Geographie,
   Klassenlehrerstunde → Klassenleitungsstunde), Bayern Mittelschule (GSE → GPG, AWT → WiB,
   PCB → NT), Baden-Württemberg (NwT → NIT from 2027/28), Austria 2023/24 (Bildnerische
   Erziehung → Kunst und Gestaltung, Werken → Technik und Design, Musikerziehung → Musik),
   Spain LOMLOE 2022 (Tecnología → Tecnología y Digitalización, Valores Éticos → Educación en
   Valores Cívicos y Éticos, PMAR → Diversificación Curricular), France 2019 lycée reform
   (séries L/ES/S → specialities such as HGGSP, NSI, LLCER; Enseignement scientifique).
   Old and new names both appear on sheets for years.
6. **Many sheets print a legend.** Swiss and Spanish sheets almost always do; Untis exports
   often print full names in a footer. A legend on the sheet beats every list here, and
   reading it is the natural next step for the parser.
7. **Parentheses and suffixes are not part of the subject.** Teacher codes and rooms stand in
   parentheses or on the second line of a cell (specs/24 already strips them); Valencian
   sheets put *rooms* in parentheses that look like subjects (`MAT1`, `INF1`, `PATI1`,
   `GIMNÀS`); French sheets add the week marker (`Q1`/`Q2`, `A`/`B`, `S1`/`S2`); German and Swiss
   sheets add level or group suffixes (`E1`, `F3`, `Math Sek`, `DEU Real`, `M*`, `Knaben D`).

## 3. The canonical groups

Seventeen groups cover every subject found. The group is what the matcher needs when the
exact subject cannot be told (and what a starter subject list is built from); the alias lists
inside each group are what the OCR token is compared with.

| # | Group | Why it is one group |
|---|---|---|
| 1 | First language (language of instruction) | Deutsch, Français, Italiano, Rumantsch, Castellano and the co-official languages |
| 2 | Mathematics | incl. Geometrie, Geometrisches Zeichnen, Calcul |
| 3 | Foreign and ancient languages | one group, the *language* is the detail worth keeping |
| 4 | Natural sciences | Physik, Chemie, Biologie and every combined form |
| 5 | Primary general studies | Sachunterricht, NMG, Questionner le monde, Conocimiento del Medio |
| 6 | Social sciences | history, geography, politics/civics, economics and their combinations |
| 7 | Visual arts | Kunst, Bildnerisches Gestalten, Arts plastiques, Plástica, theatre as a school subject |
| 8 | Music | |
| 9 | Sport | incl. swimming |
| 10 | Religion, ethics, philosophy | every confession, the ethics alternatives, philosophy |
| 11 | Crafts, technology, home economics | Werken, TTG, Technik, Hauswirtschaft, Technologie, Tecnología |
| 12 | Computer science and media | Informatik, MI, SNT/NSI, TIC |
| 13 | Study time, support, remedial | Förder-, Lernzeit, AP, Devoirs faits, Refuerzo, electives slots |
| 14 | Care and after-school | Hort, Tagesschule, périscolaire, comedor, lunch supervision |
| 15 | Class council, tutor time | Klassenrat, Vie de classe, Tutoría |
| 16 | Breaks and lunch | Pause, Hofpause, Récré, Recreo, Esplai (not lessons) |
| 17 | Other | career orientation, projects, electives, heritage languages, annotations |

Groups 1 to 12 are subjects a family keeps as subjects. Groups 13 to 15 are lessons without a
"subject" in the school sense; the app still needs them as subjects so that the sheet is
complete. Group 16 is what the parser should *not* turn into a lesson. Group 17 is left to the
parent.

### 3.1 First language

| Region | Names | Codes |
|---|---|---|
| DE | Deutsch; Deutsch als Zweitsprache; Herkunfts-/Muttersprachlicher Unterricht; Niederdeutsch (MV); Sorbisch/Wendisch (BB, SN); Schriftspracherwerb, Sprachbildung (BB, TH); Deutsch-Sachunterricht block (SN, RP Kl. 1–2); Lesezeit (MV, RP, not a subject) | official: `D` (BW, BY), `DE` (SN), `DaZ` (BY, SN), `De` (SL), `DE-SU`, `DE-HKS`, `HU`, `SMU` (SN); seen: `d`, `Deu`, `DaZ`, `FDeR` (Förder-Deutsch, NI); usual: `Deu`, `De`, `Dt`, `Ma`-style two-letter forms |
| CH-de, AT | Deutsch; Schulsprache; Deutsch (Schulsprache) (LP21); "Deutsch, Lesen, Schreiben" (AT Volksschule, inside Gesamtunterricht); Muttersprache; Tastaturschreiben | `D`, `DE`, `DEU`; `D Kurs` (AT); `WF-TAS`, `RE-TAS` (GR electives) |
| CH-fr | Français (L1); Français renforcement | official (NE): `FRA`, `FRR`; usual `Fr` |
| CH-it | Italiano; Dattilografia | `I`, `ITA`, `MF-DAT` |
| GR Romansh | Rumantsch | `R` (collides with Religion) |
| FR | Français; Lettres (lycée); primary sub-slots: Lecture, Écriture, Dictée, Étude de la langue, Grammaire, Conjugaison, Orthographe, Vocabulaire, Poésie, Littérature, Production d'écrits, Langage oral, Graphisme; Lettres-Histoire (lycée pro); FLE, FLS, UPE2A | `FR`, `FRANC`, `FRANCAIS`; group slots `FRANCAIS GR1/GR2` |
| ES | Lengua Castellana y Literatura; Lengua Cooficial y Literatura (Català/Valencià, Galego, Euskara); Literatura Universal; Lectura, Llegim, Hora de ler; Ámbito lingüístico y social (PDC, mixed with group 6) | seen: `CLL`, `CAST`, `CASTELLÀ`, `L.CASTELLANA`, `LINGUA CASTELÁ`, `L Cast`, `VLL`, `VAL`, `Cat`, `CATALÀ`, `L. GALEGA`, `LitUNIVER`, `LECTURA`; snippet: `LCL`, `Gaztelania`, `H.L`; usual: `LENG`, `LEN`, `LC`, `LV`, `LG`, `Euskera` |

### 3.2 Mathematics

| Region | Names | Codes |
|---|---|---|
| DE | Mathematik; Mathematik Additum (BY `M+T`); Mathematische Basiskompetenzen (BE/BB) | official: `M` (BW, BY), `MA` (SN), `Ma` (SL); seen: `m`, `Ma`, `Mat`, `FMa` (Förder-Mathe, NI); usual `Mathe` |
| CH, AT | Mathematik; Mathematik und Geometrie; Geometrisches Zeichnen (AT); Mathematische Früherziehung (AT Vorschule); track suffixes "Math Sek", "Math Real" | `M`, `MA`, `MAT`, `Math`, `Mathe`, `GZ`, `GEOM`; electives `WF-MA`, `RE-MA`, `MF-MA`; `MF` is also Mathematik-Förderung (AT) |
| CH-fr | Mathématiques; Mathématiques renforcement | `MAT`, `MTR` (NE) |
| CH-it | Matematica (corso base / attitudinale) | `MAT` |
| FR | Mathématiques; primary sub-slots Calcul mental, Numération, Calcul, Géométrie, Résolution de problèmes, Grandeurs et mesures; Maths expertes, Maths complémentaires (lycée); Maths-Sciences (lycée pro, mixed with group 4) | `MATHS`, `MATH`, `MA`, `MATHEMATIQUES`, `MATHS EXP`, `M.EXP`, `ME`, `MC`, `MATHS-SC`, `MATH-PC` |
| ES | Matemáticas; Matemáticas A / B (4º ESO); Matemáticas I/II, Aplicadas a las CCSS I/II, Generales (Bachillerato) | seen: `MAT`, `Mat`, `MATEMÁTICAS`, `MATEMÀTIQUES`, `MAT 1`, `MAT 2`, `MCSS`, `Mat Ap`; usual `MATE`, `MATES`, `MAT A/B`, `MACS`; snippet `MAC`, `MAP`, `Matematika` |

### 3.3 Foreign and ancient languages

Keep *which* language when the code says so; the group alone is the fallback.

| Language | DE | CH, AT | FR | ES |
|---|---|---|---|---|
| English | `E`, `E1`, `E2` (BW, BY official); `EN` (SN), `En` (SL); seen `e`, `Eng`, `FEn`; usual `Engl` | `E`, `E1`…`E6` (level suffix), `ENG`, `ENGL`; `LFE` (AT Lebende Fremdsprache Englisch); `ANG` (CH-fr), `ING` (CH-it) | Anglais: `ANG`, `ANGL`, `AGL`, `ANG LV1`; `LLCER Anglais`, `AMC` | Inglés: `ING`, `IN`, `ANG`, `INGLÉS`, `ANGLÈS`, `Ing`; `Conversa`, `CLIL`/`EMILE`; usual `LE` |
| French | `F`, `F1`…`F4` (BW, BY); `FR` (SN), `Fr` (SL); seen `f`, `Frz`, `Fra`; `FiwA`/`FiwF` (BY Waldorf) | `F`, `FRA` (= Französisch in CH-de, = first language in CH-fr), `Fr`; `F/LAT` | — (first language) | Francés: `FRANCÉS`, `FR`, `FR2`, `Francès` |
| German | — | `ALL`, Allemand (CH-fr); `Ted`, Tedesco (CH-it); `D` in GR Romansh/Italian schools | Allemand: `ALL`, `ALLEMAND LV2` | Alemán: `ALE` (inferred), `AL` |
| Spanish | `Sp` (BY official, collides with Sport elsewhere); `SPA3`, `SPA4` (BW); `SPA` (SN); seen `Spa` | `SPA`, Spanisch, espagnol | Espagnol: `ESP`, `ESPAGNOL LV2`, `LLCER ESP` | — |
| Italian | `It` (BY); `ITAL3/4` (BW); `ITA` (SN) | `I`, `ITA`, Italiano; `OLM` (NE, Italian/Spanish option) | Italien: `ITA` | — |
| Latin | `L`, `L1`…`L4` (BW, BY); `LA` (SN); seen `Lat` | `L`, `L6`, `LAT`, Latein, Latino; `LCA`, `OLA` (CH-fr) | Latin: `LAT`, `LATIN`, `LCA Latin`, `LLCA Latin` | Latín: `LAT`, `Lat`, `LLATÍ` |
| Greek | `Gr` (BY), `GR3/4` (BW), `GR` (SN) | `GRA`, `G` (AKG), Griechisch, grec | Grec: `GREC`, `GRC`, `LCA Grec` | Griego: `GREC`, `GRI`; Cultura Clásica `CC`, `CCO` |
| Russian | `Ru` (BY), `RU2`…`RU4` (BW), `RU` (SN) | — | `RUS` | — |
| Others | Türkisch `TUERK4`, `Tür`; Chinesisch `CHIN4`, `CHI` (SN); Japanisch `JAP4`; Portugiesisch `PORT3/4`, `Po`; Hebräisch `HEBR4`, `HE` (SN); Polnisch `POL`; Tschechisch `TSC`, `Ts`; Sorbisch `SOR`; Arabisch `Arab`; Niederländisch (NI); Dänisch (SH); Gebärdensprache (BE/BB) | Chinese `CHI`, `CHIN` (AKG); Romansh as foreign language `WF-R`, `MF-R` | `PORT`, `CHI`, `RUS`, `ARA`, `JAP`; regional: Breton, Occitan, Basque, Corse, Alsacien, Créole, `LCR` | Lenguas de signos |
| Unspecified slot | Fremdsprache, 1./2./3. Fremdsprache `FS`, `1. FS` (SN, SL), spät beginnend `spb` (BY), Begegnungssprache (BB), Sprachkurs (SL) | Lebende Fremdsprache, "1./2. lebende Fremdsprache" (AT) | `LV`, `LVE`, `LV1`, `LV2`, `LV3`, `LVA`, `LVB`, `LVC`; `LCA`, `LLCA`; programme labels `Bilangue`, `Euro`, `SELO`, `DNL`, `ETLV` | Lengua Extranjera, Segunda Lengua Extranjera; `LE` |

Heritage-language lessons (ESU, HSK, LCO, Herkunftssprache) belong to group 17, not here.

### 3.4 Natural sciences

| Region | Names | Codes |
|---|---|---|
| DE | Physik, Chemie, Biologie (all states); combined: Naturwissenschaften (BE/BB "Nawi 5/6", "Nawi 7-10"; HB; HH "Naturwissenschaften/Technik"; MV; HE; NI, NW, SL, SH, RP), Natur und Technik (BY `NuT`/`NT`), Biologie, Naturphänomene und Technik (BW `BNT`), Naturwissenschaft und Technik (BW `NwT`, → `NIT`), IMP (BW), Natur, Technik und Informatik (SN `NTI`), Mensch-Natur-Technik (TH `MNT`), PCB (BY old), NWA (BW RS old), Astronomie (TH, ST, SN, BE/BB; BY `Ph Ast`), Erziehungskunde (BY RS) | official: `BIO`, `CH`, `PH`, `BNT`, `NWT`, `IMP` (BW); `B`, `C`, `Ph`, `NT`, `NuT`, `BcP`, `ErK` (BY); `BIO`, `CH`, `PH`, `NTI`, `AST` (SN); `Bi`, `CH`, `Ph`, `NW` (SL); `MNT`, `NWuT` (TH); seen: `Bio`, `Che`, `Phy`, `Ch`, `b`, `NaWi`, `NAT`, `NW`; usual: `Chem`, `Phys` |
| CH-de | Natur und Technik (LP21 cycle 3, "mit Physik, Chemie, Biologie"); Naturwissenschaften; Wissenschaft und Technik (SO) | `NT`, `NAWI`, `NaWi` |
| AT | Biologie und Umweltkunde / Umweltbildung; Chemie; Physik; Naturwissenschaftliches Labor; Humanbiologie | `BU`, `BIU`, `BUK`, `BIUB`; `CH`; `PH`, `PHY`; `LAB-BIO`, `LAB-CH`, `HUM` |
| CH-fr | Sciences de la nature; domain MSN; option sciences expérimentales | `SN`, `SCN`, `MSN`, `OSE` |
| CH-it | Scienze naturali | `Scienze` |
| FR | SVT (Sciences de la vie et de la Terre); Physique-chimie; Enseignement scientifique (lycée common core); Biologie-écologie; BPH, SPCL, PCS (technological series); Maths-Sciences (lycée pro) | `SVT`, `SC.VIE & TERRE`, `PC`, `PH-CH`, `PHYS-CH`, `PHYS-CHIM`, `PHYSIQUE-CHIMIE`, `Phys/Chimie`, `SPC`, `SC.PHYSIQUES`, `ENS SCIENTIFIQUE`, `ENS.SCI.`, `EnsSci`, `BIO-ECO`, `BPH` |
| ES | Biología y Geología; Física y Química; Ciencias de la Naturaleza (primary split); Bachillerato: Biología, Geología y Ciencias Ambientales, Física, Química, Ciencias Generales, Anatomía Aplicada; Ámbito científico-tecnológico (PDC, mixed with group 11) | seen: `BIO`, `CN (BiG)`, `FQ`, `BGC`, `Anat Apl`, `CIENCIAS NATURAIS`; snippet `ByG`, `FyQ`, `C.N`; usual `BG`, `BYG`, `FYQ`, `CN`, `CCNN` |

### 3.5 Primary general studies

| Region | Names | Codes |
|---|---|---|
| DE | Sachunterricht (most states); Heimat- und Sachunterricht (BY); Heimat- und Sachkunde (TH); Heimatkunde (SN historical); Sachkunde (school legends); Mensch, Natur und Kultur (BW 2004); Vorfachlicher Unterricht (BE); BY Kl. 1–2 "Grundlegender Unterricht" block (Deutsch, Mathe, HSU, Musik, Kunst as one 16-hour block) | official: `SU` (BW, SN), `HSU`, `GU KuMuHSU` (BY), `HK`, `DE-SU`, `DE-HKS` (SN); seen: `Sa/SU`, `Su`, `VU`; usual: `Sach`, `Sachk`, `SK`, `HSK` |
| CH-de | Natur, Mensch, Gesellschaft (LP21 cycles 1–2) | `NMG`, `WF-NMG` |
| GR Romansh / CH-it | Natira, uman e societad; Natura, essere umano, società; Studio d'ambiente (Ticino) | `NUS`, `NEUS`, `RE-NUS`, `MF-NEUS` |
| AT | Sachunterricht; Sachbegegnung (Vorschule); Gesamtunterricht (mixed block) | `SU`, `GU` |
| CH-fr | Connaissance de l'environnement (VD 5P–6P); Découverte de l'environnement | `CE` |
| FR | Questionner le monde (cycle 2); Découverte du monde (pre-2016); Sciences et technologie (cycle 3) | `QLM`, `QM`, `Sciences` |
| ES | Conocimiento del Medio Natural, Social y Cultural; printed split into Naturales / Sociales goes to groups 4 and 6 | seen: `Conocimiento del Medio`, `COÑECEMENTO (DO MEDIO)`, `C. Medi`, `CONE. DEL MEDI`, `MEDI`; usual `CM`, `CMNSC`, `Ingurunea` |

### 3.6 Social sciences

| Sub-area | DE | CH, AT | FR | ES |
|---|---|---|---|---|
| History | Geschichte: `G` (BW, BY), `GE` (SN), `Ge`, `Ges`, `Gesch`; Weltkunde (MV, SH, NI); GPG, GSE (BY MS, combined) | Geschichte, Geschichte/Staatskunde (SO): `GES`*, `GS (RZG)`, `H` (AKG), `HIS`; Histoire `HIS`; Storia `ST`; Istorgia `IST`; AT Geschichte und Sozialkunde / Politische Bildung `GS`, `GSK`, `GSPB` | Histoire-géographie: `HG`, `HIST-GEO`, `HI-GE`, `HIST.GEO`, `HISTOIRE & GEOGRAPH.`, `HG-EMC`, `HGEMC`; `HGGSP` (speciality) | Geografía e Historia: `GH`, `GeH`, `GEH`, `HIST`, `CS` (Ciències Socials), `CCSS`, `CIENCIAS SOCIAIS`; Historia de España `HE`, del Mundo Contemporáneo `HMC`, del Arte `HA` |
| Geography | Geographie / Geografie / Erdkunde: `GEO` (BW, SN), `Geo` (BY), `Erd`, `Ek`; Hessen 2025 Erdkunde → Geographie | Räume, Zeiten, Gesellschaften `RZG` (LP21), `STS` (Romansh/Italian), `GG (RZG)`; Geografie `GEO`; AT Geographie und Wirtschaftskunde → wirtschaftliche Bildung `GWK`, `GW`, `GWB`, `GG` (AKG) | inside HG; Géographie, `Géo` | inside GH; Geografía |
| Politics, civics | Gemeinschaftskunde `GK` (BW, SN "/Rechtserziehung"); Politik und Gesellschaft `PuG`, Sozialkunde `Sk` (BY); Politische Bildung `PB` (BE/BB); Politik-Gesellschaft-Wirtschaft `PGW` (HH); Politik-Wirtschaft (NI), Wirtschaft-Politik (NW), Wirtschaft/Politik `WiPo` (SH); Politik und Wirtschaft `PoWi` (HE, NI); Sozialkunde (RP, ST, TH, SL) | Politische Bildung, Staatskunde; Monde contemporain et citoyenneté `MCC`, Citoyenneté, Civisme; Educazione civica `ECCD` | Enseignement moral et civique `EMC`, `ENS.MORAL & CIVIQUE`, Éducation civique, `ECJS` (old), `DGEMC` | Educación en Valores Cívicos y Éticos goes to group 10 in this list (it replaces the religion alternative) |
| Combined area | Gesellschaftswissenschaften `GeWi` (BE/BB; `GW` SL; HH); Gesellschaftslehre `GL` (HE, NW, RP, NI IGS), `GES` (CSN); "Gesellschaft" (HH); Welt-Zeit-Gesellschaft (BW HS); Gesellschaft und Wirtschaft `GuW`, `G/R/W` (SN) | domain SHS (PER); option sciences humaines `OSH` | — | Ámbito lingüístico y social (PDC) |
| Economics | Wirtschaft und Recht `WR` (BY, TH); WBS, `WI` (BW); Wirtschaft `W`; Wirtschaft und Beruf `WiB`, Wirtschaft und Kommunikation `WiK` (BY MS); WAT / W-A-T (BB, BE, HB, also group 11); AWT (BY old, MV, NI IGS); BwR (BY); Arbeitslehre (HE, HH, group 11); Wirtschaft-Recht-Technik, Wirtschaft-Umwelt-Europa (TH); Arbeitswelt Wirtschaft `AW` (NW WP) | Wirtschaft, Arbeit, Haushalt `WAH` (LP21, also group 11); économie et droit (VD) | SES (Sciences économiques et sociales); Économie-gestion `ECO-GEST`, `ECO-DROIT`, Management, `SGN`, `STSS`; `ES` is ambiguous (Enseignement scientifique / SES / old série) | Economía, Economía y Emprendimiento, Empresa y Diseño de Modelos de Negocio: `Eco`, `ECO`, `EE`; `FOPP`; Psicología `PSI` |

\* `GES` means Gestalten (group 11) on Bern sheets, Geschichte in Niedersachsen; see section 5.

### 3.7 Visual arts

| Region | Names | Codes |
|---|---|---|
| DE | Kunst; Bildende Kunst (BW, RP, SL); Kunsterziehung (TH, ST); Gestalten (ST GS); Kunst/Werken (BW GS `KUW`); Kunst/Modellieren (SN); Darstellendes Spiel / Theater (HH Pflicht Kl. 1–6, NI, SH, RP, BE/BB, SN `DS`); Darstellen und Gestalten (NW WP `DG`); Literatur und Theater `LUT` (BW Oberstufe) | official: `BK`, `KUW`, `BKPROFIL` (BW), `Ku` (BY), `KU`, `Ku/M` (SN), `BK` (SL); seen: `bk`, `BK`, `Ku`, `Kun`; usual: `Kunst`, `Bi`, `BiKu`. **`K` is Katholische Religion in BY, not Kunst.** |
| CH-de | Bildnerisches Gestalten (LP21) | `BG`, `BIG`, `WF-BG`, `GESb` (Sumiswald) |
| GR Romansh / CH-it | Art figurativ / Arti figurative; Educazione visiva; Educazione alle arti plastiche (Ticino) | `AF`, `RE-AF`, `MF-AF`, `EV`, `Ed. visiva`, `EAP` |
| AT | Bildnerische Erziehung → Kunst und Gestaltung (2023/24); Zeichnen; Fotografie und Video; Töpfern | `BE`, `KuG`, `FV`, `TÖ`; **not `KG`**, which is Kindergarten in CH |
| CH-fr | Arts visuels; domain ART; Dessin technique et artistique | `AVI`, `AV`, `ODE` |
| FR | Arts plastiques; Arts visuels; Histoire des arts; lycée speciality Arts (plastiques, cinéma-audiovisuel `CAV`, histoire des arts, musique, théâtre, danse); Arts appliqués `AACA` (lycée pro); Design (STD2A); Théâtre | `ARTS PLAST`, `ARTS PLASTIQUES`, `A.PLA`, `ARTP`, `AP` (ambiguous with accompagnement personnalisé), `HDA` |
| ES | Educación Plástica, Visual y Audiovisual; Educación Artística (primary, unsplit, default here); Expresión Artística (4º ESO); Artes Escénicas; Bachillerato Artes subjects (Dibujo Artístico, Cultura Audiovisual, Volumen, Diseño, …) | seen: `EPVA`, `PLÁSTICA`, `E. PLÁSTICA`, `EDU. PLÀSTICA I VISUAL`, `Plàstica i visual`, `Visual i Plàstica`, `ARTS ESCÈNIQUES`; snippet `EPV`, `Plastika`; usual `PLAS`, `EA` |

### 3.8 Music

| Region | Names | Codes |
|---|---|---|
| DE | Musik; Chor, Orchester, Instrumentalunterricht, Bläserklasse; Rhythmisch-musikalische Erziehung (SN); erweiterter Musikunterricht (BY) | official: `MUS`, `MUSPROFIL` (BW), `Mu`, `Cho`, `Orc`, `Ins` (BY), `MU`, `KU/MU`, `Rhy` (SN), `Mu` (SL); seen `Mu`, `Mus` |
| CH, AT | Musik; Musikerziehung → Musik (AT 2023/24); Musikalische Grundbildung / Grundschule; Spielmusik; Rhythmik (AT Vorschule); Chor, Blockflöte, Ukulele, Band | `MU`, `Mu`, `MUS`, `ME`, `MG`, `MGS`, `SPM`, `CHOR`, `VOK`, `ORCH`, `BLO`, `UK`, `BA`, `SLST`; electives `WF-MU`, `RE-MU`, `MF-MU` |
| CH-fr, CH-it | Musique; Educazione musicale | `MUS`, `Ed. musicale` |
| FR | Éducation musicale; Musique; Chant, Chorale, Chant choral; CHAM classes | `EM`, `ED.MUS`, `ED MUSICALE`, `EDUC MUSIC`, `ED.MUSICALE`, `ED.MUSICALE & CHANT.`, `CHAM`, `TMD` |
| ES | Música; Música y Danza; Bachillerato: Análisis Musical, Coro y Técnica Vocal, Lenguaje y Práctica Musical, Historia de la Música y de la Danza | seen `MUS`, `MÚSICA`, `MÚSICA I DANSA`; snippet `Musika` |

### 3.9 Sport

| Region | Names | Codes |
|---|---|---|
| DE | Sport; Bewegung, Spiel und Sport (BW GS); Sport und Schwimmunterricht (BB); Basissportunterricht, Differenzierter Sportunterricht (BY); Schwimmen; Profilsport (SN); Sporttheorie (BY) | official: `SPO`, `SPOPROFIL`, `BSS` (BW), `S`, `Sm`, `Sw`, `Smw`, `SpT` (BY), `SPO`, `PS`, `SPO/m/w` (SN), `Sp` (SL); seen: `S`, `Sp`, `Spo`, `Sw` (Schwimmen); usual `Spt`. **`Sp` is Spanisch in Bayern's official keys.** |
| CH-de, AT | Bewegung und Sport (LP21, AT); Sport; Turnen; Schwimmen; "Bewegung und Sport Mädchen/Knaben" | `BS`, `BSP`, `BSPM`, `BSPK`, `SP`, `SPO`; course codes `BALL`, `FUSB`, `VBAL`, `VOL`; `HH` (Hip Hop, Steffisburg) |
| GR Romansh / CH-it | Moviment e sport; Educazione fisica (e sport) | `MS`, `EF`, `EFS`, `Ed. fisica` |
| CH-fr | Éducation physique; domain Corps et mouvement | `EPH`, `CM`, `CMV`; `EPS` not confirmed in Swiss sources |
| FR | Éducation physique et sportive; Natation, Piscine, Gym, Motricité (primary); UNSS / AS (association sportive); EPPCS (speciality) | `EPS`, `ED.PHYSIQUE & SPORT.`, `ED.PHYS`, `Sport`, `UNSS`, `AS` |
| ES | Educación Física | seen `EF`, `E. FÍSICA`, `EDU. FÍSICA`, `EDUCACIÓ FÍSICA`, `EF 1`, `EF 2`; snippet `E.F`, `Gorputz Hezkuntza`; unverified `TAEF`, `AEF` |

### 3.10 Religion, ethics, philosophy

| Region | Names | Codes |
|---|---|---|
| DE | Religionslehre / Religion (evangelisch, katholisch, altkatholisch, alevitisch, islamisch, jüdisch, orthodox, syrisch-orthodox, …); Religion as non-confessional state subject (HB); Ethik (BW, BY, BE, SN, TH, RP, ST, SL); Werte und Normen (NI); Praktische Philosophie (NW); Philosophie (HH, HB, NI, SH, BE/BB, BY); Lebensgestaltung-Ethik-Religionskunde (BB); Philosophieren mit Kindern (MV); Humanistische Lebenskunde (BE/BB); Islamischer Unterricht (BY); Psychologie (Oberstufe); Biblischer Unterricht (private) | official BW: `REV`, `RRK`, `RAK`, `RALE`, `RISL`, `RJUED`, `RORTH`, `RSYR`, `ETH`, `PHIL`, `PSY`; BY: `Ev`, `K`, `Eth`, `IsU`, `Isr`, `FR`, `NR`, `RC`, `Ort`, `Rl`, `Phi`; SN: `RE/e`, `RE/k`, `RE/j`, `ETH`; SL: `R/E`; BB: `LER`, `L-E-R`; seen: `EvR`, `evr`, `KR`, `Eth`, `Phi`, `Psy`, `Re`, `Rel`, `Reli`, `WuN`, `Isl.Rel.`, `BU`; usual: `Rel`, `Re`, `R`, `Rev`, `Rk`, `Kath`, `ev`, `kath`, `PP` |
| CH-de | Ethik, Religionen, Gemeinschaft (LP21); Religionen, Kulturen, Ethik (ZH); Lebenskunde; Kirchliche Unterweisung; Religion | `ERG`, `RKE`, `RE`, `REL`, `KUW` (Kirchliche Unterweisung, **not Kunst/Werken as in BW**) |
| GR Romansh / CH-it | Etica, religioni, comunità; Storia delle religioni; Insegnamento / Istruzione religiosa | `ERC`, `SdR` |
| AT | Religion (röm.-kath., evang., islamisch, orthodox, …); Ethik; Psychologie und Philosophie (Oberstufe) | `R`, `REL`, `REL ev`, `RL`, `RK`, `REV`, `RGRO`, `R (kath.)`, `R (ev.)`, `Islam`, `ETH`, `PuP`, `PP`, `PUP` |
| CH-fr | Enseignement religieux; Éthique et cultures religieuses ("Histoire - ECR"); Histoire des religions | `ER`, `ECR` |
| FR | Philosophie (terminale); Culture / Instruction religieuse (Alsace-Moselle), Aumônerie, Pastorale (private schools); EMC sits in group 6 | `PHILO`, `PHIL` |
| ES | Religión; Atención Educativa / Alternativa (the non-religion slot); Educación en Valores Cívicos y Éticos (Valores Éticos before LOMLOE); Filosofía, Historia de la Filosofía | seen: `REL`, `RELIXIÓN`, `RELIGIÓ`, `RELIXIÓN /ALTERNATIVA`, `AE`, `At. Educativa`, `Alternativa`, `VALORS`, `Ed. Valors`, `EDUCACIÓ EN VALORS`, `VALORES SOCIAIS E CÍVICOS`, `Act. Cív.`, `FIL`, `HF`; snippet `REL.`, `VE`, `ECDH`; usual `VCE`, `Erlijioa` |

### 3.11 Crafts, technology, home economics

| Region | Names | Codes |
|---|---|---|
| DE | Werken (und Gestalten); Textiles Gestalten / Textillehre; Technik; Technisches Zeichnen; Technologie; Hauswirtschaft; Ernährung und Soziales (BY MS); Alltagskultur, Ernährung, Soziales (BW `AES`); Mensch und Umwelt (BW RS old); Arbeitslehre (HE, HH, SN, SL, NW); Wirtschaft-Arbeit-Technik (BB, BE, HB); Arbeit-Wirtschaft-Technik; Wirtschaft-Technik-Haushalt/Soziales (SN); Technik/Computer (SN); Verbraucherbildung (SH); Schulgarten; Gartenbau, Handarbeit, Textilarbeit mit Werken (BY Waldorf); Töpfern | official: `T`, `AES`, `KUW` (BW); `WG`, `We`, `TG`, `Te`, `T`, `ES`, `Hw`, `GaB`, `HAr`, `HaG`, `TaW` (BY); `WAT`, `W-A-T` (BB/BE); `WE`, `AL`, `WTH`, `HW`, `TC`, `AuB` (SN); `AL` (SL); seen: `AWT`, `Hw`, `Te` (Textil, NI), `We`, `Tö`, `TG`; usual: `Tec`, `Tech`, `TW`, `Werk`, `HuS`, `HS`, `AL`, `Nadelarbeit` |
| CH-de | Textiles und Technisches Gestalten (LP21); Technisches / Textiles Gestalten; Wirtschaft, Arbeit, Haushalt (incl. the practical Hauswirtschaft lessons); Hauswirtschaft, Haushalt, Kochen | `TTG`, `TxG`, `TcG`, `TG`, `GES`, `GES tx`, `GES tc`, `GEStt`, `GESt` (Bern), `WF-TTG`, `WAH`, `HW`, `KO`, `WF-KO`, `GC` |
| GR Romansh / CH-it | Arti tessili e tecniche / Art textil e tecnic; Economia domestica; Cucina | `ATT`, `RE-ATT`, `MF-ATT`, `ELT`, `ELED`, `RE-CU`, `MF-CU` |
| AT | Werkerziehung → Technik und Design (2023/24); Technisches / Textiles Werken; Ernährung und Haushalt | `WE`, `TuD`, `TD`, `TCW`, `TGW`, `WTX`, `WTC`; `TEW`, `TXW` not found in sources |
| CH-fr | Activités créatrices manuelles; Économie familiale; Éducation nutritionnelle | `ACM`, `AC&M`, `OCM`, `EFA`, `OCET` (Ticino option) |
| FR | Technologie (collège); Sciences de l'ingénieur `SI`, `SII`; STI2D, ITEC, 2I2D, CIT (lycée); Enseignement professionnel, Atelier, TP, Pratique prof. (lycée pro); SEGPA workshops | `TECHNO`, `TECH`, `EP` |
| ES | Tecnología y Digitalización; Tecnología; Tecnología e Ingeniería; Dibujo Técnico; Tallers / Taller; Projecte Interdisciplinar; Ámbito de carácter práctico (PDC) | seen: `TID`, `Tecno`, `TIE`, `DT`, `TALLERS`, `LAB CA`, `LAB AE`, `PROJECTES INTER.`; snippet `TEC`, `Teknologia`; usual `TD`, `Taller` |

### 3.12 Computer science and media

| Region | Names | Codes |
|---|---|---|
| DE | Informatik; Informatik und Medienbildung (BW, MV); Informationstechnologie (BY RS "IT"); Informatik und digitales Gestalten (BY MS); Aufbaukurs Informatik, Basiskurs Medienbildung (BW); ITG (BW RS old); Wirtschaftsinformatik (BY); Medienkunde / Medienkompetenz (NI, SH, BY); Textverarbeitung (BY); Technik/Computer, Natur-Technik-Informatik (SN); Computerunterricht | official: `INF`, `INFWF`, `INF7`, `BMB` (BW); `Inf`, `WIn`, `IdiG`, `Mk`, `Me`, `Tv` (BY); `INF`, `TC`, `NTI` (SN); seen: `Inf`, `Info`, `Mk`, `PC`, `Com`; usual `IT`, `ITG` |
| CH-de | Medien und Informatik (LP21 module); Informatik; Informatische Bildung (SO); Tastaturschreiben | `MI`, `WF-MI`, `RE-MI`, `MF-MI`, `INF`, `PRO` (Programmieren), `KaB` |
| AT | Digitale Grundbildung; Informatik | `DG`, `DGB`, `INF` |
| CH-fr, CH-it | Éducation numérique; MITIC; Informatique et médias et images (GE); Bain informatique (VD); Option informatique appliquée et gestion; Amministrazione e gestione informatica (TI) | `EN` (ambiguous), `MITIC`, `OIG`; `EDU NUM` unverified |
| FR | Sciences numériques et technologie (2nde); Numérique et sciences informatiques (1re/terminale); Informatique, Numérique, Pix, Programmation, Algorithmique; SGN (STMG) | `SNT`, `NSI`, `SGN` |
| ES | Digitalización; Tecnologías de la Información y la Comunicación; Informática; programming | `TIC`, `TIC I`, `PRO` (inferred), `DIG`, `INF`; **`INF1`…`INF3` in parentheses are rooms on Valencian sheets** |

### 3.13 Study time, support, remedial

| Region | Names | Codes |
|---|---|---|
| DE | Förderunterricht, Fördermaßnahmen, Individuelle Förderung, Flexible Stunde, Intensivierung (BY); Förderung und Vertiefung, Poolstunden, Coaching, Lernzeiten, Kompetenzanalyse (BW); Lernatelier, Talentzeit, Lernbüro, Neigungsangebote (BY private); Schülerarbeitsstunden, FiBS (BE); LRS-/Dyskalkulie-Förderung (MV); Lernzeit "Sichere Basis" (NI GS); Selbstorganisiertes Lernen, Planarbeit, Hausaufgaben-Training (NI); Ergänzungsstunden (NW, TH); Wahlpflichtkurs / -unterricht / -bereich, Wahlbereich, Wahlunterricht (NI, NW, RP, SL, SN, ST, BY, HB); Profilunterricht / Profilstunden; Komplexe Lernleistung (SN); Seminarfach (TH); Differenzierung; Beratung (SN) | official: `FöU`, `FöM`, `IF`, `FX` (BY); `FÖ`, `indFö`, `AiFKL`, `WPK`, `WPU`, `P`, `LeP`, `Brg` (SN); seen: `Fö`, `FiBS`, `M Fö`, `D Fö`, `FDeR`, `FEn`, `FMa`, `SOL`, `PLAN`, `HA-Tr`, `WP`, `WPI`, `WPII`, `WPU`, `WP I`; usual `LZ`, `Lz`, `FU`, `Förder`, `Dif-X`, `FuX` |
| CH-de | Förderunterricht, Besonderer Förderunterricht; Lernzeit (gegenstandsbezogen / individuell); Lerncoaching; Lernatelier (UR), Lernlandschaft, Altersdurchmischtes Lernen, Individuelles Lernen; Arbeitsstunde (SG); Individualisierung (GR); Deutsch als Zweitsprache; Integrative Förderung; Begabungsförderung; Logopädie, Legasthenie; Aufgabenstunde, Hausaufgabenhilfe; Kleinklasse, Werkschule; Wahlpflichtfach | `FU`, `BFU`, `FU/R`, `LZ`, `LC`, `LiLO`, `AdL`, `IL`, `IND`, `DaZ`, `DaF`, `IF`, `IS`, `BF`, `Logo`, `LEG`, `MF`, `E3`, `F3`, `LF`, `WP`; `PMT`, `SHP` unverified |
| AT | Förderunterricht; Deutschförderklasse / -kurs; Studium (sheet cell); Lernzeit (also group 14) | `FU`, `DaZ`, `LZ` |
| CH-fr | Renforcement / Extension; Travail en demi-classe; appui; enseignement spécialisé; devoirs surveillés (also group 14) | `REX`, `FRR`, `MTR`, `TDC`, `PPLS` |
| FR | Accompagnement personnalisé; Activités pédagogiques complémentaires (primary); Aide personnalisée; Soutien, Approfondissement, Aide aux devoirs, Groupe de besoins; Devoirs faits; Permanence, Étude, Étude dirigée, Étude surveillée, Salle d'étude, Vie scolaire, CDI, BCD; RASED, PPRE, Décloisonnement; Consolidation (lycée pro); Orientation, Parcours Avenir, Tutorat; Devoir surveillé, Brevet blanc; EPI (project); Club, Foyer, Atelier | `AP`, `ACCOMP. PERSONNALISE`, `Accomp. perso`, `APC`, `DF`, `DEVOIRS FAITS`, `PERM`, `ETUDE`, `ED`, `DS`, `BB`, `EPI` |
| ES | Refuerzo / Reforç / Reforzo (per subject); Apoyo; Pedagogía Terapéutica; Audición y Lenguaje; Estudio, Hora de estudio; Guardia; Hora libre; Optativa; Programa de Diversificación Curricular (PMAR before) | seen: `REF MAT`, `REF CLL`, `REF ANG`, `REF VLL`, `Reforzo Inglés`, `TRF MAT`, `TRF VLL`, `PEILL CLL`, `PEILL VLL`, `PIAR` (an adaptation plan, not a subject), `PT CLL`, `DD xxx` (desdoblament), `HORA LIBRE`; usual `PT`, `AL`, `REFUERZO`, `APOYO`; unknown Valencian internal codes `ESS`, `PI`, `IMS`, `TRDR`, `LAB` |

### 3.14 Care and after-school

Rarely a timetable code; the names appear on primary sheets and on the care parts of
Tagesschule plans. No official code was found in any region.

| Region | Names and codes |
|---|---|
| DE | Hort, eFöB (BE), GBS (HH), OGS (NW), Offener Ganztag, Ganztag(sschule), Betreuung, Verlässliche / Betreuende Grundschule (NI, RP), Pädagogische Mittagsbetreuung (HE), Mittagsbetreuung (BY), Mittagessen / Essen / Freizeit, Frühdienst, Arbeitsgemeinschaft `AG`; Untis staff suffixes `-GT`, `-PM`, `BK` (Betreuungskraft, NI) |
| CH, AT | Mittagstisch, Mittagsbetreuung `BMP`, Mittagsaufsicht `MA` (AT planner), Aufsicht, `BFLZ`, `BLZ` (Lernzeit in Tagesbetreuung), `BMKB`, Tagesbetreuung, Tagesschule, Tagesstruktur, Betreuung, `Betr.`, Hort, Auffangzeit `A`/`AZ` (ZH Kindergarten), Nachmittagsbetreuung, ganztägige Schulform, `GTS`, Freizeit, Internat, Mensa |
| CH-fr | accueil parascolaire, APEMS, accueil de midi, cantine, devoirs surveillés |
| FR | Périscolaire, Accueil périscolaire, Garderie (matin/soir), Accueil du matin / du soir, Cantine, Restaurant scolaire, Repas, Pause méridienne, Temps méridien, Étude surveillée, Centre de loisirs, ALSH, Accueil de loisirs, TAP, NAP, PEDT; collège: Demi-pension `DP`, Self |
| ES | Comedor / Menjador / Xantar, `COMIDA`, `DINAR`, Esmorzar a l'aula, Aula matinal, Madrugadores, (Actividades) extraescolares / Activitats extraescolars |

### 3.15 Class council, tutor time

| Region | Names | Codes |
|---|---|---|
| DE | Klassenrat; Klassenlehrerstunde / Klassenleitungsstunde (HE 2025, SL) / Klassenleiterstunde; Klassenstunde (SH, RP); Verfügungsstunde / Verfügungszeit (NI, RP); Klassenlehrkraftunterricht (NI); Soziales Lernen; Methodenstunde, Methodentraining, Projektlernen; Mentoring; Tutor (HH); Projekte/Schulleben, Schulprofil (BY ASV) | seen: `KR`, `SL`, `KL`, `KLU`, `Verfü`, `Verf`, `MET`, `PL`; official `Pro`, `Spr` (BY); usual `KLS`, `KlS`, `Kl.-Std.`, `Tut`, `Tutorium` |
| CH, AT | Klassenstunde, Klassenlehrerstunde, Klassenrat; Lerngespräche; Soziales Lernen; Klassenvorstand (AT); Sonstige verbindliche Übungen (AT) | `KL`, `KR`, `KV` |
| CH-fr, CH-it | Maîtrise de classe; Formation générale (NE, GE: orientation and class time); Ora di classe | `FGE`, `HVC` |
| FR | Vie de classe, Heure de vie de classe; Rituels et vie de classe, Conseil d'élèves, Quoi de neuf (primary); Conseil de classe; Heure de PP; Accueil | `VDC`, `VIE DE CLASSE`, `VIE CLASSE`, `HVC`, `PP` |
| ES | Tutoría; Tutories individuals; Titoría familias; Acción tutorial | `TUT`, `TUTORIA`, `Tutoria`, `HT`, `Tutoretza` |

### 3.16 Breaks and lunch (never lessons)

Pause, Hofpause, Grosse Pause, Mittag, Mittagspause, frei, `-`; Récré, Récréation, Pause,
Déjeuner, Midi; Recreo, Esbarjo, Pati, Patio, Esplai (Valencian long midday break),
Jolastordua, Descanso, Descans; Pausa, Ricreazione. `PATI1`, `PATI2` in parentheses are rooms.

### 3.17 Other

- **Career orientation:** Berufliche Orientierung `BO`, `BBO`, Berufs- und Studienorientierung,
  Projekt-Seminar (BY), Duales Lernen, Praxislernen (BE), Lernbereich Arbeit und Beruf (HH);
  Orientamento professionale `OP`, `OORI`; Parcours Avenir, Heure d'orientation; Stage, PFMP.
- **Projects and electives:** Projektunterricht `PU`, Projektarbeit, Wahlfach `WF`, `MF`, `RE-`
  prefix (GR), Freifach, Freigegenstand, unverbindliche Übungen (AT), Angebot der Schule, AG,
  Theater `TH`, Schach `SCH`, EPWA (AT pre-scientific paper), Jahresprojekt `JP`; EPI (FR);
  Projecte Interdisciplinar, Optativa, Libre disposición / configuración, Itinerario (ES).
- **Heritage and migrant languages:** Erstsprachenunterricht `ESU`, HSK (Heimatliche Sprache
  und Kultur), LCO (langue et culture d'origine), Herkunftssprachlicher Unterricht,
  Muttersprachlicher Unterricht (NW), Italiano per stranieri.
- **Mixed blocks:** Gesamtunterricht `GU` (AT), Grundlegender Unterricht (BY Kl. 1–2),
  Anfangs-/Erstunterricht `AU`/`EU` (NI, SN), Themenarbeit, Freiarbeit, Kurs, `ACF`.
- **Other subjects:** Verkehrserziehung, Schulgarten, Astronomie `ASTRO`, Darstellende
  Geometrie `DG`, Geologie `GEOL`, Digitale mathematische Werkzeuge `DMW`, Literatur `LIT`
  (BW Oberstufe); Eurythmie, Hauptunterricht `HU` (Waldorf); Gesundheitswissenschaften `GeWi`
  (BY FOS/BOS); Kommunikation und Interaktion `KuI`; Übungsunternehmen `ÜU`; Dehnungsjahr `DJ`
  (SN); Gesundheits- und Sanitätskurs `GeSa`; Neues Testament erleben `NT` (private).
- **Annotations, not lessons:** Cours annulé, Prof. absent, Pas de cours, Sortie, Visite,
  Voyage, Brevet, DNB, Retenue; Vertretung, Entfall, Ausfall; HSA/HSE (staff overtime, FR).

## 4. Two-letter and one-letter codes that look like weekdays

These are the collisions that matter most for the scan's header detection. The parser already
uses only the family's language's short weekday forms (specs/24); this table says why.

| Token | Weekday reading | Subject reading |
|---|---|---|
| `Mo` | Montag | — |
| `Di` | Dienstag | — |
| `Mi` | Mittwoch | Medien und Informatik is `MI` (CH); two-letter upper-case on a Swiss sheet is a subject |
| `Do` | Donnerstag | — |
| `Fr` / `FR` | Freitag (de) | Französisch (SL, SN, CH), Français (FR), Francés (ES); `FR` is also Freie Religion (BY) |
| `Sa` | Samstag | Sachunterricht ("Sa/SU", BE) |
| `So` | Sonntag | — |
| `Ma` / `MA` | mardi (fr), martes (es) | Mathematik (BE, SL, SN, GR, ZH, AT), Mittagsaufsicht (AT) |
| `Me` / `ME` | mercredi | Musikerziehung (AT), Medien (BY), Maths expertes (FR) |
| `Je` | jeudi | — |
| `Ve` | vendredi | — |
| `Lu` | lundi, lunes | — |
| `Mar` / `MAR` | mardi, martes | — (safe as weekday in fr/es, but `Mar` is no German word) |
| `Mie` | miércoles | — |
| `Ju` / `Jue` | jueves | — |
| `Vi` / `Vie` | viernes | — |
| `We` / `WE` | Wednesday | Werken / Werkerziehung (BY, NI, SN, AT) |
| `Th` / `TH` | Thursday | Theater (CH elective), Thüringen |
| `Su` / `SU` | Sunday | Sachunterricht (BW, SN, SH, AT) |
| `Tu` | Tuesday | — |
| `Sat` | Saturday | — |
| `Sun` | Sunday | — |
| `Mon` | Monday / Montag | — |
| `Dim` | dimanche | — |
| `Dom` | domingo | — |

## 5. Codes with several subject meanings

Within one language the subject codes mostly stay apart; across regions and levels they
collide. The family's own subject list (sent as hints) and a legend on the sheet are the only
reliable disambiguation; failing those, the parser should keep the token as the subject's
short name and let the parent name it in the preview.

| Code | Meanings seen | Where |
|---|---|---|
| `Sp` | Spanisch (BY official), Sport (BE, SH, NI, SL) | DE |
| `S` | Sport (BY, Schramberg) | DE |
| `K` | Katholische Religion (BY ASV); Kunst elsewhere by guess | DE |
| `KUW` | Kunst/Werken (BW GS); Kirchliche Unterweisung (CH) | DE / CH |
| `BK` | Bildende Kunst (BW, SL, BE); Blindenkurzschrift (SN); Betreuungskraft (NI staff) | DE |
| `GK` / `Gk` | Gemeinschaftskunde (BW, SN); Gesamtkonferenz (NI staff) | DE |
| `GeWi` | Gesellschaftswissenschaften (BE, BB); Gesundheitswissenschaften (BY FOS/BOS) | DE |
| `Ges` / `GES` | Geschichte (NI Gymnasium); Gesellschaftslehre (NI CSN); Gestalten (Bern) | DE / CH |
| `GS` | Geschichte in "GS (RZG)" (GR); Geschichte und Sozialkunde (AT) | CH / AT |
| `GG` | Geografie in "GG (RZG)" (GR); Geographie und Wirtschaftskunde (AT AKG) | CH / AT |
| `GW` | Gesellschaftswissenschaften (SL); Geografie und Wirtschaftskunde (AT) | DE / AT |
| `GL` | Gesellschaftslehre (HE, NW, RP) | DE |
| `F` | Französisch (BW, BY, NW, CH); Förder-prefix `FMa`, `FEn`, `FDeR` (NI) | DE |
| `E` | Englisch; `E3` is Englisch-Förderung in AT and English level 3 in BW | DE / AT |
| `NT` | Natur und Technik (BY, CH); Neues Testament erleben (private school) | DE / CH |
| `NW` | Naturwissenschaften (SL, NW) | DE |
| `AL` | Arbeitslehre (SN, SL, NW); Audición y Lenguaje (ES); Alemán (ES usual) | DE / ES |
| `AWT` | Arbeit-Wirtschaft-Technik (BY old, MV, NI) | DE |
| `R` | Religion (AT, usual DE); Rumantsch (GR) | AT / CH |
| `RE` | Religion (GR, AT); `RE-` elective prefix (GR Romansh schools); Religion evangelisch `RE/e` (SN) | CH / DE |
| `PH` | Physik (BW, SN, AT); never Philosophie in the sources (that is `PHIL`, `Phi`, `PHILO`) | DE / AT / FR |
| `PC` | Computerunterricht (BE); Physique-chimie (FR) | DE / FR |
| `PP` | Psychologie und Philosophie (AT); Praktische Philosophie (NW usual); professeur principal (FR) | AT / DE / FR |
| `MS` | Moviment e sport (GR); Malspiel (Bern) | CH |
| `MF` | Mathematik-Förderung (AT); elective prefix (GR Italian) | AT / CH |
| `BS` / `BSP` | Bewegung und Sport (CH, AT); Bühnenspiel (AT AKG) | CH / AT |
| `KG` | Kindergarten (CH); not Kunst und Gestaltung, which is `KuG` | CH / AT |
| `HH` | Hip Hop (Bern school); Hamburg | CH |
| `CH` | Chemie (AT, BW, SN, SL); the country code | AT |
| `U` | Unterricht (ZH Kindergarten); Gesamtunterricht (AT) | CH / AT |
| `A` | Auffangzeit (ZH); group or week letter | CH |
| `D` | Deutsch; German as foreign language (GR, CH-fr); group letter ("Knaben D") | DE / CH |
| `TD` | Technik und Design (AT); Tecnología y Digitalización (ES usual) | AT / ES |
| `TG` | Technisches Zeichnen (BY); Textiles Gestalten (NI); Technisches Gestalten (CH) | DE / CH |
| `TC` | Technik/Computer (SN); Technisches Gestalten "GES tc" (Bern) | DE / CH |
| `AP` | Arts plastiques; Accompagnement personnalisé; APC | FR |
| `ES` | Enseignement scientifique; SES; old série ES (FR); Ernährung und Soziales (BY) | FR / DE |
| `EM` | Éducation musicale (FR); EMC is civics | FR |
| `EN` | Éducation numérique (CH-fr); Englisch (SN) | CH / DE |
| `ED` | Étude dirigée; prefix of `ED.PHYSIQUE`, `ED.MUSICALE` | FR |
| `LV1` / `LV2` | a slot, not a language; the language stands next to it | FR |
| `VAL` | Valencià subject; language-of-instruction tag; Valores | ES |
| `CAST` / `CAS` | Castellano subject; language-of-instruction tag | ES |
| `CS` / `CN` | Ciències Socials / Naturals (ca); Ciencias Sociales / Naturales (es) | ES |
| `AE` | Atención Educativa; Artes Escénicas | ES |
| `EE` | Economía / Empresa | ES |
| `HE` | Historia de España (ES); Hebräisch (SN) | ES / DE |
| `HA` | Història de l'Art (ES); Handarbeit `HAr` (BY) | ES / DE |
| `IN` | Inglés (ES), not Informática | ES |
| `PT` | Pedagogía Terapéutica; room "(PT2)" | ES |
| `DT` / `DD` | Dibujo Técnico / desdoblament (a split group marker) | ES |
| `DG` | Darstellen und Gestalten (NW); Darstellende Geometrie (BW); Digitale Grundbildung (AT) | DE / AT |
| `DS` | Darstellendes Spiel (SN old); Devoir surveillé (FR) | DE / FR |
| `WP` | Wahlpflicht (DE, CH) | DE / CH |
| `P` | Profilunterricht (SN); bilingual marker (BE SESB) | DE |
| `Q1` / `Q2`, `A` / `B`, `S1` / `S2` | week markers, not subjects | FR, DE |

## 6. What this means for the matcher and the starter lists

*Status 2026-10-23: items 1 to 6 are implemented in
`supabase/functions/_shared/school_subjects.ts` and the starter lists of `api.school_save`
(the legend reader, aliases and the rest of the roadmap in specs/24). The second round of
research (the three parts at the end of the table) added the codes real sheets print in
Sachsen-Anhalt, NRW primary, Vaud, Neuchâtel, Fribourg, Ticino, the Basque Country,
Catalonia and Andalusia, and gave Catalonia, the Balearics, Valencia, the Basque Country and
Galicia starter lists in their own language. Still unseen: Rheinland-Pfalz, Thüringen,
Geneva, Valais, Jura, Belgium, Luxembourg, Navarra, the Balearics.*

1. **Match the family's own subjects first.** The scan already sends the household's short
   names and names (specs/24). Exact match on the folded token, then prefix, then one edit for
   tokens of five letters or more. Nothing in this research gives a better signal than that
   list; every region's codes are school-specific.
2. **Then match the full names of the family's language**, from the group tables above, with
   the same prefix and edit-distance rules. Full names are official and stable; they are what a
   legend, a footer or a Spanish/Swiss sheet prints.
3. **Short codes only as a last resort, and only within the family's language.** A two-letter
   upper-case token is a subject code, not a weekday, when it is not in the language's weekday
   list (section 4). When a short code has several meanings in the family's language (section
   5), keep the token itself as the short name and leave the name empty; the parent fills it
   in the preview. Never choose a meaning from another language's list.
4. **Read the legend when the sheet has one.** A block of `CODE = Name` or `CODE Name` pairs
   below or beside the grid (Swiss, Spanish and Untis sheets) resolves every code on that sheet
   with certainty. This is the most valuable follow-up for the parser and costs no model.
5. **Strip what is not a subject before matching:** parentheses (teacher, room), a trailing
   level or group suffix (`E1`, `F3`, `Math Sek`, `Knaben D`), week markers (`Q1`, `A`/`B`),
   and the break words of section 3.16 (those cells become no lesson).
6. **Starter subject lists per language** should come from groups 1 to 12 plus the class
   council and support slots a primary sheet shows, named in the official words of the region
   and with the most common short code of that language as the short name. A sensible default
   is one list per language, not per state: the state differences lie in the codes, which the
   family corrects once, not in the names. Suggested starter set (names in the app's four
   languages, codes to be confirmed against real sheets):
   - **de** (DE/CH/AT): Deutsch `D`, Mathematik `M`, Englisch `E`, Französisch `F`,
     Sachunterricht `SU` / NMG `NMG` (CH), Natur und Technik `NT`, Biologie `Bio`, Chemie `Ch`,
     Physik `Ph`, Geschichte `G`, Geographie `Geo`, Kunst `Ku` / Bildnerisches Gestalten `BG`
     (CH), Werken `We` / TTG `TTG` (CH), Musik `Mu`, Sport `Sp`, Religion `Rel`, Ethik `Eth`,
     Informatik `Inf` / Medien und Informatik `MI` (CH), Förderunterricht `Fö`, Klassenrat `KR`.
   - **fr**: Français `FR`, Mathématiques `MATHS`, Anglais `ANG`, Allemand `ALL`, Espagnol
     `ESP`, Histoire-géographie `HG`, EMC `EMC`, SVT `SVT`, Physique-chimie `PC`, Technologie
     `TECHNO`, Arts plastiques `ARTS PLA`, Éducation musicale `EM`, EPS `EPS`, Questionner le
     monde `QLM`, Accompagnement personnalisé `AP`, Vie de classe `VDC`, Étude `ETUDE`.
   - **es**: Lengua Castellana `LCL`, Lengua Cooficial `VLL`/`CAT`/`LG` by region, Matemáticas
     `MAT`, Inglés `ING`, Francés `FR`, Conocimiento del Medio `CM`, Biología y Geología `BG`,
     Física y Química `FQ`, Geografía e Historia `GH`, Educación Plástica `EPVA`, Música `MUS`,
     Educación Física `EF`, Religión `REL`, Atención Educativa `AE`, Valores Cívicos `VCE`,
     Tecnología y Digitalización `TID`, Tutoría `TUT`, Refuerzo `REF`.
   - **en** (for families using the app in English with a local school): the de/fr/es list of
     the school's country, since no English-language school system was researched.
7. **Do not encode hours or levels.** The parts carry weekly hours per Stundentafel for
   plausibility only; they differ by state, year and school form and are the first thing a
   reform changes.

## 7. Gaps

- **No readable timetable** was found for Rheinland-Pfalz, Sachsen-Anhalt, Thüringen,
  Nordrhein-Westfalen primary, the Romandie, Ticino, the Basque Country, Navarra and the
  Balearics. Their rows are official names only.
- **Software default codes** (Untis, Pronote/EDT, Séneca, Itaca, …) are undocumented; every
  "usual" code is a hypothesis until a sheet shows it.
- **Ministry pages in France** refused the fetcher; the French hours and some names rest on
  search summaries of the official texts.
- **Austrian** `TXW`, `TEW`, `GSP`, `VU`, `GTS` and the Untis defaults were not found;
  Austrian codes come from a few school lists (AKG, Lemberger planner, Krems, Silz).
- **Handwritten and Montessori / Waldorf sheets**, Alsace-Moselle religion, immersion schools
  (Diwan, Seaska, Calandreta) and private-school codes (CSN Buchholz, Winklhof) are covered
  by single examples.
- Nothing was cross-checked with the pilot's own sheets; specs/24 holds that evidence.

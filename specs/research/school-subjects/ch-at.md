# School-timetable subject names and abbreviations: Switzerland and Austria

Research for the WuselWall timetable scan (OCR parser). Date of research: 2026-10-23.

## How to read this file

Status tags in every table:

- **[OFF]** official: printed in a curriculum, an ordinance, a cantonal Stundentafel or an official abbreviation list. Subject names are almost always official; abbreviations are official only where a list says so (Graubünden, Neuchâtel, AKG "offiziell" column).
- **[OBS]** observed on a real school timetable or a school-published legend (the school chose the code).
- **[GEN]** general knowledge or only seen in a search snippet; I did not read the source text. Treat as unverified.

Source keys (for example `GR`, `NE`) are resolved in the "Source index" at the end. The full URL is also repeated in the table for the key sources.

Two big facts for the parser:

1. **There is no national abbreviation standard.** Lehrplan 21 and the PER define names, not timetable codes. Each canton, school or Untis export chooses its own. Only Graubünden (GR) and Neuchâtel (NE) publish an official code list (both below).
2. **Many codes collide across regions** (M/MA, BS, MS, KG, PH, GES, R, RE, MA = Mittagsaufsicht...). See "Ambiguous tokens".

---

## 1. Lehrplan 21 (German-speaking Switzerland, 21 cantons of the D-EDK)

Structure [OFF, secondary summary; D-EDK page itself not fetched]: Fachbereiche Sprachen; Mathematik; Natur, Mensch, Gesellschaft (NMG); Gestalten; Musik; Bewegung und Sport; plus the modules Medien und Informatik (MI) and Berufliche Orientierung (BO, Sek I only). Cycle 1 = Kindergarten to 2nd class, cycle 2 = 3rd to 6th class, cycle 3 = Sek I (7th to 9th class). LP21 has no Stundentafel of its own; each canton sets its own.
Source: https://www.lehrplan21.ch/stundentafeln (referenced by IDES, `IDES`); overview via cantonal documents (`LP21-OV`).

The only official abbreviation list for Stundenpläne is Graubünden's (German-language schools part), dated 23.11.2017. Wahlfächer are meant to be coloured yellow in the Stundenplan.

| Subject (official name) | Abbreviation seen | Level | Status and source |
|---|---|---|---|
| Deutsch (Schulsprache) | D | KG to Sek | [OFF] GR list |
| Italienisch (1. Fremdsprache, in GR) | I | Prim, Sek | [OFF] GR |
| Romanisch (1. Fremdsprache, in GR) | R | Prim, Sek | [OFF] GR |
| Englisch (2. Fremdsprache) | E | Prim, Sek | [OFF] GR |
| Französisch (Fremdsprache; 1. or 2. depending on canton) | F (not in GR list; GR only has WF-F as 3rd language) | Prim 5/6, Sek | [OBS] Steffisburg, Zürich (`ZH`); Wangen uses FRA |
| Mathematik | MA (GR, ZH); M (Bern, Wädenswil, Steffisburg); MAT (Wangen, Sumiswald) | all | [OFF] GR/ZH; [OBS] others |
| Natur, Mensch, Gesellschaft (Fachbereich, Prim) | NMG | KG to 6th | [OFF] GR, ZH; [OBS] Steffisburg, Sumiswald |
| Natur und Technik (with Physik, Chemie, Biologie) | NT | Sek (in NMG Prim) | [OFF] GR, ZH; [OBS] Wädenswil, Wangen |
| Wirtschaft, Arbeit, Haushalt (with Hauswirtschaft) | WAH | Sek (in NMG Prim) | [OFF] GR, ZH; [OBS] Wädenswil, Wangen |
| Räume, Zeiten, Gesellschaften (with Geografie und Geschichte) | RZG; GG (RZG) = Geografie, GS (RZG) = Geschichte | Sek | [OFF] GR; [OBS] Wädenswil, Wangen |
| Ethik, Religionen, Gemeinschaft (with Lebenskunde) | ERG | Sek | [OFF] GR; [OBS] Wangen. Zürich calls the subject "Religionen, Kulturen, Ethik" = RKE ([OFF] ZH, [OBS] Wädenswil) |
| Bildnerisches Gestalten | BG | all | [OFF] GR, ZH; [OBS] all CH sheets |
| Textiles und Technisches Gestalten | TTG; split on sheets: TxG / TcG (Steffisburg, Erlen), GES tx / GES tc (Wangen), GESt / GEStt / GESb (Sumiswald) | all | [OFF] TTG; [OBS] the split forms |
| Musik | MU (GR, ZH, Steffisburg), Mu (Wädenswil), MUS (Wangen, Sumiswald) | all | [OFF] GR; [OBS] others |
| Bewegung und Sport | BS (GR, ZH, Wädenswil, Sumiswald); SP (Steffisburg, Bern); SPO (Wangen) | all | [OFF] GR; [OBS] others |
| Medien und Informatik | MI | Prim (partly integrated), Sek | [OFF] GR, ZH; [OBS] Steffisburg, Wangen |
| Berufliche Orientierung | BO | Sek (9th) | [OFF] GR, ZH |
| Religion (confessional, cantonal churches) | RE (GR); KUW "Kirchliche Unterweisung" (Steffisburg); RL (Sumiswald, likely Religion/Lebenskunde) | KG to Sek | [OFF] GR RE; [OBS] KUW, RL |
| Individualisierung | IND | Sek | [OFF] GR |
| Projektunterricht | PU | Sek | [OFF] ZH list |
| Wahlfächer (GR): WF-I, WF-R, WF-E, WF-F, WF-TAS (Tastaturschreiben), WF-MA, WF-MI, WF-NMG, WF-KO (Kochen), WF-BG, WF-TTG, WF-MU, WF-TDS (Theater, Darstellendes Spiel) | prefix WF- | Sek | [OFF] GR |
| Musikalische Grundbildung / Musikalische Grundschule | MG / MGS | KG, 1st-2nd | [OFF] ZH (MG); [OBS] Steffisburg (MGS) |

URLs: GR https://www.gr.ch/DE/institutionen/verwaltung/ekud/avs/Volksschule/Lehrplan21_Faecherbezeichnungen_Abkuerzungen_23112017_it.pdf ; ZH https://www.zh.ch/de/bildung/informationen-fuer-schulen/informationen-volksschule/volksschule-organisation/schulinfo-stundenplaene-blockzeiten.html (read with a summariser, medium confidence) ; Wädenswil https://www.oswaedenswil.ch/system/files/page/dateien/1._sek.pdf ; Steffisburg https://www.steffisburg.ch/schule-wAssets/docs/Dokumente/Stundenplaene/PS/Gesamtstundenplan-Zulg.pdf ; Wangen https://www.wangen-a-a.ch/schule/wer-sind-wir/schulbetrieb/stundenplaene/Stundenplaene-Schuljahr-2025_26/Stundenplan-7S-SJ25_26-HP.pdf ; Sumiswald https://www.sumiswald.ch/schule/sumiswald/downloads/Stundenplaene-US/5.6.A-mee.pdf

### Kindergarten, Primar and support terms (CH)

The terms below are not Lehrplan subjects. Evidence is thin: I could not read a legend that defines all of them.

| Term | Abbreviation seen | Meaning / note | Status and source |
|---|---|---|---|
| Kindergarten | KG (also "1H/2H" HarmoS, "1./2. Klasse") | LP21 cycle 1 starts in the Kindergarten | [OFF] `LP21-OV`; Zürich Kindergarten sample timetables use A and U |
| Auffangzeit | A (ZH sample), AZ (Winterthur) | supervised time before lessons in the Kindergarten | [OFF] ZH examples https://www.zh.ch/de/bildung/informationen-fuer-schulen/informationen-volksschule/volksschule-organisation/schulinfo-stundenplaene-blockzeiten/stundenplanbeispiele-volksschule.html ; AZ from a search snippet [GEN] |
| Unterricht | U | ordinary lessons; "U (WAH)" = WAH lessons over lunch | [OFF] ZH examples |
| Halbklassenunterricht | "/" between two groups | half-class teaching | [OFF] ZH examples |
| Blockzeiten | none | at least 4 lessons every morning, 08:00 to 12:00 (SH, SZ extend to Kindergarten) | [OFF] snippets: https://schule.sh.ch/CMS/get/file/3d7df185-413f-4bf7-a28e-d1caf4d46c6e , https://www.sz.ch/public/upload/assets/11604/Checkliste%20Stundenplan.pdf?fp=6 |
| Mittagstisch / Tagesstruktur / Hort | none standard | not part of the Stundenplan; municipal care | [GEN] |
| Hausaufgabenhilfe / Aufgabenstunde | none standard | ZH: "Beaufsichtigte Stillarbeit", Aufgabenstunde under § 17 VSG | [OFF] per snippet of ZH guidance |
| Deutsch als Zweitsprache | DaZ | shown as "U/DaZ" in a Winterthur Kindergarten sheet | [OBS] via snippet (https://stadt.winterthur.ch/...laubegg), not verified by me |
| Integrative Förderung | IF | special-needs support in class | [OBS] via snippet; meaning [GEN] |
| Begabungs- und Begabtenförderung | BF | enrichment | [OBS] teacher role "Logo, IF, BF" in Trachselwald (snippet); meaning [GEN] |
| Logopädie | Logo | speech therapy; therapy, not lesson | [OBS] snippet; [GEN] |
| Musikalische Grundschule | MGS | Steffisburg Prim | [OBS] |
| Angebot der Schule | AdS | free school offers (Band, Blockflöte BLO, Theater TH, Töpfern TÖ, Ukulele UK, Gluschtig Choche GC, Schach SCH, Malspiel MS, Singe-Lose-Spiele-Tanze SLST) | [OBS] Steffisburg legend |
| Natur erleben und erforschen | NEE | Steffisburg Prim offer | [OBS] |
| Lernlandschaft / Lernen in der Lernlandschaft | LiLO | self-directed work block, subjects D E F M RZG | [OBS] Wädenswil 1. Sek |
| Altersdurchmischtes Lernen | AdL | | [OBS] Wädenswil |
| Individuelles Lernen | IL | | [OBS] Wädenswil |
| Klassenstunde | KL | class lesson | [OBS] Wädenswil |
| Lerngespräche | none | "Lektion für Lerngespräche" (TG): one lesson per week needs no entry in the Stundenplan | [OFF] IDES TG p. 155 |
| Arbeitsstunde | none | SG Realschule, up to 3 lessons | [OFF] IDES SG |
| Lebenskunde | none | part of ERG | [OFF] GR |

---

## 2. Cantonal variants (German-speaking CH)

Source for the Stundentafel texts: IDES-Dossier 2025/26, https://edudoc.ch/record/242583/files/Stundentafeln_Grilleshoraires_25-26.pdf (`IDES`). Fachbereich names are the LP21 ones; the differences are in Sek I tracks, name of the religion/ethics subject and organisation.

| Canton | Sek I tracks (names seen) | Notable subject-name differences | Status and source |
|---|---|---|---|
| Zürich | Sekundarschule Abteilung A, B, C (A has the highest requirements; communes may run only A and B). Often written "Sek A/B/C" | Primar: D, E, F, MA, NMG, RKE, BG, TTG, MU, BS, MI. Sek: also I, NT, RZG, WAH, BO, PU. RKE not ERG | [OFF] `ZH`; tracks per snippet of https://www.zh.ch/de/bildung/bildungssystem/zahlen-fakten/struktur-der-sekundarschule.html [GEN-snippet] |
| Bern (German part) | Sekundarschule and Realschule (Real/Sek as "Niveaufächer" inside mixed classes, e.g. "MAT Sek" and "MAT Real" in the same slot with two teachers). French-speaking Bern has other tracks | Primar sheets use D, M, F, E, NMG, BG, TTG/TxG/TcG, MU, SP, MI | [OFF] IDES snippet (Bern: only Sek and Real); [OBS] Wangen, Steffisburg, Sumiswald |
| Aargau | Realschule, Sekundarschule, Bezirksschule | Aargauer Lehrplan on LP21; Stundentafeln per school type | [OFF] IDES p. 4 |
| Luzern | Niveau A (higher), B (extended), C (basic). Models: getrennt, kooperativ, integriert. Niveaufächer (D, F, E, M) vs Stammklassenfächer (RZG, NT) | | [OFF] snippets of https://volksschulbildung.lu.ch/-/media/Volksschulbildung/Dokumente/syst_schulen/ss_schulsystem/schulstufen/sek_infos_schulen_eltern_lehrbetriebe.pdf and https://srl.lu.ch/frontend/versions/633/download_pdf_file |
| St. Gallen | Sekundarschule, Realschule, Kleinklasse (Oberstufe; "1. bis 3. Oberstufe") | "Arbeitsstunde" (Realschule); Freifächer; WAH 6 lessons, BO 3 (Sek) / 5 (Real) / 6 (Kleinklasse) | [OFF] IDES SG |
| Basel-Stadt | Sekundarschule since 2015 with Leistungszüge A (allgemeine), E (erweiterte), P (hohe Anforderungen) | | [OFF] snippet https://www.bs.ch/medienmitteilungen/ed/2015-es-geht-los-mit-der-neuen-sekundarschule |
| Basel-Landschaft | Sekundarschule Leistungszüge A, E, P | | [OFF] snippet https://bl.clex.ch/frontend/versions/1451/download_pdf_file?locale=de |
| Solothurn | Sek B (Basis), Sek E (erweitert), Sek P (progymnasial, 2 or 3 years) | Old subject names in the Sek P Lektionentafel: "Geschichte/Staatskunde", "Hauswirtschaft/Lebensgestaltung", "Informatische Bildung", "Technisches Gestalten", "Wissenschaft und Technik" (Wahlpflicht) | [OFF] IDES SO p. 149; https://so.ch/verwaltung/staatskanzlei/medien/medienarchiv-2000-2014/2006/medienmitteilungen-maerz-2006/fuenf-reformelemente-fuer-die-sekundarstufe-i/ |
| Thurgau | Sekundarschule Typ E (erweiterte) and Typ G (Grundansprüche); 1. to 3. Sek | LP21 names incl. "Gestalten" as one Fachbereich; "Lektion für Lerngespräche"; Wahlpflichtfächer; Typ G may drop a foreign language | [OFF] IDES TG pp. 155-158 |
| Zug | Werkschule, Realschule, Sekundarschule | Wochenstundentafel Sek I for "Werk-, Real- und Sekundarschule" (text is garbled in the PDF; decoded) | [OFF] IDES ZG p. 190 |
| Uri | Oberstufe with Niveau A and B (Französisch Pflicht for A, Wahlfach for B), Werkschule | Lernatelier, Projektunterricht, Themenspezifische Kurse | [OFF] IDES UR p. 169 |
| Graubünden | Oberstufe Real and Sek (GR has Realschule/Sekundarschule) | Three language versions: deutschsprachig (D, I or R as 1st foreign language), rätoromanisch, italienisch. Own codes: NUS/NEUS, ELT/ELED, STS, ERC, AF, ATT, MS/EFS, OP | [OFF] codes: GR list; tracks [GEN] |
| Freiburg / Fribourg (bilingual) | Cycle d'orientation / Orientierungsstufe, German part on LP21 | Stundentafel grades 1H-11H, LP21 since 2019/20 | [OFF] snippet of https://fr.ch/de/document/359821 |

Sek I naming patterns the parser may see in class names or headers: "Sek", "Sek A/B/C", "Sek E/P/B", "Real", "Bez" (Bezirksschule), "Niveau A/B/C", "Typ E/G", "Abteilung A/B/C", "Sek P", "Werk". Class names observed: "7S" with "7. Klasse Sek" (Wangen), "1a", "5/6 A" (Sumiswald, 5th and 6th combined), "1. Sek".

### Timetable-software conventions (CH)

- **Untis** is widely used in the German-speaking area (about 25,000 institutions per a Hochschule München document; https://mediapool.hm.edu/media/fk14/fk14_lokal/meinstudium_6/vorlesungsundseminarplan/stundenplaene_sose_2022/2026_02_03_UNTIS_Erklaerungen_zum_Stundenplan_fuer_Studierende.pdf). The Kanton Zürich documents a "GP-Untis to Eco web" synchronisation for Mittelschulen (https://help.mba.zh.ch/images/Ecoweb/untis-eco-sync-v04.pdf, snippet). The grid layouts of the Bern sheets below look like Untis exports; I found no document that says so for a given school. [GEN]
- **Teacher codes** observed: three lowercase letters = first two letters of the surname + first letter of the first name (Steffisburg Zulg: "Berger Ursula = beu", "Frei Yannick = fry", "Capela Lopes Mario = cam"; Wangen: skn, mhe, kob; Sumiswald: mee, vab, hor). Umlauts occur (käc, müe, bük, züs). A two-letter code also exists (Schüpfen Oberstufe: "Bt Betschart T."; https://schuepfen.ch/de/bildung/downloads/Neu_Ferien-und-Stundenplaene/7_Gesamtstundenplan-OS.pdf, snippet). [OBS]
- **Cell patterns** observed: `D bus` (subject + teacher code); `MAT Sek kob` / `MAT Real mmü` stacked in one slot (Niveaufach, two groups); `TxG*/TcG*` with `sik/rad` (two alternating groups, two teachers, "*" = Abteilungsweiser Unterricht, "**" = 14-täglich); `M*/MI*`; `NEE***`; `GES tc D mkn` (group + level letter + teacher; A/B/C/D = Gruppeneinteilung in Wangen); `ENGL 5` / `ENGL 6` (class level in 5/6 combined classes); `f` after subject = fakultatives Fach (Wangen, "VOL f").
- **Lesson grid**: 45-minute lessons from about 07:20 or 07:30, lunch slot empty around 12:00 to 13:30 (Steffisburg 12:00-12:45 empty; Wangen 12:15-13:00 only "VOL f").

---

## 3. Romandie: Plan d'études romand (PER)

PER (adopted 2009, in force in all cantons since 2013-14) has the domains Langues (L), Mathématiques et sciences de la nature (MSN), Sciences humaines et sociales (SHS), Arts (A), Corps et mouvement (CM), Formation générale (FG), Capacités transversales (CT); Genève lists **Éducation numérique** as a further domain ("Langues, MSN, SHS, Arts, Corps et mouvement, Éducation numérique et les thématiques de la FG"). Grids are cantonal. PER Arts are split into Activités créatrices et manuelles (AC&M), Arts visuels (AV), Musique (Mu) (HEP-VS excerpt https://animation.hepvs.ch/acm/index.php/files/26/Documents-officiels/114/PER-ART-Cycle-2-CM.pdf, snippet).

The only **official code list** I found is Neuchâtel's (Arrêté définissant les grilles horaires, annexe 1, 2020-21): https://rsn.ne.ch/DATA/program/books/RSN2021/20214/pdf/4103131.pdf (`NE`).

| Discipline (official name) | Abbreviation | Level | Status and source |
|---|---|---|---|
| Français (L1) | FRA | all | [OFF] NE |
| Allemand (L2) | ALL | 5H+ (Genève/Vaud 5P) | [OFF] NE |
| Anglais (L3) | ANG | 7H+ | [OFF] NE |
| Mathématiques | MAT | all | [OFF] NE |
| Sciences de la nature | SCN (NE); SN (common usage) | 5H+ (Vaud, in CE 5-6P) | [OFF] NE SCN; SN [GEN] |
| Histoire | HIS | | [OFF] NE |
| Géographie | GEO | | [OFF] NE |
| Monde contemporain et citoyenneté (1 h histoire, 1 h géographie, 1 h civisme) | MCC | upper years | [OFF] NE |
| Citoyenneté | (none in NE) | Genève 7P-8P 1 h; Vaud "Géographie - Citoyenneté" | [OFF] GE, VD |
| Histoire - Éthique et cultures religieuses | (Vaud discipline name) | Vaud 5P-11S | [OFF] VD |
| Géographie - Citoyenneté | (Vaud discipline name) | Vaud | [OFF] VD |
| Connaissance de l'environnement | CE (Vaud 5-6P: groups Histoire-ECR, Sciences de la nature, Citoyenneté) | Vaud 5P-6P | [OFF] VD |
| Arts visuels | AVI (NE); AV (PER) | all | [OFF] |
| Musique | MUS (NE); Mu (PER) | all | [OFF] |
| Activités créatrices et manuelles | ACM (NE); AC&M (PER). Vaud 9-11S: "AC&M / Éducation nutritionnelle" | 3P+ | [OFF] |
| Éducation physique | EPH (NE); "EPS" is the French-national term and was not found in any Romandie source | all | [OFF] EPH; EPS [GEN] |
| Économie familiale | EFA | upper years | [OFF] NE |
| Langues et cultures de l'Antiquité (Latin) | LCA | | [OFF] NE |
| Formation générale | FGE (NE) | | [OFF] NE |
| Éducation numérique / MITIC / Médias - Science informatique - Usages | not in NE grid; Genève: "Éducation numérique et formation générale" 1 period (1P-8P), at CO: Informatique and Médias et images 1 period each; Vaud: "MITIC / Éducation numérique", "Bain informatique" (20 periods, 7P-8P). "EDU NUM" is not an official code I could confirm | | [OFF] GE https://www.ge.ch/document/10883/telecharger ; VD https://www.vd.ch/fileadmin/user_upload/organisation/dfj/dgeo/fichiers_pdf/grilles_horaires/GrilleHoraire_Cycle2.pdf ; CO GE (snippet) https://edu.ge.ch/enseignement/enseignement/system/files/2023-07/grille-horaire-co-sae.pdf |
| Renforcement / Extension | REX | | [OFF] NE |
| Activités complémentaires facultatives | ACF | | [OFF] NE |
| Travail en demi-classe | TDC | | [OFF] NE |
| Options professionnelles (OP): Portfolio POR; Activités créatrices manuelles OCM; Dessin technique et artistique ODE; Expression orale et corporelle OEX; Informatique appliquée et gestion OIG | codes in column 1 | 9-11H | [OFF] NE |
| Options académiques (OA): Langues anciennes OLA; Langues modernes OLM (italien or espagnol); Sciences expérimentales OSE; Sciences humaines OSH | | 9-11H | [OFF] NE |
| Disciplines à choix: Anglais ANG; Français renforcement FRR; Mathématiques renforcement MTR | | | [OFF] NE |
| Domain headings (appear as section rows): ART, CMV (Corps & mouvement), LNG, MSN, SHS | | | [OFF] NE |
| Vaud Cycle 3: voie prégymnasiale (VP) and voie générale (VG); VG has "niveaux 1/2" in français, mathématiques, allemand; Option spécifique (OS: économie et droit, italien, latin, mathématiques et physique) in VP; OCOM (options de compétences orientées métiers) in VG; facultatif: grec, italien | VP, VG, OS, OCOM | 9S-11S | [OFF] https://www.es-payerne.ch/wp-content/uploads/2026/06/DGEO_Cycle3-2026.pdf |
| Genève CO: sections/profils, "Formation générale (information et orientation scolaires et professionnelles, maîtrise de classe)" 1 period | | 9e-11e | [OFF] snippet CO grid |

Grids differ: Vaud 5-6P 28 periods, 7-8P 32; Genève 5P-8P 32 (Géographie, Histoire, Citoyenneté separate; ACM 4 periods); Neuchâtel counts 1ère to 8e. Periods are 45 minutes in Genève.

### Care and support terms (Romandie) [GEN unless stated]

- Accueil parascolaire / APEMS (accueil pour enfants en milieu scolaire, Vaud), accueil de midi (cantine, "repas de midi"), devoirs surveillés (Vaud: not "devoirs accompagnés"; no pedagogic help required) [OFF snippet: https://www.vd.ch/formation/enseignement-obligatoire-et-pedagogie-specialisee/lecole-dans-son-environnement and https://www.vaudfamille.ch/N3560/le-parascolaire-dans-votre-canton.html?M=602321].
- Appui (pédagogique), enseignement spécialisé, PPLS (psychologues, psychomotriciens, logopédistes en milieu scolaire; named in the Vaud Cycle 2 brochure, [OFF] https://www.es-payerne.ch/wp-content/uploads/2026/06/DGEO_Cycle2-2026.pdf), classes d'accueil, FLS (français langue seconde), heure de vie de classe (HVC), enseignement religieux (ER), cours de langue et culture d'origine (LCO): all [GEN], not verified in a source I read.
- Year naming: HarmoS 1H-11H (Fribourg, Neuchâtel "1ère-11e", Genève/Vaud "1P-8P" and "9S-11S" or "9e-11e").

No real Romandie class timetable with abbreviations was found (search engine returned none); everything in this section comes from cantonal grids. Treat the three-letter NE codes as the best available guess for Untis exports in Romandie; other cantons likely use their own.

---

## 4. Ticino (Italian)

Official: Piano di studio della scuola dell'obbligo ticinese (2015, "perfezionato" 2022); school years: scuola dell'infanzia (3 years, 1 optional), scuola elementare (5), scuola media (4: "ciclo di osservazione" I-II media, "ciclo di orientamento" III-IV media). No official abbreviation list found; all codes below are names.

| Subject (official) | Abbreviation seen | Level | Status and source |
|---|---|---|---|
| Italiano | I (Graubünden Italian schools); full word in Ticino grids | all | [OFF] GR; Ticino names: https://pianodistudio.edu.ti.ch/wp-content/uploads/2024/02/Brochure_PdS_WEB_2.pdf |
| Lingue seconde (L2): Francese (from SE 3rd/4th class; I-II media), Tedesco (from I media), Inglese (III-IV media), Latino (optional) | Fr/Ted/Ing; "Opz. francese", "Opz. latino" | media | [OFF] PdS figure p. 14; grid https://minusio.sm.edu.ti.ch/wp-content/uploads/sites/40/2026/03/Presentazione-V-elementare-2026.pdf |
| Matematica | MA (GR Italian); courses A and B: "corso attitudinale" and "corso base" (maths and German, III-IV media) | | [OFF]; the abolition of the A/B courses is proposed by government message of 18 March 2026 (approval not confirmed) |
| Studio d'ambiente (SE) | | scuola elementare | [OFF] PdS |
| Geografia | GG (STS) (GR Italian) | media | [OFF] |
| Storia | ST (STS) (GR) | media | [OFF] |
| Educazione civica / Educazione alla cittadinanza e alla democrazia (ECCD in PdS figure) | | media | [OFF] PdS; grid: 0.5 h |
| Scienze naturali | | media | [OFF] |
| Educazione alimentare | EA? (not confirmed) | III media, obligatory, inside scienze naturali (12 weeks) | [OFF] PdS; school presentation https://minusio.sm.edu.ti.ch/wp-content/uploads/sites/40/2025/11/Presentazione-ciclo-dorientamento-II-media-2025.pdf |
| Educazione visiva | Ed. visiva (EV not confirmed); GR Italian: AF (Arti figurative) | | [OFF] |
| Educazione alle arti plastiche | Arti plastiche | I-II media | [OFF] |
| Educazione musicale | Ed. musicale; GR Italian: MU | | [OFF] |
| Educazione fisica | Ed. fisica; GR Italian: EFS (Educazione fisica e sport) | | [OFF] |
| Insegnamento religioso (facoltativo) / Storia delle religioni (SdR, IV media) | Istruz. religioso; "Storia religione" | | [OFF] |
| Ora di classe | | I-IV media, 1 h | [OFF] school grid |
| Opzioni di orientamento (OORI, IV media 2 h), Opzione capacità espressive e tecniche (OCET, IV media 2 h) | OORI, OCET | IV media | [OBS] Minusio sheet; OCET/OORI described there |
| Amministrazione e gestione informatica (option) | | III-IV media | [OBS] Minusio |
| Educazione tessile e tecnica (GR Italian: Arti tessili e tecniche) | ATT | | [OFF] GR |
| Media e informatica | MI | | [OFF] GR; Ticino: "L'alfabetizzazione informatica" (I-II media) |
| Orientamento professionale | OP | | [OFF] GR |
| Individualizzazione | IND | | [OFF] GR |
| Materie facoltative (GR Italian): MF-D, MF-E, MF-R, MF-F, MF-DAT, MF-MA, MF-MI, MF-NEUS, MF-CU, MF-AF, MF-ATT, MF-MU, MF-TARS | prefix MF- | | [OFF] GR |
| Materie GR Italian: Natura, essere umano, società NEUS; Natura e tecnica NT; Economia, lavoro ed economia domestica ELED; Spazi, tempi, società STS; Etica, religioni, comunità ERC; Religione RE | | | [OFF] GR |

Ticino scuola media weekly grid (hours, I/II/III/IV media), observed on a school presentation 30.03.2026 [OBS]: Italiano 6/5/6/6; Francese 3/4/-/-; Tedesco 2/3/3/3; Inglese -/-/2.5/3; Storia 1.5/1.5/2/1.5; Educazione civica 0.5 each; Geografia 2 each; Matematica 5 each; Scienze naturali 3/2/4/3; Ed. visiva 2/2/2/-; Ed. musicale 2/2/1/-; Arti plastiche 2/2/-/-; Ed. fisica 3 each; Istruzione religiosa 1/1/1/-; Storia delle religioni -/-/-/1; Ora di classe 1 each; OCET, OORI IV media 2 each; Opz. francese -/-/2/2; Opz. latino -/-/2/4. Source: https://minusio.sm.edu.ti.ch/wp-content/uploads/sites/40/2026/03/Presentazione-V-elementare-2026.pdf

Support/after-school in Ticino seen on the same presentation: studio assistito (parascolastic), docente di sostegno pedagogico, differenziazione curricolare, corso di lingua italiana e attività di integrazione. I found no real Ticino class timetable with subject codes; timetable codes are unknown. [GEN]

---

## 5. Austria: Volksschule

Official (Lehrplan der Volksschule, RIS, BGBl. II Nr. 303/2012 as amended; Stundentafel after the 2023 reform; read via https://www.ris.bka.gv.at/GeltendeFassung.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10009275 with a summariser, medium confidence): Pflichtgegenstände 1st to 4th Schulstufe (weekly hours): Religion 2; Deutsch 7; Lebende Fremdsprache (verbindliche Übung 1st-2nd, 1 h in 3rd-4th: "x2"); Mathematik 4; Sachunterricht 3; Musik 1; Kunst und Gestaltung 1; Technik und Design 1-2; Bewegung und Sport 3-2; verbindliche Übung Verkehrs- und Mobilitätsbildung; Förderunterricht 1; Freigegenstände/unverbindliche Übungen (e.g. Chorgesang, Spielmusik); Erstsprachenunterricht; Deutschförderklassen / Deutschförderkurs. Vorschulstufe: Mathematische Früherziehung, Sachbegegnung, Rhythmik, Spiel.

Before the 2023 reform the names were Musikerziehung (ME), Bildnerische Erziehung (BE), Werkerziehung with Technisches Werken and Textiles Werken (WE, TEW/TXW) (names confirmed through Silz/AKG, see section 6; the codes TEW and TXW themselves were **not** found on any sheet I could read).

| Subject | Abbreviation seen | Level | Status and source |
|---|---|---|---|
| Gesamtunterricht | GU (Angedair, Augustinum "Bären-Klasse"), U (Pians, Tirol) | 1st-4th | [OBS] https://vs-angedair.tsn.at/sites/default/files/2024-09/stundenplan_1m_24_25_kinder.pdf ; https://www.pvs.augustinum.at/site/assets/files/3180/stundenplan_der_baren-klasse_2025-2026.pdf ; https://vs-pians.tsn.at/sites/default/files/2024-09/stundenplan_pians_2024_2025_kl2_und_3.pdf |
| Gesamtunterricht contents | Angedair: "GU Gesamtunterricht (Deutsch & Mathematik)"; Augustinum: "GU Themenarbeit, freies Arbeiten, Plan- und Zielarbeit, Feier, Gespräch, Spiel, Zeichnen"; Obervellach (page now dead, per snippet) GU = D, M, SU, ME, BE, E | | [OBS] |
| Freiarbeit | no code; part of GU (Augustinum "freies Arbeiten") | | [OBS] |
| Deutsch / Mathematik | D, M (Augustinum "Kurs in der Jahrgangsgruppe für Deutsch und Mathematik" = "GU (Kurs)") | | [OFF] names |
| Sachunterricht | SU | | [OBS] Angedair |
| Englisch / Lebende Fremdsprache | E (Pians 3rd class), E4 (Augustinum, "Englisch für die 4. Schulstufe"), LFE (Angedair, "Lebende Fremdsprache Englisch") | | [OBS] |
| Religion | RE (Pians), R (Angedair; "R/BFU"), R (kath.) / R (ev.) (Augustinum), "Islam" as own cell (Angedair), REL (Obervellach per snippet) | | [OBS] |
| Musik | MUS (Angedair) | | [OBS] |
| Spielmusik | SPM (Pians) | | [OBS] |
| Kunst und Gestaltung | KuG (Angedair) | | [OBS] |
| Technik und Design | TuD (Angedair, Pians, Augustinum), TD (Obervellach per snippet), "Werken" in Pians 3rd class legend ("TuD Werken") | | [OBS] |
| Bewegung und Sport | BS (Pians, Angedair), BSP (Augustinum) | | [OBS] |
| Turnen + Werken (alternating) | BS / TuD "14tägig geblockt" | | [OBS] Pians |
| Förderunterricht | FU (Angedair, Augustinum "Förderunterricht, Lernwerkstatt") | | [OBS] |
| Besonderer Förderunterricht | BFU | | [OBS] Angedair |
| Erstsprachenunterricht | ESU (also "ESU_A") | | [OBS] Angedair; [OFF] name |
| Verkehrserziehung | "VU" not found on any sheet; official name today "Verkehrs- und Mobilitätsbildung" (verbindliche Übung) | | [OFF] name; code [GEN] |
| Schulische Tagesbetreuung / Nachmittagsbetreuung / GTS | GTS not found. Official structure of Betreuungsteil in ganztägigen Schulformen: gegenstandsbezogene Lernzeit, individuelle Lernzeit, Freizeit (incl. Verpflegung); renamed "Betreuungsteil plus" in the new model | | [OFF] https://www.bmb.gv.at/dam/jcr:01809dd3-13c2-469e-886d-7504890ebe72/betreuungsplaene_lf.pdf (snippet) |
| Bläserklasse | school offer with the Musikschule, 1st-4th | | [OBS] https://vs-flattach.ksn.at (home page) |

Sheet layout seen (Austria Volksschule): rows by "Std." with times 07:45 to 08:35 etc., 14-day alternation marked with "*" or "14-tägig"; a legend under the grid.

---

## 6. Austria: Sekundarstufe (Mittelschule, AHS Unterstufe and Oberstufe)

Official Mittelschule Stundentafel (Lehrplan der Mittelschulen, BGBl. II 185/2012 as amended by II 239/2023, rolling in force from 2023/24; Anlage 3 text read: https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40255187/NOR40255187.pdf): Religion; Deutsch; Lebende Fremdsprache (Zweite lebende Fremdsprache, Latein as alternative); Mathematik; Geometrisches Zeichnen (integrated into Mathematik unless school-autonomous); Digitale Grundbildung; Chemie; Physik; Biologie und Umweltbildung; Geschichte und Politische Bildung; Geografie und wirtschaftliche Bildung; Musik; Kunst und Gestaltung; Technik und Design; Bewegung und Sport; Ernährung und Haushalt (1 h in 2nd class); verbindliche Übung Bildungs- und Berufsorientierung (3rd-4th class); Förderunterricht; Deutschförderklassen.

Renamed from 2023/24 (official, listed by MS Silz-Mötz, https://ms-silz-moetz.tsn.at/sites/default/files/2024-12/Stundentafeln%20im%20SJ%202025%2026.pdf): Geschichte und Sozialkunde/Politische Bildung -> Geschichte und Politische Bildung; Geographie und Wirtschaftskunde -> Geographie und wirtschaftliche Bildung; Biologie und Umweltkunde -> Biologie und Umweltbildung; Bildnerische Erziehung -> Kunst und Gestaltung; Technisches und Textiles Werken -> Technik und Design; Berufsorientierung -> Bildungs- und Berufsorientierung. Still "alter" Lehrplan for the 4th class in 2025/26, so both name sets coexist in 2025/26 and 2026/27 sheets.

AHS Unterstufe Stundentafel 2026 (AKG Wien, https://akg-wien.at/wp-content/uploads/2026/04/Stundentafeln_2026_04_16_u-st.pdf) [OFF]: Religion/Ethik; Deutsch; 1. lebende Fremdsprache (Französisch/Englisch); 2. lebende Fremdsprache; Latein; Geschichte und Politische Bildung; Geographie und wirtschaftliche Bildung; Mathematik; Digitale Grundbildung; Biologie und Umweltbildung; Chemie; Physik; Musik; Kunst und Gestaltung; Technik und Design; Bewegung und Sport. Realgymnasium adds Geometrisches Zeichnen, WRG more Chemie (Rainergymnasium, https://www.rainergymnasium.at/unsere-schule/unser-angebot/stundentafeln/stundentafeln-unterstufe/).

Best direct evidence of codes: Akademisches Gymnasium Wien "Abkürzungen der Pflichtgegenstände" (SJ 2015/16, columns "offiziell" and "Stundenplan"), https://akg-wien.at/wp-content/uploads/2023/01/Fachbezeichnungen-Abkuerzungen.pdf (`AKG`). Other: Lemberger school planner Mittelschule 6th-7th Schulstufe (https://www.bildungsverlag-lemberger.at/assets/bsp_musterseiten/978-3-7098-2645-4_M.pdf, `LEMB`); BG/BRG Krems Oberstufe "Life Sciences" Stundentafel (https://marywardschulen.com/kremsorg/images/Formulare/life%20sciences%20lehrinhalte_stundentafel.pdf, `KREMS`).

| Subject (name used) | Abbreviation seen | Level | Status and source |
|---|---|---|---|
| Religion katholisch / evangelisch / orthodox | RK / REV / RGRO (AKG "offiziell"); REL (Lemberger, Krems); "REL ev" (Winklhof) | all | [OBS-list] AKG, LEMB, KREMS |
| Ethik | ETH | AHS | [OBS-list] AKG |
| Deutsch | D | all | [OBS-list] |
| Lebende Fremdsprache Englisch | E (Lemberger: "E Lebende Fremdsprache Englisch"); 1./2. lebende Fremdsprache E/F, F/E (AKG); F6/E6 on the Stundenplan (AKG; 6 = Schulstufe) | all | [OBS-list] |
| Latein | L (AKG offiziell), L6 (Stundenplan); F/LAT (Krems) | AHS | [OBS-list] |
| Griechisch | GRA (offiziell), G (Stundenplan) | AHS Oberstufe | [OBS-list] AKG |
| Geschichte und Sozialkunde (older) / Geschichte, Sozialkunde und Politische Bildung / Geschichte und Politische Bildung | GS (Lemberger); GSK (AKG offiziell, Krems); GSPB (AKG offiziell); "H" on AKG Stundenplan | all | [OBS-list] |
| Geographie und Wirtschaftskunde / Geographie und wirtschaftliche Bildung | GW (Lemberger, "GW/BO" = Geografie und Wirtschaftskunde/Berufsorientierung); GWK (AKG, Krems); "GG" on AKG Stundenplan | all | [OBS-list] |
| Mathematik | M | all | [OBS-list] |
| Biologie und Umweltkunde / -bildung | BU (Lemberger); BI (AKG); BIU (Krems); BIUB = Biologische Übungen (AKG) | all | [OBS-list] |
| Chemie / Physik | CH / PH | all | [OBS-list] |
| Psychologie und Philosophie | PuP (AKG offiziell), PP (Stundenplan), PUP (Krems) | Oberstufe | [OBS-list] |
| Informatik | INF | Oberstufe, some Unterstufe | [OBS-list] |
| Digitale Grundbildung | DG, DGB (not found on a sheet; **name** official) | Unterstufe | [OFF] name; code [GEN] |
| Musikerziehung / Musik | ME (AKG, Lemberger, Krems) | all | [OBS-list] |
| Bildnerische Erziehung / Kunst und Gestaltung | BE (AKG, Lemberger, Krems); KuG (Volksschule Angedair) | all | [OBS-list] |
| Textiles Werken / Technisches Werken / Werkerziehung | TGW / WTC (textil), TCW / WTX (technisch) in AKG (offiziell / Stundenplan); WE (Lemberger Werkerziehung). "TXW" and "TEW" **not found** in any source | | [OBS-list] |
| Technik und Design | TD, TuD (Volksschule); Mittelschule code not found | | [OFF] name |
| Ernährung und Haushalt | not found | Mittelschule 2nd class | [OFF] name |
| Bewegung und Sport | BSP (AKG, Krems); BS (Lemberger, Pians); BSPM / BSPK (Mädchen / Knaben); caution: at AKG "BSP" is also the code for the unverbindliche Übung Bühnenspiel | all | [OBS-list] |
| Wahlpflichtfächer | WP (Lemberger), W_ with letters e.g. ITA, SPA (AKG), WAPFL (Krems) | | [OBS-list] |
| Berufsorientierung / Bildungs- und Berufsorientierung | BO (Lemberger "GW/BO") | 7th-8th | [OBS] |
| Lernzeit, Lerncoaching, Mittagsaufsicht | LZ, LC, MA (Lemberger) | Mittelschule | [OBS] LEMB |
| Tagesbetreuung codes | BMP Mittagsbetreuung; BFLZ Aufsicht; BLZ Lernzeit; BMKB kreative Stunde (AKG) | AHS | [OBS-list] |
| Unverbindliche Übungen (AKG): DAF Deutsch als Fremdsprache/Zweitsprache, LEG Legasthenie-Förderung, NaWi Naturwissenschaftliches Labor, BIG Bildnerisches Gestalten, FV Fotografie und Video, CHOR, VOK, ORCH, THE Französisches Theater, MDN/MED Peer-Mediation, BALL, FUSB, VBAL, EPWA Einführung in Vorwissenschaftliches Arbeiten, MF Mathematik-Förderung, E3/F3 Förderung, LF Latein-Förderung | | | [OBS-list] AKG |
| Krems Oberstufe extras | KO/KO Kommunikation und Konfliktlösung; GPSY Gesundheitspsychologie; HUM Humanbiologie; LAB-BIO, LAB-CH Nawi-Labor | | [OBS-list] KREMS |

Notes on Austrian codes:

- Austria Oberstufe "PH" = **Physik**, not Philosophie (AKG: PuP/PP for Psychologie und Philosophie). "PPP" is the Swiss Gymnasium subject (Pädagogik/Psychologie/Philosophie), not Austrian.
- Not found anywhere in what I read: TXW, TEW, GSP, BUK, VU, GTS. (Mentions in your request; treat as plausible but unconfirmed.)
- Teacher codes (Untis-style) on an Austrian Fachschule timetable (Winklhof, https://www.winklhof.at/wp-content/uploads/2025/03/Stundenplan_2024_2025_original-1.pdf): three UPPERCASE letters (FUP, STL, SCA, KRP) after the subject; group numbers after the subject ("BSP 1 FUP", "E 2 SCA", "MR 3 KRP"); "KV RED" (Klassenvorstand), "Studium", "PU" (Praxis/practical), "Mittag", "Aufsicht (KRP, BUM)". This is a vocational agricultural school, so only the *shape* of the cells applies. [OBS]
- **Untis defaults in Austria**: I found no source that documents Untis default subject codes. Austrian schools generally decide their own list (compare the AKG list with two columns, official and Stundenplan). [GEN: Untis is widely used, no figure sourced]
- Krems (Oberstufe) legend columns "Kurzbezeichnung" with up to 8 chars (KO/KO, LAB-BIO).

---

## 7. Groups

Canonical groups, each listing every abbreviation and name variant gathered above. "@" marks a variant that is region-specific or ambiguous (see next section). Country marks: CH, CH-fr, CH-it, AT.

### 7.1 German / first language (school language)

- Deutsch: D, DE, DEU, Deutsch, Schulsprache, "Deutsch (Schulsprache)", Sprache, "Deutsch Lesen Schreiben" (AT VS), Lesen, Schreiben (AT, inside GU), "Deutsch, Gesamtunterricht Deutsch" (GU), "D Kurs" (AT), Muttersprache.
- Français (CH-fr first language L1): FRA, Fr, Français, Français L1, Français renforcement FRR, "Français (par niveau)".
- Italiano (CH-it, and GR Italian schools): I @, ITA, Italiano.
- Romontsch (GR Romansh schools): R @, Rumantsch.
- Related: Tastaturschreiben (WF-TAS, RE-TAS), Dattilografia (MF-DAT), Scrivere con tastatura.

### 7.2 Mathematics

- M @, MA @ (Mittagsaufsicht in AT Lemberger), MAT, Math, Mathe, Mathematik, "Mathematik und Geometrie" (Wädenswil), Mathématiques, Matematica, Matematica corso base/attitudinale, "Math Sek" / "Math Real" (Wangen), "M*" (Abteilungsweiser Unterricht).
- Geometrisches Zeichnen: GZ, GEOM, "Mathematik + GZ", "Mathematik RG".
- Elective/support: WF-MA, RE-MA, MF-MA, MTR (Mathématiques renforcement), Mathematische Früherziehung (AT Vorschulstufe), MF (Mathematik-Förderung, AKG, goes also to 7.13).

### 7.3 Foreign languages (record which language)

- English: E @, E1/E2/E3/E4/E 5/E 6 (level or Schulstufe suffix), ENG, ENGL, ANG, ING, Englisch, "Englisch (2. Fremdsprache)", Anglais, Inglese, Anglais L3, LFE (AT "Lebende Fremdsprache Englisch"), "Lebende Fremdsprache", "1./2. lebende Fremdsprache", WF-E, RE-E, MF-E, E3 (Förderung).
- French: F @, FRA @ (in German-speaking CH = Französisch, in Romandie = L1 first language), Fr, Französisch, Français, Francese, WF-F, RE-F, MF-F, "Opz. francese", F6 (Stundenplan AKG), F3 (Förderung), Französisch/Latein "F/LAT".
- German as a foreign language (Romandie, Ticino): ALL, Allemand, Ted, Tedesco, D (in GR-Romansh/Italian schools), MF-D, RE-D, WF-D, "Approches interlinguistiques" (Genève, 5P-8P).
- Italian: I @, ITA, Italiano (as foreign language in German-speaking CH or Romandie), WF-I, RE-I, OLM (option langues modernes: italien/espagnol), "Cours facultatif d'italien".
- Spanish: SPA, Spanisch, espagnol.
- Latin: L @ (AKG offiziell), L6, LAT, Latein, Latino, LCA (Langues et cultures de l'Antiquité), OLA (options académiques langues anciennes), "Opz. latino".
- Greek: GRA, G @ (AKG), Griechisch, grec (Vaud facultatif).
- Romansh as foreign language: WF-R, MF-R.
- Chinese: CHI, CHI1, CHI2, CHIN (AKG unverbindliche Übung).
- Heritage language: ESU (Erstsprachenunterricht, AT), HSK, LCO (cours de langue et culture d'origine) [GEN]: go to 7.16 Other, not here.

### 7.4 Natural sciences

- NT @, Natur und Technik, "Natur und Technik (mit Physik, Chemie, Biologie)", Wissenschaft und Technik (SO Sek P Wahlpflicht), Naturwissenschaften, NAWI, NaWi (AKG "Naturwissenschaftliches Labor"), LAB-BIO, LAB-CH, HUM (Humanbiologie).
- Biologie: BIO, BI, BIU, BU, BUK @, "Biologie und Umweltkunde", "Biologie und Umweltbildung", BIUB (Biologische Übungen).
- Chemie: CH @ (AT: Chemie; CH is also the country code), Chemie, Chimie.
- Physik: PH @ (AT Physik; not Philosophie), PHY, Physik, Physique.
- French-speaking: SN, SCN, Sciences de la nature, MSN (domain), OSE (option sciences expérimentales), Scienze naturali, Scienze.
- NMG parts when listed separately: NT (see Natur und Technik) (in Prim the whole NMG is 7.5).
- Related offers: NEE ("Natur erleben und erforschen", Steffisburg Angebot).

### 7.5 Primary general studies

- NMG, "Natur, Mensch, Gesellschaft", "Natur-Mensch-Gesellschaft", NUS (Romansh: Natira, uman e societad), NEUS (Italian: Natura, essere umano, società), WF-NMG, RE-NUS, MF-NEUS (elective, excl. WAH).
- SU, Sachunterricht, Sachbegegnung (AT Vorschulstufe).
- Studio d'ambiente (Ticino SE).
- CE, Connaissance de l'environnement (Vaud 5P-6P), Découverte de l'environnement [GEN].
- U (Pians), GU (AT: Gesamtunterricht) belong to 7.16 / see AT note; GU is a mixed block (D, M, SU, ME, BE...).

### 7.6 Social sciences (history, geography, politics/society, economics)

- RZG, "Räume, Zeiten, Gesellschaften", STS (Romansh/Italian: Spazis, temps e societads / Spazi, tempi, società), GG (RZG), GS (RZG) @, GS @ (AT: Geschichte und Sozialkunde), IST (STS, Romansh Istorgia), ST (STS, Italian Storia), Geografie, Geographie, Geografia, GEO, Géographie, GG @ (AKG Stundenplan code for GWK), Geschichte, GES @ (Bern GES = Gestalten), Geschichte/Staatskunde (SO), HIS, Histoire, Storia, H @ (AKG Stundenplan for GSK).
- Politics/civics: Politische Bildung, Staatskunde, MCC (Monde contemporain et citoyenneté), Citoyenneté, Civisme, Educazione civica / ECCD, "Géographie - Citoyenneté", GSK, GSPB (GPB and GSP not found on any sheet).
- Economics: GWK, GW @ (also Geografie und Wirtschaftskunde/Berufsorientierung in Lemberger), GWB, "Geographie und wirtschaftliche Bildung", Wirtschaft (WAH, see 7.11), "économie et droit" (OS Vaud), WF-NMG excl. WAH.
- Domain heading: SHS.
- Related option: OSH (option sciences humaines).

### 7.7 Arts (visual)

- BG, Bildnerisches Gestalten, WF-BG, BIG (AKG), GESb (Sumiswald Gestalten bildnerisch), BE, Bildnerische Erziehung, Zeichnen, KuG, Kunst und Gestaltung, AF (Romansh/Italian: Art figurativ/Arti figurative, RE-AF, MF-AF), AVI, AV, Arts visuels, Ed. visiva, EV, Educazione visiva, Arti plastiche, Educazione alle arti plastiche, EAP, FV (Fotografie und Video), TÖ (Töpfern), ART (domain), ODE (Dessin technique et artistique).

### 7.8 Music

- MU, Mu, MUS, Musik, ME, Musikerziehung, Musique, Educazione musicale, Ed. musicale, WF-MU, RE-MU, MF-MU, MG / MGS (Musikalische Grundbildung / Grundschule), SPM (Spielmusik), Rhythmik (AT Vorschulstufe), BLO (Blockflöte), UK (Ukulele), BA (Band), MS @ (Malspiel in Steffisburg; Moviment e sport in GR Romansh), SLST (Singe-Lose-Spiele-Tanze), CHOR, VOK, ORCH, Chor, Bläserklasse.

### 7.9 Sport

- BS @, Bewegung und Sport, BSP @ (also AKG Bühnenspiel), BSPM, BSPK, SP @, SPO, Sport, Turnen, EPH, Éducation physique, EPS (not confirmed in sources), Ed. fisica, EF, EFS (Educazione fisica e sport), MS @ (Moviment e sport), CM, CMV (Corps et mouvement domain), Schwimmen [GEN], BALL, FUSB, VBAL, VOL (Volleyball), "Bewegung und Sport Mädchen/Knaben", HH @ (Steffisburg: Hip Hop & Streetdance), Spiel (AT Vorschulstufe).

### 7.10 Religion / ethics / philosophy

- ERG, "Ethik, Religionen, Gemeinschaft", ERC (Romansh/Italian), RKE (Zürich), "Religionen, Kulturen, Ethik", Lebenskunde, RE @ (GR: Religion; Pians: Religion), R @ (AT: Religion; GR Romansh: Rumantsch), REL, REL ev, RL, RK, REV, RGRO, R (kath.), R (ev.), Islam (AT sheet cell), KUW (Kirchliche Unterweisung), ETH, Ethik, ER (enseignement religieux), ECR (Éthique et cultures religieuses, in "Histoire - ECR"), Histoire des religions, Storia delle religioni, SdR, Insegnamento religioso, Istruz. religioso, PuP, PP, PUP (Psychologie und Philosophie, AT Oberstufe), Philosophie, Religion/Ethik.

### 7.11 Crafts, technology, home economics

- TTG, "Textiles und Technisches Gestalten", TxG, TcG, TG, GES tx, GES tc, GEStt, GESt, GES @, WF-TTG, ATT (Arti tessili e tecniche; Art textil e tecnic), RE-ATT, MF-ATT, WE (Werkerziehung), Werken, TuD, TD, Technik und Design, TEW?, TXW? (not found), TCW, TGW, WTX, WTC, ACM, AC&M, Activités créatrices manuelles, OCM, OCET (Opzione capacità espressive e tecniche), Technisches Gestalten, Textiles Gestalten.
- Home economics: WAH @ (Wirtschaft, Arbeit, Haushalt; mixed economics and home-economics, mapped here because of the practical Hauswirtschaft lessons; cross-reference 7.6), ELT (Romansh), ELED (Italian), EFA (Économie familiale), Hauswirtschaft, HW, Hauswirtschaft/Lebensgestaltung (SO), Haushalt, Kochen, KO, WF-KO, RE-CU, MF-CU, Cucina, GC (Gluschtig Choche), Ernährung und Haushalt (AT Mittelschule), Educazione alimentare, Éducation nutritionnelle (Vaud "AC&M / Éducation nutritionnelle"), Cuisine.

### 7.12 Computer science / media

- MI @, Medien und Informatik, WF-MI, RE-MI, MF-MI, INF, Informatik, Informatische Bildung (SO), DG, DGB, Digitale Grundbildung, Éducation numérique (EN @, not EDU NUM confirmed), EDU NUM [GEN], MITIC, "Médias - Science informatique - Usages", "Informatique et médias et images" (Genève CO), "Bain informatique" (Vaud), OIG (Option informatique appliquée et gestion), "Amministrazione e gestione informatica" (Ticino option), L'alfabetizzazione informatica, PRO (Programmieren, Steffisburg), KaB (Kunststücke am Bildschirm, Steffisburg), Tastaturschreiben (also 7.1).

### 7.13 Study time, support, remedial

- FU, Förderunterricht, BFU (Besonderer Förderunterricht), FU/R (FU alternating with Religion), "FU, Lernwerkstatt", LZ, Lernzeit, gegenstandsbezogene Lernzeit, individuelle Lernzeit, LC (Lerncoaching), Studium (AT sheet cell), Lernatelier (UR), LiLO (Lernlandschaft), AdL (Altersdurchmischtes Lernen), IL (Individuelles Lernen), Arbeitsstunde (SG), Individualisierung / IND (GR), DaZ, DaF, DAF, Deutsch als Zweitsprache, Deutschförderklasse, Deutschförderkurs, IF (Integrative Förderung), IS, BF (Begabungsförderung), Begabtenförderung, Logo / Logopädie, PMT [GEN], SHP [GEN], LEG (Legasthenie-Förderung), MF (Mathematik-Förderung), E3/F3 (Englisch/Französisch-Förderung), LF (Latein-Förderung), REX (Renforcement/Extension), FRR, MTR, TDC (Travail en demi-classe), appui, enseignement spécialisé, PPLS, devoirs surveillés (also 7.14), Aufgabenstunde, Hausaufgabenhilfe, beaufsichtigte Stillarbeit, studio assistito, Nachhilfe, Kleinklasse, Werkschule, Wahlpflichtfach WP @.

### 7.14 Care / after-school

- Mittagstisch, Mittagsbetreuung (BMP), Mittagsaufsicht (MA @), Aufsicht, BFLZ, BLZ (Lernzeit in Tagesbetreuung), BMKB (kreative Stunde), Tagesbetreuung, Tagesschule, Tagesstruktur, Betreuung, Betr., Hort, Auffangzeit (A @, AZ), Nachmittagsbetreuung, Schulische Tagesbetreuung, ganztägige Schulform, GTS [GEN], Freizeit (Betreuungsteil), Internat (Winklhof), Mittag, accueil parascolaire, APEMS, accueil de midi, cantine, devoirs surveillés, Mensa, Pause.

### 7.15 Class council / tutor time

- KL (Klassenstunde, Wädenswil), Klassenstunde, Klassenlehrerstunde, Klassenrat, KR [GEN], Ora di classe, HVC (heure de vie de classe) [GEN], Maîtrise de classe, FGE (Formation générale, NE), Formation générale (Genève CO: information and orientation, maîtrise de classe), KV (Klassenvorstand, AT, Winklhof), Lerngespräche, Soziales Lernen, Sonstige verbindliche Übungen (AT).

### 7.16 Other

- Career orientation: BO @, Berufliche Orientierung, BBO, Bildungs- und Berufsorientierung, OP (Orientamento professionale; Orientaziun professiunala; options professionnelles @), OORI (Opzioni di orientamento), OS (Option spécifique), POR (Portfolio).
- Projects and electives: PU (Projektunterricht), PRO @, Projektarbeit, Wahlfach, WF @, MF @, RE- @, Freifach, Freigegenstand, Freifächer, unverbindliche Übungen, AdS (Angebot der Schule), TH (Theater), WF-TDS, RE-TGF, MF-TARS, Théâtre, SCH (Schach), EPWA (vorwissenschaftliche Arbeit), TÖ (Töpfern, also 7.7), NEE, Singen, Lager.
- Heritage and migrant language: ESU, Erstsprachenunterricht, HSK, LCO, Italiano per stranieri.
- Mixed blocks: GU (Gesamtunterricht, AT), U (Gesamtunterricht in Pians; elsewhere Unterricht), "Themenarbeit", "Freiarbeit", Kurs (Jahrgangsgruppe), ACF (Activités complémentaires facultatives).
- Lunch break / free: "Mittag", "frei", "-" (ZH examples), "Pause".

---

## 8. Ambiguous tokens (collision list)

| Token | Reading A | Reading B | Where |
|---|---|---|---|
| M | Mathematik (Bern, Zürich, AT) | no competing subject seen | CH, AT |
| MA | Mathematik (GR, ZH, CH-it) | Mittagsaufsicht (AT Lemberger planner) | CH vs AT |
| E | Englisch | none seen; E4 = Englisch 4. Schulstufe (AT) | |
| F | Französisch | | |
| I | Italienisch / Italiano | | GR, CH |
| R | Romanisch (GR) | Religion (AT VS: Angedair, Augustinum) | GR vs AT |
| RE | Religion (GR, Pians AT) | "RE-" prefix = Wahlfach (roms d'elecziun) in GR Romansh schools (RE-D, RE-E, RE-MA) | GR |
| BS | Bewegung und Sport (CH, Pians) | | |
| BSP | Bewegung und Sport (AT) | Bühnenspiel (AKG unverbindliche Übung) | AT |
| SP | Sport (Steffisburg) | | Bern |
| MS | Moviment e sport (GR Romansh) | Malspiel (Steffisburg) | |
| MG / MGS | Musikalische Grundbildung / Grundschule | | |
| MU, Mu, MUS, ME | Musik | | |
| MI | Medien und Informatik | | all CH |
| KG | Kindergarten (CH) | Kunst und Gestaltung is KuG, not KG | |
| PH | Physik (AT) | Pädagogische Hochschule; not a school subject | AT |
| GS | Geschichte (GS (RZG) in GR) | Geschichte und Sozialkunde (AT Lemberger) | |
| GES | Gestalten (Bern: Wangen, Sumiswald) | Geschichte (GES tc/GES tx used for Gestalten, not Geschichte, in Wangen) | Bern |
| GG | Geografie (GG (RZG) in GR) | Geographie und Wirtschaftskunde on AKG Stundenplan | |
| GW | Geografie und Wirtschaftskunde (AT) | | AT |
| H | Geschichte on AKG Stundenplan | | AT |
| L | Latein (AKG) | | AT |
| G | Griechisch (AKG Stundenplan) | Gymnasium column (Rainer) | AT |
| HH | Hip Hop & Streetdance (Steffisburg) | Hauswirtschaft/Haushalt (not seen) | Bern |
| WAH | Wirtschaft, Arbeit, Haushalt (CH) | | CH |
| CH | Chemie (AT) | CH = Switzerland (Länderkürzel, not a subject) | AT |
| U | Unterricht (ZH Kindergarten sample) | Gesamtunterricht (Pians AT) | |
| A | Auffangzeit (ZH Kindergarten) | A, B, C = Abteilungen/Niveaus/Gruppen | |
| D | Deutsch | D = German as foreign language in GR Romansh/Italian schools and in Romandie grids; "D" also group letter (Wangen "Knaben D") | |
| Sek / Real | track name | used as a subject suffix ("MAT Sek", "DEU Real") | Bern |
| GU | Gesamtunterricht | | AT VS |
| TD / TuD | Technik und Design (AT) | | |
| TCW/TGW, TEW/TXW | Technisches/Textiles Werken (various) | | AT |

## 9. Gaps and caveats

- No real timetable found for Romandie or Ticino with abbreviations; Romandie codes come from the Neuchâtel decree and may not match school exports in other cantons.
- Austrian Untis defaults, the codes TXW, TEW, GSP, BUK, VU and GTS: no source found.
- Several Swiss cantonal items (Luzern, BS, BL, SO, ZH tracks, DaZ/IF/BF) are from search snippets and short summaries; I read the primary text only for GR, NE, GE, VD, TG, SG, UR, SO (Lektionentafel), AT RIS, AKG, Lemberger, Krems, Silz and the school PDFs named in the tables.
- Dead URLs: the Volksschule Obervellach and Flattach Stundenplan PDFs listed by the search engine now return the school home page; their content appears here only through search summaries (GU, TD, REL, FU).
- The schools' own codes change from year to year; the parser should learn per-sheet legends (most CH sheets print a legend; AKG-type lists exist only for some AT schools).

---

## Source index

| Key | URL | What it is |
|---|---|---|
| GR | https://www.gr.ch/DE/institutionen/verwaltung/ekud/avs/Volksschule/Lehrplan21_Faecherbezeichnungen_Abkuerzungen_23112017_it.pdf | Graubünden official LP21 abbreviation list (de, rm, it), read in full |
| ZH | https://www.zh.ch/de/bildung/informationen-fuer-schulen/informationen-volksschule/volksschule-organisation/schulinfo-stundenplaene-blockzeiten.html | Zürich Volksschulamt Kürzel table (summariser) |
| IDES | https://edudoc.ch/record/242583/files/Stundentafeln_Grilleshoraires_25-26.pdf | IDES dossier of all cantonal Stundentafeln 2025/26 (213 pages), parts read |
| LP21-OV | https://www.lehrplan21.ch/stundentafeln and cantonal summaries (https://fr.ch/document/44836) | LP21 structure |
| NE | https://rsn.ne.ch/DATA/program/books/RSN2021/20214/pdf/4103131.pdf | Neuchâtel hourly grid with codes, read |
| GE | https://www.ge.ch/document/10883/telecharger | Genève primary grille horaire (V8.9, 2026), read |
| VD | https://www.vd.ch/fileadmin/user_upload/organisation/dfj/dgeo/fichiers_pdf/grilles_horaires/GrilleHoraire_Cycle2.pdf ; https://www.es-payerne.ch/wp-content/uploads/2026/06/DGEO_Cycle2-2026.pdf ; https://www.es-payerne.ch/wp-content/uploads/2026/06/DGEO_Cycle3-2026.pdf | Vaud grids and parent brochures, read |
| TI | https://pianodistudio.edu.ti.ch/wp-content/uploads/2024/02/Brochure_PdS_WEB_2.pdf | Ticino Piano di studio brochure, read |
| TI-M | https://minusio.sm.edu.ti.ch/wp-content/uploads/sites/40/2026/03/Presentazione-V-elementare-2026.pdf ; https://minusio.sm.edu.ti.ch/wp-content/uploads/sites/40/2025/11/Presentazione-ciclo-dorientamento-II-media-2025.pdf | Scuola media di Minusio grid, read |
| Steffisburg | https://www.steffisburg.ch/schule-wAssets/docs/Dokumente/Stundenplaene/PS/Gesamtstundenplan-Kirchbuehl.pdf (also -Erlen.pdf, -Zulg.pdf) | Bern Primar Gesamtstundenplan with legend and teacher codes, read |
| Wangen | https://www.wangen-a-a.ch/schule/wer-sind-wir/schulbetrieb/stundenplaene/Stundenplaene-Schuljahr-2025_26/Stundenplan-7S-SJ25_26-HP.pdf | Bern 7th Sek sheet with legend, read |
| Sumiswald | https://www.sumiswald.ch/schule/sumiswald/downloads/Stundenplaene-US/5.6.A-mee.pdf | Bern 5/6 A Mittelstufe sheet, read |
| Wädenswil | https://www.oswaedenswil.ch/system/files/page/dateien/1._sek.pdf | Zürich Musterstundenplan 1. Sek with legend, read |
| AT-VS | https://www.ris.bka.gv.at/GeltendeFassung.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10009275 | Lehrplan der Volksschule incl. Stundentafel (summariser) |
| AT-MS | https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40255187/NOR40255187.pdf | Lehrpläne der Mittelschulen, Anlage 3 (Stundentafel), read |
| Silz | https://ms-silz-moetz.tsn.at/sites/default/files/2024-12/Stundentafeln%20im%20SJ%202025%2026.pdf | Subject renamings 2023, read |
| AKG | https://akg-wien.at/wp-content/uploads/2023/01/Fachbezeichnungen-Abkuerzungen.pdf | Akademisches Gymnasium Wien abbreviation list (official vs Stundenplan), read |
| AKG-T | https://akg-wien.at/wp-content/uploads/2026/04/Stundentafeln_2026_04_16_u-st.pdf | AHS Unterstufe Stundentafel 2026, read |
| Rainer | https://www.rainergymnasium.at/unsere-schule/unser-angebot/stundentafeln/stundentafeln-unterstufe/ | Unterstufe Stundentafel names (summariser) |
| LEMB | https://www.bildungsverlag-lemberger.at/assets/bsp_musterseiten/978-3-7098-2645-4_M.pdf | Publisher's Mittelschule planner legend, read |
| KREMS | https://marywardschulen.com/kremsorg/images/Formulare/life%20sciences%20lehrinhalte_stundentafel.pdf | Oberstufe Stundentafel with Kurzbezeichnung, read |
| Pians | https://vs-pians.tsn.at/sites/default/files/2024-09/stundenplan_pians_2024_2025_kl2_und_3.pdf | Volksschule Pians (Tirol), read |
| Angedair | https://vs-angedair.tsn.at/sites/default/files/2024-09/stundenplan_1m_24_25_kinder.pdf ; https://vs-angedair.tsn.at/sites/default/files/2025-10/stundenplan_klasse_1a_sj2526.pdf | Volksschule Angedair (Tirol), read |
| Augustinum | https://www.pvs.augustinum.at/site/assets/files/3180/stundenplan_der_baren-klasse_2025-2026.pdf | Volksschule Augustinum, read |
| Winklhof | https://www.winklhof.at/wp-content/uploads/2025/03/Stundenplan_2024_2025_original-1.pdf | Fachschule sheet with Untis-style cells, read |
| Betreuung | https://www.bmb.gv.at/dam/jcr:01809dd3-13c2-469e-886d-7504890ebe72/betreuungsplaene_lf.pdf | Betreuungspläne ganztägige Schulformen (snippet) |

# School subjects and timetable abbreviations: BW, BY, BE, BB, HB, HH, HE, MV

Research date: 2026-10-23. Scope: Baden-Wuerttemberg (BW), Bayern (BY), Berlin (BE), Brandenburg (BB),
Bremen (HB), Hamburg (HH), Hessen (HE), Mecklenburg-Vorpommern (MV).

## How to read this file (provenance tags)

Every abbreviation carries one tag. Do not treat tags as interchangeable.

| Tag | Meaning |
|---|---|
| `[OFF-CODE]` | Abbreviation defined by a Kultusministerium / state administration source (curriculum abbreviation table, school-administration software value list, regulation text). Official, but often a curriculum or admin-software code, NOT necessarily what a school prints on a timetable. |
| `[OFF-NAME]` | Full subject name taken from an official regulation (Stundentafel) or ministry page. No abbreviation implied. |
| `[SCHOOL]` | Seen in a document published by an individual school (legend, teacher list, timetable). Named in the row. Observed on one school only, not a state standard. |
| `[KNOW]` | Customary form from general knowledge, NOT verified by any source fetched in this research. Use only as a fuzzy-matching alias, never as evidence. |

Method and honesty notes:
- Fetched and read: Verordnungen/Stundentafeln (gesetze-bayern.de, km.baden-wuerttemberg.de, bravors.brandenburg.de, bildung.bremen.de, Hamburg APO-GrundStGy, verkuendung.hessen.de), the BW Bildungsplan 2016 abbreviation tables (bildungsplaene-bw.de), the Bavarian school-administration documentation (doku.asv.bayern.de), the Bavarian Gymnasium Lehrplan abbreviation table, Berlin/Brandenburg RLP-Online subject list, and a handful of school documents.
- Real school timetable legends turned out to be hard to find: most school sheets either print full subject names (e.g. Nymphenburger Schulen BY, Grundschule Ringgau HE) or are not indexed. Genuine observed legends: Regenbogen-Grundschule Berlin, Gymnasium Schramberg BW (teacher subject codes). Everything else about timetable abbreviations is therefore weaker than the tables suggest; see "Gaps".
- The web-search quota for the session was used up before MV, Bremen-Grundschule and Hessen-Sek-I school legends could be searched further. See "Gaps".
- The search tool summarised some pages; where a fact rests only on such a summary (page not fetched by me) the row says `snippet only`.
- No abbreviation standard exists across states. Untis/WebUntis has no built-in German subject list: the subject short name is free master data per school (search-result summary of Untis help pages, `snippet only`). So "Untis defaults" cannot be listed; what schools print is whatever they typed.

---

## Cross-state ambiguities (important for a matcher)

Same short code, different subject, depending on state/school (all observed in the sources below):

| Code | Meanings seen |
|---|---|
| `Sp` | Spanisch (BY Gymnasium Lehrplan, `[OFF-CODE]`); Sport (Berlin Grundschule Regenbogen, `[SCHOOL]`; customary elsewhere `[KNOW]`); possibly Spanisch at Gymnasium Schramberg BW (`E, Sp` next to `Spa`) |
| `S` | Sport (BY Gymnasium Lehrplan `[OFF-CODE]`; Schramberg `[SCHOOL]`) |
| `K` | Katholische Religionslehre (BY ASV `[OFF-CODE]`) vs Kunst (customary elsewhere `[KNOW]`); BY Kunst is `Ku` |
| `E` | Englisch (everywhere); Ethik is `Eth`/`ETH` |
| `Ph` | Physik (BY, BW `PH`); Philosophie is `Phi`/`PHIL` |
| `G` | Geschichte (BY, BW); `Ge` = Geschichte at Regenbogen-GS Berlin `[SCHOOL]` |
| `Geo` | Geographie (BY, BW); `Erd` = Erdkunde (Berlin school) |
| `L` | Latein (BY, BW); LER (BB) is `LER`/`L-E-R` |
| `T`/`Te` | BW `T` = Technik (Wahlpflichtfach) `[OFF-CODE]`; BY ASV `Te` = Technologie, `T` = Technik (Mittelschule, `[OFF-CODE]`) |
| `We` | BY Werken (RSO "Ku, We, TG", ASV `We`); `WG` = Werken und Gestalten (BY Grundschule) |
| `GK` | BW Gemeinschaftskunde `[OFF-CODE]` |
| `NT` / `NuT` | BY Natur und Technik: ASV key is `NuT` (Gymnasium/Realschule list), Mittelschule curriculum name "Natur und Technik (NT)" |
| `PCB` | old BY Mittelschule "Physik/Chemie/Biologie", replaced by "Natur und Technik" (NT) since 2017-2022 `[OFF-CODE]` |
| `AWT` | old BY Mittelschule "Arbeit-Wirtschaft-Technik", now "Wirtschaft und Beruf (WiB)" `[OFF-CODE]`; in MV schools "AWT" still seen `[SCHOOL]` (Schwerin guide) |
| `HSU` | Heimat- und Sachunterricht (BY); old BY name HSK (forum, `snippet only`). Not "Herkunftssprachlicher Unterricht" (that is NRW, irrelevant) |
| `FÖ`/`Fö` | Förderunterricht (Regenbogen-GS Berlin `[SCHOOL]`; BY ASV `FöU`, `FöM`) |
| `VU` | "Vorfachlicher Unterricht" at Regenbogen-GS Berlin `[SCHOOL]`; "Vernetzter Unterricht" at a Schwerin school (MV) `[SCHOOL]`. Different things. |

---

# 1. Baden-Wuerttemberg (BW)

Subject grouping in law: Fächerverbünde were abolished/dissolved step by step. Grundschule: Kontingentstundentafel (hours per 4 years, school distributes). Gymnasium G9 starts with Klasse 5 in 2025/26. "Bildungsplan 2016" abbreviation tables are the official codes.

## 1a. Grundschule (Klasse 1-4)

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch | `D` [OFF-CODE] | GS | BW-GS-ANH |
| Mathematik | `M` [OFF-CODE] | GS | BW-GS-ANH |
| Sachunterricht | `SU` [OFF-CODE] (Fächerverbund "Mensch, Natur und Kultur" was the 2004 name; today "Sachunterricht") | GS | BW-GS-ANH, BW-GS-TAFEL |
| Englisch / Französisch (Fremdsprache from Klasse 3; Französisch near the French border) | `E`, `F` [OFF-CODE] | GS | BW-GS-ANH, BW-ELTERN |
| Kunst/Werken | `KUW` [OFF-CODE] (full name "Kunst/Werken"; Bildungsplan 2016 splits into Bildende Kunst + Textiles/Technisches Werken inside this subject) | GS | BW-GS-ANH, BW-GS-TAFEL |
| Musik | `MUS` [OFF-CODE] | GS | BW-GS-ANH |
| Bewegung, Spiel und Sport | `BSS` [OFF-CODE] | GS | BW-GS-ANH |
| Religionslehre | `REV` evangelisch, `RRK` katholisch, `RAK` altkatholisch, `RALE` alevitisch, `RISL` islamisch (sunnitisch), `RJUED` jüdisch, `RSYR` syrisch-orthodox [OFF-CODE]. No Ethik subject in the BW Grundschule abbreviation table. | GS | BW-GS-ANH |
| Stunden für Förderung und Vertiefung (vorrangig Deutsch/Mathematik, verpflichtend Kl. 1-2) | no code | GS | BW-GS-TAFEL |
| Themenorientierte Projekte (integrativ) | no code | GS | BW-GS-TAFEL |
| Lernzeiten, Blockunterricht, Atelierangebote, Kursunterricht (named as possible organisation forms) | no code | GS | BW-ELTERN |

School sheets: no genuine BW Grundschule legend found. (A search summary mentioned a legend at Grundschule Reutenen with `SU, E, MU, KW, SP, SWIM, R rk, R ev, M Fö, D Fö`; I could not verify it on the school's page. `snippet only`, treat as unverified.)

## 1b. Gymnasium (Klasse 5-10/11; G9 from 2025/26 for Klasse 5-6)

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch | `D` [OFF-CODE]; `d` [SCHOOL: Gymnasium Schramberg teacher list] | Gym | BW-GYM-ANH, SCHRAMBERG |
| Mathematik | `M` [OFF-CODE]; `m` [SCHOOL Schramberg] | Gym | same |
| Englisch (1./2./3. FS) | `E1`, `E2` [OFF-CODE]; `E`, `e` [SCHOOL Schramberg] | Gym | same |
| Französisch | `F1`, `F2`, `F3`(Profil), `F4`(Oberstufe) [OFF-CODE]; `F`, `f` [SCHOOL] | Gym | same |
| Latein | `L1`, `L2`, `L3`, `L4` [OFF-CODE]; `L` [SCHOOL] | Gym | same |
| Spanisch (Profilfach 3. FS / spät beginnend) | `SPA3`, `SPA4` [OFF-CODE]; `Spa` [SCHOOL Schramberg] | Gym | same |
| Weitere Sprachen (Profil/Oberstufe) | `GR3/GR4` Griechisch, `ITAL3/ITAL4` Italienisch, `RU2/RU3/RU4` Russisch, `PORT3/PORT4`, `JAP4`, `CHIN4`, `TUERK4`, `HEBR4` [OFF-CODE] | Gym | BW-GYM-ANH |
| Geschichte | `G` [OFF-CODE]; `G` [SCHOOL] | Gym | same |
| Geographie | `GEO` [OFF-CODE]; `Geo` [SCHOOL] | Gym | same |
| Gemeinschaftskunde | `GK` [OFF-CODE]; `GK`, `Gk`, `gk` [SCHOOL] | Gym | same |
| Wirtschaft / Berufs- und Studienorientierung | `WBS` [OFF-CODE]; `W` (Wirtschaft) [SCHOOL Schramberg]; Oberstufe `WI` Wirtschaft [OFF-CODE] | Gym | same |
| Biologie | `BIO` [OFF-CODE]; `B`, `b` [SCHOOL] | Gym | same |
| Chemie | `CH` [OFF-CODE]; `Ch` [SCHOOL] | Gym | same |
| Physik | `PH` [OFF-CODE]; `Ph` [SCHOOL] | Gym | same |
| Biologie, Naturphänomene und Technik (G8 Kl. 5-6; gone in G9) | `BNT` [OFF-CODE] | Gym (G8) | BW-GYM-ANH, BW-GYM-TAFEL, BW-GYM-KONT |
| Naturwissenschaft und Technik (Profilfach; becomes "Naturwissenschaft, Informatik und Technik" NIT from 2027/28 per GMS page) | `NWT` [OFF-CODE] | Gym | BW-GYM-ANH, BW-GMS |
| Informatik, Mathematik, Physik (Profilfach) | `IMP` [OFF-CODE] | Gym | BW-GYM-ANH |
| Informatik und Medienbildung / Aufbaukurs Informatik / Basiskurs Medienbildung | `INF`, `INF7`, `INFWFO`, `BMB` [OFF-CODE] | Gym | BW-GYM-ANH, BW-GYM-TAFEL |
| Bildende Kunst | `BK` [OFF-CODE]; `bk` [SCHOOL] ; Profil `BKPROFIL` | Gym | same |
| Musik | `MUS` [OFF-CODE]; `Mu` [SCHOOL]; Profil `MUSPROFIL` | Gym | same |
| Sport | `SPO` [OFF-CODE]; `S` [SCHOOL]; Profil `SPOPROFIL` | Gym | same |
| Religion | `REV`, `RRK`, `RAK`, `RALE`, `RISL`, `RJUED`, `RORTH`, `RSYR` [OFF-CODE]; `EvR`, `evr`, `KR` [SCHOOL Schramberg] | Gym | same |
| Ethik | `ETH` [OFF-CODE]; `Eth` [SCHOOL] | Gym | same |
| Philosophie / Psychologie / Literatur und Theater / Astronomie etc. (Oberstufe) | `PHIL`, `PSY`, `LUT`, `LIT`, `ASTRO` [OFF-CODE]; `Phi`, `Psy` [SCHOOL] | Gym Oberstufe | same |
| Profile (Profilfach, 4 h in Kl. 8-10) | no code | Gym | BW-GYM-TAFEL |
| Poolstunden (e.g. Mentoring, Förderung) | no code | Gym | BW-GYM-TAFEL |
| Klassenlehrerstunden (Kl. 5-6) | no code in official table; model school prints `KL` (Klassenleitungsstunde), `MET` (Methodenstunde Geographie), `PL` (Projektlernen) [SCHOOL: Justus-Knecht-Gymnasium Bruchsal G9 model] | Gym | BW-GYM-TAFEL, JKG |

## 1c. Realschule (Klasse 5-10)

Official stundentafel page not fetched in detail (km-bw page for Realschule gives structure only); Sek-I abbreviation table is the common Bildungsplan 2016 table (shown under 1d, plus the Realschule-specific items below).

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch, Mathematik, Englisch, Geschichte, Geographie, Gemeinschaftskunde, WBS, Biologie, Physik, Chemie, Musik, Bildende Kunst, Sport, Religion/Ethik | same `[OFF-CODE]` codes as 1d (`D, M, E1, G, GEO, GK, WBS, BIO, PH, CH, MUS, BK, SPO, REV/RRK, ETH`) | RS | BW-SEK1-ANH |
| BNT (Kl. 5-6) | `BNT` [OFF-CODE] | RS | BW-SEK1-ANH, BW-RS-NECK |
| Wahlpflichtfach Technik | `T` [OFF-CODE] | RS | BW-SEK1-ANH |
| Wahlpflichtfach Alltagskultur, Ernährung, Soziales (chosen from Klasse 5/6; replaces old "Mensch und Umwelt", MuM) | `AES` [OFF-CODE]; MuM only in the old 2004 plan (`snippet only` for "AES replaces MuM") | RS | BW-SEK1-ANH, BW-RS-INFO, BW-RS-NECK |
| Wahlpflichtfach 2. Fremdsprache (Französisch) | `F2` [OFF-CODE] | RS | BW-SEK1-ANH |
| Old (2004/2013) structure still shows in older material: NWA (Naturwissenschaftliches Arbeiten), EWG (Erdkunde-Wirtschaftskunde-Gemeinschaftskunde), Technik, Mensch und Umwelt, ITG (Informationstechnische Grundbildung) | `NWA`, `EWG`, `MuM`, `ITG` (names from the 2013 regulation; no abbreviations officially defined except as acronyms in the title) | RS (old) | BW-RS-2013 |
| Kompetenzanalyse / individuelle Förderung (Kl. 8) | no code | RS | BW-RS-2013 |

## 1d. Gemeinschaftsschule (Klasse 5-10, verbindliche Ganztagsschule; E-/M-/G-Niveau)

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Religionslehre / Ethik | `REV, RRK, RAK, RALE, RISL, RJUED, RORTH, RSYR`, `ETH` [OFF-CODE] | GMS | BW-SEK1-ANH, BW-GMS |
| Deutsch | `D` | GMS | same |
| Englisch (Pflichtfremdsprache) | `E1` ; as 2nd FS `E2` | GMS | same |
| Mathematik | `M` | GMS | same |
| Geschichte, Geographie, Gemeinschaftskunde, Wirtschaft/Berufs- und Studienorientierung | `G, GEO, GK, WBS` | GMS | same |
| Physik, Chemie, Biologie | `PH, CH, BIO` | GMS | same |
| Biologie, Naturphänomene und Technik (Kl. 5-6; 7 Kontingentstunden: Bio 4, Phys 1, Chem 1, Technik 1) | `BNT` | GMS | same |
| Informatik und Medienbildung; Aufbaukurs Informatik (Kl. 7); Basiskurs Medienbildung (Kl. 5) | `INF7`, `INFWF`, `BMB` | GMS | same |
| Projektorientiertes Vorhaben "Engagement und Verantwortung" | no code | GMS | BW-GMS |
| Musik / Bildende Kunst / Sport | `MUS, BK, SPO` | GMS | same |
| Wahlpflichtbereich: Technik; Alltagskultur, Ernährung, Soziales; 2. Fremdsprache (Französisch) | `T`, `AES`, `F2` | GMS | same |
| Profilfach (ab Klasse 8): Naturwissenschaft und Technik (NwT; becomes NIT 2027/28), Informatik/Mathematik/Physik (IMP), Musik, Bildende Kunst, Sport, Spanisch (3. FS) | `NWTPROFIL`, `IMP`, `MUSPROFIL`, `BKPROFIL`, `SPOPROFIL`, `SPA3PROFIL` | GMS | same |
| Coaching (2 h) | no code | GMS | BW-GMS |
| Pool für Maßnahmen zur Differenzierung und Förderung (20 h) | no code | GMS | BW-GMS |
| Lernzeiten (self-directed learning is the core of the GMS timetable) | no official code | GMS | BW-GMS (Ganztag), BW-ELTERN (GS wording) |

Sources BW (URLs):
- BW-GS-ANH https://www.bildungsplaene-bw.de/,Lde/LS/BP2016BW/ALLG/GS/RAK/ANH (Fächer der Grundschule, abbreviation table, fetched)
- BW-SEK1-ANH https://www.bildungsplaene-bw.de/,Lde/LS/BP2016BW/ALLG/SEK1/G/ANH (Fächer der Sekundarstufe I incl. Gemeinschaftsschule profile subjects, fetched)
- BW-GYM-ANH https://www.bildungsplaene-bw.de/,Lde/LS/BP2016BW/ALLG/GYM/SPA3/ANH (Fächer des Gymnasiums, fetched)
- BW-GS-TAFEL https://lexaris.de/book/version/documentflat/head/1123584 (GrSchulStTafelV BW 2001, Kontingentstundentafel; text of the regulation, fetched)
- BW-ELTERN https://km.baden-wuerttemberg.de/fileadmin/redaktion/m-km/intern/PDF/Publikationen/Grundschule/Elterninfo_2025_bf_web.pdf
- BW-GYM-TAFEL https://km.baden-wuerttemberg.de/de/schule/gymnasium/bildungsplan-2016-faecher-und-kontingentstundentafel (G9 and G8 Stundentafel, fetched)
- BW-GYM-KONT https://lehrerfortbildung-bw.de/u_sprachlit/englisch/gym/bp2016/fb3/1_info/2_stunden/101_kontingentstunden_gymnasium_beispiel.pdf (G8 example allocation, 2015)
- BW-GMS https://km.baden-wuerttemberg.de/de/schule/gemeinschaftsschule/bildungsplan-2016-fuer-die-gemeinschaftsschule (Kontingentstundentafel valid from 1 Aug 2025, fetched)
- BW-RS-INFO https://km.baden-wuerttemberg.de/de/schule/realschule/allgemeine-informationen-zur-realschule
- BW-RS-NECK https://www.realschule-neckargemuend.de/unterricht-von-a-z/faecher/ (school page: AES, BNT, Bildende Kunst)
- BW-RS-2013 https://Km-bw.de/fileadmin/redaktion/m-km/intern/PDF/Gesetze_und_Verordnungen/Verordnung_des_KM_zur_nderung_der_Verordnung_ber_die_Stundentafel_der_Realschule.pdf (2013 regulation, outdated)
- SCHRAMBERG https://home.gymnasium-schramberg.de/images/Berichte/2025_2026/PDF/Lehrkräfte_02.pdf and .../Lehrkräfte_01.pdf (teacher list 2025/26 with subject codes and teacher codes)
- JKG https://www.jkg-bruchsal.de/wordpress/inhalte/uploads/2025/11/Stundentafel-G9-JKG-2025-11-23.pdf

Observed BW case variants (Schramberg): the same subject appears as `D`/`d`, `M`/`m`, `E`/`e`, `F`/`f`, `B`/`b`, `GK`/`Gk`/`gk`, `EvR`/`evr`, `Ch`. Lower case likely marks a second/minor teaching qualification, not a different subject (inference, not stated in the document). A matcher should therefore be case-insensitive for such codes.

---

# 2. Bayern (BY)

Pre-notes: the Bavarian ASV (Amtliche Schulverwaltung) documentation publishes the "Schlüsselkurzform" per Fach: these are the official admin codes used for reports/Zeugnisse. Lehrplan abbreviations for the Gymnasium are a separate official table. Timetables of individual schools may differ.

## 2a. Grundschule (Jgst. 1-4)

Official Stundentafel (GrSO Anlage 1): Deutsch, Mathematik, Heimat- und Sachunterricht, Kunst, Musik, Werken und Gestalten, Religionslehre/Ethik/Islamischer Unterricht, Englisch (Jgst. 3-4), Sport, Flexible Stunde. Grundlegender Unterricht in Jgst. 1-2 is one block (Deutsch, Mathematik, HSU, Musik, Kunst).

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch | `D` [OFF-CODE: ASV Grundschule UP 2024] | GS | BY-ASV-GS |
| Mathematik | `M` [OFF-CODE: ASV] | GS | BY-ASV-GS |
| Heimat- und Sachunterricht | `HSU` [OFF-CODE: ASV GS] ; combined "Grundlegender Unterricht Kunst/Musik/HSU" = `GU KuMuHSU` [OFF-CODE: ASV] (Jgst. 1-2). Older name HSK (forum, `snippet only`) | GS | BY-ASV-GS, BY-GRSO |
| Kunst | `Ku` [OFF-CODE: ASV list "Mu/Ku/WG" for Jgst. 3-4] | GS | BY-ASV-GS |
| Musik | `Mu` [OFF-CODE: ASV] | GS | BY-ASV-GS |
| Werken und Gestalten | `WG` [OFF-CODE: ASV] (old Hauptschule name "Werken/Textiles Gestalten" WTG) | GS | BY-ASV-GS, BY-ASV-MS |
| Religionslehre (ev./kath.) / Ethik / Islamischer Unterricht | ASV keys `Ev`, `K`, `Eth`, `IsU` [OFF-CODE: ASV Fächerliste, Waldorf variant] | GS | BY-ASV-FWS |
| Englisch (1. Fremdsprache, Jgst. 3-4) | `E` | GS | BY-ASV-GS (listed as "Englisch / 1. Fremdsprache") |
| Sport | No GS-specific code found. ASV list shows Sport keys `Sm`, `Sw`, `Smw` (Basissport) and `SpT` (Spiel-Turnen Jgst. 1-4) [OFF-CODE: ASV Waldorf list]; Gymnasium Lehrplan uses `S` | GS | BY-ASV-FWS, BY-GYM-LP |
| Flexible Stunde | `FX` (marker "Bereich", not a subject) [OFF-CODE: ASV] | GS | BY-ASV-GS |
| Individuelle Förderung | `IF` [OFF-CODE: ASV subject added with UP 2024] ; Förderunterricht `FöU`, Fördermaßnahmen `FöM` [OFF-CODE: ASV list] | GS | BY-ASV-GS, BY-ASV-FWS |
| Deutsch als Zweitsprache | `DaZ` [OFF-CODE: ASV list] ; LehrplanPLUS also has "Deutsch als Zweitsprache" | GS | BY-ASV-FWS, BY-LP-GS |
| Ganztag / Mittagsbetreuung | no subject code (Ganztagsschule is a separate organisational offer on km.bayern.de) | GS | BY-KM-GS |

## 2b. Mittelschule (Jgst. 5-10; Hauptschule renamed)

Official Stundentafel (MSO Anlage 1): Pflichtfächer Religionslehre; Deutsch; Mathematik; Englisch; Informatik; Wirtschaft und Beruf; Natur und Technik; Geschichte/Politik/Geographie; Sport; Musik (5-6); Kunst (5-6); Werken und Gestalten (5-6); Technik / Wirtschaft und Kommunikation / Ernährung und Soziales (berufsorientierende Wahlpflichtfächer Jgst. 7-10); Förderunterricht (5-6). Wahlpflichtfächer: Ethik/Islamischer Unterricht, Musik, Kunst (7-9). Wahlfächer: alle Fächer des Wahlpflichtbereichs, Informatik und digitales Gestalten, Buchführung. Arbeitsgemeinschaften.

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Wirtschaft und Beruf | `WiB` [OFF-CODE: ASV mapping] ; old "Arbeit-Wirtschaft-Technik" `AWT` | MS | BY-ASV-MS |
| Wirtschaft und Kommunikation | `WiK` [OFF-CODE] ; old `Wi` | MS | BY-ASV-MS |
| Technik | `T` [OFF-CODE] (unchanged) | MS | BY-ASV-MS |
| Ernährung und Soziales | `ES` [OFF-CODE] ; old "Soziales" `So` | MS | BY-ASV-MS |
| Natur und Technik | `NT` [OFF-CODE] ; old "Physik/Chemie/Biologie" `PCB` | MS | BY-ASV-MS |
| Geschichte/Politik/Geographie | `GPG` [OFF-CODE] ; old "Geschichte/Sozialkunde/Erdkunde" `GSE` | MS | BY-ASV-MS |
| Werken und Gestalten | `WG` [OFF-CODE] ; old `WTG` | MS | BY-ASV-MS |
| Informatik | `Inf`; Wahlfach "Informatik und digitales Gestalten" `IdiG` [OFF-CODE] | MS | BY-ASV-MS |
| Buchführung | no abbreviation found | MS | BY-MSO |
| Deutsch, Mathematik, Englisch, Musik, Kunst, Sport, Religion, Ethik, Islamischer Unterricht | ASV keys as in 2c (`D, M, E, Mu, Ku`, `Ev, K, Eth, IsU`) | MS | BY-ASV-FWS |
| Förderunterricht (Jgst. 5-6), Stütz- und Förderkurse (7-9), Tastschreiben, Flexibilisierung (up to 2 h D/M/E) | `FöU` [OFF-CODE: ASV] | MS | BY-MSO |

## 2c. Realschule (Jgst. 5-10, Wahlpflichtfächergruppen I, II, IIIa, IIIb)

Official Stundentafel (RSO Anlage 1): Religionslehre/Ethik; Deutsch; Englisch; Zweite Fremdsprache (Französisch, IIIa/IIIb); Geschichte; Geographie; Politik und Gesellschaft; Wirtschaft und Recht; Mathematik; Physik; Chemie; Biologie; Informationstechnologie (Schwerpunkt TZ/CAD oder Informatik, or BwR); Betriebswirtschaftslehre/Rechnungswesen; Sport; "Musisch-ästhetische Bildung: Gestaltung (Ku, We, TG)"; Musik; Ernährung und Gesundheit.

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Religionslehre/Ethik | `Ev`, `K`, `Eth`, `IsU` [OFF-CODE ASV] | RS | BY-RSO, BY-ASV-FWS |
| Deutsch / Englisch / Französisch / Mathematik | `D`, `E`, `F`, `M` [OFF-CODE ASV key list] | RS | BY-ASV-FWS |
| Geschichte | `G` [OFF-CODE] | RS | BY-ASV-FWS |
| Geographie | `Geo` [OFF-CODE] | RS | BY-ASV-FWS |
| Politik und Gesellschaft | `PuG` [OFF-CODE]; old `Sk` (Sozialkunde) | RS/Gym | BY-ASV-FWS |
| Wirtschaft und Recht | `WR` [OFF-CODE] | RS/Gym | BY-ASV-FWS |
| Physik / Chemie / Biologie | `Ph`, `C`, `B` [OFF-CODE] | RS | BY-ASV-FWS |
| Informationstechnologie | `IT` (RSO text wording "Informationstechnologie"; ASV key not in the fetched list; `Inf` = Informatik) | RS | BY-RSO |
| Betriebswirtschaftslehre/Rechnungswesen | `BwR` [OFF-CODE: ASV FOS/BOS list; RS group II/III use "Betriebswirtschaftslehre/Rechnungswesen"] | RS | BY-ASV-FOSBOS, BY-RSO |
| Gestaltung = Kunst (`Ku`), Werken (`We`), Technisches Zeichnen (`TG`) | `Ku`, `We`, `TG` [OFF-CODE: printed in the RSO table itself] ; ASV `We` Werken, `Te` Technologie | RS | BY-RSO, BY-ASV-FWS |
| Musik | `Mu` [OFF-CODE] | RS | BY-ASV-FWS |
| Sport (Basissportunterricht BSU / Differenzierter Sportunterricht DSU) | `BSU`, `DSU` appear in RSO text [OFF-CODE]; ASV Sport keys see 2a | RS | BY-RSO |
| Ernährung und Gesundheit | no abbreviation found (RSO full name; "EuG" is a guess, unverified) | RS | BY-RSO |
| Erziehungskunde (Jgst. 10 content in Biologie) | `ErK` [OFF-CODE: ASV list] | RS | BY-ASV-FWS |

## 2d. Gymnasium (Jgst. 5-11 under G9, Ausbildungsrichtungen HG, SG, NTG, MuG, WWG, SWG)

Official Stundentafel (GSO Anlage 1): Religionslehre/Ethik/Islamischer Unterricht; Deutsch; Latein/Englisch; Englisch/Latein; Griechisch; Französisch/Italienisch/Russisch/Spanisch/Chinesisch (SG); Mathematik; spät beginnende Informatik; Informatik (NTG); Physik; Chemie; Biologie; Natur und Technik (Jgst. 5-7); Geschichte; Politik und Gesellschaft; Geographie; Wirtschaft und Recht; Kunst; Musik; Sport; verpflichtende/freiwillige Intensivierungsstunden; Modul zur beruflichen Orientierung; Profilstunden (NTG, MuG); Instrument (MuG); Wirtschaftsinformatik (WWG); Sozialpraktische Grundbildung (SWG).

Lehrplan abbreviation table (official, Gymnasium): `B` Biologie, `BcP` Biologisch-chemisches Praktikum, `C` Chemie, `D` Deutsch, `E` Englisch, `Eth` Ethik, `Ev` Evangelische Religionslehre, `F` Französisch, `G` Geschichte, `Geo` Geographie, `Gr` Griechisch, `Inf` Informatik, `It` Italienisch, `K` Katholische Religionslehre, `Ku` Kunst, `L` Latein, `M` Mathematik, `Mu` Musik, `NT` Natur und Technik, `Ph` Physik, `Ru` Russisch, `S` Sport, `SpG` Sozialpraktische Grundbildung, `Sk` Sozialkunde, `Sp` Spanisch, `spb` spät beginnende Fremdsprache, `SwA` Sozialwissenschaftliche Arbeitsfelder, `WIn` Wirtschaftsinformatik, `WR` Wirtschaft und Recht. [OFF-CODE: BY-GYM-LP]. Note: this table is from the G8 Lehrplan (Vorbemerkungen); PuG is not in it (ASV list has `PuG`).

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch, Englisch, Latein, Griechisch, Französisch, Italienisch, Russisch, Spanisch | `D, E, L, Gr, F, It, Ru, Sp` [OFF-CODE] ; ASV also `FiwA/FiwF` (Französisch Waldorf), `SpiwA/SpiwF` (Spanisch) | Gym | BY-GYM-LP, BY-ASV-FWS |
| Mathematik | `M` | Gym | BY-GYM-LP |
| Natur und Technik (Jgst. 5-7) | `NT` (Lehrplan) ; `NuT` (ASV key) [OFF-CODE] | Gym | BY-GYM-LP, BY-ASV-FWS |
| Physik / Chemie / Biologie | `Ph`, `C`, `B` | Gym | BY-GYM-LP |
| Informatik / spät beginnende Informatik / Wirtschaftsinformatik | `Inf`, `WIn` | Gym | BY-GYM-LP |
| Geschichte / Geographie | `G`, `Geo` | Gym | BY-GYM-LP |
| Politik und Gesellschaft | `PuG` (ASV), `Sk` (old Lehrplan) | Gym | BY-ASV-FWS, BY-GYM-LP |
| Wirtschaft und Recht | `WR` | Gym | BY-GYM-LP |
| Kunst / Musik / Sport | `Ku`, `Mu`, `S` | Gym | BY-GYM-LP |
| Religion / Ethik / Philosophie | `Ev`, `K`, `Eth`, `IsU`, `Phi` (ASV) | Gym | BY-GYM-LP, BY-ASV-FWS |
| Intensivierungsstunden | no subject code in the Lehrplan ("keine eigenen Lernziele") | Gym | BY-GYM-LP, BY-GSO |
| Projekte/Schulleben, Schulprofil, Hauptunterricht, Chor/Orchester/Instrumental | `Pro`, `Spr`, `HU`, `Cho`, `Orc`, `Ins` [OFF-CODE: ASV list] | Gym | BY-ASV-FWS |

Observed school sheet (private Gymnasium/Realschule, Nymphenburger Schulen München, Klasse 5): prints full words, not codes: "Klassenleiterstunde", "Lernatelier", "Intensivierung", "Talentzeit", "Natur und Technik", "Religion / Ethik", "Neigung Kunst", "offene Lernbüros und Neigungsangebote", "Essen / Freizeit" [SCHOOL: BY-NYS5]. A Realschule (Vilsbiburg) 5th-grade sample also uses written-out names (`snippet only`).

Sources BY (URLs):
- BY-GRSO https://www.gesetze-bayern.de/Content/Document/BayVSO-ANL_1 (GrSO Anlage 1 Stundentafel, fetched)
- BY-MSO https://www.gesetze-bayern.de/Content/Document/BayMSO-ANL_1 (MSO Anlage 1, fetched)
- BY-RSO https://www.gesetze-bayern.de/Content/Document/BayRSO-ANL_1 (RSO Anlage 1, fetched)
- BY-GSO https://www.gesetze-bayern.de/Content/Document/BayGSO-ANL_1 (GSO Anlage 1, fetched)
- BY-ASV-GS https://doku.asv.bayern.de/gms/unterrichtsplanung/anpassung_stundentafel (Grundschule UP 2024: GU KuMuHSU, IF, FX, WG, D, M, HSU; fetched)
- BY-ASV-MS https://doku.asv.bayern.de/gms/unterricht/lehrplanplusms (Mittelschule Fächerbezeichnung old -> new with Kürzel; fetched)
- BY-ASV-FWS https://doku.asv.bayern.de/_media/fws/faecher/asv_faecherliste_neu.pdf (ASV Fächerliste "Schlüsselkurzform"; this copy is the Freie Waldorfschule variant but uses the shared state keys; fetched)
- BY-ASV-FOSBOS https://doku.asv.bayern.de/bs/fosbos/noze/fachkuerzel ("Liste der offiziellen Fachkürzel" for FOS/BOS; fetched)
- BY-GYM-LP https://www.gym8-lehrplan.bayern.de/contentserv/3.1.neu/g8.de/id_26344.html (Lehrplan Gymnasium, Abkürzungen; fetched)
- BY-LP-GS https://www.lehrplanplus.bayern.de/fachlehrplan/grundschule/3/hsu (navigation lists Grundschule subjects: Deutsch, DaZ, Englisch, Ethik, Evangelische Religionslehre, HSU, Katholische Religionslehre, Kunst, Mathematik, Musik, Sport, Werken und Gestalten; fetched)
- BY-KM-GS https://www.km.bayern.de/lernen/schularten/grundschule/unterricht-und-faecher
- BY-NYS5 https://www.nymphenburger-schulen.de/medien/nys_downloads/datei/319_stundenplan_klasse_5_.pdf
- Forum on HSK->HSU: https://www.rund-ums-baby.de/eltern-forum/grundschule/was-ist-hsu__1347143 (`snippet only`)

---

# 3. Berlin (BE)

Structure: Grundschule Klasse 1-6; Integrierte Sekundarschule (ISS) / Gemeinschaftsschule (GemS) Klasse 7-10; Gymnasium Klasse 7-10 (or Klasse 5 at Gymnasien mit grundständigem Zug). Religion/Weltanschauung (Lebenskunde, Religionsunterricht) is voluntary and taught outside the Stundentafel: the Schulgesetz requires 2 free hours per week in the timetable (Anmerkung g) to the Gymnasium Stundentafel).

Official subject list for Berlin and Brandenburg (RLP-Online, Teil C, fetched): Altgriechisch, Astronomie, Biologie, Chemie, Chinesisch, Deutsch, Deutsche Gebärdensprache, Englisch, Ethik, Französisch, Geografie, Geschichte, **GeWi 5/6**, Hebräisch, Informatik, Italienisch, Japanisch, Kunst, Latein, **L-E-R**, Mathematik, Musik, **Nawi 5/6**, **Nawi 7-10**, Neugriechisch, Philosophie, Physik, Politische Bildung, Polnisch, Portugiesisch, Psychologie, Russisch, **Sachunterricht**, Sorbisch/Wendisch, **SoWi-WiWi**, Spanisch, Sport, Theater, Türkisch, **W-A-T**.

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch | `D` [SCHOOL: Regenbogen-GS] | GS | BE-REGEN |
| Mathematik | `Ma` [SCHOOL] | GS | BE-REGEN |
| Sachunterricht (Kl. 1-4) | `Sa/SU` ("Sachkunde") [SCHOOL] ; RLP name "Sachunterricht" [OFF-NAME] | GS | BE-REGEN, BE-RLP |
| Vorfachlicher Unterricht (Schulanfangsphase) | `VU` [SCHOOL] | GS | BE-REGEN |
| Englisch / Französisch | `Eng`, `Frz` [SCHOOL] | GS | BE-REGEN |
| Sport / Schwimmen | `Sp`, `Sw` [SCHOOL] | GS | BE-REGEN |
| Musik | `Mu` [SCHOOL] | GS | BE-REGEN |
| Bildende Kunst | `BK` [SCHOOL] | GS | BE-REGEN |
| Geschichte / Erdkunde / Politische Bildung | `Ge`, `Erd`, `PB` [SCHOOL] ; RLP: Geschichte, Geografie, Politische Bildung | GS (5-6) | BE-REGEN, BE-RLP |
| Naturwissenschaften (Kl. 5-6) | `NaWi` [SCHOOL] ; RLP "Nawi 5/6" | GS (5-6) | BE-REGEN, BE-RLP |
| Gesellschaftswissenschaften (Kl. 5-6) | `GeWi` [SCHOOL] ; RLP "GeWi 5/6" | GS (5-6) | BE-REGEN, BE-RLP |
| Islamische Religion | `Isl.Rel.` [SCHOOL] | GS | BE-REGEN |
| Förderung individueller Besonderheiten der Schüler | `FiBS` [SCHOOL] | GS | BE-REGEN |
| Förderunterricht | `Fö` [SCHOOL] | GS | BE-REGEN |
| Deutsch als Zweitsprache | `DaZ` [SCHOOL] | GS | BE-REGEN |
| Klassenrat | `KR` [SCHOOL] | GS | BE-REGEN |
| Soziales Lernen | `SL` [SCHOOL] | GS | BE-REGEN |
| Computerunterricht | `PC` [SCHOOL] | GS | BE-REGEN |
| Türkisch / Arabisch (Herkunftssprachen-Kurse) | `Tür`, `Arab` [SCHOOL] | GS | BE-REGEN |
| Arbeitsgemeinschaft | `AG` [SCHOOL] | GS | BE-REGEN |
| School-own project "PRiiL" (interreligiös/interkulturell) | `PRiiL` [SCHOOL] | GS | BE-REGEN |
| Gymnasium (Kl. 7-10): Deutsch; Mathematik; Erste/Zweite Fremdsprache; Lernbereich Naturwissenschaften (Biologie, Physik, Chemie); Lernbereich Gesellschaftswissenschaften (Geschichte, Politische Bildung, Geografie, Ethik); Musik; Kunst; Sport; Wahlpflichtunterricht; Profilstunden | no official abbreviations in the Stundentafel [OFF-NAME] | Gym | BE-GYM |
| ISS/GemS (Kl. 7-10; SESB variant fetched): Deutsch; Fremdsprachen; Mathematik; Biologie; Chemie; Physik; Ethik; Geografie; Geschichte; Politische Bildung; Kunst; Musik; Sport; Wahlpflichtunterricht; Profilstunden; Schülerarbeitsstunden (1,25 h) | Profilstunden support the Fach Wirtschaft-Arbeit-Technik (WAT); WAT mandatory Kl. 9-10 (min. 45 min/week) [OFF-NAME / snippet only for the min. 45 min] | ISS/GemS | BE-SESB, BE-SNIPPET |
| Wirtschaft-Arbeit-Technik | `WAT`, `W-A-T` [OFF-CODE: RLP-Online title "W-A-T"] ; "Leitfach für das Duale Lernen" (Fachbrief 2010, `snippet only`) | ISS/GemS (and BB GS 5-6) | BE-RLP |
| Wahlpflichtunterricht | `WPU` (`snippet only`, Peter-Ustinov-Schule) | ISS | BE-SNIPPET |
| Unterrichtssprache marker for Staatliche Europaschulen | `D` = Deutsch, `P` = nichtdeutsche Partnersprache [OFF-CODE: legend in the Anlage] | SESB ISS/GemS | BE-SESB |
| Religion / Weltanschauung (Ev./Kath. Religionsunterricht, Humanistische Lebenskunde) | none in sources (full names only; voluntary) | all | BE-GYM, BB-FK |

Sources BE (URLs):
- BE-RLP https://bildungsserver.berlin-brandenburg.de/rlp-online/c-faecher/sachunterricht (RLP-Online Fächerliste, fetched)
- BE-GYM https://schulgesetz-berlin.de/media/anlagen/sek-i-vo/sek-i-vo-anlage-2-stundentafel-und-jahresstundenrahmen-gymnasium-2025-09-22.pdf (Sek I-VO Anlage 2, fetched)
- BE-SESB https://www.berlin.de/sen/bildung/schule/besondere-schulangebote/staatliche-europaschule/anlage-7-sesb-stundentafel-iss-gems.pdf (fetched)
- BE-REGEN https://regenbogen-grundschule.de/wp-content/uploads/2017/11/Abk%C3%BCrzungen-f%C3%BCr-die-Unterrichtsf%C3%A4cher.pdf (legend of Regenbogen-Grundschule, Berlin-Neukoelln, published 2017; fetched)
- BE-SNIPPET search-result summaries (not fetched by me): https://www.berlin.de/sen/bildung/schule/bildungswege/integrierte-sekundarschule/ , https://peter-ustinov-schule.de/fachbereiche/ , https://schulportal.berlin.de/get-data/1b8645b3-9212-4714-aac8-60214e1f7d63/fachbrief_wat_01.pdf
- Berlin Grundschule Stundentafel (Anlage zur Grundschulverordnung) and ISS Anlage 1: could not be fetched (JS-only site / HTTP 429). Subject list for GS above therefore comes from RLP-Online and from the Regenbogen legend.

---

# 4. Brandenburg (BB)

Structure: Grundschule Klasse 1-6 (in BB the Grundschule runs to 6). Sek I: Oberschule, Gesamtschule, Gymnasium (Kl. 7-10, Gymnasium may start at Kl. 5 for Leistungs- und Begabungsklassen). LER is compulsory (no denominational religion in Stundentafel; Religionsunterricht is voluntary and organised by churches).

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch (Kl. 1-6) | none in sources | GS | BB-FK, BB-KST |
| Mathematik (Kl. 1-6) | none | GS | BB-FK |
| Sachunterricht (Kl. 1-4) | none (full name only) | GS | BB-FK, BB-KST |
| Kunst, Musik (Lernbereich Ästhetik) | none | GS | BB-KST |
| Sport und Schwimmunterricht | none | GS | BB-FK |
| Begegnungssprache (Kl. 1-2) und erste Fremdsprache (Kl. 3-6; mostly Englisch) | none | GS | BB-FK |
| Sorbisch/Wendisch | none | GS | BB-FK |
| Naturwissenschaften (Kl. 5-6) | `NaWi` [OFF-CODE: BB-FK heading "Naturwissenschaften (NaWi)"; RLP "Nawi 5/6"] | GS 5-6 | BB-FK, BE-RLP |
| Gesellschaftswissenschaften (Kl. 5-6; Geografie, Geschichte, Politische Bildung) | `GeWi` [OFF-CODE: BB-FK; RLP "GeWi 5/6"] | GS 5-6 | BB-FK, BE-RLP |
| Wirtschaft-Arbeit-Technik (Kl. 5-6) | `WAT` [OFF-CODE: BB-FK heading]; `W-A-T` [RLP] | GS 5-6 | BB-FK |
| Lebensgestaltung-Ethik-Religionskunde (Kl. 5-6) | `LER` [OFF-CODE: BB-FK]; `L-E-R` [RLP]. Note: the MBJS page uses "Lebensgestaltung-Ethik-Religion (LER)" (heading) while the 2008-style Stundentafel says "Lebensgestaltung-Ethik-Religionskunde" | GS 5-6, Sek I | BB-FK, BB-KST, BB-SEK1 |
| Religionsunterricht (from Kl. 1, church responsibility; voluntary) | none (EKBO / Erzbistum Berlin / Bistum Görlitz) | all | BB-FK |
| Humanistischer Lebenskundeunterricht (voluntary, from Kl. 1) | none | all | BB-FK |
| Schwerpunktgestaltung (school-chosen hours) | none | GS | BB-KST |
| Sek I (Oberschule, Gesamtschule): Deutsch; 1. Fremdsprache; Wahlpflichtunterricht ab Kl. 7 or 2. Fremdsprache; Mathematik; Biologie / Chemie / Physik; Geografie / Geschichte / Politische Bildung; Lebensgestaltung-Ethik-Religion; Wirtschaft-Arbeit-Technik; Kunst; Musik; Sport; Schwerpunktunterricht für 2./3. Fremdsprache | none in the Anlage | Sek I | BB-SEK1 |
| Gymnasium Sek I: same plus 2. Fremdsprache; Naturwissenschaften / Gesellschaftswissenschaften in Kl. 5-6 for Leistungs- und Begabungsklassen | none | Gym | BB-SEK1 |
| Oberschule school table (Oberschule Nord, `snippet only`) uses short forms `PB`, `LER`, `WAT`, `WP I` | `PB`, `WP I` [SCHOOL, snippet only] | Oberschule | https://www.oberschule-nord.de/index.php?option=com_content&view=article&id=17%3Astundentafel&catid=24%3Afaecher&Itemid=51 |

Sources BB (URLs):
- BB-FK https://mbjs.brandenburg.de/bildung/allgemeinbildende-schulen/grundschule/faecherkanon-stundentafel.html (fetched)
- BB-KST https://mbjs.brandenburg.de/sixcms/media.php/140/kontingentstundentafel_grundschule.pdf (fetched)
- BB-SEK1 https://bravors.brandenburg.de/fm/68/Anlage.243389.pdf (Sek I-V Anlage Kontingentstundentafeln Gesamtschule/Oberschule/Gymnasium, fetched)
- RLP-Online as BE-RLP.

---

# 5. Bremen (HB)

Notable: "Religion" in Bremen is a purely state-run, non-confessional subject taught to the whole class (the 2026 Mitteilung says "rein staatliches Schulfach ... im Klassenverband ... kein (bestimmtes) religiöses Bekenntnis"). In the Oberstufe Religion or Philosophie is chosen. The Grundschule Stundentafel itself could not be fetched; information below is partly from search summaries.

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Religion (5 h Kl. 1-4, practice 0/1/2/2; 6 h Oberschule Kl. 5-10, 5 h Gymnasium Kl. 5-9) | none | GS/OS/Gym | HB-REL |
| Philosophie (alternative to Religion in the Oberschule Stundentafel row "Religion, Philosophie") | none | OS | HB-OS |
| Sachunterricht (18 h Kl. 1-4 per search summary, `snippet only`) | none | GS | https://kleineanfragen.de/bremen/19/375-wie-steht-es-um-die-wirtschafts-und-politikbildung-an-den-schulen-im-lande-bremen.pdf |
| Deutsch (22 h Kl. 5-10), Englisch (22 h) | none | OS | HB-OS |
| Wahlpflichtunterricht (16 h; 2. Fremdsprache und weitere Lernbereiche, from Kl. 6) | none | OS | HB-OS |
| Lernbereich Gesellschaft und Politik: Geografie, Geschichte, Politik (17 h, Gymnasium 15 h Kl. 5-9) ; Wirtschaft, Arbeit, Technik (WAT, 7 h) | `WAT` [OFF-NAME in parentheses in the Anlage] | OS/Gym | HB-OS, https://www.rathaus.bremen.de/sixcms/media.php/13/20191112_Wirtschafts-Politik-Technikuntericht.pdf (`snippet only` for Gym) |
| Mathematik (22 h) | none | OS | HB-OS |
| Naturwissenschaften (12 h; Kl. 5-8 taught integrated as one subject "Naturwissenschaft"), Chemie (2), Physik (4), Biologie (4) in Kl. 9-10 | none | OS | HB-OS (§ 4 Abs. 6) |
| Kunst/Musik/Darstellendes Spiel (12 h) | none | OS | HB-OS |
| Sport (18 h) | none | OS | HB-OS |
| Profil und Ergänzung (14 h) | none | OS | HB-OS |
| Wahlunterricht (4 h) | none | OS | HB-OS |
| "selbstständiges Lernen - Vertiefung" (6 h in Deutsch/Mathematik, Kl. 5-9) | none | OS | HB-OS (Anlage + § 4 Abs. 3) |
| Freiarbeit, Wochen- und Arbeitsplan, Projektunterricht (named as teaching forms inside the quota) | none | OS | HB-OS (§ 4 Abs. 3) |
| Medienbildung and informatische Grundbildung (not separate subjects until Kl. 8) | none | OS | HB-OS (§ 4 Abs. 7) |
| Projektarbeit (Kl. 10) | none | OS | HB-OS (§ 4a) |

No Bremen school timetable legend found.

Sources HB (URLs):
- HB-OS https://www.bildung.bremen.de/sixcms/media.php/13/11094-Anlage%20169-2025_ANL%20verordnung-ueber-die-sekundarstufe-i-der-oberschule2025.pdf (fetched; in force 06.06.2025)
- HB-REL https://bildung.bremen.de/sixcms/media.php/13/mitteilung_108_2026.pdf (fetched)

---

# 6. Hamburg (HH)

Structure: Grundschule Klasse 1-4; Stadtteilschule and Gymnasium from Klasse 5. Hamburg has no single Kürzel authority in anything I could reach; the regulation uses full names. Hamburg-specific names: "Lernbereich Arbeit und Beruf", "Politik-Gesellschaft-Wirtschaft (PGW)", "Naturwissenschaften/Technik", "Gesellschaftswissenschaften", "Theater" (Pflichtfach in Kl. 1-6), "Künste".

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch | none official | GS/StS/Gym | HH-APO |
| Mathematik | none | all | HH-APO |
| Englisch | none | all | HH-APO |
| Sachunterricht | none | GS | HH-APO |
| Religion (Grundschule 4 yrs; StS/Gym Kl. 5-6 Religion, from Kl. 7 Wahlpflicht "Religion oder Philosophie") | none | all | HH-APO |
| Bildende Kunst | none | all | HH-APO |
| Musik | none | all | HH-APO |
| Theater (Pflicht Kl. 1-6; Wahlpflicht "Künste": Bildende Kunst, Musik, Theater from Kl. 7) | none | all | HH-APO |
| Sport (min. 2 h each Jahrgangsstufe) | none | all | HH-APO |
| Naturwissenschaften/Technik (Kl. 5-6); Biologie, Chemie, Physik (Kl. 7-10) | none | StS/Gym | HH-APO |
| Gesellschaftswissenschaften: Geographie und Geschichte (Kl. 5-6); Geographie, Geschichte, Politik-Gesellschaft-Wirtschaft (Kl. 7-10) | `PGW` [SCHOOL: Stadtteilschule Bergstedt brochure] | StS/Gym | HH-APO, HH-BERG |
| "Gesellschaft" (combines Geographie, Geschichte, PGW in Kl. 5-9) | named "Gesellschaft" [SCHOOL] | StS | HH-BERG |
| Lernbereich Arbeit und Beruf / Arbeitslehre (Technik, Wirtschaft, Haushalt, Beruf) | "Arbeitslehre" [SCHOOL] | StS | HH-APO, HH-BERG |
| Informatik (Wahlpflichtbereich) | none | StS/Gym | HH-APO |
| weitere Sprache / Wahlpflicht 2. Fremdsprache (from Kl. 6, spätestens 7) | none | StS/Gym | HH-APO |
| Wahlpflichtbereich (natur-/gesellschaftswiss. Fächer, Informatik, Bildende Kunst, Musik, Theater, Arbeit und Beruf; naturwissenschaftliches Praktikum) | none | StS/Gym | HH-APO |
| Gestaltungsraum (school-defined hours) | none | all | HH-APO |
| Tutor/Tutorin (term for Klassenlehrkraft in StS; two tutors per class) | "Tutor", "Tutorinnen/Tutoren" [SCHOOL] | StS | HH-BERG |
| "flexible Lernzeit" (some hours organised in Lernzeit from Jahrgang 5) | "Lernzeit" [SCHOOL] | StS | HH-BERG |
| Kernfächer Deutsch, Mathematik, Englisch; Pflichtfächer Arbeitslehre, Bildende Kunst, Biologie, Chemie, Musik, Physik, Gesellschaft, Geographie, PGW, Sport | named in the school brochure [SCHOOL] | StS | HH-BERG |
| GBS (Ganztägige Bildung und Betreuung an Schulen) | not found in any fetched source ([KNOW] only) | GS | none |

Sources HH (URLs):
- HH-APO https://albrecht-thaer-gymnasium.schulhomepages.hamburg.de/wp-content/uploads/sites/823/2024/08/2024_apo-grundstgy.pdf (APO-GrundStGy, Stundentafeln Anlagen 2-7; also at https://dokumente.hamburg.de/resource/blob/136184/0f0b5da5811d0277de8491e6de3acb42/apo-grundstgy-data.pdf ; fetched)
- HH-BERG https://stadtteilschule-bergstedt.hamburg.de/wp-content/uploads/sites/776/2024/11/StSBergstedtElternbroschuere2024_2025.pdf (fetched)

---

# 7. Hessen (HE)

Structure: Grundschule Klasse 1-4; Sek I with Hauptschul-, Realschul- (Mittlerer Bildungsgang) and gymnasialer Bildungsgang, taught in Haupt-/Real-/Gesamtschulen (Förderstufe 5-6) and Gymnasium. Official renames by the 2nd amendment of the Stundentafel-Verordnung (GVBl. 22 Jan 2025): "Erdkunde" -> **Geographie**; "Klassenlehrerstunde" -> **Klassenleitungsstunde**; "LB" abbreviation spelled out as **Lernbereich**; Fach **Politik und Wirtschaft** (in practice PoWi) taught in one-hour units ("in der Regel durchgängig in einem einstündigen Unterricht in jeder Jahrgangsstufe"), also when merged in **Lernbereich Gesellschaftslehre**; **Lernbereich Ästhetische Bildung**, **Lernbereich Naturwissenschaften**, **Arbeitslehre** (Hauptschule/Haupt-Realschule), Förderstunden.

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch | none in fetched sources | GS/Sek I | HE-KULTUS |
| Mathematik | none | all | HE-KULTUS |
| Sachunterricht | none | GS | HE-KULTUS |
| Kunst, Musik (Primarstufe) | none | GS | HE-KULTUS |
| Religion/Ethik | none | all | HE-KULTUS |
| Sport | none | all | HE-KULTUS |
| Fremdsprache (ab Klasse 3; mostly Englisch) | none | GS | HE-KULTUS |
| Erdkunde -> Geographie (official 2025) | none | Sek I | HE-GVBL |
| Politik und Wirtschaft | none in sources (customary PoWi [KNOW]) | Sek I | HE-GVBL |
| Geschichte | none | Sek I | HE-GVBL |
| Lernbereich Gesellschaftslehre (GL; Geographie + Politik und Wirtschaft + Geschichte, integrated in Haupt-/Real-/Gesamtschulen) | `GL` [OFF-CODE: "Lernbereich Gesellschaftslehre (GL)" in the 2025 amendment text] | Sek I | HE-GVBL |
| Lernbereich Naturwissenschaften; Lernbereich Ästhetische Bildung | none | Sek I | HE-GVBL |
| Arbeitslehre | none | Sek I (Haupt-/Realschulbildungsgang) | HE-GVBL |
| Wahlunterricht / Wahlpflichtunterricht (2./3. Fremdsprache etc.) | none | Sek I | HE-GVBL |
| Förderstunden; Klassenleitungsstunde | none | Sek I | HE-GVBL |
| Praxisorientierter Bildungsgang / Mittlerer Bildungsgang / Aufbaustufe (organisational terms in the table) | none | Sek I | HE-GVBL |

Observed Hessian Grundschule timetable (Grundschule Ringgau, Klasse 4a): full words "Deutsch", "Religion/Ethik", "Englisch", "Sachunterricht", "Musik", "Sport", "Mathe", "Hofpause" [SCHOOL: https://mpgs.ringgau.schule.hessen.de/aktuell/2023-klasse-2b.html]. The Hessian "landeseinheitlicher Schlüssel" for subjects (form Z 100) is mentioned in a Studienseminar abbreviation list (`snippet only`: AL, B, CH, D, E, EK, EV, F ...). I could not open the key list itself.

Sources HE (URLs):
- HE-KULTUS https://kultus.hessen.de/schulsystem/schulformen-und-bildungsgaenge/grundschule/grundschule/unterricht-grundschule ("Die Stundentafel umfasst die Fächer Deutsch, Mathematik, Kunst, Musik, Sachunterricht, Religion/Ethik und Sport sowie ab dem dritten Schuljahr auch Fremdsprachenunterricht"; fetched)
- HE-GVBL https://verkuendung.hessen.de/sites/verkuendung.hessen.de/files/veroeffentlichungsplattform_plugin/published/732/GVBl_2025_Nr_2_Regelungstext.pdf (fetched)
- Studienseminar abbreviation list: https://sts-ghrf-badvilbel.bildung.hessen.de/service/Beihilfe_u_sonstige_Antraege/Reisekosten/LiV/abkuerzungsverzeichnis_module_u-avs.pdf (`snippet only`; the URL returned 404 when I fetched it)

---

# 8. Mecklenburg-Vorpommern (MV)

Weakest section: the official portal (regierung-mv.de downloads, bildung-mv.de) could not be fetched (redirect to an app shell / DNS failure), and no more searches were possible. What follows is limited to facts I did read, plus clearly marked items.

Structure: Grundschule Klasse 1-4; Orientierungsstufe Klasse 5-6 (school-type independent, common Stundentafel and Rahmenpläne, at Regionale Schule and Gesamtschule); from 7 Regionale Schule / Gymnasium / Gesamtschule. Stundentafelverordnung M-V of 26 July 2024 (Mitteilungsblatt 8/2024); from 2024/25 Klasse 3-4 one more hour Deutsch and Mathematik (25 -> 27 h per week), a daily 20-minute cross-curricular "Lesezeit" in Klasse 1-4 (Nordkurier, fetched); new Kontingentstundentafel planned from 2025/26 with core subjects Deutsch, Mathematik, erste Fremdsprache and an aesthetic block Musik, Theater (Darstellendes Spiel), Kunst (Nordkurier, fetched).

| Subject | Abbreviations seen | Level | Source |
|---|---|---|---|
| Deutsch, Mathematik, Englisch | none | GS/OS/RS/Gym | MV-NK1, MV-NK2 |
| Sachunterricht | none (named as 3 h/class in the Förderschule-Lernen table of the 2026 amendment, `snippet only`) | GS | search summary of https://www.regierung-mv.de/serviceassistent/download?id=1691039 |
| Religion or "Philosophieren mit Kindern" (pupils may choose; offered Kl. 1-10) | none | GS/Sek I | MV-SCHWERIN |
| Musik, Kunst, Theater/Darstellendes Spiel (aesthetic block) | none | all | MV-NK2 |
| Sport | none | all | MV-NK1 |
| Orientierungsstufe combined subjects: "Weltkunde" (Geschichte + Geografie), "Naturwissenschaften" (Biologie + Physik), "Vernetzter Unterricht" (`VU`; Biologie, Geografie, Geschichte, Deutsch), "Methodentraining" | `VU` [SCHOOL: Schwerin school guide] | OS | MV-SCHWERIN |
| Arbeit-Wirtschaft-Technik | `AWT` [SCHOOL: Schwerin guide, rooms "AWT/Informatik"] | Regionale Schule | MV-SCHWERIN |
| Informatik und Medienbildung (Pflichtfach, naturwissenschaftliches Aufgabenfeld with Physik, Chemie, Biologie) | none (name only, `snippet only`) | Regionale Schule 7-10 | search summary of https://www.regierung-mv.de/serviceassistent/download?id=1611200 |
| Zweite Fremdsprache (min. 12 h Kl. 7-10 in Regionale Schule, `snippet only`; Französisch/Latein from Kl. 7 at Gymnasium; Spanisch from Kl. 10) | none | RS/Gym | MV-SCHWERIN |
| Wahlpflichtkurse (Informatik, künstlerische Fächer, Hauswirtschaft, naturwissenschaftliche Fächer, LRS-Förderung, Junge Sanitäter) | none | Regionale Schule | MV-SCHWERIN |
| LRS-/Dyskalkulie-Förderstunden | none | school level | MV-SCHWERIN |
| Niederdeutsch (Plattdeutsch) offered under the Stundentafelverordnung (§ 2, `snippet only`) | none | all | search summary of StdTafVO M-V 2024 |

Sources MV (URLs):
- MV-NK1 https://www.nordkurier.de/regional/mecklenburg-vorpommern/nach-pisa-studie-mehr-deutsch-und-mathe-fuer-grundschueler-2328751 (fetched)
- MV-NK2 https://www.nordkurier.de/regional/mecklenburg-vorpommern/da-ist-musik-drin-debatte-um-neue-stundentafel-2510681 (fetched); also https://www.nordkurier.de/regional/mecklenburg-vorpommern/streit-um-neue-stundentafel-spezial-gymnasien-in-gefahr-2629326
- MV-SCHWERIN https://schwerin.de/export/sites/default/.galleries/Dokumente/Lernen-in-Schwerin/Wegweiser-WS-2021_22-Internet.pdf (guide to Schwerin's weiterführende Schulen 2021/22; fetched)
- Official texts that exist but could not be read: Stundentafelverordnung M-V, https://www.regierung-mv.de/serviceassistent/download?id=1671772 (§ 9 Regionale Schule) and ?id=1671683 (§ 6 Grundschule); 2017 Kontingentstundentafel ?id=1590840 and ?id=580.

---

# Gaps (what is NOT covered or weak)

1. MV: official Stundentafel and Rahmenplan names unavailable; subject names above are partial. No MV timetable legend found.
2. Bremen Grundschule and Gymnasium Stundentafel tables not read; Bremen has no abbreviations in anything fetched.
3. Berlin Grundschule Stundentafel and ISS Anlage 1 not read (JS site / 429); ISS subject list reconstructed from the SESB variant and RLP-Online.
4. Hessen: no official Kürzel list reached; no Hessian Sek-I school legend found.
5. Hamburg, Brandenburg, Bremen, Hessen: no legend by a real school found for Sek I; Hamburg only the Bergstedt brochure (names, no codes).
6. Bayern Grundschule/Mittelschule/Realschule: official ASV admin keys found, but no real school legend with codes found; one private school prints full words.
7. Untis/WebUntis defaults: could not be established; subject abbreviations are school master data.
8. Search quota for the session was exhausted, so no further queries were possible; one query through a web-search engine called via curl (DuckDuckGo) earlier returned the ASV FOS/BOS Fachkürzel page; later attempts were blocked and I stopped.

---

# Groups

For each canonical group: all subject names and all abbreviation/name variants seen. Tags as above. `[KNOW]` items are listed separately at the end of each group and must not be treated as evidence. State codes in brackets: BW, BY, BE, BB, HB, HH, HE, MV.

## German / first language
- Names: Deutsch (all states), Deutsch als Zweitsprache (BY, BE), Niederdeutsch (MV, `snippet only`), Sorbisch/Wendisch (BB; first language for Sorbian speakers), Lesezeit (MV, daily 20 min, not a subject), Schriftspracherwerb (BB, within Deutsch)
- Codes: `D` [OFF-CODE BW, BY]; `d` [SCHOOL Schramberg]; `DaZ` [OFF-CODE BY ASV; SCHOOL BE Regenbogen]; Tastschreiben (BY MS, no code)
- [KNOW] Deu, De, Dt, DeuA

## Mathematics
- Names: Mathematik (all), Mathematik Additum (BY, `M+T` in ASV), Mathematische Basiskompetenzen (BB/BE portal)
- Codes: `M` [OFF-CODE BW, BY]; `m` [SCHOOL Schramberg]; `Ma` [SCHOOL BE Regenbogen]
- [KNOW] Mat, Mathe, Ma

## Foreign languages (which one)
- Englisch: `E`, `E1`, `E2` [OFF-CODE BW, BY]; `e`, `E` [SCHOOL Schramberg]; `Eng` [SCHOOL BE]. As 1. FS from Klasse 3 in BW GS and BY GS (Jgst. 3-4), BB GS Begegnungssprache Kl. 1-2 then FS Kl. 3, HE GS from Kl. 3.
- Französisch: `F`, `F1`, `F2`, `F3`, `F4` [OFF-CODE BW; BY `F`]; `f`, `F` [SCHOOL]; `Frz` [SCHOOL BE]; ASV `FiwA`, `FiwF` (Waldorf). BW GS: Französisch near French border.
- Latein: `L`, `L1`..`L4` [OFF-CODE BW; BY `L`]; `L` [SCHOOL]
- Altgriechisch / Griechisch: `Gr` [OFF-CODE BY]; `GR3`, `GR4` [OFF-CODE BW]
- Spanisch: `Sp` [OFF-CODE BY Gym Lehrplan, ASV `Sp`/`SpiwA`]; `SPA3`, `SPA4`, `SPA3PROFIL` [OFF-CODE BW]; `Spa` [SCHOOL Schramberg]
- Italienisch: `It` [OFF-CODE BY]; `ITAL3`, `ITAL4` [OFF-CODE BW]
- Russisch: `Ru` [OFF-CODE BY]; `RU2`, `RU3`, `RU4` [OFF-CODE BW]
- Türkisch: `TUERK4` [OFF-CODE BW]; `Tür` [SCHOOL BE]; ASV `Ts` is Tschechisch
- Weitere (names): Chinesisch (`CHIN4` BW), Japanisch (`JAP4` BW), Portugiesisch (`PORT3/4` BW; ASV `Po`), Hebräisch (`HEBR4` BW), Polnisch, Neugriechisch, Deutsche Gebärdensprache (BE/BB RLP list), Arabisch (`Arab` [SCHOOL BE]), Ungarisch (ASV `Ung`), Tschechisch (ASV `Ts`)
- Generic: Fremdsprache, Erste/Zweite Pflichtfremdsprache, Wahlpflicht "weitere Sprache" (HH), spät beginnende Fremdsprache `spb` (BY)
- Other: Begegnungssprache (BB), Herkunftssprachen-Kurse (BE school), bilingual/SESB markers `D`/`P` (BE)
- [KNOW] En, Engl, Fr, Franz, La, Lat, Latein, Span, Spanisch, Ita, Ital, Rus

## Natural sciences (Physik, Chemie, Biologie, combined science)
- Names: Physik, Chemie, Biologie (all); Naturwissenschaften (BE/BB "Nawi 5/6", "Nawi 7-10"; HB Kl. 5-8 integrated "Naturwissenschaft"; HH "Naturwissenschaften/Technik" Kl. 5-6; MV "Naturwissenschaften (Biologie und Physik)" in OS; HE "Lernbereich Naturwissenschaften"); Natur und Technik (BY MS/Gym/RS-5-6; ASV `NuT`); Biologie, Naturphänomene und Technik (BW); Naturwissenschaft und Technik (BW Profilfach NwT -> NIT 2027/28); Informatik, Mathematik, Physik (IMP, BW Profilfach); Physik/Chemie/Biologie (PCB, BY MS old); Naturwissenschaftliches Arbeiten (NWA, BW RS old); Naturwissenschaftliches Praktikum (HH); Astronomie (BE/BB RLP, BY `Ph Ast`); Biologisch-chemisches Praktikum (BY `BcP`); Erziehungskunde (BY RS `ErK`)
- Codes: `BIO`, `CH`, `PH`, `BNT`, `NWT`, `NWTPROFIL`, `IMP` [OFF-CODE BW]; `B`, `C`, `Ph`, `NT`, `NuT`, `BcP`, `Ph Ast`, `ErK` [OFF-CODE BY]; `PCB` [OFF-CODE BY old]; `NaWi` [SCHOOL BE Regenbogen; OFF-CODE BB GS heading]; `Nawi 5/6`, `Nawi 7-10` [OFF-CODE RLP]; `Ch`, `B`, `b`, `Ph` [SCHOOL Schramberg]; `NWA` [BW RS old, acronym in 2013 regulation text]
- [KNOW] Bio, Chem, Phy, Phys, NW, NWT, NaWi, NuT, PCB.
- Requested names NOT found in any fetched source of these 8 states: "MNT", "Natur und Technik" as a BW/BE/HH/HB subject name (BW uses BNT/NwT; HH uses "Naturwissenschaften/Technik"), "GPG" outside Bayern Mittelschule (there = Geschichte/Politik/Geographie), "Werte und Normen" (Niedersachsen), "Lernbüro"/"Freiarbeit" as timetable codes (Freiarbeit appears only as a teaching form in HB § 4 Abs. 3).

## Sachunterricht / Sachkunde (primary general studies)
- Names: Sachunterricht (BW, BB, BE, HB, HH, HE, MV), Heimat- und Sachunterricht (BY), Sachkunde (BE school legend only), Mensch, Natur und Kultur (BW 2004 Fächerverbund), Welt/Umwelt (Bremen 2004, old), Vorfachlicher Unterricht (BE school)
- Codes: `SU` [OFF-CODE BW]; `Sa/SU` [SCHOOL BE Regenbogen]; `HSU` [OFF-CODE BY ASV GS]; `GU KuMuHSU` [OFF-CODE BY ASV, Jgst. 1-2 combined block Kunst/Musik/HSU]; `HSK` (old BY name, forum `snippet only`); `VU` [SCHOOL BE]
- Note: BY Grundschule 1-2: Grundlegender Unterricht = Deutsch, Mathematik, HSU, Musik, Kunst as one 16-hour block (km.bayern.de).
- [KNOW] SU, Sach, Sachk, SK

## Social sciences (history, geography, politics/society, economics)
- History: Geschichte `G` [OFF-CODE BW, BY]; `Ge` [SCHOOL BE]; `G` [SCHOOL Schramberg]; combined: Geschichte/Politik/Geographie `GPG` [OFF-CODE BY MS], Geschichte/Sozialkunde/Erdkunde `GSE` [OFF-CODE BY MS old], Weltkunde (Geschichte + Geografie) [SCHOOL MV OS], "Geschichte" within "Gesellschaft" [SCHOOL HH StS]
- Geography: Geographie `GEO` [OFF-CODE BW]; `Geo` [OFF-CODE BY]; `Geo` [SCHOOL Schramberg]; Erdkunde `Erd` [SCHOOL BE], renamed to Geographie in HE 2025 [OFF-NAME]; Geografie (BE, BB, HB, MV spelling with "f"); Erdkunde, Wirtschaftskunde, Gemeinschaftskunde `EWG` (BW RS old)
- Politics/society: Gemeinschaftskunde `GK` [OFF-CODE BW], `GK`/`Gk`/`gk` [SCHOOL Schramberg]; Politik und Gesellschaft `PuG` [OFF-CODE BY]; Sozialkunde `Sk` [OFF-CODE BY]; Politische Bildung `PB` [SCHOOL BE, BB Oberschule snippet] (BE/BB RLP name "Politische Bildung"); Politik und Wirtschaft (HE, customary PoWi [KNOW]); Politik-Gesellschaft-Wirtschaft `PGW` [SCHOOL HH Bergstedt]; Politik (HB "Geografie, Geschichte, Politik"); SoWi-WiWi (BE/BB RLP); Sozialwissenschaftliche Arbeitsfelder `SwA` (BY)
- Combined area: GeWi / Gesellschaftswissenschaften `GeWi` [SCHOOL BE; OFF-CODE BB 5/6]; Gesellschaftslehre `GL` [OFF-CODE HE, as "Lernbereich Gesellschaftslehre (GL)"]; "Welt – Zeit – Gesellschaft" (BW Hauptschule certificate, snippet only); "Gesellschaft" [SCHOOL HH]; "Gesellschaft und Politik" Lernbereich (HB); "Gesellschaftswissenschaften" (HH)
- Economics: Wirtschaft und Recht `WR` [OFF-CODE BY]; Wirtschaft / Berufs- und Studienorientierung `WBS` [OFF-CODE BW]; `WI` Wirtschaft (Oberstufe BW); Wirtschaft `W` [SCHOOL Schramberg]; Wirtschaft und Beruf `WiB` [OFF-CODE BY MS]; Wirtschaft und Kommunikation `WiK` [OFF-CODE BY MS]; Wirtschaft-Arbeit-Technik `WAT`/`W-A-T` [OFF-CODE BB/BE/HB]; Arbeit-Wirtschaft-Technik `AWT` [OFF-CODE BY old; SCHOOL MV Schwerin]; Betriebswirtschaftslehre/Rechnungswesen `BwR` [OFF-CODE BY]; Buchführung (BY MS Wahlfach); Lernbereich Arbeit und Beruf (HH); Arbeitslehre (HH school, HE)
- [KNOW] Gesch, Ge, Erd, Ek, Geo, Pol, PoWi, Gemk, Sowi, Sozi, Gewi, Wipo, WiPo, Wirtschaft

## Arts (visual)
- Names: Kunst, Bildende Kunst, Kunst/Werken (BW GS), Kunst und Gestalten (MV rahmenplan name, not verified), Gestaltung (BY RS: Ku, We, TG), Lernbereich Ästhetik/Ästhetische Bildung (BB, HE), Kunst/Musik/Darstellendes Spiel (HB block)
- Codes: `KUW` [OFF-CODE BW GS]; `BK` [OFF-CODE BW]; `BKPROFIL`; `bk` [SCHOOL Schramberg]; `BK` [SCHOOL BE]; `Ku` [OFF-CODE BY; RSO]; `K` is Katholische Religionslehre in BY ASV (NOT Kunst)
- [KNOW] Kun, Kunst, Bi, BiKu, Ku

## Music
- Names: Musik; Chor, Orchester, Instrumentalunterricht (BY ASV `Cho`, `Orc`, `Ins`); erweiterter Musikunterricht (BY GS/MS); Bläserklasse (MV school)
- Codes: `MUS` [OFF-CODE BW]; `MUSPROFIL`; `Mu` [OFF-CODE BY; SCHOOL BE; SCHOOL Schramberg]
- [KNOW] Mus

## Sport
- Names: Sport; Bewegung, Spiel und Sport (BW GS `BSS`); Sport und Schwimmunterricht (BB); Basissportunterricht BSU / Differenzierter Sportunterricht DSU (BY); Spiel-Turnen (BY ASV `SpT`); Schwimmen `Sw` [SCHOOL BE]; Sporttheorie `S Theo` (BY Gym Lehrplan)
- Codes: `SPO`, `SPOPROFIL` [OFF-CODE BW]; `BSS` [OFF-CODE BW GS]; `S` [OFF-CODE BY Gym; SCHOOL Schramberg]; `Sp` [SCHOOL BE]; ASV `Sm`/`Sw`/`Smw` (Basissport) [OFF-CODE BY]
- [KNOW] Spo, Sp, Spt

## Religion / ethics / philosophy
- Names: Religionslehre (ev., kath., altkath., alevitisch, islamisch, jüdisch, orthodox, syrisch-orthodox, Freie christliche, Neuapostolisch, Christengemeinschaft, Israelitisch), Religion (HB, state subject; HH), Ethik (BW, BY, BE; compulsory in BE Sek I), Islamischer Unterricht (BY `IsU`), Lebensgestaltung-Ethik-Religionskunde (BB `LER`/`L-E-R`), Philosophie (HH Wahlpflicht "Religion oder Philosophie"; HB "Religion, Philosophie"; BE/BB RLP; BY ASV `Phi`), Philosophieren mit Kindern (MV, alternative to Religion), Humanistischer Lebenskundeunterricht (BB/BE, voluntary), Religion/Weltanschauung (BE, 2 free hours), Psychologie (BW/BY/BE Oberstufe)
- Codes BW: `REV`, `RRK`, `RAK`, `RALE`, `RISL`, `RJUED`, `RORTH`, `RSYR`, `ETH`, `PHIL`, `PSY` [OFF-CODE]; BY: `Ev`, `K`, `Eth`, `IsU`, `Isr` (israelitisch), `FR`, `NR`, `RC`, `Ort`, `Rl` (sonstige), `Phi` [OFF-CODE ASV]; BB `LER`, `L-E-R`; BE `Isl.Rel.` [SCHOOL]; Schramberg: `EvR`, `evr`, `KR`, `Eth`, `Phi`, `Psy` [SCHOOL]
- [KNOW] Rel, Re, R, Ev, Rev, Rk, Rrk, Kath, Eth, WuN (Werte und Normen is a Niedersachsen subject, not found in these 8 states), Phi

## Crafts, technology, home economics
- Names: Werken und Gestalten (BY GS/MS; `WG`), Werken `We` (BY), Textiles Gestalten (BY), Technisches Zeichnen `TG` (BY RS), Technologie `Te` (BY ASV), Technik `T` (BW Wahlpflichtfach; BY MS), Ernährung und Soziales `ES` (BY MS), Ernährung und Gesundheit (BY RS), Alltagskultur, Ernährung, Soziales `AES` (BW), Mensch und Umwelt `MuM` (BW RS old), Hauswirtschaft `Hw` (BY ASV), Arbeitslehre (HH school, HE), Wirtschaft-Arbeit-Technik `WAT` (BB/BE/HB), Arbeit-Wirtschaft-Technik `AWT` (BY old, MV school), Gartenbau `GaB`, Handarbeit `HAr`, Handwerkliches Gestalten `HaG`, Textilarbeit mit Werken `TaW` (BY ASV Waldorf list), Hauswirtschaft/Kochstudio/Nähstudio (MV school rooms)
- Codes: `T`, `AES`, `KUW` (BW GS: Kunst/Werken) [OFF-CODE]; `WG`, `We`, `TG`, `Te`, `T`, `ES`, `Hw`, `GaB` [OFF-CODE BY]; `WAT`, `W-A-T` [OFF-CODE BB/BE]; `AWT` [SCHOOL MV]
- [KNOW] Tec, Tech, TW (Textiles Werken BW), Werk, Wer, HuS, HS, AL, Nadelarbeit

## Computer science / media
- Names: Informatik; Informatik und Medienbildung (BW, MV); Informatik und digitales Gestalten `IdiG` (BY MS Wahlfach); Aufbaukurs Informatik `INF7`; Basiskurs Medienbildung `BMB` (BW); Informationstechnologie (BY RS "IT"); Medienkunde `Mk`, Medien `Me`, Textverarbeitung `Tv` (BY ASV); Informationstechnische Grundbildung `ITG` (BW RS old); Wirtschaftsinformatik `WIn` (BY); Computerunterricht `PC` [SCHOOL BE]; Computerunterricht `Com` [SCHOOL SH Tremser Teich, out of scope]; Medienbildung as cross-curricular (HB)
- Codes: `INF`, `INFWF`, `INFWFO`, `INF7`, `BMB` [OFF-CODE BW]; `Inf`, `WIn`, `IdiG`, `Mk` [OFF-CODE BY]; `PC` [SCHOOL BE]
- [KNOW] IT, Info, ITG

## Study time, support, remedial
- Names: Förderunterricht (BY MS/GS/Gym; BE school `Fö`; BY ASV `FöU`), Fördermaßnahmen `FöM` (BY), Individuelle Förderung `IF` (BY GS ASV UP 2024), Flexible Stunde `FX` (BY GS), Intensivierungsstunden (BY Gym, MS-RS "Intensivierung" on Nymphenburger sheet), Stütz- und Förderkurse (BY MS), Förderung und Vertiefung (BW GS), Pool für Differenzierung und Förderung (BW GMS/Gym "Poolstunden"), Coaching (BW GMS), Lernzeiten (BW GS/GMS; HH StS "flexible Lernzeit"), Lernatelier / Talentzeit / Lernbüro / Neigungsangebote (BY private school sheet), selbstständiges Lernen - Vertiefung (HB OS), Schülerarbeitsstunden (BE ISS/SESB), FiBS (BE school), LRS-Förderung, Dyskalkulie-Förderstunden (MV), Förderstunden (HE), Kompetenzanalyse mit individueller Förderung (BW RS), Nachhilfe/Hausaufgabenbetreuung (not found)
- Codes: `FöU`, `FöM`, `IF`, `FX` [OFF-CODE BY]; `Fö`, `FiBS` [SCHOOL BE]; `M Fö`, `D Fö` (`snippet only`, BW GS Reutenen)
- [KNOW] LZ, Lz, FU, FÖ, Förder, FuX/Dif-X (appears in a school legend of unknown state via search summary, `snippet only`)

## Care / Hort / after-school
- Names found: Ganztagsschule, Betreuungsangebote (BW school page), Ganztägige Bildung und Betreuung (BB, bildungsserver nav), Mittagessen / Essen / Freizeit (BY private school sheet), Hofpause (HE GS sheet), Offene Ganztagsangebote (BY sheet), Arbeitsgemeinschaft `AG` (BY MSO, BE school legend), Wahlunterricht (BY MSO, HB OS), Neigungsangebote (BY private school)
- No Hort/eFöB/GBS code was found in any fetched source (BE eFöB, HH GBS, HE Pädagogische Mittagsbetreuung, BY Mittagsbetreuung are [KNOW] names only; they are not timetable subjects)
- Codes: `AG` [SCHOOL BE]
- [KNOW] Hort, eFöB, GBS, OGS, Betreuung, Mittag, Frühdienst

## Class council / tutor time
- Names: Klassenrat `KR` [SCHOOL BE Regenbogen]; Soziales Lernen `SL` [SCHOOL BE]; Klassenlehrerstunde (BW Gym G9 table; formerly HE) ; Klassenleitungsstunde (HE 2025 official; BW JKG model `KL`); Klassenleiterstunde (BY private school sheet); Tutor/Tutorinnen (HH StS); Methodenstunde `MET`, Projektlernen `PL` (BW JKG G9 model); Methodentraining (MV school); Mentoring (BW Gym Poolstunde); Klassenlehrkraft term in BY GS ("Klassenleiterin oder Klassenleiter hält grundsätzlich den gesamten Unterricht"); Projekte/Schulleben `Pro` (BY ASV); Schulprofil `Spr` (BY ASV)
- Codes: `KR`, `SL` [SCHOOL BE]; `KL`, `MET`, `PL` [SCHOOL BW JKG]; `Pro`, `Spr` [OFF-CODE BY ASV]
- [KNOW] KL, KLS, Kl.-Std., Klassenlehrerstunde, Tut, Tutorium

## Other
- Names: Theater / Darstellendes Spiel (HH Pflicht Kl. 1-6, MV aesthetic block, BE/BB RLP "Theater"); Literatur und Theater `LUT`, Literatur `LIT` (BW Oberstufe); Astronomie `ASTRO`; Darstellende Geometrie `DG`; Digitale mathematische Werkzeuge `DMW`; Geologie `GEOL` (BW Oberstufe); Schulgarten `Sga`, Schulspiel `SSp`, Eurythmie `Eur`, Hauptunterricht `HU` (BY ASV, mostly Waldorf); Kommunikation und Interaktion `KuI`, Gesundheitswissenschaften `GeWi` (BY ASV FOS/BOS — NOTE: ASV `GeWi` = Gesundheitswissenschaften, different from BE/BB GeWi = Gesellschaftswissenschaften!); Übungsunternehmen `ÜU`; Praxislernen (BE ISS, new Anlage 1a 2026, `snippet only`); Duales Lernen (BE); Berufliche Orientierung (BY Gym module, HH, HB); Wahlpflichtunterricht `WPU` (BE school snippet) / `WP I` (BB school snippet); Projekt-Seminar zur beruflichen Orientierung (BY Gym); Profilstunden (BE, BY Gym), Profile (BW Gym), Profilfach (BW GMS/Gym); Schwerpunktunterricht / Schwerpunktgestaltung (BB); Gestaltungsraum (HH); Seminarfach (not in these 8 states' sources); Lesezeit (MV GS)
- Codes: `WPU`, `WP I`, `Pro`, `Spr` as above.

---

## Quick list of strongest findings for the app

1. Official abbreviation tables exist only for BW (Bildungsplan 2016) and BY (ASV admin keys; Gymnasium Lehrplan; Mittelschule renaming table). Everywhere else the regulation uses full names and the codes are school-specific.
2. BW curriculum codes are mostly 1-3 letters upper case (`D, M, E1, F1, L1, G, GEO, GK, WBS, BIO, CH, PH, MUS, BK, SPO, ETH, REV, RRK, BNT, NWT, IMP, AES, T, BSS, KUW, SU`); a real BW Gymnasium prints mixed case (`d`, `Geo`, `Mu`, `bk`, `Spa`, `EvR`, `KR`).
3. BY keys: `D, E, M, B, C, Ph, Inf, G, Geo, PuG, Sk, WR, NuT/NT, Ku, Mu, We, WG, Te, T, Hw, Ev, K, Eth, IsU, Sp(=Spanisch), S(=Sport), FöU, IF, FX, HSU, GU KuMuHSU, WiB, WiK, ES, GPG, AWT(old), GSE(old), PCB(old)`.
4. Berlin/Brandenburg official curriculum names that look like codes: `GeWi 5/6`, `Nawi 5/6`, `Nawi 7-10`, `L-E-R`, `W-A-T`, `SoWi-WiWi`. A Berlin Grundschule legend adds `Ma, Sa/SU, Eng, Frz, Sp, Sw, Mu, BK, Ge, Erd, NaWi, GeWi, VU, FiBS, KR, SL, PC, Fö, DaZ, AG`.
5. Hessen 2025 renames: Erdkunde -> Geographie, Klassenlehrerstunde -> Klassenleitungsstunde; Lernbereich Gesellschaftslehre (GL) with Geographie, Politik und Wirtschaft, Geschichte.
6. Hamburg: StS/Gym use "Gesellschaftswissenschaften" and "Naturwissenschaften/Technik" in Kl. 5-6, "Politik-Gesellschaft-Wirtschaft (PGW)" from Kl. 7; "Theater" is a regular subject from Kl. 1; "Lernbereich Arbeit und Beruf"; tutors instead of Klassenlehrer.
7. Bremen: "Religion" is a state, non-confessional subject (5 h GS, 6 h OS, 5 h Gym); Oberschule has "Naturwissenschaft" integrated Kl. 5-8 and "Gesellschaft und Politik" with "Wirtschaft, Arbeit, Technik (WAT)".
8. MV: "Philosophieren mit Kindern" as alternative to Religion; Orientierungsstufe Kl. 5-6; "Weltkunde" / "Naturwissenschaften" combined subjects; "AWT" still used.

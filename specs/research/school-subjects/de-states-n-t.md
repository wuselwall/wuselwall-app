# Fächer und Fächerkürzel auf Stundenplänen: NI, NW, RP, SL, SN, ST, SH, TH + Software

Research date 2026-10-23. Scope: Niedersachsen (NI), Nordrhein-Westfalen (NW), Rheinland-Pfalz (RP), Saarland (SL), Sachsen (SN), Sachsen-Anhalt (ST), Schleswig-Holstein (SH), Thüringen (TH).

## 0. Read this first: how reliable is what follows

Evidence labels used in every table:

- **[OFF]** = taken from an official document (Ministerium, Gesetzestext, Lehrplan portal). Where an official abbreviation list exists, the code is [OFF] too.
- **[SHEET]** = observed on a school's own published timetable or school-published legend (a single school, not binding).
- **[WEB]** = published by a non-official site (parent guide, blog). Weaker than [SHEET].
- **[GEN]** = customary / general knowledge of the German school-software scene that I could NOT verify with a source in this session. Treat as a hypothesis for alias lists, never as fact.
- "text read from local copy" = I downloaded the PDF and extracted its text myself; "search summary" = I only have the search engine's summary of the page, not the page itself.

Main findings:

1. **Only Sachsen publishes an official, binding abbreviation list** (Anlage 7 of the VwV Stundentafeln: "Einheitliche Abkürzungen für alle Schularten"). For NI, NW, RP, SL, ST, SH, TH I found no Kultusministerium list of timetable Kürzel. In those states the codes on timetables are chosen by the school (or by the software), so a parser must use alias lists plus the full subject names, not a fixed code table. The nearest thing to an official code set outside Sachsen is the Saarland ministry slide deck (De, Ma, FS, NW, GW, R/E, AL, BK, Mu, Sp).
2. The **full official subject names are well documented** (Stundentafeln, Kerncurricula, Fachanforderungen, Lehrplanportale) and are listed per state below.
3. The software vendors (Untis/WebUntis, Indiware/Stundenplan24, IServ, Sdui, Schulmanager, DaVinci) **do not document a default code table**; see section 9. Short names are free text, so they are school-specific.
4. Observed sheets I could actually read: SH Grundschule (Untis export), NI Gymnasium (Untis export), NI parent-guide list, NI private school list, SL ministry slides, NW Gesamtschule Wahlpflicht brochures. **No readable sheet found for RP, ST, TH, or NW Grundschule.** The web-search budget of the session ran out before I could look for those; a follow-up search for "Stundenplan <Schule> Kürzel Legende" for RP/ST/TH is the obvious next step.
5. Pitfalls proven by the sources: the same code means different things (see section 10): `BK` = Bildende Kunst in SL, Blindenkurzschrift in SN; `Ges` = Geschichte in NI Gymnasium but `GES` = Gesellschaftslehre at CSN Buchholz; `F` = Französisch (NW WP) or Förder-prefix (NI Gymnasium: FMa, FEn).

---

## 1. Niedersachsen

### 1.1 Official subject names

| Subject (official name) | Level | Source | Status |
|---|---|---|---|
| Deutsch, Mathematik, Sachunterricht, Englisch, Sport, Musik, Kunst | Grundschule | https://www.schure.de/22410/32-82150.htm (Kerncurricula list) | [OFF] |
| Gestaltendes Werken, Textiles Gestalten | Grundschule and Sek I | same | [OFF] |
| Evangelische / Katholische / Islamische Religion | Grundschule, Sek I | same | [OFF] |
| Herkunftssprachlicher Unterricht | Grundschule | same | [OFF] |
| Werte und Normen (Ersatzfach für Religion; compulsory in Grundschule from school year 2026/27, ascending from Jg. 1) | Sek I; Grundschule new | https://www.mk.niedersachsen.de/startseite/aktuelles/presseinformationen/land-will-die-erprobungsphase-werte-und-normen-an-grundschulen-ausweiten--kuenftig-nehmen-40-grundschulen-teil-165458.html ; https://www.news4teachers.de/2018/06/niedersachsen-will-fach-werte-und-normen-an-mehr-grundschulen-testen/ ; SVBl 05/26 https://www.mk.niedersachsen.de/download/227945/MK-SVBl_05_26_Amtl._Teil_S.246-255_.pdf.pdf (search summary) | [OFF] |
| Lernzeit "Sichere Basis" (Jg. 1-4, "kein Unterrichtsfach"; Stundentafel in Erlass "Die Arbeit in der Grundschule" vom 01.07.2024, Nr. 3) | Grundschule | https://www.mk.niedersachsen.de/startseite/schule/unsere_schulen/allgemein_bildende_schulen/grundschule/verlassliche_grundschule/verlassliche-grundschule-149807.html | [OFF] |
| Verlässliche Grundschule (at least 5 Zeitstunden daily) | Grundschule | same | [OFF] |
| Oberschule Stundentafel I/II: Fachbereich Sprachen (Deutsch, 1. Fremdsprache, 2. Fremdsprache); Mathematik-Naturwissenschaften (Mathematik, Physik, Chemie, Biologie, Informatik); geschichtlich-soziale Weltkunde (Geschichte, Politik / Politik-Wirtschaft in the gymnasial Angebot, Erdkunde); Arbeit / Wirtschaft-Technik (Wirtschaft, Technik, Hauswirtschaft); musisch-kulturelle Bildung (Musik, Kunst, Gestaltendes Werken, Textiles Gestalten); Religion / Werte und Normen; Sport; **Verfügungsstunden** (class teacher, Jg. 6-10); Wahlpflichtunterricht/Profile; Wahlunterricht, Förderunterricht, Arbeitsgemeinschaften | Oberschule | https://www.schure.de/22410/32-81028.htm | [OFF] |
| Oberschule Kerncurricula: Deutsch, Englisch, Niederländisch, Spanisch, Latein, Mathematik, Naturwissenschaften (Physik, Chemie, Biologie), Informatik, Geschichte, Erdkunde, Politik, Wirtschaft, Technik, Hauswirtschaft, Musik, Kunst, Gestaltendes Werken, Textiles Gestalten, Ev./Kath./Islam. Religion, Werte und Normen, Sport | Oberschule | https://www.schure.de/22410/32-82150.htm | [OFF] |
| Gymnasium Kerncurricula additionally: Französisch, Griechisch, Russisch, Chinesisch, **Politik-Wirtschaft**, **Theater / Darstellendes Spiel** | Gymnasium Sek I | same | [OFF] |
| Realschule / Hauptschule: same list as Oberschule | Realschule, Hauptschule | same | [OFF] |
| IGS Kerncurricula: **Gesellschaftslehre** (Geschichte, Politik, Erdkunde), Naturwissenschaften (Biologie, Chemie, Physik), **Arbeit-Wirtschaft-Technik**, Theater/Darstellendes Spiel | Integrierte Gesamtschule | same | [OFF] |
| Ganztag: Oberschule as Ganztagsschule offers "ganztägiges Unterrichts- und Förderangebot" | Oberschule | https://www.schure.de/22410/32-81028.htm Nr. 3.2.2 | [OFF] |
| Legal claim to Ganztagsbetreuung at Grundschulen from school year 2026/27; Untis NI handout: define own subjects per offer or one subject "Betreuung" / "Ganztag"; staff codes may get suffix "-GT" or "-PM" | Grundschule | https://www.untis.at/fileadmin/user_upload/partners/Niedersachsen/Downloads/anleitung/Umsetzung_der_Ganztagsbetreuung_in_Stundenplan_und_Klassenbuch.pdf (Stand 22.04.2026, text read from local copy) | vendor handout for NI |

### 1.2 Abbreviations seen

| Subject | Abbreviations seen | Level | Source | Status |
|---|---|---|---|---|
| Deutsch | D, De | Grundschule | https://www.grundschulratgeber.de/abkuerzungen-aus-dem-schulalltag/ (page says "Gilt für Niedersachsen") | [WEB] |
| Mathematik | M, Ma | Grundschule | same | [WEB] |
| Sachunterricht | SU | Grundschule | same | [WEB] |
| Englisch | E | Grundschule | same | [WEB] |
| Musik | Mu | Grundschule | same | [WEB] |
| Sport | Sp | Grundschule | same | [WEB] |
| Kunst | Ku | Grundschule | same | [WEB] |
| Religion | Rel, Reli | Grundschule | same | [WEB] |
| Textiles Gestalten | TG | Grundschule / Sek I | same | [WEB] |
| (Gestaltendes) Werken | WE | Grundschule / Sek I | same | [WEB] |
| Klassenlehrkraftunterricht | KLU | Grundschule | same | [WEB] |
| Erstunterricht / Anfangsunterricht (both listed as "X") | EU, AU | Grundschule | same | [WEB] |
| (Betreuungskraft, a staff role, not a subject) | BK | Grundschule | same | [WEB] |
| Deutsch | Deu | Gymnasium | Untis export, Gymnasium Neu Wulmstorf https://www.gym-nw.de/wp-content/uploads/2023/05/Stundenplaene_Internet_Periode11.pdf (text read from local copy) | [SHEET] |
| Mathematik | Mat | Gymnasium | same | [SHEET] |
| Englisch | Eng | Gymnasium | same | [SHEET] |
| Latein / Französisch | Lat / Fra | Gymnasium | same | [SHEET] |
| Musik / Kunst | Mus / Kun | Gymnasium | same | [SHEET] |
| Geschichte / Erdkunde / Politik | Ges / Erd / Pol | Gymnasium | same | [SHEET] |
| Biologie / Chemie / Physik | Bio / Che / Phy | Gymnasium | same | [SHEET] |
| Informatik | Inf | Gymnasium | same | [SHEET] |
| Religion | Rel | Gymnasium | same | [SHEET] |
| Werte und Normen | WuN | Gymnasium | same | [SHEET] |
| Verfügungsstunde (class teacher) | Verfü | Gymnasium | same | [SHEET] |
| Förderunterricht (F + subject) | FEn (Förder Englisch), FMa (Förder Mathe), FDeR (Förder Deutsch/...; exact expansion not given) | Gymnasium | same | [SHEET] |
| Sport | not clearly decodable in that export (`sp` appears); do not assume | Gymnasium | same | [SHEET] |
| Arbeit Wirtschaft Technik | AWT | Sek I (private school) | https://www.csn-buchholz.de/enzyklopaedie/faecher-abkuerzungen/ (Christliche Schule Nordheide, Buchholz; the page does not name the state, Buchholz in der Nordheide is in NI) | [SHEET] |
| Biologie, Chemie, Deutsch, Englisch, Mathematik, Physik | Bio, Che, Deu, Eng, Ma, Phy | Sek I | same | [SHEET] |
| Gesellschaftslehre (Sammelfach Geschichte + Erdkunde) | GES | Sek I | same | [SHEET] |
| Geschichte (Oberstufe) | Ges | Sek II | same | [SHEET] |
| Naturwissenschaften (Kl. 5-8) | NAT | Sek I | same | [SHEET] |
| Politik und Wirtschaft | PoWi | Sek II | same | [SHEET] |
| Hauswirtschaft / Textil / Werken / Kunst / Musik (Wahlpflicht) | Hw / Te / We / Ku / Mu | Sek I | same | [SHEET] |
| Spanisch / Sport / Religion / Psychologie | Spa / Spo / Rel / Ps | Sek I-II | same | [SHEET] |
| Medienkunde | Mk | Sek I | same | [SHEET] |
| Selbstorganisiertes Lernen / Planarbeit / Verfügungsstunde KL / Hausaufgaben-Training (GS) / Jahresprojekt | SOL / PLAN / Verf / HA-Tr / JP | Sek I, GS | same | [SHEET] |
| Biblischer Unterricht, Neues Testament erleben | BU, NT | private Christian school | same | [SHEET] |
| Klassenlehrerstunde; Differenzierungsstunde in subject X | KlS; Dif-X | a school legend reported by a search summary (school and URL not captured) | unverified |

Grundschule Altenlingen (NI) prints full subject names with teacher in brackets, no codes (search summary; PDF not fetchable any more).

---

## 2. Nordrhein-Westfalen

### 2.1 Official subject names

| Subject (official name) | Level | Source | Status |
|---|---|---|---|
| Stundentafel Grundschule (AO-GS, in Kraft 01.08.2025): Deutsch; Mathematik; Sachunterricht; Kunst, Musik (one row); Englisch; Religionslehre; Sport. Former variable Förderstunden are now allocated to the subjects (the old combined block "Deutsch, Sachunterricht, Mathematik, Förderunterricht" is gone) | Grundschule | https://bass.schule.nrw/20144.htm | [OFF] |
| Gesamtschule Sek I (Anlage 4, Amtsblatt-Fassung 2022; text read from local copy): Deutsch; **Gesellschaftslehre** (Geschichte, Erdkunde, Wirtschaft-Politik); Mathematik; **Naturwissenschaften** (Biologie, Chemie, Physik); Informatik; Englisch; Technik; Hauswirtschaft; Künstl./musischer Bereich (Kunst, Musik); Religionslehre; Sport; Wahlpflichtunterricht; Ergänzungsstunden; up to 5 h muttersprachlicher Unterricht | Gesamtschule | https://recht.nrw.de/system/files/BHA/24798-38442-sgv_223_20121102_1_anlage4.pdf | [OFF] |
| Older Gesamtschule table (2005): Arbeitslehre (Technik, Wirtschaft, Hauswirtschaft) instead of the separate Technik/Hauswirtschaft rows | Gesamtschule (historical) | https://recht.nrw.de/system/files/BHA/20369-22743-sgv_223_20050429_2_anlage4.htm | [OFF] |
| Gymnasium G8 Sek I (Stundentafel 2019; text read from local copy): Deutsch; Gesellschaftslehre (Geschichte, Erdkunde, Wirtschaft-Politik); Mathematik; Naturwissenschaften (Biologie, Chemie, Physik); Englisch; Zweite Fremdsprache; Künstl./musischer Bereich (Kunst, Musik); Religionslehre; Sport; Wahlpflichtunterricht; Praktische Philosophie per § 3 Abs. 5 | Gymnasium | https://www.schulministerium.nrw/sites/default/files/documents/Stundentafel.pdf | [OFF] |
| Footnotes: all subjects of the Lernbereiche Gesellschaftslehre and Naturwissenschaften must be taught; Chemie starts usually in Kl. 7; Kunst and Musik at least 6 h each | all Sek I forms | same | [OFF] |
| Praktische Philosophie = Ersatzfach for Religionslehre (footnote, not a table row) | Sek I | same | [OFF] |
| Hauptschule: "Wirtschaft und Arbeitswelt"; Realschule groups Geschichte, Erdkunde, Politik / Wirtschaft and Biologie, Chemie, Physik | Hauptschule, Realschule | search-result summaries of recht.nrw.de PDFs (not readable by me) | unverified |
| Wahlpflicht (WP) areas: Französisch/Spanisch; Naturwissenschaften; Darstellen & Gestalten; Arbeitswelt Wirtschaft / Wirtschaft und Arbeitswelt; Informatik | Gesamtschule | brochures in 2.2 | [SHEET] |
| Offener Ganztag (OGS) | Grundschule | school-run, no code found | - |
| Kernlehrpläne portal https://www.lehrplannavigator.nrw.de not reachable from the research environment | - | - | gap |

### 2.2 Abbreviations seen

| Subject | Abbreviations seen | Level | Source | Status |
|---|---|---|---|---|
| Wahlpflichtbereich / -fach | WP, WP 1 / WPI (Wahlpflichtbereich I), WPII | Gesamtschule | https://ge-kreuztal.de/wp-content/uploads/2025/03/WP-Info_Brochuere_2025.pdf ; https://www.gesamtschule-eiserfeld.de/wp-content/uploads/2026/04/WPI_aktuell-ohne-Termine.pdf (text read from local copies) | [SHEET] |
| Französisch (WP) | F | Gesamtschule Kreuztal | Kreuztal brochure | [SHEET] |
| Naturwissenschaften | NW | Gesamtschule Kreuztal; Teamschule Drensteinfurt | Kreuztal brochure; https://www.teamschule.drensteinfurt.de/wp-content/uploads/2021/04/Praesentation-InfoAbend.pdf | [SHEET] |
| Darstellen und Gestalten | DG | same | same | [SHEET] |
| Arbeitswelt Wirtschaft | AW | Kreuztal | Kreuztal brochure | [SHEET] |
| Arbeitslehre (Technik, Wirtschaftslehre, Haushaltslehre) | AL | Teamschule Drensteinfurt | Drensteinfurt presentation | [SHEET] |
| Informatik | Info | Kreuztal | Kreuztal brochure | [SHEET] |
| Erweiterungs- / Grundkurs level | E-Kurs / G-Kurs | Kreuztal | Kreuztal brochure | [SHEET] |
| Französisch / Spanisch course sets | F7, S8, F9, S9, F11, S11 | Eiserfeld | Eiserfeld presentation | [SHEET] |
| Ergänzungsstunden (context) | ERG | Eiserfeld | Eiserfeld presentation | [SHEET] |
| NW-typical SchILD / Untis codes (GL, KR, ER, PP, PK, SW, IF, TC, EK ...) | - | SchILD-NRW/SVWS has an internal Fach-Kürzel catalogue that I could not retrieve; codes are not verified | [GEN] |

---

## 3. Rheinland-Pfalz

### 3.1 Official subject names

| Subject | Level | Source | Status |
|---|---|---|---|
| Grundschule VV Unterrichtsorganisation (28.06.2024), table "Fächer/Lernbereiche": Religion/Ethik; Deutsch; Sachunterricht (Lernbereich Deutsch/Sachunterricht in Kl. 1-2); Mathematik; Musik; Kunst; Sport; Fremdsprache (Kl. 3-4; Englisch bzw. Französisch); "Integrierte Fremdsprachenarbeit"; Verfügungszeit (0,5 h, Kl. 3-4); daily Lesezeit in Deutsch | Grundschule | https://bildung.rlp.de/fileadmin/user_upload/grundschule.bildung.rlp.de/Rechtsgrundlagen/Verwaltungsvorschrift_Unterrichtsorganisation_in_der_Grundschule-2024.pdf (text read from local copy) | [OFF] |
| Teilrahmenpläne GS: Deutsch, Mathematik, Fremdsprachen, Evangelische Religion, Katholische Religion, Ethik, Sport, Musik, Kunst, Sachunterricht | Grundschule | https://bildung.rlp.de/grundschule/rechtsgrundlagen | [OFF] |
| Realschule plus Stundentafel (VV 07.04.2009), 30 Wochenstunden: Religion/Ethik; Deutsch; 1. Fremdsprache; Mathematik; **Gesellschaftswissenschaftlicher Bereich** (Erdkunde, Geschichte, Sozialkunde, alternativ **Gesellschaftslehre**); **Naturwissenschaftlicher Bereich** (Naturwissenschaften, Biologie, Chemie, Physik); Künstlerischer Bereich (**Bildende Kunst**, Musik); Sport; **Klassenstunde**; Wahlpflichtbereich (**Technik und Naturwissenschaft**, **Hauswirtschaft und Sozialwesen**, **Wirtschaft und Verwaltung**, 2. Fremdsprache, schuleigene Angebote e.g. Sport, Darstellendes Spiel, Informatik); Profilstunden; Wahlfreier Bereich (Chor/Orchester, Arbeitsgemeinschaften, **Förderunterricht**) | Realschule plus | https://bildung.rlp.de/fileadmin/user_upload/realschuleplus.bildung.rlp.de/Service/Rechtliche_Grundlagen/VV_Stundentafel_RS_plus.pdf (text read from local copy) | [OFF] |
| Lehrplan Gesellschaftslehre (March 2022, Kl. 5-10, Realschule plus and IGS) | Sek I | https://bildung.rlp.de/fileadmin/user_upload/demokratie.bildung.rlp.de/Downloads/Lehrplan_Gesellschaftslehre_Maerz-2022.pdf (title only) | [OFF] |
| Ganztagsschule (verpflichtende Form / Angebotsform) | Grundschule | same GS VV, Nr. 2.5.4 | [OFF] |
| Gymnasium Sek I | - | not retrieved (RLP Lehrplan database gave no static list) | gap |

### 3.2 Abbreviations seen
None in an RP source (no official list, no readable RP sheet). Only a Untis guide for RP bilingual Gymnasium courses (course subject pattern `<Fach>_<Niveau>_<Parallelkursnummer>`, example `Gkbili-E_GK_11`, i.e. "Gk" for Gemeinschaftskunde) from https://help.untis.at/hc/de/article_attachments/15056875156892 (search summary) [SHEET-level, unverified].

---

## 4. Saarland

### 4.1 Official subject names

| Subject | Level | Source | Status |
|---|---|---|---|
| Grundschule Stundentafel (GrSchulSTV 2005, older; may be superseded): Kl. 1-2: Religion (2), Deutsch (5), Sachunterricht (3), Mathematik (5), Bildende Kunst/Musik (3), Sport (2), Förderunterricht (5, range 3-5); Kl. 3-4: Religion, Deutsch, Sachunterricht, Mathematik, Bildende Kunst, Musik, Sport, Französisch (2), Förderunterricht (2) | Grundschule | https://lexaris.de/book/version/documentflat/head/1368505 | [OFF] (old) |
| Gemeinschaftsschule Stundentafel structure: Gesamtstunden 180 (KMK 176); "Klassenleitungsstunde" and "Lernen lernen" (1 h each in Kl. 5/6); Grundstunden in **De, Ma, FS, NW, GW** (98); übrige Stunden in **R/E, AL, BK, Mu, Sp** (63); flexible Stunden in De, Ma, FS, NW, GW (15); Sprachkurs (2 h, second foreign language); differentiation in De, Ma, 1. FS, NW (Bi, CH, Ph) | Gemeinschaftsschule | ministry slide deck "Das Saarland macht Schule", hosted at https://www.gems-schmelz.de/wp-content/uploads/2015/01/Das-Saarland-macht-Schule.pdf (text read from local copy) | [OFF] (ministry slides, c. 2012) |
| Naturwissenschaften (NW) integrated in Kl. 5-7, optionally Biologie / Chemie / Physik from Kl. 8; Gesellschaftswissenschaften (GW) integrated Kl. 5-8, optionally Erdkunde / Geschichte / Sozialkunde from Kl. 9 | Gemeinschaftsschule | same | [OFF] |
| Eingangsklasse 5 Gemeinschaftsschule: Klassenrat, Deutsch, Mathematik, 1./2. Fremdsprache (Fr/En), Sprachkurs (En/Fr), Naturwissenschaften, Gesellschaftswissenschaften, Arbeitslehre, Bildende Kunst, Musik, Sport, Religion bzw. Allgemeine Ethik, Schuleigene Förderkonzepte | Gemeinschaftsschule | https://gs-geislautern-wehrden.voelklingen.de/wp-content/uploads/2022/11/WelcheSchulefuermeinKind_Elterninfo_2022_11_08_Endversion.pdf (text read from local copy) | ministry parent info |
| Eingangsklasse 5 Gymnasium: Klassenrat, Deutsch, Mathematik, 1./2. Fremdsprache (Fr/En/La), Naturwissenschaften, Erdkunde, Religion bzw. Allgemeine Ethik, Bildende Kunst, Sport, Musik, Schuleigene Förderkonzepte | Gymnasium | same | ministry parent info |
| Gemeinschaftsschule portal (Arbeitslehre, Religion oder Ethik, Sport, Bildende Kunst, Musik) | GemS | https://www.saarland.de/mbk/DE/portale/bildungsserver/schulen-und-bildungswege/schulen/gemeinschaftsschule (search summary; fetch returns 403) | [OFF] |

### 4.2 Abbreviations seen

| Subject | Abbreviations seen | Source | Status |
|---|---|---|---|
| Deutsch, Mathematik | De, Ma | ministry slides above | [OFF] |
| Fremdsprache | FS, 1. FS; Fr, En | same | [OFF] |
| Naturwissenschaften | NW (parts: Bi, CH, Ph) | same | [OFF] |
| Gesellschaftswissenschaften | GW | same | [OFF] |
| Religion / Ethik | R/E | same | [OFF] |
| Arbeitslehre | AL | same | [OFF] |
| Bildende Kunst | BK | same | [OFF] |
| Musik, Sport | Mu, Sp | same | [OFF] |
| Allgemeine Ethik (Oberstufe) | Et | search summary of https://www.ludwigsgymnasium.com/fileadmin/user_upload/DOS_2019_PowerPoint.pdf | unverified |

The deck is a ministry presentation, not a timetable, but its codes are the closest thing to an official Saarland code set.

---

## 5. Sachsen (the only state with an official abbreviation list)

Source of all codes below: **Anlage 7 zu VwV Stundentafeln** (SMK; "Abkürzungen der Fächer, Lernbereiche ... und der sonstigen in den Stundentafeln verwendeten Begriffe (Grundschule, Oberschule einschließlich Oberschule+, Förderschule, Gymnasium, Gemeinschaftsschule und Schulen des zweiten Bildungsweges)", column "Einheitliche Abkürzungen für alle Schularten"), edition 29.04.2024: https://www.revosax.sachsen.de/attachments/35181 ; parent regulation https://www.revosax.sachsen.de/vorschrift/3200 . Text read from local copy of the PDF. Earlier editions: 2019 https://revosax.sachsen.de/attachments/31926 ; 2004 "Anlage 18" https://www.recht.sachsen.de/GetAttachment.link?id=1117 (still had Mittelschule, `HK` Heimatkunde, `PHI` Philosophie, `PSY`, `AST`, `MS` Maschineschreiben, `SPO/m/w`).

Status of every row in this section: **[OFF]**.

### 5.1 Subjects of the Stundentafeln (Anlagen 1a, 3a, 4a; version effective 01.08.2026; text read from local copies)

| Level | Subjects (exact names) |
|---|---|
| Grundschule (Anlage 1a) https://www.revosax.sachsen.de/attachments/38081 | Deutsch; Sachunterricht; Englisch (Kl. 3-4); Mathematik; Sport; Evangelische Religion / Katholische Religion / Ethik (Wahl); Kunst; Musik; Werken; Intensives Sprachenlernen; Angebote zur individuellen Förderung |
| Oberschule (Anlage 3a) https://www.revosax.sachsen.de/attachments/31917 | Deutsch; Englisch; Mathematik; Biologie; Chemie; Physik; Geschichte; Gemeinschaftskunde/Rechtserziehung; Geographie; Wirtschaft-Technik-Haushalt/Soziales; Sport; Ev./Kath. Religion/Ethik; Kunst oder Musik; Technik/Computer (Kl. 5-6); Informatik (Kl. 7-10); Förderunterricht (Kl. 5-6); Wahlbereich: 2. Fremdsprache (abschlussorientiert), Angebote zur individuellen Förderung / Komplexe Lernleistung |
| Gymnasium Sek I (Anlage 4a) https://www.revosax.sachsen.de/attachments/35174 | Deutsch; Englisch; 2. Fremdsprache; Mathematik; Biologie; Chemie; Physik; Geschichte; Gemeinschaftskunde/Rechtserziehung/Wirtschaft; Geographie; Sport; Religion/Ethik; Kunst; Musik; Technik/Computer; Informatik; Wahlpflicht: schulspezifisches Profil, 3. Fremdsprache; Individuelle Förderung; Selbstorganisiertes Lernen (Kl. 8-10, "individuelle Lernzeit") |

### 5.2 Official abbreviations (Anlage 7, 2024 edition)

| Name | Code |
|---|---|
| Deutsch | DE |
| Mathematik | MA |
| Englisch | EN |
| Französisch | FR |
| Latein | LA |
| Griechisch | GR |
| Spanisch | SPA |
| Russisch | RU |
| Italienisch | ITA |
| Polnisch / Tschechisch / Sorbisch / Chinesisch / Hebräisch | POL / TSC / SOR / CHI / HE |
| 1. / 2. / 3. Fremdsprache | 1. FS / 2. FS / 3. FS (2. FS abschlussorientiert: "2. FS (abschl.)") |
| Intensives Sprachenlernen | ISL (ISL/FR, ISL/POL, ISL/TSC, ISL/SOR) |
| Deutsch als Zweitsprache | DaZ |
| Herkunftssprache / spezifisch muttersprachlicher Unterricht | HU / SMU |
| Biologie / Chemie / Physik | BIO / CH / PH |
| Natur, Technik und Informatik | NTI |
| Sachunterricht | SU |
| Deutsch-Sachunterricht (integrated block) / Deutsch-Heimatkunde/Sachunterricht | DE-SU / DE-HKS |
| Geschichte | GE |
| Geographie | GEO |
| Gemeinschaftskunde/Rechtserziehung | GK |
| Gemeinschaftskunde/Rechtserziehung/Wirtschaft | G/R/W |
| Gesellschaft und Wirtschaft (Gemeinschaftsschule) | GuW |
| Wirtschaft-Technik-Haushalt/Soziales | WTH |
| Hauswirtschaft | HW |
| Arbeitslehre | AL |
| Arbeit und Beruf | AuB |
| Berufsorientierung | BO |
| Technik/Computer | TC |
| Informatik | INF |
| Werken | WE |
| Kunst | KU |
| Kunst/Modellieren | Ku/M |
| Kunst und Musik | KU/MU |
| Musik | MU |
| Rhythmisch-musikalische Erziehung | Rhy |
| Sport | SPO |
| Profilsport | PS |
| Evangelische / Katholische / Jüdische Religion | RE/e / RE/k / RE/j |
| Ethik | ETH |
| Förderunterricht | FÖ |
| Angebote zur individuellen Förderung | indFö |
| Angebote zur individuellen Förderung/Komplexe Lernleistung | AiFKL |
| Angebote zur individuellen sonderpädagogischen Förderung | AisF |
| Anfangsunterricht | AU |
| Dehnungsjahr | DJ |
| Wahlpflichtkurs / Wahlpflichtunterricht | WPK / WPU |
| Profilunterricht | P |
| Beratung | Brg |
| Begleitung der inklusiven Unterrichtung | BiU |
| Lernen in der Praxis | LeP |
| Maschineschreiben | MAS |
| Blindenkurzschrift | BK (differs from Saarland BK = Bildende Kunst) |
| Kurs Gebärde | KURSG |
| Zertifikatskurse | ZENA, ZENF, ZFRA, ZFRF, ZRUA, ZRUF, ZSPAA, ZSPAF |
| Förderschule-specific | O/M, PSB, SLF, WDBK, DVzF |
| AbiBac variants | FR-AbiBac, Geo-AbiBac, GE-biku-AbiBac |

Sachsen sheets: none retrieved. Related fact: Stundenplan24/Indiware (Kannenberg Software, Mühlhausen) subject Kurzform is max. 4 characters, see section 9.

---

## 6. Sachsen-Anhalt

### 6.1 Official subject names

| Subject | Level | Source | Status |
|---|---|---|---|
| Fachlehrpläne Grundschule: Deutsch; Englisch; Ethikunterricht; **Gestalten** (art + craft combined); Mathematik; Musik; Evangelischer / Katholischer Religionsunterricht; **Sachunterricht**; Sport | Grundschule | https://www.bildung-lsa.de/informationsportal/unterricht/grundschule/schulformbezogene_informationen/lehrplan.htm | [OFF] |
| Fachlehrpläne Sekundarschule: Astronomie; Biologie; Chemie; Deutsch; Englisch; Ethikunterricht; Französisch; Geographie; Geschichte; **Hauswirtschaft**; Informatik (Erprobung from 01.08.2026); **Kunsterziehung**; Mathematik; Musik; Physik; ev./kath. Religion; Russisch; **Sozialkunde**; Sport; **Technik**; **Wirtschaft** (no plan named Gesellschaftslehre, Werken or Naturwissenschaften) | Sekundarschule (also Gemeinschaftsschule) | https://www.bildung-lsa.de/informationsportal/unterricht/sekundarschule/schulformbezogene_informationen/lehrplan.htm | [OFF] |
| Stundentafel Sekundarschule/Gemeinschaftsschule (RdErl. Unterrichtsorganisation 2024/25): Kernfächer Deutsch, Mathematik, Englisch; naturwissenschaftliche Gruppe; gesellschaftswissenschaftliche Gruppe Geographie, Geschichte, Sozialkunde; Profilbereich Hauswirtschaft, Informatik, Technik, Wirtschaft(-Technik); künstlerisch-musische Gruppe; Ethik bzw. Religion; Sport; 2. Fremdsprache or Wahlpflichtkurs from Jg. 7 | Sekundarschule | https://mb.sachsen-anhalt.de/fileadmin/Bibliothek/Landesjournal/Bildung_und_Wissenschaft/Erlasse/Unterrichtsorganisation_Sekundarschulen_und_Gemeinschaftsschulen.pdf (now 404; search summary only). Gemeinschaftsschulverordnung https://www.gms-muldenstein.bildung-lsa.de/dat/cms1002283/images/Januar2022/gemeinschaftsschulverordnung.pdf (text read from local copy) mentions Pflichtfächer, Wahlpflichtfächer, Wahlpflichtkurse, 2. Fremdsprache from Jg. 7 | [OFF] (second-hand) |
| Zeugnis-Erlass (RdErl. MK 05.11.2015, last changed 23.02.2024) | all | https://mb.sachsen-anhalt.de/fileadmin/Bibliothek/Landesjournal/Bildung_und_Wissenschaft/Erlasse/Zeugnisse_und_Bescheinigungen_der_allgemeinbildenden_Schule.pdf (now 404) | no abbreviation list known |

### 6.2 Abbreviations seen
None found (no official list, no readable sheet). Gap.

---

## 7. Schleswig-Holstein

### 7.1 Official subject names (Fachanforderungen, IQSH portal)

Source: http://www.schleswig-holstein.de/DE/landesregierung/ministerien-behoerden/IQSH/Arbeitsfelder/Schulentwicklung/Lehrplaene/lehrplaene.html - all [OFF].

| Level | Subjects (exact plan names) |
|---|---|
| Primarstufe (Grundschule) | Deutsch; Englisch; Mathematik; Musik; Kunst; Philosophie; **Sachunterricht**; Religion evangelisch; Religion katholisch; Sport; Technik; Textillehre; Allgemeiner Teil; Medienkompetenz |
| Sekundarstufe I only | Naturwissenschaften; **Weltkunde**; Technik; Textillehre; Verbraucherbildung |
| Sekundarstufe I/II | Deutsch; Englisch; Mathematik; Französisch; Geographie; Kunst; Latein; Musik; Spanisch; Sport; Biologie; Chemie; Dänisch; Geschichte; Griechisch; Philosophie; Physik; Religion evangelisch; Religion katholisch; Russisch; **Wirtschaft/Politik**; Italienisch; Chinesisch; **Darstellendes Spiel**; Informatik; Medienkompetenz |

Further facts:
- Kontingentstundentafel applies to Grundschule, Gemeinschaftsschule, Gymnasium (Sek I); schools decide whether Naturwissenschaften (Ph, Ch, Bio) and gesellschaftswissenschaftliche Fächer are combined (e.g. NW combined to Kl. 7 at Albert-Schweitzer-Schule Selent, Erdkunde and Geschichte separate): https://schule-selent.lernnetz.de/files/Schule%20Selent/Juergensen/Anmeldung%20Klasse%205/2021%20Schule%20Selent%20Pr%C3%A4sentation_Kommentar.pdf (text read from local copy) - [SHEET]-level.
- Gemeinschaftsschulen must teach 4 h WiPo in the Mittelstufe (https://www.news4teachers.de/2019/10/spd-fordert-wirtschaft-politik-schon-ab-der-5-klasse-prien-dagegen/, search summary) - [WEB].
- Zeugnisverordnung SH 2018 https://fachportal.lernnetz.de/files/rechtliche%20Grundlagen/ZeugnV_SH_2018.pdf has no subject/abbreviation list (text read from local copy).

### 7.2 Abbreviations seen

| Subject | Abbreviations seen | Level | Source | Status |
|---|---|---|---|---|
| Deutsch | D | Grundschule | Untis export, Grundschule Ellerau, class 4a, "Stundenplan ab 1.2.2023": http://grundschule-ellerau.de/wp-content/uploads/2023/02/2022_23_HJ2_ab0223-verschoben-9.pdf (legend with columns "Fächer" and "Räume" printed on the sheet; text read from local copy) | [SHEET] |
| Englisch | Eng | Grundschule | same | [SHEET] |
| Klassenstunde | KL | Grundschule | same | [SHEET] |
| Kunst | Ku | Grundschule | same | [SHEET] |
| Mathematik | M | Grundschule | same | [SHEET] |
| Musik | Mu | Grundschule | same | [SHEET] |
| Religion | Re | Grundschule | same | [SHEET] |
| Sport | Sp | Grundschule | same | [SHEET] |
| Sachunterricht | SU (cells also show "Su") | Grundschule | same | [SHEET] |
| Room Sporthalle | SP-H | Grundschule | same | [SHEET] |
| Naturwissenschaften parts | Ph, Ch, Bio | Gemeinschaftsschule | Selent parent info | [SHEET] |
| Wirtschaft/Politik | WiPo | Sek I | news4teachers (press usage, not a timetable) | [WEB] |

---

## 8. Thüringen

### 8.1 Official subject names (Schulportal Thüringen)

Source: https://www.schulportal-thueringen.de/lehrplaene (link list read). All [OFF].

| Level | Subjects (exact names) |
|---|---|
| Grundschule | Deutsch; Mathematik; Englisch; **Heimat- und Sachkunde**; Schulgarten; Werken; Musik; **Kunsterziehung**; Sport; Ethik; Verkehrserziehung; (Religionslehre ev./kath./jüd. under the GeWi page) |
| Gesellschaftswissenschaften / Religion (Sek) | Ethik; Evangelische Religionslehre; Katholische Religionslehre; Jüdische Religionslehre; Geographie; Geschichte; Sozialkunde; Wahlpflichtfächer; Wirtschaft und Recht (Gymnasium); **Wirtschaft-Recht-Technik**; **Wirtschaft-Umwelt-Europa** |
| Sprachen | Deutsch; Deutsch als Zweitsprache; Englisch; Französisch; Alte Sprachen; Italienisch; Russisch; Spanisch; Schriftspracherwerb; Sprachbildung (Kl. 6) |
| MINT | Mathematik; **Mensch-Natur-Technik** (URL key `mnt`); Biologie; Chemie; **Physik/Astronomie**; Informatik; Wahlpflichtfach **NWuT - NuT**; Wirtschaft-Recht-Technik |
| Schulformen with plans | Grundschule, Regelschule, Gymnasium, Thüringer Gemeinschaftsschule |
| Rahmenstundentafel (ThürSchulO Anlagen 1, 2, 4; older text, table garbled so hours unreliable): Grundschule: Deutsch, Mathematik, Heimat- und Sachkunde, Werken, Schulgarten, Musik, Kunst, Fremdsprache, Religionslehre/Ethik, Sport, Ergänzungsstunden. Regelschule: Deutsch, 1./2. Fremdsprache, Mathematik, Biologie, Chemie, Physik, Astronomie, Geografie, Geschichte, Sozialkunde, Religionslehre/Ethik, Musik, Kunst, Sport, Wirtschaft-Recht-Technik. Gymnasium: + Wirtschaft und Recht, Seminarfach | | https://www.lexaris.de/book/version/documentflat/head/1320526 | [OFF] (names only) |

### 8.2 Abbreviations seen
Only portal keys: MNT (Mensch-Natur-Technik, in portal URL), NWuT / NuT (Wahlpflichtfach). "HSK" appears in titles of Thüringen workbooks for Heimat- und Sachkunde (search summary, [WEB]). No Kürzel table and no readable Thüringer timetable found. Gap. WUE, WRT, KE are only candidate aliases built from the official names [GEN].

---

## 9. Software defaults (Untis/WebUntis, Indiware/Stundenplan24, DaVinci, Schulmanager, Sdui, IServ)

Result: **none of the six documents a default list of Fächerkürzel.** What is documented:

| Product | What the documentation says | Source | Status |
|---|---|---|---|
| Untis / WebUntis | Subjects have a short name ("Name") and a long name ("Langname"); free text. Short names must match between Untis, WebUntis and external systems. Since Untis 2018 a selection list of existing subjects is offered in the lesson table. Third-party export = GPU001.TXT (lessons) and GPU002.TXT (student groups). For Ganztag the NI vendor handout recommends own subjects ("Betreuung", "Ganztag" or per offer) and teacher codes with suffix -GT / -PM. No default subject table. | https://webhelp.untis.at/HTML/WebHelp/uk/untis/8u_stammdaten_klassen_auswahlfeld.htm (search summary) ; https://help.untis.at/hc/de/article_attachments/360004481760 (Austrian leaflet, text read) ; NI handout in 1.1 | vendor docs |
| Indiware Stundenplaner / Stundenplan24 (Kannenberg Software, Mühlhausen) | "Beim ersten Öffnen der Fach- oder der Stundentafeldatei werden diese je nach Bundesland und Klassentyp mit Standardfächern und -tafeln vorbesetzt." Subject master data has *Kurzform* (max. 4 characters) and *Langform*; the file can be reset with "Datei leeren/vorbesetzen". The list of Standardfächer itself is not printed in the manual. Stundenplan24.de publishes plans exported from Indiware. | Handbuch Unterrichtsplaner Version 4, section 2.2.2 https://indiware.de/service/daten/Handbuch%20zum%20Unterrichtsplaner%20Version%204.pdf (text read from local copy); https://www.indiware.de/service/daten/Handreichung%20Indiware%20online%20und%20mobil.pdf | vendor docs |
| DaVinci | No documentation of subject codes found. Listed as supported import source by Schulmanager and Sdui. | https://www.schulmanager-online.de/ ; https://support.sdui.de/de_DE/96064-horario/wie-kann-ich-das-stunden-und-vertretungsplan-programm-mit-sdui-verkn%C3%BCpfen | gap |
| Schulmanager Online | Imports Fächer, Klassen, Lehrkräfte from Indiware, Willi, SPO-Office, DaVinci, Untis, Tabulex, svPlan, Turbo-Planer, aSc, or Excel. No default code list documented. | https://www.schulmanager-online.de/module.stundenplanung.html | vendor docs |
| Sdui | Takes plans from Untis, DAVINCI, aSc, TurboPlaner via desktop plug-in or manual upload; subjects appear as in the source plan; no default list. | https://support.sdui.de/de_DE/96064-stundenplan | vendor docs |
| IServ | After Untis import (GPU001.TXT, UTF-8, comma, double quote) "every subject initially has only an abbreviation"; full name and colour are added per subject in the Fächer tab; a pop-up proposes "gängige Fächer" (list not documented). Teacher codes in user field `Klasse/Information` must be unique and identical to Untis. | https://hilfe.iserv.de/den-stundenplan-als-datei-ins-iserv-klassenbuch-importieren ; https://hilfe.iserv.de/basisdaten-fuer-die-digitale-stundenplanung-im-iserv-stundenplan-hinterlegen ; https://doku.iserv.de/modules/dsa-timetable/ | vendor docs |

Practical conclusion: in every product the printed code equals whatever the school typed as short name. Observed exports: `Deu`, `Mat`, `Eng` (NI Gymnasium Untis), `D`, `M`, `SU` (SH Grundschule Untis); Indiware limits to 4 characters.

---

## 10. Cross-state conflicts a parser must resolve with context

| Code | Meanings seen |
|---|---|
| BK | Bildende Kunst (SL); Blindenkurzschrift (SN); Betreuungskraft (NI staff role, not a subject) |
| GK | Gemeinschaftskunde/Rechtserziehung (SN); Gesamtkonferenz (NI staff abbreviations) |
| Ges / GES | Geschichte (NI Gymnasium Neu Wulmstorf, CSN Oberstufe); Gesellschaftslehre (CSN Buchholz, Sek I) |
| F | Französisch (NW Gesamtschule WP); Förder-prefix (NI Gymnasium FMa, FEn, FDeR) |
| NW | Naturwissenschaften (SL, NW Gesamtschule) |
| AL | Arbeitslehre (SN, SL, NW) |
| GW | Gesellschaftswissenschaften (SL) |
| Re / Rel / RE/e / R/E | Religion (SH Re, NI Rel, SN RE/e RE/k, SL R/E = Religion/Ethik) |
| KL / Verfü / Verf / KLU / Klassenrat | class council / class teacher time (SH KL, NI Verfü/Verf/KLU, SL Klassenleitungsstunde + Klassenrat) |
| Sp | Sport in SH, NI, SL sheets (other lists use Sp for Spanisch; not among these eight states) |

---

## 11. Groups

Tags: states NI, NW, RP, SL, SN, ST, SH, TH. Status: O official, S sheet, W web, G general-knowledge/unverified.

### 11.1 German / first language
- Names: Deutsch; Deutsch als Zweitsprache (DaZ); Herkunftssprachlicher Unterricht (NI); Herkunftssprache / spezifisch muttersprachlicher Unterricht (SN); Muttersprachlicher Unterricht (NW, up to 5 h); Sprachbildung and Schriftspracherwerb (TH); Deutsch-Sachunterricht block (SN, RP Kl. 1-2); Lesezeit (RP).
- Abbreviations: D (SH S, NI W), De (NI W, SL O), Deu (NI S), DE (SN O), DaZ (SN O), DE-SU / DE-HKS (SN O), HU / SMU (SN O). Förder-Deutsch: FDeR (NI S).

### 11.2 Mathematics
- Names: Mathematik.
- Abbreviations: M (SH S, NI W), Ma (NI W, NI CSN S, SL O), Mat (NI S), MA (SN O). Förder-Mathe: FMa (NI S).

### 11.3 Foreign languages
- Names: Englisch; Französisch; Latein; Spanisch; Russisch; Italienisch; Niederländisch (NI); Chinesisch; Griechisch / Alte Sprachen (TH); Dänisch (SH); Polnisch, Tschechisch, Sorbisch, Hebräisch (SN); 1./2./3. Fremdsprache; Sprachkurs (SL); Intensives Sprachenlernen (SN); Integrierte Fremdsprachenarbeit (RP); Zertifikatskurse (SN). Grundschule foreign language: Englisch (NI, NW, SN, TH, SH), Englisch bzw. Französisch (RP), Französisch (SL, old table).
- Abbreviations: E (NI W); Eng (SH S, NI S); En (SL O); EN (SN O); Fr (SL O); Fra (NI S); FR (SN O); F (NW WP S); Lat (NI S); LA (SN O); Spa (NI CSN S); SPA (SN O); RU, ITA, POL, TSC, SOR, CHI, HE, GR (SN O); FS, 1. FS, 2. FS, 3. FS (SN O, SL O); ISL (SN O); ZENA/ZENF/ZFRA/ZFRF/ZRUA/ZRUF/ZSPAA/ZSPAF (SN O); FEn = Förder-Englisch (NI S). Aliases from an unknown-state school list: Eng, Frz, Tür (Türkisch), Arab.

### 11.4 Natural sciences
- Names: Physik; Chemie; Biologie; Naturwissenschaften (combined: NI Oberschule/IGS, NW, SL, SH, RP); Natur, Technik und Informatik (SN); Mensch-Natur-Technik (TH); Physik/Astronomie, Astronomie (TH, ST, SN old); Naturwissenschaft und Technik NWuT/NuT (TH Wahlpflicht); Technik und Naturwissenschaft (RP Wahlpflicht).
- Abbreviations: Bio, Che, Phy (NI S); Ph, Ch, Bio (SH S); BIO, CH, PH (SN O); Bi, CH, Ph (SL O); NW (SL O, NW S); NAT (NI CSN S); NTI (SN O); MNT (TH O key); NWuT/NuT (TH O); AST (SN O 2004); NaWi (unknown-state school list).

### 11.5 Sachunterricht / Sachkunde (primary general studies)
- Names: Sachunterricht (NI, NW, RP, SL, SN, ST, SH); Heimat- und Sachkunde (TH); Heimatkunde (SN historical, DE-HKS); Sachkunde (shows up as alias in an unknown-state sheet "Sa/SU"); Deutsch-Sachunterricht (SN, RP).
- Abbreviations: SU (SH S, NI W, SN O), Su (SH S), Sa (unknown-state), HSK (TH, titles W), HK (SN O 2004), DE-SU, DE-HKS (SN O).

### 11.6 Social sciences (history, geography, politics/society, economics)
- Names: Geschichte; Erdkunde (NI, NW, RP, SL) / Geographie (SN, ST, SH, TH); Politik (NI Oberschule/Realschule); Politik-Wirtschaft (NI Gymnasium, Oberschule gymnasiales Angebot); Wirtschaft-Politik (NW); Wirtschaft/Politik (SH); Sozialkunde (RP, ST, TH, SL); Gemeinschaftskunde/Rechtserziehung (SN); Gemeinschaftskunde/Rechtserziehung/Wirtschaft (SN Gymnasium); Gesellschaft und Wirtschaft (SN Gemeinschaftsschule); Gesellschaftslehre (NW, NI IGS, RP); Gesellschaftswissenschaften (SL); Weltkunde (SH; NI Fachbereich "geschichtlich-soziale Weltkunde"); Wirtschaft (NI, ST); Wirtschaft und Recht (TH Gymnasium); Wirtschaft-Recht-Technik (TH); Wirtschaft-Umwelt-Europa (TH); Wirtschaft und Arbeitswelt (NW Hauptschule/WP); Arbeitswelt Wirtschaft (NW WP); Politik und Wirtschaft (NI CSN).
- Abbreviations: Ges (NI Gymnasium S), GES (NI CSN S, Gesellschaftslehre), GE (SN O), Erd (NI Gymnasium S), GEO (SN O), Pol (NI Gymnasium S), PoWi (NI CSN S), WiPo (SH W), GK (SN O), G/R/W (SN O), GuW (SN O), GW (SL O), AW (NW WP S), GeWi, Ge, Erd, PB (unknown-state list). Unverified candidates [GEN]: GL, Gk, Sk, EK, PK, WUE, WRT.

### 11.7 Arts (visual)
- Names: Kunst (NI, NW, SN, SH); Bildende Kunst (RP, SL); Kunsterziehung (TH, ST Sek); Gestalten (ST Grundschule); Kunst/Modellieren (SN); Darstellendes Spiel / Theater (NI Gymnasium/IGS, SH, RP Wahlpflicht, SN old DS); Darstellen und Gestalten (NW WP).
- Abbreviations: Ku (SH S, NI W), Kun (NI Gymnasium S), KU (SN O), BK (SL O), Ku/M (SN O), DG (NW WP S), DS (SN O 2004).

### 11.8 Music
- Names: Musik; Rhythmisch-musikalische Erziehung (SN); Chor / Orchester (RP Wahlfreier Bereich; SN old CHO/ORC).
- Abbreviations: Mu (SH S, NI W, SL O, NI CSN S), Mus (NI Gymnasium S), MU (SN O), KU/MU (SN O, combined), Rhy (SN O).

### 11.9 Sport
- Names: Sport; Schwimmen (unknown-state sheet "Sw"); Profilsport (SN).
- Abbreviations: Sp (SH S, NI W, SL O), Spo (NI CSN S), SPO (SN O), PS (SN O, Profilsport), SPO/m/w (SN 2004).

### 11.10 Religion / ethics / philosophy
- Names: Religion (evangelisch / katholisch / islamisch / jüdisch); Religionslehre (NW, TH); Religion/Ethik combined row (RP, SN Wahl); Ethik (SN, TH, RP, ST "Ethikunterricht", SL "Allgemeine Ethik"); Werte und Normen (NI); Praktische Philosophie (NW, Ersatzfach footnote); Philosophie (SH, NI Oberstufe; SN 2004 PHI).
- Abbreviations: Re (SH S), Rel / Reli (NI W, NI Gymnasium S), RE/e RE/k RE/j (SN O), ETH (SN O), R/E (SL O), Et (SL Oberstufe, unverified), WuN (NI Gymnasium S), BU (Biblischer Unterricht, private school S), Isl.Rel. (unknown-state list). [GEN]: ev, kath, PP, Eth.

### 11.11 Crafts, technology, home economics
- Names: Werken (SN, TH GS); Gestaltendes Werken, Textiles Gestalten (NI); Textillehre (SH); Technik (NI, ST, SH, NW); Technik/Computer (SN); Hauswirtschaft (NI, NW Gesamtschule, SN, ST); Arbeitslehre (SN, SL, NW historic/WP); Arbeit-Wirtschaft-Technik (NI IGS); Wirtschaft-Technik-Haushalt/Soziales (SN); Technik und Naturwissenschaft / Hauswirtschaft und Sozialwesen / Wirtschaft und Verwaltung (RP Wahlpflicht); Arbeit und Beruf (SN); Verbraucherbildung (SH); Schulgarten (TH GS); Wirtschaft-Recht-Technik (TH); Töpfern (private school).
- Abbreviations: WE (NI W, SN O), TG (NI W), AWT (NI CSN S), Hw (NI CSN S), Te (NI CSN S, Textil), We (NI CSN S), Tö (CSN S), AL (SN O, SL O, NW Teamschule S), WTH (SN O), HW (SN O), TC (SN O), AuB (SN O).

### 11.12 Computer science / media
- Names: Informatik; Medienkunde / Medienkompetenz (NI, SH); Technik/Computer (SN); Natur, Technik und Informatik (SN).
- Abbreviations: Inf (NI Gymnasium S), INF (SN O), Info (NW WP S), Mk (NI CSN S), TC (SN O), NTI (SN O), PC (unknown-state list).

### 11.13 Study time, support, remedial
- Names: Lernzeit "Sichere Basis" (NI GS); Förderunterricht (NI, NW historic, RP, SL GS, SN); Angebote zur individuellen Förderung / Individuelle Förderung (SN); Selbstorganisiertes Lernen / individuelle Lernzeit (SN Kl. 8-10; NI CSN); Schuleigene Förderkonzepte (SL); Lernen lernen (SL); Planarbeit (NI CSN); Hausaufgaben-Training (NI CSN); Differenzierung (NI); Ergänzungsstunden (NW, TH); Wahlpflichtkurs / Wahlpflichtunterricht / Wahlpflichtbereich (NI, NW, RP, SL, SN, ST); Wahlbereich / Wahlfreier Bereich / Wahlunterricht (RP, SN, NI); Profilunterricht / Profilstunden (SN, RP); Komplexe Lernleistung (SN); Seminarfach (TH); Sprachkurs (SL); Beratung (SN).
- Abbreviations: Fö (unknown-state list), FÖ (SN O), indFö (SN O), AiFKL (SN O), FDeR / FEn / FMa (NI S), SOL (NI S), PLAN (NI S), HA-Tr (NI S), WP / WPI / WPII (NW S), WPK / WPU (SN O), P (SN O), Dif-X (NI school legend, unverified), LeP (SN O), Brg (SN O), FiBS (unknown-state list).

### 11.14 Care / Hort / after-school
- Names: Ganztag / Ganztagsangebot (NI, RP; NW "Offener Ganztag"); Betreuung (NI Untis handout); Betreuende Grundschule / Verlässliche Grundschule (RP / NI); Hort (TH, ST, SN typical; no source for codes in this research).
- Abbreviations: none official. NI Untis handout suggests staff-code suffix -GT, -PM; "PM" = Pädagogische Mitarbeitende, "BK" = Betreuungskraft (NI W). Candidate aliases [GEN]: OGS, GT, Hort, Betr.

### 11.15 Class council / tutor time
- Names: Klassenrat (SL; unknown-state KR); Klassenleitungsstunde (SL); Klassenstunde (SH KL, RP); Verfügungsstunde (NI Oberschule/Gymnasium); Klassenlehrkraftunterricht (NI); Verfügungszeit (RP GS).
- Abbreviations: KL (SH S), KLU (NI W), Verfü (NI Gymnasium S), Verf (NI CSN S), KlS (NI school legend, unverified), KR (unknown-state), Klassenrat (SL O).

### 11.16 Other
- Names: Verkehrserziehung (TH GS); Schulgarten (TH GS); Seminarfach (TH); Jahresprojekt (NI CSN, JP); Gesundheits- und Sanitätskurs (GeSa); Psychologie (Ps); Astronomie; Schwimmen (Sw); Neues Testament erleben (NT); Biblischer Unterricht (BU); Arbeitsgemeinschaft AG (RP/NI/NW Wahlfreier Bereich); Dehnungsjahr (SN); Anfangsunterricht / Erstunterricht (NI GS list, SN); Vorfachlicher Unterricht (unknown-state, VU).
- Abbreviations: AG (RP VV, NI Oberschule Erlass, unknown-state list), AU / EU (NI W, SN O), DJ (SN O), JP, GeSa, Ps, Sw, NT, BU, VU.

---

## 12. Gaps and suggestions

1. Readable timetable sheets for RP, ST, TH and NW (Grundschule and Sek I) are missing; the WebSearch quota ran out. Suggested follow-up: 2 to 3 school PDF timetables with legend per state.
2. The SchILD-NRW / SVWS Fach-Kürzel catalogue (NW) could not be retrieved (GitHub paths returned 404). Worth fetching `ZulaessigesFach` from the SVWS-Server repo for exact NW statistic codes.
3. The Sachsen-Anhalt Stundentafel text is second-hand (original URLs 404 now).
4. Thüringen Rahmenstundentafel hours are unreliable in the extracted tables; only subject names are used.
5. grundschulratgeber.de is a parent-advice site, not an authority. The CSN list is from a private Christian school.
6. An unidentified-state Grundschule list "Abkürzungen für die Unterrichtsfächer für den Stundenplan" (https://regenbogen-grundschule.de/wp-content/uploads/2017/11/Abk%C3%BCrzungen-f%C3%BCr-die-Unterrichtsf%C3%A4cher.pdf) has: D, Ma, VU (Vorfachlicher Unterricht), Sa/SU (Sachkunde), Eng, Frz, Sp, Sw (Schwimmen), Mu, BK (Bildende Kunst), Ge, Erd, NaWi, GeWi (Ge, Erd, PB), FiBS, KR (Klassenrat), SL (Soziales Lernen), PC, Tür, Arab, Isl.Rel., AG, Fö (Förderunterricht), DaZ. State not determinable, so it is only mentioned as alias evidence, not as a state fact.

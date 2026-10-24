# German timetable codes: Rheinland-Pfalz, Sachsen-Anhalt, Thüringen, NRW Grundschule

Researched 2026-10-23. Compared against the `de` list in `supabase/functions/_shared/school_subjects.ts`.

Method note: about 47 WebFetch calls (about a dozen failed or came back empty) and many WebSearch calls. PDFs that
WebFetch could not read were saved locally and their text layer extracted with pdf.js; those entries say "text layer
read". The general search index barely knows small-school timetables; the productive trick was `allowed_domains`
(bildung-lsa.de, schulen.gelsenkirchen.de, schulnetz.hamm.de).

Result by region: Sachsen-Anhalt good (one real primary sheet, one real Sek-I Untis plan). NRW Grundschule good (one
real legend, two Stundentafeln). Rheinland-Pfalz and Thüringen: no readable sheet with subject codes found (names and a
few terms only).

## 1. Sources

"cell" = codes printed in the grid; "legend" = the document explains its codes. All URLs fetched by me unless marked.

| Id | URL | School | Region | Level | What it is | Fetched? |
|---|---|---|---|---|---|---|
| S1 | https://www.gs-rottleberode.bildung-lsa.de/grundschule-thyratal-/stundenplan/ | Grundschule "Thyratal" (Rottleberode) | ST | GS (columns LGAa, LGBb = learning groups Kl. 1-2, Klasse 3, Klasse 4) | sheet WITHOUT legend, "Stundenplan 2026/27 ab 05.10.2026", page text | fetched |
| S2 | https://www.gs-merseburg-west.bildung-lsa.de/startseite/unterrichtszeiten/ | Grundschule Merseburg-West (name inferred from the host name) | ST | GS | Stundentafel table with two codes (SSU, SW), no legend | fetched |
| S3 | https://www.sks-tierpark.bildung-lsa.de/dat/cms1002015/images/vertretungsplan.pdf | Sekundarschule "Am Tierpark", Staßfurt | ST | Sek I, Kl. 5-10 | Untis substitution plan (16.10.2026), codes in the Fach column, no legend; text layer read | fetched |
| S4 | https://www.gebr-grimm.schulnetz.hamm.de/wp-content/uploads/2018/12/Abk%C3%BCrzungsverzeichnis.pdf | Gebrüder-Grimm-Schule, Hamm | NRW | GS | LEGEND page ("Kürzel und Abkürzungen") of the school's class folders (Dec 2018); text layer read | fetched |
| S5 | https://gs-laendchenweg.de/unterricht/stundenverteilung | Grundschule Ländchenweg (Schwelm per "Schwelmer Hallenbad"; page names no town or state) | NRW (inferred) | GS | Stundenverteilung table, full words, no codes | fetched |
| S6 | https://glg.monheim.de/fileadmin/user_upload/Media/HGS/Dokumente/Infoabend_Eltern_Schulanfänger_Oktober_2023.pdf | Hermann-Gmeiner-Schule (HGS), Monheim am Rhein | NRW | GS | parents' evening slides (cites AO-GS): subject list and day structure, no codes; text layer read | fetched |
| S7 | https://gs-schweich.de/unser-konzept/unterricht/ | Frida-Kahlo-Grundschule Schweich | RLP | GS | Stundenverteilung by Lernbereich, one code (IFA) | fetched |
| S8 | https://wittlich.de/de/leben-in-wittlich/bildung/grundschulen/grundschule-georg-meistermann/unsere-schule/jahrgangsgemischtes-lernen-in-der-familienklasse/tagesablauf.pdf?cid=yz7 | Georg-Meistermann-Grundschule, Wittlich | RLP | GS (Familienklasse, mixed ages) | day-structure text with in-line terms (ILZ, DAZ); text layer read | fetched |
| S9 | https://jenaplan-weimar.de/getmedia.php/_media/201605/448v0-orig.pdf | Jenaplan-Schule (Gemeinschaftsschule), Weimar | TH | Sek I Kl. 7-9 | school Stundentafel after ThürSchulO Anlage 10a (2016): full names plus a few short forms; text layer read | fetched |
| S10 | https://www.schule-am-kiliansberg.de/regelschule/th%C3%BCringer-lehrpl%C3%A4ne/ | Schule "Am Kiliansberg", Meiningen | TH | Regelschule | list of curriculum downloads; short codes only in file names (not a timetable) | fetched |
| S11 | https://regelschule-seelingstaedt.de/vertretungsplan | Staatliche Regelschule "Im Ländereck", Seelingstädt | TH | Regelschule | substitution page, only "Bio" and "Ch" visible as text | fetched |
| S12 | https://christophorusschulen-sachsen-anhalt.cjd.de/de/unterricht-und-stundentafel-am-gymnasium | Gymnasium Droyßig (CJD) | ST | Gymnasium Kl. 5-10 | Stundentafel with full names, no codes | fetched |
| S13 | https://gskesselheim.koblenz.de/services/eltern-abc/ | Grundschule Kesselheim, Koblenz | RLP | GS | parents' ABC, subject names in prose, no codes | fetched |
| S14 | https://www.gs-engels-piesteritz.bildung-lsa.de/schulalltag/ablauf-des-schultages/ | GS Friedrich Engels, Wittenberg-Piesteritz | ST | GS | prose: "Deutsch, Mathematik, Sachunterricht, Englisch und Ethik oder Religion", no codes | fetched |
| S15 | https://gs-guentersleben.de/unterricht/stundentafel-1-4-klasse/ | Grundschule Güntersleben | BAVARIA, not in scope (a search summary had called it Thüringen; the site links km.bayern.de and Güntersleben is near Würzburg) | GS | legend-like Stundentafel; used only as a side note in section 3 | fetched |
| X1 | https://www.rsh.schulnetz.hamm.de/Broschuere.pdf | Realschule Heessen, Hamm | NRW | Sek I Kl. 5 | said (search snippet) to show a Klasse 5 Stundenplan with SP, KU, MU, Rel; the fetch was a 404 | snippet only |
| X2 | search summary of the S3 site | Sekundarschule Am Tierpark | ST | Sek I | summary mentions "Ko Ge" and "Neb Eth" lines in some version of the plan; I did not see them in the file I read, so "Ge" there is unverified (probably Geschichte, "Ko" looks like a teacher) | snippet only |
| X3 | Untis HTML substitution pages of RLP Realschulen plus (spmai.de, augustiner-rsp.de, anne-frank-realschule-plus.de) | | RLP | Sek I | exist per search; my fetches failed on certificate errors / 404 | snippet only, content unknown |
| X4 | https://195546.schulen.gelsenkirchen.de/..., https://sternschule.essen.de/media/Downloads/Elternheft_2023-2024.pdf, https://mb.sachsen-anhalt.de/.../Unterrichtsorganisation_Sekundarschulen_und_Gemeinschaftsschulen.pdf | | NRW, ST | | leads that returned 404 | not available |
| X5 | https://119398.schulen.gelsenkirchen.de/de/wir_ueber_uns/die_klassen/_doc/IF%C3%B6_2.Halbjahr.pdf | a Gelsenkirchen GS | NRW | GS | "Stundenplan für die IFö A": only "Sport" and "X" in the cells (IFö not explained) | fetched, nothing usable |

Rejected: https://c-brentano-grundschule.de/... (only "M" and "D" with colour groups, 2020, state unknown); Austrian, Swiss, Saxon and Lower Saxon hits (Altenlingen, Neu Wulmstorf) are other regions.

## 2. Codes per region

Evidence marks: C = printed in a grid cell; L = printed in a legend; N = full name printed (no code); F = code only in a file name.

### 2.1 Sachsen-Anhalt

| Code | Subject as printed or read | Source | Where | Note |
|---|---|---|---|---|
| D | Deutsch | S1 | C | meaning from the Stundentafel (S2) |
| Ma | Mathematik | S1, S3 | C | |
| Eng | Englisch | S1, S3 | C | not "E" |
| Mu | Musik | S1 | C | |
| Sp | Sport | S1, S3 | C | |
| Sw/Sp | Schwimmen/Sport (a swimming slot shared with Sport) | S1 | C | S2 lists "1 + 1 SW" in Kl. 2 |
| Rel | Religion | S1 | C | |
| Eth | Ethik | S1, S3 | C | |
| Rel/Eth, Eth/An, Rel/An | parallel slot Religion or Ethik (in "Eth/An" and "Rel/An" the partner is "An") | S1 | C | |
| SaU | Sachunterricht (S2 lists only "Sachunterricht", 3 h each year) | S1 | C | capital U, no legend: inferred |
| Ge | Gestalten (inferred): S2 lists Gestalten 2 h per year and no Kunst or Geschichte; the Kl. 3 and 4 columns show about two "Ge" a week | S1 | C | NOT Geschichte on this sheet. Conflicts with `ge` = Geschichte in the vocabulary |
| SsU / SSU | not explained anywhere: S1 has it about 5 times a week across the Kl. 1-2 groups and the Kl. 3 column; S2 lists "SSU" 1 h every year | S1, S2 | C, N | unresolved |
| An | not explained: about 8 times a week for the learning groups LGAa and LGBb (Kl. 1-2), never for Kl. 3-4 except in "Eth/An" | S1 | C | unresolved |
| Geo | Geographie | S3 | C | |
| Bio | Biologie | S3 | C | |
| Ph | Physik | S3 | C | |
| Ku | Kunst (Kunsterziehung in ST Sek) | S3 | C | |
| Inf | Informatik | S3 | C | |
| Sk | Sozialkunde | S3 | C | |
| (not subjects) | "TH" in the Text column and "E.10", "2.05" are ROOMS (Turnhalle, building E), "Veranst." = event, "Ausfall" = cancelled | S3 | C | |
| (full names) | Kunsterziehung, Lernen Lernen (1 h Kl. 5, a private school's own subject), Sozialkunde from Kl. 8, Astronomie Kl. 9, Religion, Sport, Französisch, Latein, Spanisch | S12 | N | |

### 2.2 Nordrhein-Westfalen, Grundschule

| Code | Subject as printed | Source | Where | Note |
|---|---|---|---|---|
| D | Deutsch | S4 | L | |
| M | Mathematik | S4 | L | one letter, not "Ma" |
| SU | Sachunterricht | S4 | L | |
| E | Englisch | S4 | L | |
| MU | Musik | S4 | L | |
| SP | Sport/Schwimmen (one code for both) | S4 | L | |
| KU | Kunst | S4 | L | |
| RU | Religion | S4 | L | conflicts with `ru` = Russisch |
| HSU | Herkunftssprachlicher Unterricht | S4 | L | conflicts with `hsu` = Sachunterricht (the Bavarian Heimat- und Sachunterricht) |
| ES, RS, S., Nr. | Einsterns Schwester (Deutschbuch), Rechtschreibheft, Seite, Nummer | S4 | L | not subjects: book and page references in homework notes ("ES 2, S. 17 Nr. 3"). `es` and `s` are in the vocabulary as Ernährung und Soziales and Sport |
| (full names) | Deutsch, Mathematik, Sachunterricht, Kunst (3 h per week there), Musik, Sport (of which 2 h Schwimmen), Religion, Englisch (Kl. 3-4, 3 h), Sport-Förderunterricht (Kl. 1), Förderunterricht (Deutsch/Mathe) 2-3 h, Lernzeit 3 h | S5 | N | |
| (full names) | Deutsch, Mathematik, Englisch ab Kl. 3, Sport/Schwimmen, Sachunterricht, Kunst/Textil, Musik, ev. und kath. Religion; Lernphase 1-3 in an "Rhythmisierter Ganztag" | S6 | N | |
| SP, KU, MU, Rel | (snippet only) Klasse 5 sheet of Realschule Heessen, Hamm | X1 | C | unverified |

### 2.3 Rheinland-Pfalz

No sheet with subject codes was readable. What was read:

| Term | Meaning as printed | Source | Where |
|---|---|---|---|
| IFA | Integrierte Fremdsprache (row "Deutsch/ Sachunterricht/ Integrierte Fremdsprache (IFA)", 1 h of the block) | S7 | in-line |
| ILZ | individuelle Lernzeit (in Mathe und Deutsch) | S8 | in text |
| DAZ | Deutsch als Zweitsprache | S8 | in text |
| Schreibzeit | a lesson type (Sport, Kunst or Schreibzeit in the 5th hour) | S8 | N |
| "Musik/ Bildende Kunst/ Sport" | one row of the Stundenverteilung (6-7 h, "nach Möglichkeit 3 Stunden Sport") | S7 | N |
| "Religion/ Ethik" | one row (2 h Kl. 1-2, 2.5 h Kl. 3-4 in S7; the ministry says 2 h from 2024/25) | S7 | N |
| "zur Verfügung (Förderung, Spielpause, Projekte, Klassenrat, AGs o.ä.)" | the Verfügungszeit row, 1 h | S7 | N |
| Sachunterricht, Sport- und Schwimmunterricht (Kl. 3), Radfahrunterricht (Kl. 3-4) | | S13 | N |

### 2.4 Thüringen

No Thüringer primary sheet was found. Secondary names and codes:

| Code or term | Meaning | Source | Where |
|---|---|---|---|
| Mu/Ku | the Stundentafel row for the arts pair | S9 | N |
| (names) | Deutsch, Mathe, Englisch (1.FS), TW, Biologie, Chemie, Physik, Astronomie, Kunst, Musik, Geografie, Geschichte, Sozialkunde, Wirtschaft/Recht, Ethik and evangelische / katholische Religion (printed "Ethik/R E/RK" after extraction), Sport, Französisch, Latein, Darstellen und Gestalten, Informatik | S9 | N |
| TW | not explained (a MINT row, 2 h; probably Technik/Wirtschaft) | S9 | N |
| WRT | Wirtschaft-Recht-Technik (file LP_RS_WRT) | S10 | F |
| MNT | Mathematik-Naturwissenschaft-Technik (file Lehrplan_MNT) | S10 | F |
| KR, ER | Katholische, Evangelische Religion (files LP_RS_KR, LP_RS_ER) | S10 | F |
| NT, WUE, DG, MBI, HRA | appear in file names, never explained on the page | S10 | F |
| (names) | Technisches Werken, Sozialwesen, Kunst, Jüdische Religionslehre, Ethik, Informatik (Regelschule curricula) | S10 | N |
| Bio, Ch | substitution entries | S11 | C |

## 3. Additions proposed for the German vocabulary

Groups are those already used in `school_subjects.ts`. Everything below comes from the sources in section 1.

### 3.1 New entries or codes (not yet in the list)

| Code | Name | Group | Evidence | Confidence |
|---|---|---|---|---|
| sau | Sachunterricht (add to the existing entry's codes) | primary-studies | S1 (ST) | medium: printed "SaU" on a sheet without legend; the Stundentafel S2 has only Sachunterricht |
| gestalten, gest (new entry) | Gestalten | arts | S1, S2 (ST: art and craft in one subject, 2 h) | medium for the name; the short code `ge` is the problem, see 3.2 |
| kunsterziehung (alias of Kunst) | Kunsterziehung | arts | S12, S3 (ST), TH curricula | high for the word |
| ilz (add to Lernzeit) | Individuelle Lernzeit | support | S8 (RLP) | medium |
| ifa | Integrierte Fremdsprache(narbeit) | language-slot (the group the `fr` list uses for "Langue vivante") | S7 (RLP) | medium; an RLP official term, 1 h in Kl. 1-4 inside the Deutsch/Sachunterricht block |
| schreibzeit | Schreibzeit | first-language | S8 (RLP) | low (one school) |
| wrt | Wirtschaft-Recht-Technik | economics | S10 (TH file name, plus official subject name) | medium for the TH Regelschule |
| er (add to Evangelische Religion) | Evangelische Religion | religion | S10 (file LP_RS_ER; `kr` is already present) | low-medium |
| wue | Wirtschaft-Umwelt-Europa | economics | S10 (file name only) | low |
| hsu (as ambiguous) / new entry | Herkunftssprachlicher Unterricht | other-language | S4 (NRW) | high for the NRW Grundschule meaning |
| (words only, no codes seen) Schulgarten, Heimat- und Sachkunde, Verkehrserziehung, Werken | official Thüringen primary subjects (earlier research; the portal pages were not re-read in detail here) | crafts, primary-studies, other, crafts | prior research README / de-states-n-t.md | name only |

Cheap matcher rule suggested by S4: homework-book references (`ES 2, S. 17 Nr. 3`) are not subjects; `es`, `rs`, `s` and `nr` after a digit or "S." should not be read as subjects there.

### 3.2 Conflicts with existing entries

| Code | Existing | Found | Where | Suggestion |
|---|---|---|---|---|
| `ge` | Geschichte | Gestalten (ST Grundschule, S1) | ST | Add the Gestalten entry so that, when the family's own subject list contains Gestalten and no Geschichte, the group hint `arts` wins. Keep `ge` = Geschichte for Sek I. Do not move `ge` to AMBIGUOUS unless field tests show the hint route fails. |
| `hsu` | Sachunterricht (Bavarian Heimat- und Sachunterricht) | Herkunftssprachlicher Unterricht | NRW (S4) | The Bavarian meaning is confirmed by S15 ("HSU = Heimat- und Sachunterricht", Bavaria, out of scope). Both are real: put `hsu` in AMBIGUOUS, or add a second entry so the family's hints decide. |
| `ru` | Russisch (other-language) | Religion (RU = Religionsunterricht) | NRW GS (S4) | Add `ru` to AMBIGUOUS, or to Religion's codes for primary sheets. A primary school with Russisch is unlikely. |
| `m` / `ma` | Mathematik | NRW legend prints `M`; ST prints `Ma` | both present | no conflict |
| `sp` | Sport | NRW "SP = Sport/Schwimmen": one code covers both | | `sw` is optional on NRW sheets |
| `gu` | Gesamtunterricht (AT) | S15 (Bavaria): GU = Grundlegender Unterricht (Kl. 1-2: Deutsch, Mathematik, HSU, Kunst, Musik) | out of scope | note only |
| `fu`, `wg` | Förderunterricht, Werken | S15 (Bavaria): FU = Förderunterricht, WG = Werken und Gestalten; D-F = Deutsch Förderstunden | out of scope | confirms the existing entries; `d-f` could be added as Förderunterricht |
| `ssu`, `an` | not in the list | unexplained in S1/S2 | ST | Add both to AMBIGUOUS so the token is "known, no name" and the parent names it, instead of being read as a weekday or snapped to a wrong word. They are frequent on that school's sheet. |
| `tw` | not in the list | S9, unexplained | TH | no action |

## 4. Starter-list check

German starter list of specs/21: Deutsch D, Mathematik Ma, Sachunterricht SU, Englisch E, Musik Mu, Kunst Ku, Werken We, Religion/Ethik Rel, Förderunterricht Fö, Sport Sp, Schwimmen Sw.

| Region | Matches | Does not match | What a regional list would change |
|---|---|---|---|
| Sachsen-Anhalt (S1, S2) | Deutsch D, Mathematik Ma, Musik Mu, Sport Sp, Schwimmen Sw | Sachunterricht prints `SaU`, Englisch `Eng`; no Kunst and no Werken: one subject "Gestalten" (2 h) covers both; Religion and Ethik are separate subjects and cells (`Rel`, `Eth`, `Rel/Eth`); no Förderunterricht on the sheet (the unexplained `SsU`/`SSU` is in its place); Englisch starts in Kl. 2 or 3 | Deutsch D, Mathematik Ma, Sachunterricht SaU, Englisch Eng, Gestalten Ge, Musik Mu, Ethik Eth, Religion Rel, Sport Sp, Schwimmen Sw. Drop Kunst, Werken and Förderunterricht (or keep Fö as an option). Only one primary school was read, so `SaU` and `Ge` are one school's habit; the subject names are the state's. |
| NRW Grundschule (S4, S5, S6) | Deutsch D, Englisch E, Musik, Kunst Ku, Sachunterricht SU, Sport; Förderunterricht is real and large (S5: 2-3 h) | Mathematik prints `M` (not `Ma`); Sport and Schwimmen are ONE code `SP` and S5/S6 treat swimming as part of Sport; Religion prints `RU`; no Werken (it is "Kunst/Textil", S6) | Mathematik M, Religion RU or Rel, Schwimmen optional (harmless), replace Werken by Textiles Gestalten or drop it, add Lernzeit (3 h at S5) and Sport-Förderunterricht. HSU must not be the Sachunterricht shortcut here. |
| Rheinland-Pfalz | Religion/Ethik (the ministry and S7 use exactly this pair), Musik, Sport, Mathematik | No sheet read, codes unknown. Curriculum names differ: Kunst is "Bildende Kunst"; Sachunterricht is part of the block Deutsch/Sachunterricht/Integrierte Fremdsprache in Kl. 1-2; from Kl. 3 a Fremdsprache (Englisch or Französisch, 2 h) stands apart; "Verfügungszeit" (Kl. 3-4, 0.5 h) and "Lesezeit" exist; Werken is not a primary subject in the VV (Kunst only) | Keep the German list but drop Werken; add Fremdsprache (Englisch or Französisch) and Verfügungszeit; `Fö` becomes "Förderung" inside the Verfügungszeit. Codes cannot be confirmed. |
| Thüringen | Deutsch, Mathematik, Englisch, Musik, Sport, Werken (it IS a Thüringen primary subject), Ethik | No sheet read. Official names: Heimat- und Sachkunde (not Sachunterricht), Kunsterziehung, Schulgarten, Ethik as its own subject next to Religionslehre, Verkehrserziehung, Ergänzungsstunden | Sachunterricht -> Heimat- und Sachkunde (code `HSK` is a search-snippet claim, never seen on a sheet), Kunst -> Kunsterziehung, add Schulgarten, keep Werken, split Ethik and Religion, Fö -> Ergänzungsstunden/Förderunterricht. All from official names, not from sheets. |

## 5. Gaps

1. Thüringen: no primary sheet and no legend at all. Candidates that exist but were not readable: Vertretungsplan or Stundenplan published as an image (Ichtershausen `vertretungsplan.jpg`, Dobitschen `stundenplan.jpg`; would need OCR), and a Seelingstädt page that showed only "Bio" and "Ch". The Edith-Stein-Schule Erfurt has an Untis page (https://www.ess-erfurt.de/vertretungsplan/, search snippet only, not fetched). `HSK` for Heimat- und Sachkunde is unconfirmed.
2. Rheinland-Pfalz: no sheet with codes. Untis HTML substitution pages of Realschulen plus (Maikammer, Hillesheim, Montabaur, Prüm) exist; two fetches failed on certificate errors (goneo-hosted pages) and the Augustiner page returned 404. A retry through the real school domain or a browser would likely close it. Primary: only terms (IFA, ILZ), no cell codes.
3. NRW Grundschule: one legend (S4) plus Stundentafeln, but no printed Stundenplan with cells. The Realschule Heessen sheet (X1) was a 404. The SVWS/SchILD Fach-Kürzel catalogue is still unfetched (GitHub code search needs a login; the NRW open-data Fächer table found is for bilingual offers only).
4. Sachsen-Anhalt: `SsU`/`SSU` and `An` are unexplained; the answer is probably in the state's Grundschulverordnung or Stundentafel (the Erlass PDFs on mb.sachsen-anhalt.de were 404 again). Sekundarschule: one plan, one day, no legend; Gemeinschaftsschule none. Edupage timetables (Tangermünde) are JavaScript only; Bad Lauchstädt's per-class pages were not reached.
5. Every finding is one school: use the codes as aliases and ambiguity flags, not as state standards. The family's own subject list plus a legend on the sheet still outrank them.
6. Dates: the Thyratal sheet is "2026/27 ab 05.10.2026", the Staßfurt plan 16.10.2026, the Hamm legend December 2018, the Weimar table 2016.

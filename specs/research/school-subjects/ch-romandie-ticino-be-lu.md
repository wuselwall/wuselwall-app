# Timetable sheets and legends: Romandie, Ticino, Belgium, Luxembourg

Researched 2026-10-23. Scope: close the gap named in ch-at.md section 9 (no real Romandie or
Ticino timetable with abbreviations; Belgium and Luxembourg not researched). Compared with
`supabase/functions/_shared/school_subjects.ts` (`fr`, `it` lists; no `nl` list) and the
`ch-fr` / `ch-it` starter lists of `20261023105000_starter_subjects.sql`.

Result in one line: **real sheets found for Ticino (scuola media, two schools) and Vaud
(7P to 12, two schools), a school-published code list for Fribourg (CO), and code lists for
Neuchatel; nothing readable for Geneva, Valais, Jura, Belgium or Luxembourg.**

How the documents were read: the Massagno, Gravesano and Aigle PDFs have no text layer the
fetch tool can use, so I decoded them locally (Flate and, for Aigle, the RC4 "empty password"
encryption that any viewer applies silently) and rebuilt the text by position. The Lausanne
(Elysee) timetables are PNG images, which I read as images. Every code below was read in one
of those; nothing is from memory. Expansions that no document printed next to the code are
marked **inferred**.

Marks used: **cell** = the code is printed in a lesson cell of a class timetable;
**list** = printed in a school or cantonal list of codes (legend); **name** = the sheet prints
the full name, no code; **snippet** = only seen in a search-result summary, not fetched.

## 1. Sources

| Id | URL | School / body | Region | Level | What it is | Fetched? |
|---|---|---|---|---|---|---|
| T1 | https://massagno.sm.edu.ti.ch/wp-content/uploads/sites/38/2026/08/{1A..1E,2A..2D,3A..3D,4A..4D}_2026-2027_Orario.pdf (17 files read, e.g. .../1B_2026-2027_Orario.pdf) | Scuola media Massagno | Ticino | scuola media I-IV (Untis 2026, created 2026-08-17) | class timetables, 5 days x 10 periods, codes only, **no legend** | fetched (decoded locally) |
| T2 | https://gravesano.sm.edu.ti.ch/wp-content/uploads/sites/31/2025/08/I-e-II-3.pdf | Scuola media Gravesano | Ticino | I and II media, 8 classes (Untis 2026, 28.8.2025) | class timetables, full names plus teacher and room | fetched (decoded locally) |
| T3 | https://minusio.sm.edu.ti.ch/wp-content/uploads/sites/40/2026/03/Presentazione-V-elementare-2026.pdf | Scuola media Minusio | Ticino | grid, already in ch-at.md | curricular grid | not re-fetched |
| V1 | https://elys.ch/wp-content/uploads/horaires/classes.html (index of 52 classes); PNGs under /classes/edc00000NNp00001s3fffffffffffffff_<class>_ac.png; linked from https://www.lausanne.ch/vie-pratique/enfance-jeunesse-famille/scolarite-a-lausanne/etablissements-scolaires/eps-de-l-elysee.html ("Horaires des classes 2026-2027") | EPS de l'Elysee, Lausanne (Index Education EDT, 2026) | Vaud | 7P, 8P, 9VP/9VG, 10VG/10VP, 11VG/11VP, 12RAC, ACC | class timetables as PNG, public, codes only, no legend. Read: 7P/03, 8P/02, 9VP/01, 10VG/01, 11VP/01 | fetched (images read) |
| V2 | https://www.ecoles-aigle.ch/wp-content/uploads/sites/66/2026/07/Horaire_7-8P_26-27-1.pdf | Etablissement primaire et secondaire d'Aigle ("Aigle PS", EDT, 10.07.2026) | Vaud | 7P-8P (17 pages) | class timetables, **full names**, room | fetched (decoded locally) |
| V3 | https://www.ecoles-aigle.ch/wp-content/uploads/sites/66/2026/07/Horaire_9-12S_26-27-1.pdf | same | Vaud | 9S-12 (28 pages: 9VG, 9VP, 10VG, 10VP, 11VG, 11VP, 12RAC, ACC) | class timetables, **mix of codes and full names**, group labels like `[10GMAT.` | fetched (decoded locally) |
| V4 | https://www.lausanne.ch/.binaryData/website/path/lausanne/vie-pratique/enfance-jeunesse-famille/scolarite-a-lausanne/etablissements-scolaires/eps-isabelle-de-montolieu/content/0/containerFullWidth/0/col1/0/accordeonAccrochesList/03/websitedownload/HorairesClasses_2026-2027_Version2.2026-07-07-14-50-31.pdf | EPS Isabelle-de-Montolieu, Lausanne | Vaud | 26 pages | class timetables | fetched, **not decoded** |
| F1 | https://coveveyse.ch/activites/ | Cycle d'orientation de la Veveyse, Chatel-St-Denis | Fribourg | 9H-11H | school page with the disciplines and their codes as printed | fetched (page summary) |
| N1 | https://rsn.ne.ch/DATA/program/books/RSN2024/20242/htm/410.101.htm (art. 3) | Canton de Neuchatel, Reglement du cycle 3 | Neuchatel | 9H-11H | official list of PER codes | fetched |
| N2 | https://csvr.ch/liste-des-abreviations/ | Cercle scolaire Val-de-Ruz | Neuchatel | 1H-11H | school-published "Liste des abreviations" (domains, disciplines, class codes) | fetched (condensed reading; expansions of EAC and OSH not verbatim) |
| N3 | https://rsn.ne.ch/DATA/program/books/RSN2021/20214/pdf/4103131.pdf and the 2025-26 grid https://www.ne.ch/legislation-jurisprudence/pubfo/ArrRegCE/Documents/2025/FO08_04_2025_02_17_DFFD_102_ACE_Grilles_horaires_EO_2025-2026.pdf | Canton NE | Neuchatel | all | grids with codes, already in ch-at.md | snippet only |
| B1 | https://www.espkarreveld.be/lecole/les-cours/grille-horaire/ | Ecole secondaire plurielle Karreveld, Brussels | Belgium fr | secondaire, 3 degres | curricular grid (names, hours), not a class timetable, no codes | fetched (summary) |
| B2 | https://gallilex.cfwb.be/sites/default/files/imports/25078_000.pdf (circulaire 4); circulaire 4141; https://www.lalibre.be/belgique/2023/04/06/les-3es-et-4es-primaires-de-bruxelles-iront-une-heure-de-plus-a-lecole-par-semaine-que-les-autres-eleves-OMCCPVDGJBHMJKR2VD5SSVEJ7M/ | Federation Wallonie-Bruxelles | Belgium fr | primaire | official frame (28 periods of 50 min; subject groups) | snippet only |
| B3 | https://pro.katholiekonderwijs.vlaanderen/download/content/25cfdc40-795f-4a2a-9332-631573051137/attachments/Lessentabel%20algemene%20vorming%20en%20keuzegedeelte%20eerste%20graad%20-%20210216.pdf | Katholiek Onderwijs Vlaanderen | Belgium nl | secundair, 1st graad | lessentabel with subject names | snippet only |
| L1 | https://www.cc.lu/fileadmin/user_upload/tx_ccavis/6069bis_PRG_Grilles_ESG_Texte.pdf ; https://www.csl.lu/app/uploads/2022/08/20140825_csl_rgd_grilles-horaires-de-lannee-scolaire-2014_2015.pdf ; https://legilux.public.lu/eli/etat/leg/rgd/2017/07/28/a714/jo ; https://ljbm.lu/wp-content/uploads/2024/06/2024-Fiche-C-C-1.pdf | Luxembourg ministry (grids); Lycee Josy Barthel Mamer (fiche) | Luxembourg | secondaire (ESG, ESC) | official grids with 5-letter course codes | **snippet only** (PDFs downloaded, text not extractable by my tools) |
| L2 | https://www.lmrl.lu/wp-content/uploads/2020/09/WebUntis-guide-e%CC%81le%CC%80ves_parents.pdf | Lycee Michel Rodange | Luxembourg | secondaire | WebUntis guide | fetched, unreadable |
| G1 | https://edu.ge.ch/enseignement/sites/default/files/2021-07/grille_horaire_2021_web.pdf ; https://www.fr.ch/document/347781 ; Jura arrete grilles horaires of 2026-08-01 (https://www.jura.ch/Htdocs/Files/v/abbd4b6f6df1fa8c00f5ca88e18c9c5e0f3c87d292a31bbe22848963ab00a2ac.pdf/AR_grilles-horaires-des-EP-et-ES_260801.pdf) | GE, FR, JU | | | cantonal lesson grids | fetched, **not decoded** (no simple text layer, or scans) |

Searched and not found (nothing public): a Geneva class timetable (primary or CO), a Valais one,
a Jura one, a Fribourg one (the cantons say "ask your school"), any Romandie primary 1P-6P
timetable, any Ticino scuola elementare timetable, any Belgian class timetable (fr or nl), any
Luxembourg class timetable (schools use WebUntis behind a login). About 40 fetches and 25
searches were used.

## 2. Per area: code to subject name as printed

### 2.1 Ticino, scuola media (T1 Massagno; T2 Gravesano)

T1 prints codes only and has no legend. Counts are over 17 class sheets. A leading `.` (".MAT",
".TED", ".LAT", ".IRE", ".ING", ".ORI", ".CET", ".EAL", ".FRA", ".STO") occurs on the same
subjects as the dotless form; it looks like a marker for a split lesson (courses A and B in
III-IV media, language groups, laboratories): **inferred**, the sheet does not say so. T2 has
the same split lessons with names ("Lab. TED gr. 1", "Lab. MAT gr. 2").

| Code (T1, cell) | Subject | Count | Name evidence |
|---|---|---|---|
| ITA | Italiano | 43 | T2 prints "Italiano" |
| MAT / .MAT | Matematica | 18 / 25 | T2 "Matematica" |
| TED / .TED, .TED1, .TED2 | Tedesco | 12 / 16 / 4 | T2 "Tedesco", "Lab. TED gr. 1" |
| FRA / .FRA | Francese | 22 / 3 | T2 "Francese" |
| ING / .ING | Inglese | 6 / 10 | III-IV media (grid in ch-at.md) |
| STO / .STO | Storia | 20 / 3 | T2 "Storia" |
| GEO | Geografia | 26 | T2 "Geografia" |
| SCI / .SCI | Scienze naturali | 22 / 1 | T2 "Scienze" |
| EVI | Educazione visiva | 13 | T2 "Ed. visiva" |
| EMU | Educazione musicale | 19 | T2 "Ed. musicale" |
| EFI | Educazione fisica | 30 | T2 "Ed. fisica" |
| APLA / .APLA | Educazione alle arti plastiche | 9 | T2 "Arti plastiche 1" / "Arti plastiche 2" (two half-classes) |
| OCL | Ora di classe | 17 (once per class) | T2 "Ora classe" |
| IRE / .IRE | Insegnamento religioso (cattolico) | 13 | T2 "Rel. cattolica", and "NO religione" for the alternative slot |
| .REV | religione evangelica (inferred) | 2 | T2 "Rel. evangelica" |
| LAT / .LAT | Latino | 24 | name not printed (Opz. latino, III-IV media) |
| ST.REL. | Storia delle religioni | 4 (IV media only) | IV media grid in ch-at.md |
| .ORI | opzione di orientamento (OORI), IV media (inferred) | 4 | ch-at.md |
| .CET | opzione capacita espressive e tecniche (OCET), IV media (inferred) | 4 | ch-at.md |
| .EAL | educazione alimentare, III media (inferred) | 3 | ch-at.md |
| .IT1, .IT2 | **unknown**: appear in every year (9 and 8 times) next to ITA; may be "Italiano, gruppo 1/2" like T2's "Lab. ITA gr. 1/2" | 9 / 8 | not expanded anywhere |

T2 (names only), additionally: "Diff. curr." (differenziazione curricolare, inferred), "Lab.
MAT gr. 1/2", "Lab. ITA gr. 1/2", "Lab. TED gr. 1/2", "Lab STO II", "Lab GEO II", "Ora classe",
"Rel. cattolica", "Rel. evangelica", "NO religione". Each T2 cell also has room, teacher's
surname in capitals and a group letter A or B.

Layout of T1: header with class and class teacher ("1B Landolfi", "2A Bertuol"), "Untis 2026",
five day columns `LU MA ME GI VE`, and **period numbers 1 to 10 instead of clock times**. `MA`
is the weekday (martedi) in the header and also the `it` list's code for Matematica; only the
header row tells them apart. T2 uses full weekday names.

### 2.2 Vaud (V1 Lausanne Elysee, cells; V2 and V3 Aigle)

V1 prints a code and the room (no teacher); cells with groups show the group label in brackets
(`[10VG1_ALL_1]`). V2 (7P-8P) prints **full names** only. V3 (secondary) mixes: ALL, FRA, MAT,
SCN, ACM-EDN as codes and the rest as full names.

| Code (V1 or V3 cell) | Name as printed (V2/V3) | Seen in |
|---|---|---|
| FRA, `FRA 1`, `FRA 2` | Francais; "Francais niveau 1" | 7P-11VP, cell |
| MAT, `MAT 1`, `MAT 2` | Mathematiques; "Mathematiques niveau 1" | cell |
| ALL, `ALL 1`, `ALL 2` | Allemand | cell |
| ANG | Anglais | cell (V3 prints the name) |
| HIS | "Histoire/Ethique et cultures religieuses": one Vaud discipline, no separate ECR cell | cell |
| GEO | Geographie | cell, 9VP and 10VG |
| GEOCIT | "Geographie-Citoyennete" | cell, 7P, 8P, 11VP |
| SCN | "Sciences de la nature" | cell |
| MUS | Musique | cell |
| AVI | Arts visuels | cell |
| ACM | Activites creatrices et manuelles | cell, 7P, 8P |
| ACM-EDN | code in V1 and V3; EDN = education nutritionnelle (**inferred** from the Vaud grid in ch-at.md "AC&M / Education nutritionnelle"); groups `_TM`, `_ACT` | cell, 9VP and 10VG |
| EPH | "Education physique" | cell |
| FORGEN | "Formation generale" | cell, 10VG |
| `*AMS*` | not printed in full anywhere; sport colour and gym rooms 001, 2, 3 on 7P to 10VG, group `[AMS_7_8]`, `[AMS_9_10]` (**unknown**, probably an optional sport slot) | cell |
| OS-ITA, OS-LAT, OS-MEP, OS-ECO | options specifiques: italien, latin, mathematiques et physique (MEP), economie et droit (ECO); V3 prints "Cours facultatif d'italien", "Latin", "Economie Droit" | cell, 9VP and 11VP |
| OC-SCN, OC-EDN, OC-MITIC, OC-SPOR; `OCOM` (V3) | options de competences orientees metiers (OCOM, as in ch-at.md); the four read as sciences, education nutritionnelle (inferred), MITIC, sport | cell, 10VG |
| other names in V3 | "Bain Informatique", "Mathematiques et sciences de la nature", "Sciences humaines et sociales", "Cours facultatif de grec" | name |

Not seen on any Vaud sheet: EPS, SN, AV, ECR as a cell, MCC, ACT as a cell (only inside group labels).

### 2.3 Neuchatel (N1 official list, N2 school list)

In ch-at.md from the arrete; N1 and N2 confirm it from two other documents. New: N1 art. 3 also
lists the **cantonal options** OCM, ODE, OEX, OIG, OLA, OLM, OSE, OSH and **ACF, FRR, MTR**; a
search summary of the 8th-year reglement adds **MIU** (medias, science informatique et usages;
not re-read). N2 (Val-de-Ruz) groups by domain: ART (MUS, AVI, ACM), ATI (ATI/T, ATI/1, ATI/2),
CMV (EPH, EFA), FGE (EAC, INF), LNG (FRA, ALL, ANG), MSN (MAT, SCN), SHS (HIS, GEO, MCC), REX,
TDC, LCA, REP, OLM, OSE, OSH; class codes such as `3CRCO1` (level, track, village, number).
**These are list codes (legend); no Neuchatel class timetable was found.**

### 2.4 Fribourg (F1, list)

The CO de la Veveyse prints its disciplines with codes (French-speaking Fribourg, 9H-11H):

| Domain | Code and name as printed |
|---|---|
| Langues | ALL Allemand; ANG Anglais; FRA Francais; GRE Grec; LAT Latin |
| MSN | MAT Mathematiques; SCN Sciences de la nature |
| SHS | CIT Citoyennete; ERC Enseignement religieux confessionnel; ECR Ethique et cultures religieuses; GEO Geographie; HIS Histoire; HG Histoire-geographie (11H) |
| Arts | ACM Activites creatrices manuelles; ACT Activites creatrices sur textile; AV Arts visuels; MUS Musique |
| Corps et mouvement | EF Economie familiale; EP Education physique |
| Formation generale | FG Formation generale; INF Informatique |
| Options 11H | DT Dessin technique; ECO Economie; ITA Italien; MIT Medias, images, technologies de l'information et de la communication; TPS Travaux pratiques de sciences |
| Other | DS Devoirs surveilles; ETU Etudes |

Fribourg prints `AV`, `EP`, `EF` where Neuchatel and Vaud print `AVI`, `EPH`, `EFA`: the one place
where a Romandie canton prints a different code for the same subject.

### 2.5 Geneva, Valais, Jura

Nothing readable. Geneva CO and Jura grids were fetched but could not be decoded; Valais and
Jura publish no class timetables. The codes of Vaud and Neuchatel (V1, V3, N1) and the PER codes
in ch-at.md are the best proxy.

### 2.6 Belgium and Luxembourg

No class timetable found. Only names (not codes):

- **Belgium fr, secondaire (B1 Karreveld, a grid):** Francais; Mathematique; Neerlandais; Anglais; Initiation scientifique; Sciences (biologie - chimie - physique); Histoire / Geographie; Histoire / Geographie / Actualites; Education artistique; Education a la technologie; Education physique; Morale / Religion / EPC; Education a la philosophie et a la citoyennete; Culture antique; Initiation aux sciences sociales; Sciences economiques; Latin; Grec; Informatique; Theatre; Sciences sociales; Espagnol; Communication.
- **Belgium fr, primaire (B2, snippet only):** the frame names Francais, Mathematiques, "Sciences et applications technologiques, manuelles et numeriques", "Histoire, geographie, sciences economiques et sociales", "Education culturelle et artistique", "Education physique et a la sante" (incl. natation), "Philosophie et citoyennete et/ou religion" (CPC "Philosophie et citoyennete" is on one school grid), "langue moderne" (Neerlandais), "accompagnement personnalise" (2 periods in 3rd-5th primaire in 2024-25).
- **Belgium nl (B3, snippet only):** Nederlands, Wiskunde, Frans, Engels, Aardrijkskunde, Geschiedenis, Lichamelijke opvoeding, Godsdienst; primary: "wereldorientatie, muzische vorming, lichamelijke opvoeding, godsdienst". The Flemish government sets no lessenrooster for basisonderwijs; schools publish their own, usually inside a portal (Smartschool, Bingel; not checked).
- **Luxembourg (L1, snippet only):** the ministry's grids use 5-letter course codes: ALLEM Allemand, FRANC Francais, ANGLA Anglais, LATIN Latin, MATHE Mathematiques, HISTO Histoire, GEOGR Geographie; the ESG grids also quote ALLUX, SCNAT (sciences naturelles), SCSOC (sciences sociales), ESTEC (education technologique); the exact expansions of ALLUX, SCSOC and ESTEC are from the search summary. The lycee fiche (ljbm.lu) lists FRANC, ALLEM, ANGLA, LATIN, MATHE. Schools publish class timetables only through WebUntis behind a login. For the ecole fondamentale (cycles 2-4) literacy is taught in German (Eurydice); no timetable found.

## 3. Additions proposed for the scanner's vocabulary

Format `{code, name, group, language}`. Codes are folded (lowercase, no accents). Groups are
the ones already used in `school_subjects.ts`. "Add to existing" means: put the code into the
existing entry of that name instead of creating a second entry.

### 3.1 `it` (Ticino scuola media, from T1 and T2)

| code | name | group | language | note |
|---|---|---|---|---|
| efi | Educazione fisica | sport | it | add to existing (has `ef`, `efs`, `fisica`) |
| evi | Educazione visiva | arts | it | add to existing (has `ev`, `visiva`) |
| emu | Educazione musicale | music | it | add to existing (has `em`) |
| apla | Educazione alle arti plastiche | crafts | it | add to existing (has `eap`); also "arti plastiche 1/2" |
| sto | Storia | history | it | add to existing (has `st`) |
| sci | Scienze naturali | science | it | add to existing (has `sn`, `scienze`) |
| ocl | Ora di classe | class | it | add to existing; T2 prints "ora classe" |
| ire | Insegnamento religioso | religion | it | add to existing (has `rel`) |
| rev | Religione evangelica | religion | it | new; "rel. evangelica", "rel. cattolica" |
| lat | Latino | latin | it | new; the `it` list has no Latin entry |
| st.rel | Storia delle religioni | religion | it | add to the entry with `sdr`; also `st rel` |
| ori | Opzione di orientamento (OORI) | elective | it | new, IV media |
| cet | Opzione capacita espressive e tecniche (OCET) | elective | it | new, IV media |
| eal | Educazione alimentare | home-economics | it | new, III media (inferred) |
| diff. curr. | Differenziazione curricolare | support | it | T2 |
| lab. mat, lab. ita, lab. ted | Laboratorio (matematica, italiano, tedesco) | group of the subject (mathematics, first-language, german) | it | T2; "lab. X gr. n" should resolve to X |
| rel. cattolica, no religione | Religione cattolica; alternative to religion | religion | it | T2 |

Parser rules the sheets show: strip a **leading dot** (`.MAT`); strip a trailing group digit
(`TED1`, `.TED2`) and a trailing "gr. 1", "1", "2" or "II"; the first column of T1 is the
period number 1-10, not a clock time.

### 3.2 `fr` (Romandie)

| code | name | group | language | note |
|---|---|---|---|---|
| geocit | Geographie-Citoyennete | geography | fr | Vaud (V1 cell, V2 and V3 name); also `geographie-citoyennete` |
| forgen | Formation generale | class | fr | add to the entry with `fge`; Fribourg prints `fg` |
| fg | Formation generale | class | fr | F1 |
| acm-edn | ACM / Education nutritionnelle | crafts | fr | V1, V3 (expansion inferred) |
| act | Activites creatrices sur textile | crafts | fr | F1 |
| efa | Economie familiale | home-economics | fr | N1, N2 |
| ef | Economie familiale | home-economics | fr | F1; `it` `ef` is a separate list |
| mcc | Monde contemporain et citoyennete | civics | fr | N1, N2 |
| cit | Citoyennete | civics | fr | F1 |
| os-ita | Option specifique italien | italian | fr | V1, V3 |
| os-lat | Option specifique latin | latin | fr | V1 |
| os-mep | Option specifique mathematiques et physique | elective | fr | V1 |
| os-eco | Option specifique economie et droit | economics | fr | V1 |
| oc-scn, oc-edn, oc-mitic, oc-spor, ocom | Option de competences orientee metiers | elective | fr | V1, V3 |
| olm, ola, ose, osh, ocm, ode, oex, oig | NE options: modern languages, ancient languages, experimental sciences, human sciences, creative manual, drawing, oral expression, applied computing | elective | fr | N1 |
| frr, mtr, rex, tdc, acf | Francais renforcement; Mathematiques renforcement; Renforcement/Extension; Travail en demi-classe; Activites complementaires facultatives | support | fr | N1, N2 |
| miu | Medias, science informatique et usages | computing | fr | NE 8th-year reglement (summary) |
| inf | Informatique | computing | fr | add to the entry with `info` (F1, N2) |
| mit | Medias, images, technologies de l'information et de la communication | computing | fr | F1 |
| tps | Travaux pratiques de sciences | science | fr | F1 |
| dt | Dessin technique | crafts | fr | F1 |
| eco | Economie | economics | fr | F1 |
| gre | Grec | greek | fr | add to the entry with `grec`; F1 |
| erc | Enseignement religieux confessionnel | religion | fr | F1; add to the entry with `er` |
| etu | Etudes | support | fr | F1; add to the entry with `etude` |
| bain informatique | Bain informatique | computing | fr | V3 |

**Conflicts and cautions**

- `ds`: the `fr` list marks it ambiguous (devoir surveille in France). Fribourg CO prints `DS` = Devoirs surveilles (study hall, support). Keep ambiguous.
- `ef`: Economie familiale in Fribourg; `it` `ef` = Educazione fisica. A clash only if the lists were shared; they are not.
- `ma`: weekday martedi vs Matematica (Ticino) in the day header; the header row decides.
- `sn` (existing alias) vs `scn`: Vaud, Neuchatel and Fribourg print `SCN`; `scn` is already in the entry. `sn` stays as a "common usage" alias only.
- `eps`: not printed on any Romandie sheet (they print EPH or EP); the existing `eps` entry is France; harmless.
- `ecr`: Vaud has no separate ECR cell (the cell is `HIS`, name "Histoire/Ethique et cultures religieuses"); Fribourg lists ECR and ERC. Map `ecr` to religion, `his` to history.
- `st`: in `fr` it means Sciences et technologie (France primary); no Swiss sheet prints it.
- A suffix " 1" or " 2" after FRA, MAT, ALL, ANG (niveaux, Vaud V1, V3) must not be read as a count.
- `*AMS*` (with asterisks): printed in the sport colour on Vaud sheets; leave it for the parent to name.

### 3.3 `nl`: no list can be proposed from fetched sheets

Only names (section 2.6, snippet only). A `nl` list from Flemish usage would be guesswork until
a real sheet is found.

## 4. Starter-list check

**ch-fr** (FRA, MAT, ALL, ANG, SN, HIS, GEO, AVI, ACM, MUS, ECR, EPH):

- FRA, MAT, ALL, ANG, HIS, GEO, AVI, ACM, MUS, EPH match what V1 and N1 print.
- `SN` should be `SCN`: Vaud (V1 cell), Neuchatel (N1, N2) and Fribourg (F1) all print SCN. The scanner knows both, but the starter's short name is what the family sees on its own cards.
- `ECR` is not a cell on any Vaud sheet (merged with Histoire); it exists in Fribourg and in the PER. Keep, but a Vaud family will not scan it.
- Missing against what the sheets print: `GEOCIT` (Vaud 7P+, replaces GEO in several grades), `FORGEN` or `FGE` (Vaud, NE), `EFA`/`EF` (economie familiale, 9H+), `MCC` (NE). Fribourg CO short names differ: `AV`, `EP`, `EF`, `FG`. One list cannot fit all cantons. The SQL picks `ch-fr` for GE, VD, NE, JU and for any other state whose language is fr (FR, VS), so Fribourg and Valais families get the Vaud/NE codes.
- Primary 1P-6P: no sheet. V2 (7P-8P at Aigle) prints **full names**, so there OCR matches names, not codes: Francais, Mathematiques, Allemand, Anglais, Sciences de la nature, "Histoire/Ethique et cultures religieuses", "Geographie-Citoyennete", Arts visuels, "Activites creatrices et manuelles", Musique, Education physique. The `fr` list has these names, except the two long combined ones.

**ch-it** (ITA, MAT, TED, FRA, AMB, EV, EAP, EM, EF):

- The two scuola media sheets print `EVI`, `APLA`, `EMU`, `EFI` (Massagno) or "Ed. visiva", "Arti plastiche", "Ed. musicale", "Ed. fisica" (Gravesano); the starter's `EV`, `EAP`, `EM`, `EF` are what Massagno does not print. Suggest `EVI`, `APLA`, `EMU`, `EFI` for scuola media; keep `AMB` for scuola elementare (no elementary sheet found to confirm).
- Missing for scuola media: ING (III-IV; `.ING` on 10 cells), STO, GEO, SCI, OCL (Ora di classe), IRE (religion, optional), LAT (option), plus IV media ORI, CET and ST.REL.
- The starter list reads as a scuola elementare list plus media words; Ticino needs two lists (SE and SM) if the app wants to be exact.

**Belgium fr, proposed starter (names only; no code verified, short names for the family to set):** Francais, Mathematiques, Neerlandais, Sciences (Initiation scientifique), Histoire-Geographie, Education artistique, Education physique, Morale / Religion, Education a la philosophie et a la citoyennete (CPC / EPC), Education a la technologie. Source B1 (secondaire) and B2 (primaire frame, snippet). I would not ship this before one real sheet confirms the wording.

**Belgium nl and Luxembourg:** no basis for a starter list. For Luxembourg the ministry codes (section 2.6) are admin codes; school sheets are behind WebUntis.

## 5. Gaps I could not close

1. **Geneva (primary and CO), Valais, Jura, Fribourg class timetables**: none public; each canton says "contact your school".
2. **Romandie primary 1P-6P and Ticino scuola elementare**: only Vaud 7P-8P and scuola media found.
3. **Belgium (fr and nl) and Luxembourg**: no class timetable, no code legend. Belgian primary timetables are made by the teacher; secondary schools use Untis or Smartschool behind logins. The Luxembourg codes are from search snippets only.
4. **Fetched but undecoded PDFs worth a second pass with a real PDF-to-text or OCR tool**: V4 (Lausanne Isabelle-de-Montolieu, 26 pages of class timetables, same family as V1), the Geneva grid, the Fribourg cycle 1-2 grid (https://www.fr.ch/document/347781), the Jura arrete (scanned), the Luxembourg grids (L1), the Michel Rodange WebUntis guide (L2).
5. **Unexpanded codes**: Ticino `.IT1`, `.IT2`, `.REV`, `.EAL`, `.ORI`, `.CET` (inferred only); Vaud `*AMS*`, `PA`, `PB` (printed in Aigle's 9-12S sheets, not expanded), `EDN` (inferred), `OC-MITIC`; Neuchatel `EAC`.
6. The Massagno and Elysee sheets are one school each; Untis and EDT let every school choose its own codes, and the two Ticino schools already differ (codes against names). The parser should read the family's own sheet first; these lists are priors, not rules.
7. Dutch (nl): no list can be built; needs one Flemish class sheet (for instance a Smartschool export a parent can share).

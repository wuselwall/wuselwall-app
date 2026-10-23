# France: school subject names and timetable abbreviations

Research for the timetable-scan feature. Compiled 2026-10-23.

## How to read the provenance tags

| Tag | Meaning |
|---|---|
| **[O]** | Official name or rule. A ministry / Eduscol / BO page, or a page quoting it, confirmed it this session. |
| **[O\*]** | Official, but the ministry page returned HTTP 403/503 to the fetcher. Confirmed only through search-result summaries or prior knowledge. Re-check exact hours before relying on them. |
| **[S]** | Seen on a real school document found this session (timetable, handbook, parents' presentation). |
| **[T]** | Typical on timetables, from general knowledge of French sheets. Not confirmed by a fetch this session. Treat as a candidate dictionary entry, not as proof. |

Limits:

- The web search tool returns summaries, not raw text. Ministry sites (education.gouv.fr, eduscol, legifrance, BCN) returned 403 or 503 to the fetcher. Several school PDFs refused connections or were image-only.
- I found **no published list** of the default subject codes of Pronote, EDT or UnDeuxTemps. Everything about default short codes is [T]; only the three long labels from S18 are [S].
- Nothing was checked against the pilot's own sheets (see `specs/24`). Those remain the ground truth.

## Sources

| ID | URL | Used for |
|---|---|---|
| S1 | https://www.education.gouv.fr/bo/15/Hebdo44/MENE1526553A.htm | Arrêté of 9 Nov 2015, primary hours (403 to fetcher; figures corroborated by S3 and search summaries) |
| S2 | https://eduscol.education.gouv.fr/5229/l-ecole-elementaire | Primary school overview (403 to fetcher) |
| S3 | https://www.ac-nantes.fr/media/34993/download | Cycle 2 annual/weekly hours |
| S4 | https://aufutur.fr/college/emploi-du-temps-troisieme-cours-horaires/ | 3e subjects and hours (fetched) |
| S5 | https://www.letudiant.fr/college/rentree-2026-combien-d-heures-de-cours-au-college.html | Collège hours 2026-27, options, Devoirs faits (fetched) |
| S6 | https://eduscol.education.gouv.fr/5208/l-organisation-des-enseignements-au-college | 25 h in 6e, 26 h in 5e-3e, Devoirs faits (403 to fetcher; quoted by search) |
| S7 | https://www.education.gouv.fr/l-emploi-du-temps-de-votre-enfant-au-college-455718 | Collège timetable, EPI, AP (403 to fetcher) |
| S8 | https://www.weka.fr/actualite/education/article/les-groupes-de-besoins-au-college-sont-confirmes-pour-les-classes-de-6e-et-de-5e-198775/ | Groupes de besoins in 6e/5e |
| S9 | https://www.education.gouv.fr/bo/18/Hebdo4/MENE1802241C.htm | LCA (latin/grec) option, hour limits |
| S10 | https://eduscol.education.gouv.fr/5466/seconde-generale-et-technologique | Seconde GT |
| S11 | https://www.education.gouv.fr/les-enseignements-de-la-classe-de-seconde-41651 | Seconde GT hours |
| S12 | https://eduscol.education.gouv.fr/5418/cycle-terminal-de-la-voie-generale | Cycle terminal, common core |
| S13 | https://eduscol.education.fr/document/71237/download | Specialty combinations |
| S14 | https://eduscol.education.gouv.fr/31284/domaines-enseignement/numerique-informatique-sciences-de-l-ingenieur-lycee-gt | SNT, NSI, SI |
| S15 | https://le-verrier.lycee.ac-normandie.fr/IMG/pdf/re_union_parents_pp_2gt_2025.pdf | A real 2nde grid, 2025-26 (via search summary; fetch refused) |
| S16 | https://etab.ac-reunion.fr/clg-jean-desme/wp-content/uploads/sites/46/2022/04/Presentation-2nde-GT-Lycee-Le-Verger-rentree-2022.pdf | 2nde with LVA/LVB, AP split (via search summary) |
| S17 | https://lycee-valentine-labbe.fr/wordpress/wp-content/uploads/2024/01/Plaquette-Bac-General-finale.pdf | The 12 specialties, Maths expertes/complémentaires (via search summary) |
| S18 | https://webetab.ac-bordeaux.fr/college-mauriac-leognan/fileadmin/0332244K/fichiers_publics/enseignement/emplois-du-temps/edt4C.pdf (also edt3D, edt3F, edt4D, edt4E, edt3E) | Real Index Éducation 2013 collège sheets: "HISTOIRE & GEOGRAPH.", "PHYSIQUE-CHIMIE", "ED.PHYSIQUE & SPORT."; cell = subject, teacher surname, room (via search summary; fetch refused) |
| S19 | https://etab.ac-reunion.fr/clg-tamarins/wp-content/uploads/sites/56/2026/08/Livret-eleve-2026.pdf | Week letters A/B on the student timetable; the subject in a slot can differ between A and B (via search summary) |
| S20 | https://www.lycee-descartes.ac.ma/medias/RENTREE2020/Alternancesdesgroupesetdesdemigroupes.pdf | A/B weeks plus C/D for courses "en quinzaine", entered in Pronote (Moroccan French-system lycée, not France) |
| S21 | https://download-aed.axess.fr/Manuels_site/Manuel%20UnDeuxTEMPS.pdf | UnDeuxTEMPS manual: "Matières" is the first base-data table; up to 500 subjects (table of contents only) |
| S22 | https://chlorofil.fr/fileadmin/user_upload/03-actions/orientation/plan-etudiant/guide-pronote-parcoursup.pdf | Pronote/EDT can use the national subject nomenclature |
| S23 | https://www.pedagogie.ac-nice.fr/dane/documents-dane/editeurs/laffez/lsu/01b-Préparer_ses_bases_de_données_EN_DEBUT_D_ANNEE.pdf | Pronote subjects must match STS-Web subjects (LSU import) |
| S24 | https://bcn.depp.education.fr/bcn/uploads/domaines/scolarite_bcn_scolarite.pdf | BCN N_MATIERE / N_MATIERE_ENSEIGNEE (503 to fetcher; structure only via search) |
| S25 | https://www.pass-education.fr/actu-journee-type-elementaire/ | Primary day labels (fetched): "Rituels et vie de classe", "Calcul mental", "Vocabulaire", "Éducation physique et sportive", "EMC", "Questionner le monde / langue vivante / arts plastiques", "Histoire-géographie ou EMC / sciences et technologie", APC, décloisonnement |
| S26 | https://ecole-flaumont.etab.ac-lille.fr/files/2017/12/EDT-Flaumont-2017-18-revu.pdf | Primary timetable with "APC" slots Mon/Thu (via search summary) |
| S27 | https://blendecqueszay.etab.ac-lille.fr/files/2019/09/EMPLOI_du_temps_2019-2020.pdf | Primary timetable with FRANCAIS and MATHS labels (via search summary) |
| S28 | https://www.education.gouv.fr/bo/16/Hebdo39/MENE1630321C.htm and https://sui.fsu.fr/wp-content/uploads/sites/95/2018/04/2016-05-22_apc_extrait_lia65_.pdf | APC: 36 h/year per teacher, small groups; périscolaire framework (via search summary) |
| S29 | https://enseignants.se-unsa.org/IMG/pdf/grille_horaire_bac_pro_definitive.pdf and https://snalc.fr/wp-content/uploads/BacPro_GrilleHoraireModif_20231206.pdf | Bac pro grid (via search summary) |
| S30 | https://eduscol.education.gouv.fr/646/horaires-de-la-serie-sciences-et-technologies-du-management-et-de-la-gestion-stmg and https://eduscol.education.gouv.fr/645/horaires-de-la-serie-sciences-et-technologies-de-l-industrie-et-du-developpement-durable-sti2d | Technological series hours |
| S31 | https://sections.se-unsa.org/51/IMG/pdf/les_dispositifs_ash_2nd_degre.pdf | SEGPA, ULIS, UPE2A definitions |
| S32 | https://sgermain.loire-atlantique.e-lyco.fr/wp-content/uploads/sites/75/2022/03/Glossaire-a-destination-des-parents.pdf | A school's parent glossary: HG-EMC, EPS, AP, FCA, FLS, HSA/HSE (via search summary; the URL returned 404 when fetched) |
| S33 | https://sgen-cfdt.fr/contenu/uploads/sites/7/2017/02/Ex-EDT-5eme.pdf | A 5e sample sheet showing "Phys/Chimie", SVT, Techno, AP (via search summary; the PDF was image-only) |
| S34 | https://moliere.college.ac-normandie.fr/IMG/pdf/la_classe_de_6eme.pdf | A collège 6e sample week with one "vie de classe" hour (via search summary) |

---

## 1. École élémentaire (cycles 2 and 3)

Official frame: 24 h of teaching per week, 864 h per year, arrêté of 9 Nov 2015 [O* S1, S3]. Weekly hours are indicative; the annual total per domain binds. 10 h/week (cycle 2) and 12 h/week (cycle 3) of oral, reading and writing run across all subjects [O* S1].

| Subject | Official name / domain | Abbreviations and labels seen or typical | Hours | Tag, source |
|---|---|---|---|---|
| French | Français | FRANCAIS (S27), Fr, Français; sub-slots: Lecture, Écriture, Dictée, Étude de la langue, Grammaire, Conjugaison, Orthographe, Vocabulaire (S25), Poésie, Littérature, Production d'écrits, Langage oral, Graphisme (CP), "Silence, on lit", Lecture offerte, Rituels | C2 10 h (360 h/yr); C3 8 h (288 h/yr) | O* S1, S3; S S25, S27; T for other sub-slots |
| Mathematics | Mathématiques | MATHS (S27), Maths, Math; sub-slots: Calcul mental (S25), Numération, Calcul, Géométrie, "Résolution de problèmes" (S25), Mesures, Grandeurs et mesures | 5 h (180 h/yr), both cycles | O* S1, S3; S S25, S27 |
| Questionner le monde | Questionner le monde (C2: with EMC, 90 h/yr, 2 h 30) | QLM, Questionner le monde (S25), QM, "Découverte du monde" (pre-2016 name, still printed), Sciences, Histoire, Géo | C2 2 h 30 with EMC | O* S1, S3; S S25; T for QLM |
| Sciences et technologie | Sciences et technologie (C3) | "sciences et technologie" (S25), Sciences, Sciences et techno, ST | C3 2 h (72 h/yr) | O* S1; S S25 |
| History-geography | Histoire et géographie (C3, with EMC 2 h 30) | "Histoire-géographie ou EMC" (S25), HG, Hist-Géo, Histoire, Géo | C3 2 h 30 with EMC | O* S1; S S25 |
| EMC | Enseignement moral et civique | EMC (S25), Éducation civique, Instruction civique, Débat | inside QLM (C2) / HG (C3) | O* S1; S S25 |
| EPS | Éducation physique et sportive | EPS, "Éducation physique et sportive" (S25), Sport, Natation, Piscine, Motricité, Gym | 3 h (108 h/yr) | O* S1, S2; S S25 |
| Visual arts | Arts plastiques (within "enseignements artistiques") | "arts plastiques" (S25), Arts visuels, Arts, AP (ambiguous), Dessin, Histoire des arts | enseignements artistiques 2 h total | O* S1, S3; S S25 |
| Music | Éducation musicale | Éducation musicale, Musique, Chant, Chorale, EM | in the 2 h artistic block | O* S1; T |
| Modern language | Langues vivantes | "langue vivante" (S25), LV, LVE, Anglais, ANG, Allemand, Espagnol | C2 1 h 30 (54 h/yr); C3 1 h 30 | O* S1, S3; S S25 |
| APC | Activités pédagogiques complémentaires | APC (S25, S26), "Aide personnalisée" (pre-2013 name), Soutien, Aide aux devoirs | 36 h/yr per teacher, small groups, outside the 24 h, often after 15:45 | O* S28; S S26 |
| Directed study | Études dirigées / étude surveillée (municipal) | Étude, Étude dirigée, Étude surveillée, ED | after school, outside the 24 h | O* S28 (frame); T |
| Class life | Vie de classe | "Rituels et vie de classe" (S25), Vie de classe, Conseil d'élèves, Quoi de neuf | within the 24 h | S S25; T |
| Library, digital | BCD / informatique | BCD, Bibliothèque, Informatique, Numérique, Pix (CM2) | none fixed | T |
| Breaks | Pause méridienne, récréation | Récré, Récréation, Pause, Pause méridienne (at least 1 h 30), Accueil | pause at least 1 h 30 | O* S28 |
| Périscolaire | Périscolaire | Garderie (matin/soir), Accueil périscolaire, Cantine, Restaurant scolaire, Repas, Étude surveillée, Centre de loisirs, ALSH, TAP / NAP (2013-2018), PEDT | municipal, outside the 24 h | O* S28 (morning care, lunch break, evening care: study, leisure centre, garderie); T for abbreviations |
| Support | RASED, décloisonnement, PPRE | RASED, Décloisonnement (S25), Décloi, PPRE | n/a | S S25 (décloisonnement); T |

Weekday pattern: most schools run **lundi, mardi, jeudi, vendredi** (4 days, since the 2017-18 return to the 4-day week); some run those plus **mercredi matin** (4.5 days, the 2013-2017 reform and some towns now). Saturday morning is rare on the mainland and appears in a few overseas académies and some private schools [T].

---

## 2. Collège (cycle 3 for 6e, cycle 4 for 5e-3e)

Official frame [O* S6]: 6e has 25 h of compulsory teaching plus the Devoirs faits time; 5e-3e have 26 h. From 2024-25 French and maths in 6e and 5e are taught in **groupes de besoins** [S8]. EPI and AP were the cycle 4 complements until the 2023-24 changes; older sheets still print them [O* S7, T].

2026-27 weekly hours (S5, fetched; the page's own table does not add up exactly to its totals): EPS 4 h in 6e, 3 h in 5e-3e; arts plastiques 1 h; éducation musicale 1 h; français 4.5 h (6e-4e), 4 h (3e); histoire-géographie and EMC 3 h (3.5 h in 3e) of which 30 min EMC; LV1 4 h in 6e, 3 h after; LV2 2.5 h from 5e; maths 4.5 h in 6e, 3.5 h after; SVT 1.5 h; physique-chimie 1.5 h; technologie 1.5 h. Older 3e grid (S4): français 4 h, maths 3 h 30, HG+EMC 3 h 30, SVT 1 h 30, PC 1 h 30, LV1 3 h, LV2 2 h 30, EPS 3 h, techno 1 h 30, éducation musicale 1 h, arts plastiques 1 h.

| Subject | Official name | Abbreviations seen or typical | Tag, source |
|---|---|---|---|
| French | Français | FRANC, FRANCAIS, FR, Français, "FRANCAIS GR1/GR2" (groupes de besoins) | O S5; T for abbreviations |
| French/maths support | Groupes de besoins, soutien, approfondissement | Soutien, Appro, Approfondissement, GB, "Gpe besoin" | O* S8; T |
| Mathematics | Mathématiques | MATHS, MATHEMATIQUES, Maths, MA, Math. | O S5; T |
| History-geography | Histoire-géographie (with EMC) | HG, HG-EMC (S32), HIST-GEO, HI-GE, HIST.GEO, "HISTOIRE & GEOGRAPH." (S18), HGEMC | O S5; S S18, S32; T for HIST-GEO, HI-GE |
| Civics | Enseignement moral et civique | EMC, "ENS.MORAL & CIVIQUE", Éducation civique (older) | O S5 (30 min/week inside HG); T |
| Life and earth sciences | Sciences de la vie et de la Terre | SVT, "SC.VIE & TERRE" | S S33 (SVT); T |
| Physics-chemistry | Physique-chimie | PC, PH-CH, PHYS-CH, PHYS-CHIM, PHYSIQUE-CHIMIE (S18), "Phys/Chimie" (S33), SPC, "SC.PHYSIQUES" (old) | S S18, S33; T for PC / PH-CH / SPC |
| Technology | Technologie | TECHNO, TECH, Technologie | S S33; T |
| Visual arts | Arts plastiques | AP (clashes with accompagnement personnalisé), ARTS PLAST, ARTS PLASTIQUES, A.PLA, ARTP | O S5; T |
| Music | Éducation musicale | EM, ED.MUS, ED MUSICALE, EDUC MUSIC, ED.MUSICALE, "ED.MUSICALE & CHANT.", Musique | O S5; T |
| Physical education | Éducation physique et sportive | EPS, "ED.PHYSIQUE & SPORT." (S18), ED.PHYS, Sport, "EPS 1 / EPS 2" (half groups) | O S5; S S18, S32 |
| Language 1 | Langue vivante 1 / LVA | ANGLAIS LV1, LV1, LVA, ANG, ANGL, AGL, Anglais | O S4, S5; T |
| Language 2 | Langue vivante 2 / LVB (from 5e) | LV2, LVB, ESP, ESPAGNOL LV2, ALL, ALLEMAND LV2, ITA, Italien, Espagnol, Allemand, PORT, CHI | O S4, S5; T |
| Language 3 / bilangue | LVC; classe bilangue | LV3, LVC, Bilangue, Bil., "ANG+ALL" | O* S5 (mentions "section bilangue"); T |
| European section | Section européenne (language + DNL taught in it) | Euro, SELO, "Section euro", DNL | O* S9; T |
| Ancient languages | Langues et cultures de l'Antiquité (LCA), optional: latin, grec; limit 1 h in 5e, 3 h in 4e and 3e | LAT, LATIN, GREC, GRC, LCA, "LCA Latin", "Option Latin" | O S9; T |
| Regional languages | Langues et cultures régionales (LCR) | LCR, Breton, Occitan, Basque, Corse, Alsacien, Créole | O* S5 ("langue régionale"); T |
| Class life | Heures de vie de classe | VDC, VIE DE CLASSE, "Vie de classe", HVC, "VIE CLASSE" | S S34 (one class-life hour in a sample week); T for abbreviations |
| Personalised support | Accompagnement personnalisé | AP, "ACCOMP. PERSONNALISE", "Accomp. perso" | O* S7; S S32, S33 |
| EPI | Enseignements pratiques interdisciplinaires | EPI (cycle 4, older sheets) | O* S7 |
| Homework help | Devoirs faits | DF, DEVOIRS FAITS, "Dev. faits" | O S5, S6 |
| Study hall | Permanence / étude | PERM, Permanence, ETUDE, Étude, "Vie scolaire", "Salle d'étude" | T; S5 mentions "heures de devoirs surveillés" |
| Library | CDI | CDI | T |
| Sports association | UNSS / AS | UNSS, AS, "AS Sport", Wednesday afternoon | T |
| Arts options | CHAM / CHAD / CHAT (classes à horaires aménagés music / dance / theatre) | CHAM, CHAD, CHAT, Chorale, "Chant choral", Théâtre | O* S5 (mentions CHAM, CHAT); T |
| Orientation | Parcours avenir | Parcours Avenir, Orientation, PP (professeur principal) | T |
| Tests | Devoir surveillé, brevet blanc, DNB | DS, "Brevet blanc", BB, DNB, "Oral de stage" | O* S4 ("brevet blanc", "devoirs surveillés"); T |
| School life | Demi-pension | Cantine, DP, Self, Repas, Récré, "Pause méridienne" | T |
| Dispositifs | SEGPA (section d'enseignement général et professionnel adapté); ULIS (unité localisée pour l'inclusion scolaire); UPE2A (unité pédagogique pour élèves allophones arrivants) | SEGPA, ULIS, UPE2A, FLS ("Français langue de scolarisation", S32), "Atelier" (SEGPA workshops) | O S31; S S32 for FLS; T for workshops |
| Staff-side | Heures supplémentaires | HSA, HSE (teacher overtime, staff sheets only) | S S32 |
| Cell layout | not a subject | subject + teacher surname (+ "Mme/M.") + room (e.g. "B2") | S S18 |

---

## 3. Lycée (général, technologique, professionnel)

### 3.1 Seconde générale et technologique (S10, S11, S15, S16)

Compulsory [O* S10, S11]: français 4 h; histoire-géographie 3 h; LVA+LVB 5 h 30; SES 1 h 30; maths 4 h; physique-chimie 3 h; SVT 1 h 30; EPS 2 h; EMC 18 h/year; SNT 1 h 30; accompagnement personnalisé (varies with needs); aide à l'orientation (54 h/year). About 26 h 30 plus options. A real 2025-26 grid: LV1 3 h, LV2 2 h 30, SES 1 h 30, SNT 1 h 30, an AP hour reserved for the professeur principal [S S15]. A 2022 grid: LVA anglais 2 h 30, LVB 2 h, EMC 18 h/year, AP split into orientation 1 h and extra French and maths 0 h 30 each [S S16].

### 3.2 Première and terminale générales (S12, S13, S14, S17)

Common core [O S12]: français (1re), philosophie (terminale), histoire-géographie, LVA, LVB, enseignement scientifique, EMC, EPS. Three specialties in 1re (4 h each), two in terminale (6 h each). Terminale options: maths expertes (3 h), maths complémentaires (3 h), DGEMC. Enseignement scientifique is 2 h; students without the maths specialty get an extra 1 h 30 of maths in 1re [O S12].

### 3.3 Table for lycée général and seconde

| Subject | Official name | Abbreviations seen or typical | Tag, source |
|---|---|---|---|
| French | Français | FRANC, FRANCAIS, FR, Lettres | O S11; T |
| Philosophy | Philosophie | PHILO, PHILOSOPHIE | O S12; T |
| History-geography | Histoire-géographie | HG, HIST-GEO, HI-GE, "HISTOIRE & GEOGRAPH." (S18) | O S11; S S18 |
| Civics | Enseignement moral et civique; historically ECJS (éducation civique, juridique et sociale, replaced by EMC in 2019) | EMC, ECJS, "EDUC. CIVIQUE" | O S11; T |
| Language A / B | Langue vivante A, B | LVA, LVB, LV1, LV2, ANG, ANGL, AGL, ESP, ALL, ITA, "ANGLAIS LV1", "ESPAGNOL LV2" | O S11, S15, S16 |
| Language C | LVC / LV3 (option) | LVC, LV3 | O* S11; T |
| Ancient languages | Latin, grec (option) | LAT, GREC, LCA | O* S9; T |
| Mathematics | Mathématiques | MATHS, MATH, MA | O S11 |
| Maths option | Mathématiques expertes; mathématiques complémentaires | "MATHS EXP", M.EXP, ME, "Maths expertes", "MATHS COMP", MC | O S17 (names); T for abbreviations |
| Physics-chemistry | Physique-chimie | PC, PH-CH, PHYS-CHIM, PHYSIQUE-CHIMIE | O S11; T |
| Life and earth sciences | Sciences de la vie et de la Terre | SVT | O S11 |
| Scientific teaching | Enseignement scientifique | "ENS SCIENTIFIQUE", ENS.SCI., ES (clashes with SES and the old série ES), EnsSci | O S12; T |
| Economics and social sciences | Sciences économiques et sociales | SES | O S11, S17 |
| Digital | Sciences numériques et technologie (2nde, 1 h 30) | SNT | O S11, S14 |
| Computer specialty | Numérique et sciences informatiques (1re 4 h, terminale 6 h) | NSI | O S14 |
| History specialty | Histoire-géographie, géopolitique et sciences politiques | HGGSP | O S17 |
| Humanities specialty | Humanités, littérature et philosophie | HLP | O S17 |
| Languages specialty | Langues, littératures et cultures étrangères et régionales (LLCER; LLCE on older sheets); anglais monde contemporain (AMC) | LLCER, LLCE, AMC, "LLCE Anglais", "LLCER ESP" | O* S17 (LLCER listed); T for LLCE and AMC |
| Ancient specialty | Littérature, langues et cultures de l'Antiquité | LLCA, "LLCA Latin", "LLCA Grec" | O S17 |
| Engineering | Sciences de l'ingénieur | SI, SII (older) | O S14; T |
| Arts specialty | Arts (arts plastiques, cinéma-audiovisuel, histoire des arts, musique, théâtre, danse: seven disciplines) | ARTS, "ARTS PLASTIQUES", CAV, HDA, THEATRE, MUSIQUE, DANSE | O S17 |
| Biology-ecology | Biologie-écologie (lycées agricoles only) | BIO-ECO | O S17 |
| Physical education | EPS; specialty EPPCS | EPS, EPPCS | O* S11; T |
| Law option | Droit et grands enjeux du monde contemporain | DGEMC, DROIT | O* S12; T |
| Support | Accompagnement personnalisé, orientation (54 h/yr), heure de vie de classe | AP, "ACCOMPAGNEMENT PERSONNALISE", ORIENTATION, HVC, VDC | S S15, S16 |
| Study | Permanence, étude, CDI | PERM, ETUDE, CDI | T |
| Section euro | Section européenne with DNL | EURO, SELO, DNL | O* S9; T |

### 3.4 Lycée technologique (brief; S30)

| Series | Official name | Typical subject labels (all [T] unless noted) |
|---|---|---|
| STMG | Sciences et technologies du management et de la gestion | Management, Sciences de gestion et numérique (SGN), Droit-économie ("Éco-droit"), Économie, Maths, Philo, HG, LV1/LV2 |
| ST2S | Sciences et technologies de la santé et du social | STSS (sciences et techniques sanitaires et sociales), BPH (biologie et physiopathologie humaines), "Physique-chimie pour la santé" (PCS), Maths |
| STI2D | Sciences et technologies de l'industrie et du développement durable | ITEC (innovation technologique et éco-conception), 2I2D (ingénierie, innovation et développement durable), ETLV (enseignement technologique en langue vivante), Phys-Chim, Maths |
| STL | Sciences et technologies de laboratoire | SPCL (sciences physiques et chimiques en laboratoire), Biochimie-biologie-biotechnologie, Biotechnologies, ETLV |
| STD2A, STHR, TMD, STAV | Design et arts appliqués; hôtellerie-restauration; techniques de la musique et de la danse; agronomie-vivant | Series acronym; "Enseignement technologique" as generic label |

Technological cycle terminal [O* S30]: 14 h common core in 1re, 13 h in terminale; EPS 2 h each year; 2 h philosophy in terminale.

### 3.5 Lycée professionnel (brief; S29)

Official 2019 grid, modified Dec 2023 [O* S29]: seconde 900 h. Prévention-santé-environnement 30 h/yr, économie-gestion or économie-droit 30 h/yr, co-intervention français / enseignement professionnel and maths / enseignement professionnel (30 h each in 2nde in the 2019 grid; halved in the 2023 version), chef-d'œuvre from 1re (56 h in 1re, 52 h in terminale).

| Subject | Official name | Typical labels ([T]) |
|---|---|---|
| French / HG / EMC | Français, histoire-géographie et EMC | FRANC, HG-EMC, HGEMC, "Lettres-Histoire" |
| Maths and science | Mathématiques et physique-chimie | MATHS, MATHS-SC, MATH-PC, "Maths-Sciences", PC, "Sc. physiques" |
| Languages | Langue vivante A, B | ANG, LV1, LV2, ESP |
| Applied arts | Arts appliqués et cultures artistiques | AACA, "ARTS APPL" |
| EPS | EPS | EPS |
| Prevention | Prévention-santé-environnement | PSE |
| Economics | Économie-gestion, économie-droit | ECO-GEST, ECO-DROIT |
| Professional teaching | Enseignement professionnel | EP, "Ens. prof.", Atelier, TP, "Pratique prof.", Technologie |
| Co-intervention | Co-intervention | CO-INT, "Co-int Fr", "Co-int Maths" |
| Masterpiece | Chef-d'œuvre | CHEF-D'ŒUVRE |
| Support | Consolidation, accompagnement personnalisé et accompagnement au choix d'orientation | AP, Consolidation |
| Work placement | Période de formation en milieu professionnel | PFMP, Stage |

---

## 4. Timetable software conventions

### 4.1 What is documented

- Pronote and EDT (Index Éducation) build the timetable from a "Matières" table. A school can use the national nomenclature so subjects match STS-Web, Parcoursup and LSU [S22, S23]. A mismatch between STS-Web subjects and Pronote subjects raises LSU import warnings [S23]. The BCN (Base centrale de nomenclature) holds the national table (N_MATIERE and N_MATIERE_ENSEIGNEE, the latter with a short-label field LIBELLE_COURT_MATIERE_ENSEIGNE) [S24]. So labels on sheets from schools that imported STS-Web are likely BCN edition labels [T inference].
- Real Index Éducation 2013 sheets print three long labels: **"HISTOIRE & GEOGRAPH."**, **"PHYSIQUE-CHIMIE"**, **"ED.PHYSIQUE & SPORT."**. Each cell shows the subject, the teacher's surname, then the room (e.g. "CASTAGNEDE B2"), with footer "© Index Education 2013" [S18].
- A 2019-20 primary timetable uses plain labels **FRANCAIS** and **MATHS** [S27].
- UnDeuxTEMPS (Axess) has "Matières" as the first base-data table and allows up to 500 subjects [S21]. No default abbreviation list is published in the pages I could reach.

### 4.2 Typical labels ([T], not verified)

- STS-style long labels (Pronote/EDT with import): FRANCAIS, MATHEMATIQUES, HISTOIRE & GEOGRAPH., PHYSIQUE-CHIMIE, SCIENCES VIE & TERRE, TECHNOLOGIE, ARTS PLASTIQUES, ED.MUSICALE & CHANT., ED.PHYSIQUE & SPORT., ANGLAIS LV1, ESPAGNOL LV2, ALLEMAND LV2, LATIN, ENS.MORAL & CIVIQUE, ACCOMP. PERSONNALISE. Cut at about 20 characters in a cell.
- Short codes a school sets itself: FRANC, MATHS, HI-GE, HIST-GEO, PH-CH, PHYS-CHIM, SVT, TECHNO, ANG, AGL, ESP, ALL, EPS, ARTS PLAST, ED MUSICALE, EDUC MUSIC, VIE CLASSE, AP, DEVOIRS FAITS, PERM, ETUDE, CDI.
- Status words that are not subjects: "Cours annulé", "Prof. absent", "Absence prof.", "Pas de cours", "Sortie pédagogique", "Cours déplacé", "Cours modifié", and a room change.
- Group marks in a corner: "GR1", "Gpe 2", "1/2 gr", "Demi-groupe", "Gr A".

### 4.3 Semaine A / semaine B, quinzaine

- A school can label its weeks **A** and **B**. The letter appears on the student's timetable, and the subject in the same slot can differ between A and B [S19]. Some weeks carry no letter (holidays or exams) [S19].
- A finer alternation **C / D** is used for courses taught once per fortnight (en quinzaine) so students get all their hours over a month [S20; Moroccan French-system lycée, so shown there, not proven for France].
- In Pronote and EDT the course frequency can be weekly or every other week; the two halves are commonly labelled **Q1 / Q2** (quinzaine 1 / 2), and a one-in-three rhythm exists too [T]. No fetched page explained Q1/Q2. Schools print them as "Q1", "Q2", "S1"/"S2", "Sem A"/"Sem B", "A"/"B", "Quinz. 1" [T].
- Half-group alternation: classes split into two half-groups attending on alternating weeks or days (the 2020-21 health protocol) [S20].
- For a parser: one slot can hold two courses (A or Q1, B or Q2), separated by "/" or drawn as a split cell.

### 4.4 Weekdays and half-days [T]

- Collège and lycée: lundi to vendredi; **Wednesday afternoon** is usually free in collège (UNSS, clubs); some lycées and private schools run **samedi matin**. A Saturday column appears only when a course exists.
- Primary: lundi, mardi, jeudi, vendredi (4-day week), **mercredi matin** in the 4.5-day week; **samedi matin** in some overseas académies and private schools.
- Slots: collège and lycée periods are 55 or 60 min, labelled "M1 M2 ... S1 S2" or "08h00-08h55"; lunch 1 h to 1 h 30.

---

## 5. Groups

Provenance tags follow the tables above.

### French / first language
- Français (O), FRANC, FRANCAIS, FR, Lettres (T)
- Primary sub-slots: Lecture, Écriture, Dictée, Étude de la langue, Grammaire, Conjugaison, Orthographe, Vocabulaire (S25), Poésie, Littérature, Production d'écrits, Langage oral, Graphisme, Lecture offerte, "Silence, on lit", Rituels (S/T)
- Lycée pro: "Lettres-Histoire", Co-intervention français (T)
- French as second language: FLE, FLS (S32), UPE2A (O S31)
- Group-based: "FRANCAIS GR1/GR2", "Gpe besoin" (T)

### Mathematics
- Mathématiques (O), MATHS, MATH, MA, MATHEMATIQUES (S/T)
- Primary sub-slots: Calcul mental (S25), Numération, Calcul, Géométrie, "Résolution de problèmes" (S25), Mesures, Grandeurs et mesures
- Lycée: Maths expertes ("MATHS EXP", M.EXP, ME), Maths complémentaires (MC) (O names S17, T abbreviations)
- Lycée pro: MATHS-SC, MATH-PC, "Maths-Sciences" (T; mixed with physics-chemistry, so classify as mathematics or natural sciences by context)

### Foreign and ancient languages (which one)
- **Modern, unspecified**: Langue vivante (S25), LV, LVE, LV1, LV2, LV3, LVA, LVB, LVC (O/T)
- **English**: Anglais, ANG, ANGL, AGL, "ANG LV1", "ANGLAIS LV1", "ANGLAIS LV2"; LLCER Anglais, "LLCE Anglais", AMC (anglais monde contemporain) (O*/T)
- **Spanish**: Espagnol, ESP, "ESPAGNOL LV2", "ESPAGNOL LV1", "LLCER ESP" (T)
- **German**: Allemand, ALL, "ALLEMAND LV2" (T); bilangue classes are usually English + German (T)
- **Italian**: Italien, ITA (T)
- **Other modern and regional**: PORT, CHI, RUS, ARA, JAP; Breton, Occitan, Basque, Corse, Alsacien, Créole, LCR (O* S5 for the regional-language option; T)
- **Latin**: Latin, LAT, LATIN, "LCA Latin", "LLCA Latin" (O S9, S17)
- **Greek**: Grec, GREC, GRC, "LCA Grec", "LLCA Grec" (O S9, S17)
- **Ancient, unspecified**: LCA, LLCA (O S9, S17)
- **Programme labels**: Bilangue, Bil., "Section européenne", Euro, SELO, DNL (O* S9, T); ETLV (technology taught in a foreign language, STI2D/STL, T); LVA/LVB (O S12)

### Natural sciences (physics, chemistry, biology/SVT, combined science)
- **Biology/Earth**: SVT, Sciences de la vie et de la Terre, "SC.VIE & TERRE" (S33/T); Biologie-écologie, BIO-ECO (O S17); BPH (ST2S, T); Biochimie-biologie-biotechnologie (STL, T); Biotechnologies (T)
- **Physics and chemistry**: Physique-chimie, PC, PH-CH, PHYS-CH, PHYS-CHIM, PHYSIQUE-CHIMIE (S18), "Phys/Chimie" (S33), SPC, "Sc. physiques", "SC.PHYSIQUES", SPCL (STL), PCS (ST2S) (S/T)
- **Combined science**: Enseignement scientifique, "ENS SCIENTIFIQUE", ENS.SCI., EnsSci (lycée common core, O S12); ES is ambiguous with SES and the old série ES (T)
- **Lycée pro combined**: MATHS-SC, "Maths-Sciences" (T)

### Primary general studies (questionner le monde)
- Questionner le monde (S25, O* S1), QLM, QM, "Découverte du monde" (pre-2016), "Questionner le monde / langue vivante / arts plastiques" (S25), Sciences, "Sciences et technologie" (cycle 3, S25) (O*/S/T)
- In cycle 3, the content splits into Sciences et technologie and Histoire-géographie; in cycle 2 it includes EMC.

### Social sciences (history, geography, civics/EMC, economics/SES)
- **History/Geography**: Histoire-géographie, HG, HIST-GEO, HI-GE, HIST.GEO, "HISTOIRE & GEOGRAPH." (S18), HG-EMC (S32), HGEMC, Histoire, Géo, Géographie, "Histoire-géographie ou EMC" (S25); HGGSP (O S17)
- **Civics/EMC**: EMC, Enseignement moral et civique, "ENS.MORAL & CIVIQUE", Éducation civique, Instruction civique, ECJS (historical), DGEMC (O* S12)
- **Economics/Law/Management**: SES, Sciences économiques et sociales (O S17); Économie-gestion, ECO-GEST, ECO-DROIT, "Droit-économie", "Éco-droit", Management, Sciences de gestion et numérique (SGN), STSS (T)
- Philosophy goes in the religion/ethics/philosophy group.

### Arts (visual)
- Arts plastiques (S25), ARTS PLAST, ARTS PLASTIQUES, A.PLA, ARTP, AP (ambiguous: arts plastiques on some collège sheets, accompagnement personnalisé on others, S32/S33), Arts visuels, Arts, Dessin, Histoire des arts, HDA (O*/T)
- Lycée specialty: Arts (seven disciplines: arts plastiques, cinéma-audiovisuel CAV, histoire des arts, musique, théâtre, danse) (O S17); Arts appliqués (AACA, lycée pro), Design (STD2A) (T); Théâtre and Option théâtre (T)

### Music
- Éducation musicale, EM, ED.MUS, ED MUSICALE, EDUC MUSIC, ED.MUSICALE, "ED.MUSICALE & CHANT.", Musique, Chant, Chorale, "Chant choral" (O/T); CHAM (O* S5); TMD (T)
- Danse and théâtre sit with arts; CHAD/CHAT are their aménagé versions.

### Sport (EPS)
- EPS, Éducation physique et sportive (S25), "ED.PHYSIQUE & SPORT." (S18), ED.PHYS, Sport, Natation, Piscine, Gym, Motricité (O/S/T); EPPCS (T); UNSS, AS (association sportive, T)

### Religion / ethics / philosophy
- Philosophie, PHILO (lycée terminale, O S12)
- EMC is classed under social sciences. Débat and Philo in primary are [T].
- Religion: "Culture religieuse", "Instruction religieuse" (Alsace-Moselle local law has religious education as a subject), "Aumônerie", "Pastorale" (private Catholic schools). [T]; no source found this session.

### Crafts, technology
- Technologie, TECHNO, TECH (collège, S33/T); STI2D, ITEC, 2I2D, Sciences de l'ingénieur (SI, SII), "Enseignement technologique" (T; O S14 for SI); "Création et innovation technologiques" (CIT, T); "Enseignement professionnel", EP, Atelier, TP, "Pratique prof." (lycée pro, T); SEGPA workshops (T/S31)
- Arts appliqués belongs to visual arts.

### Computer science / digital (SNT, NSI)
- SNT, Sciences numériques et technologie (2nde, 1 h 30, O S14); NSI, Numérique et sciences informatiques (1re 4 h, terminale 6 h, O S14); Informatique, Numérique, Pix, Programmation, Algorithmique (T); SGN (STMG digital strand, T)
- Programming inside collège "Technologie" stays in crafts/technology.

### Study time, support, remedial (AP, devoirs faits, étude, permanence)
- AP, Accompagnement personnalisé, "ACCOMP. PERSONNALISE", "Accomp. perso" (O* S7; S S32, S33)
- APC, Activités pédagogiques complémentaires (primary; O* S28; S S25, S26); "Aide personnalisée" (old primary); Soutien, Approfondissement, "Aide aux devoirs", "Groupe de besoins" (O* S8)
- DF, DEVOIRS FAITS (O S5, S6)
- PERM, Permanence, ETUDE, Étude, Étude dirigée, ED (primary), Étude surveillée (municipal; also periscolaire), "Salle d'étude", "Vie scolaire", CDI, BCD (T)
- RASED, PPRE, Décloisonnement (S25 for décloisonnement; T)
- Consolidation (lycée pro, T); Orientation, "Parcours Avenir", "Heure d'orientation" (O S15 for the lycée orientation hour); Tutorat (T)
- DS, "Devoir surveillé", "Brevet blanc", BB (tests, O* S4/T)
- EPI (interdisciplinary project, O* S7): product choice, here or under Other.
- Club, Foyer, Atelier (T)

### Care / after-school (périscolaire, garderie, cantine)
- Périscolaire, "Accueil périscolaire", Garderie (matin, soir), "Accueil du matin", "Accueil du soir", Cantine, "Restaurant scolaire", Repas, "Pause méridienne", "Temps méridien", "Étude surveillée" (municipal evening study), "Centre de loisirs", ALSH, "Accueil de loisirs", TAP, NAP (2013-2018), PEDT (O* S28; T for abbreviations)
- Breaks: Récré, Récréation, Pause, Déjeuner, Midi (T)
- Collège: Demi-pension, DP, Self (T)

### Class council / tutor time (vie de classe)
- VDC, VIE DE CLASSE, "Vie de classe", "VIE CLASSE", HVC, "Heure de vie de classe" (S34), "Rituels et vie de classe" (S25), "Conseil d'élèves", "Conseil de classe", "Quoi de neuf" (primary), PP, "Heure de PP", Accueil (T)

### Other
- Not subjects (annotations): Cours annulé, Prof. absent, Pas de cours, Sortie, "Sortie pédagogique", Visite, Voyage (T)
- Events: Stage, PFMP, "Oral de stage", Brevet, DNB (T)
- Dispositifs: SEGPA, ULIS, UPE2A (O S31); HSA, HSE (staff overtime, S32); FCA (Français et culture de l'Antiquité, S32)
- Retenue, "Heure de colle" (detention, T)

---

## 6. Ambiguities a parser must resolve

| Token | Possible meanings | How to disambiguate |
|---|---|---|
| AP | Arts plastiques (collège/primary), accompagnement personnalisé (collège/lycée), APC (primary) | Level; hours per week (arts plastiques is 1 h, AP 1-2 h); sheet legend |
| ES | Enseignement scientifique, SES, old série ES | Lycée level; 2 h |
| EM | Éducation musicale | Collège |
| PC | Physique-chimie | Collège/lycée |
| ED / ETUDE | Étude dirigée (primary) or the prefix of ED.PHYSIQUE, ED.MUSICALE | Prefix pattern |
| LV1/LV2 | Slot type, not a language; the language is on another line or in the group column (ESP, ALL) | Take the language name when present |
| EPI | Project, not a subject | Study/support or Other |
| HG | Histoire-géographie; HG-EMC also covers EMC | Same group |
| Q1 / Q2, A / B | Week markers, not subjects | Strip from the label; store as week type |
| SPC | Sciences physiques et chimiques (old name) | Natural sciences |
| SI | Sciences de l'ingénieur | Crafts, technology |

## 7. Gaps to verify with real sheets

1. The default short codes of Pronote/EDT/UnDeuxTEMPS (whether the default is `HI-GE`, `HIST-GEO` or `HISTOIRE & GEOGRAPH.`) were not found in public docs. Only the three long labels in S18 are confirmed.
2. Q1/Q2 as the quinzaine label is general knowledge of Index Éducation software; the only fetched page on quinzaine alternation (S20) uses weeks C and D.
3. Ministry pages were blocked, so hours marked [O*] come from search-result summaries of the official texts (S1, S6, S7, S11, S12). Re-check before encoding totals.
4. Alsace-Moselle religion, Montessori and regional-language immersion schools (Diwan, Seaska, Calandreta) are not covered.

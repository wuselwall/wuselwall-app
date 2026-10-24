# Tischfrage, French deck: research notes and open points

Draft: [table-questions-fr-draft.json](table-questions-fr-draft.json) (150 questions, same ids/categories/decks/riddle positions as de.json). The app ships the 50 chosen in [README](README.md#table-questions-fr-and-es).
Research limit: web search was thin on francophone "conversation at the table" sociology and on
Switzerland/Quebec specifically. What follows separates what a source says from my own editorial judgement.

## 1. Table-talk culture (what the sources support)

- The French "repas gastronomique" is on UNESCO's intangible heritage list (2010); the official
  description names conversation as a component of the meal. https://www.france.fr/fr/article/repas-gastronomique-francais/
  (background: https://www.slate.fr/story/30397/patrimoine-immateriel-unesco-repas-gastronomique)
- Romandie: a 1985 study of about a hundred families in Geneva (Bastard and Cardia-Vonderscher) describes the
  family meal as a high point of family life; a Swiss nutrition survey says convivialite is what matters to
  Romands. Found via search results at https://www.sge-ssn.ch/media/1-2011-MM-VII-EiF-_12-12-11_f.pdf and
  https://www.erudit.org/en/journals/qf/1999-n112-qf1202079/56268ac.pdf (I only saw summaries, not the full texts).
- Parenting advice in French converges on one point: do not ask "Comment s'est passee ta journee ?"; ask specific,
  light questions (best moment, something that made you laugh), give the child time to land, and share your own
  story too. Sources: https://www.pass-education.fr/actualites/communication-avec-votre-enfant-decouvrez-cette-astuce-simple-qui-remplace-la-question-comment-etait-ta-journee/
  (examples: "Quel a ete ton moment prefere aujourd'hui ?", "Raconte-moi quelque chose qui t'a fait rire");
  https://fr.aleteia.org/2021/09/08/ces-deux-questions-a-poser-tous-les-jours-a-son-enfant/ (daily service/gratitude angle);
  Famigros (Migros, Swiss) advice page https://famigros.migros.ch/fr/enfants-et-adolescents/ecole-et-formations/rentree-scolaire/faire-s-exprimer-un-enfant
  (redirects now; I only saw it through the search summary).
  Consequence for the deck: the "today" questions are concrete (a sound, a colour, something odd, what your hands did)
  rather than "how was your day", and none asks about school results.
- Not found: any Quebec-specific source on family-table rituals. I could not confirm the Quebec situation beyond vocabulary.

## 2. Register and regional vocabulary

- The existing FR strings (`app/l10n/app_fr.arb`) address the user with **tu** ("Demande une invitation a ta famille",
  "Appuie sur ton image"), and the family as a group with **votre** ("les donnees de votre famille"). Wusel is "il"
  in the arb ("quand il te parle"), so I avoided pronouns for Wusel anyway; the deck does not mention Wusel.
  Meal windows in the arb are "Dejeuner" (midi) and "Diner" (soir), the France/standard usage.
- Deck choice: **tu** for the person being asked (the card is read to one person at a time, and a five-year-old is
  tutoye in all francophone regions; tutoiement within the family is the norm in France per
  https://halshs.archives-ouvertes.fr/file/index/docid/354003/filename/HavuTanska.pdf, and Quebec uses tu even more freely
  per https://www.slate.fr/societe/vouvoiement-tutoiement-comment-choisir-tu-vous-pronom-usage-politesse-communication-langue-francaise).
  The family as a group is **nous / chez nous / notre**, not "vous". Imperatives in the tu form.
  Open: the arb sometimes uses "vous" for the family as an audience; the deck never addresses the whole table as "vous".
- Meal words: **dejeuner/diner/souper/petit-dejeuner are avoided completely** in the deck. In Belgium, Switzerland and Quebec
  "dejeuner" is breakfast, "diner" is lunch and "souper" is dinner; in France the shift is by one meal. Sources:
  https://fr.wiktionary.org/wiki/petit_d%C3%A9jeuner, Larousse (dejeuner, regional senses),
  https://www.letribunaldunet.fr/le-saviez-vous/pourquoi-dejeuner-diner-midi-france-regions.html,
  https://www.erudit.org/en/journals/qf/1999-n112-qf1202079/56268ac.pdf. The deck says "le matin", "a midi", "ce repas", "un repas".
  Consequence for the app (not the deck): the arb's "Dejeuner/Diner" labels read oddly in BE/CH/QC. Worth a separate look.
- Numbers: **septante/huitante/nonante vs soixante-dix/quatre-vingt-dix** avoided; the deck uses "cent ans", "vingt ans", "trente-six".
  Sources: https://fr.wiktionary.org/wiki/huitante, https://elon.io/grammar/french/regional/numbers-belgian-swiss.
- Other regionalisms avoided: "gouter / quatre-heures / collation" (snack), "doudou / toutou / nounours" (comforter),
  "chandail / pull", "maternelle / crèche / garderie / CP" (school stages differ), "fin de semaine / week-end",
  "boite a lunch / gamelle", "rotie / tartine" (I kept "tartine", see doubts), "devoirs", "cartable".
- Gender agreement: written French makes "fier/fiere", "content/contente", "etonne(e)" show the child's gender, and the
  past participle after a preceding "t'" agrees ("qui t'a aide(e)"). I wrote questions so no agreement shows:
  "t'a fait rire", "t'a fait ouvrir de grands yeux", "qui t'a donne un coup de main", nouns instead of adjectives
  (plaisir, souvenir). Please check that none slipped through.
- Typography: apostrophes are typographic (U+2019) as in the arb; "?" and "!" are preceded by a plain space, which matches
  the arb. Real French typography uses a no-break space; on the 34pt kiosk card a lone "?" could wrap to its own line.
  Decide whether the card should convert the space to U+00A0 at render time rather than in the data.

## 3. Cultural fit (editorial, not sourced)

- Gratitude: American "what are you grateful for ?" reads stiff, therapeutic or religious in French (and "reconnaissant" is
  formal). The thanks cards use plain **merci** and **plaisir** ("quelle petite chose t'a fait plaisir ?"). 9 of 150 (6 %).
- No grace/blessing, no religious references, no Noel/Easter/saints (laicite; also mixed households).
- No school-results pressure: no notes, classement, devoirs, "as-tu ete sage ?". School appears only as a place children
  played or learned something. The two "learned today" questions are about people, not grades.
- No food policing: no "finis ton assiette", no healthy/unhealthy, no body comments; food appears only as fun or memory.
  "Qu'y avait-il dans ton assiette a midi ?" is the one question near food reporting; it asks for description, not judgement.
- Family forms: no "papa/maman" built into the text; "chez nous", "la maison", "en famille".
- No brands, screens, points, comparisons. "Qu'as-tu appris de quelqu'un ici, a cette table ?" (older) names no person.
- Humour: French children love wordplay and absurd images (the silly set uses tartine, crepe, patate, herisson), not
  slapstick body humour.

## 4. Conversation-card games, to avoid copying (not reproduced, not consulted for content)

- The Blah Blah Box (Hellofun), 5+ http://www.ludum.fr/jeux-d-ambiance-en-famille/the-blah-blah-box-9136
- Social : Familles (Esprit Jeu), 6+ https://www.espritjeu.com/social-familles.html
- Repas de famille (Matagot), storytelling card game, 10+ https://www.play-in.com/fr/produit/626058/repas-de-famille
- Quelle famille ! (66 questions), Le grand defi parents vs enfants, boite de jeu Parents vs Enfants (Marabout)
- Table Topics (English-language original; I did not find a French listing, so I did not verify an FR edition).
- "Les questions du dîner": no product found with that title.
I did not open any of their question lists. Questions are original wording; a few themes (best moment, funny thing,
an animal for the family) are generic family-conversation ideas that appear in many sources.

## 5. Riddles: provenance

Traditional French folk riddles (devinettes) are public domain. Collections: Eugene Rolland, *Devinettes ou enigmes
populaires de la France* (1877, Internet Archive ids `devinettesoueni00parigoog`, `devinettesoueni01parigoog`);
Rolland, *Les Enfantines du bon pays de France* (1878) https://fr.wikisource.org/wiki/Les_Enfantines_du_bon_pays_de_France/Devinettes_ou_%C3%A9nigmes_populaires ;
Paul Sebillot, *Litterature orale de la Haute-Bretagne* (1881), "Devinettes" https://fr.wikisource.org/wiki/Litt%C3%A9rature_orale_de_la_Haute-Bretagne/Deuxi%C3%A8me_partie/II/I

Verified in those texts (wording shortened or modernised by me, the idea and image are theirs):

| Riddle | Source |
|---|---|
| Petite robe blanche, sans couture ni manche = un oeuf | Rolland, Enfantines 1878, verbatim first two lines |
| trente-six habits sans couture = l'oignon | Rolland, Enfantines 1878 |
| Madame Grand-Manteau couvre tout, sauf l'eau = la neige | Rolland, Enfantines 1878 ("excepte" modernised to "sauf") |
| plein la nuit, vide le jour = un lit | Sebillot 1881 (dialect, modernised) |
| gros comme deux boeufs, ne pese pas deux oeufs = la fumee | Sebillot 1881 (dialect, modernised; I wrote "plus leger que") |
| cent pieces sans couture = les nuages | Sebillot 1881 (I added "dans le ciel" to make it solvable) |
| cinq petits dans un bois mort = les doigts de pied dans le sabot | Sebillot/Rolland (I replaced "sabot" with "chaussure", answer "les orteils") |
| tantot claire, tantot obscure = la lune | Rolland, Enfantines 1878 (rewritten in plain words, nothing kept but the idea) |
| autour du bois, ne peut rentrer dedans = l'ecorce | Sebillot 1881 (rewritten with "arbre") |
| Quel etre a quatre pattes le matin, deux a midi, trois le soir = l'homme | Sphinx riddle, Greek myth; ancient, public domain; the wording is the usual French phrasing (also quoted at https://fr.wikipedia.org/wiki/Devinette) |

Widely circulated oral/folk riddles that I know as common stock but did **not** find in the sources I could open
(treat as "folk, unverified provenance"): un peigne a des dents mais ne mord pas; le champignon (chapeau, pied, pas de tete);
le livre (des feuilles sans etre un arbre); l'eau de ruisseau qui court sans jambes; le trou (plus on en enleve, plus il est grand;
Sebillot has a related "plus i' en a, moins ca pese: des trous"); le silence (on le brise en le nommant); ton prenom;
l'avenir; ton age (monte sans redescendre). The last four I cannot trace to any particular collection; they are
international "classic" riddles and none matches a French commercial product that I know of. A native reviewer or Rolland's
index could confirm.

Riddles also exist in the DE and EN decks in similar form (peigne, livre, trou, champignon) because they are international;
the French wording is independent.

## 6. Questions I am least sure about (for the native reviewer)

1. q-0022 "Que dirait une tartine ..." : "tartine" is fine in FR/BE/CH; Quebec says "rotie" for toast and may read it as bread and butter.
2. q-0021 "Si les bonbons construisaient une ville" : check the natural verb (bâtir/construire) and that "bonbons" (sweets) reads the same in BE/CH/QC.
3. q-0041 "tout doux, comme un câlin" : sweet or too precious for a 5-year-old?
4. q-0063 "Il neige du sucre glace" : "sucre glace" (FR) vs "sucre à glacer" (QC); maybe "de la barbe à papa".
5. Several imagine questions use the present tense for the scenario ("Tu deviens minuscule comme une fourmi pendant une heure. Où vas-tu ?", q-0048) instead of "Imagine que ...". Natural in speech, but inconsistent with the "Imagine que" ones (q-0046 ...). Pick one voice.
6. q-0104 "Cinq petits frères habitent dans la même chaussure" : a 5-year-old must think of toes; answer "Les orteils" (FR also "doigts de pied").
7. q-0105 "Un jour toute ronde, un autre jour en croissant" : possibly too abstract.
8. q-0100 "Madame Grand-Manteau couvre tout, sauf l'eau" : old-fashioned but charming (Rolland); keep?
9. q-0109 "Qu'est-ce qui court sans jamais avoir de jambes ?" answer "L'eau d'un ruisseau" : children may say "le temps" or "le nez" (the app shows one answer).
10. q-0113 "pour quoi" is written as two words (for what); check it reads right, or use "pourquoi".
11. q-0150 "même s'il ou elle ne le sait pas" : heavy gender-neutral phrasing; alternative "sans que cette personne le sache".
12. q-0145 (Sphinx) : the answer text is long for the tap-to-reveal card.
13. q-0112 "Qu'est-ce qui monte chaque année ... ?" answer "Ton âge" : is it fine for adults at the table?
14. q-0124 and q-0133 mention "film" : only as a metaphor, but the brief says no screens. Replace with "livre" if strict.
15. q-0097 "Qu'est-ce qu'on fait chez nous et qu'on ne fait sans doute nulle part ailleurs ?" : naturalness.
16. q-0043 "Qu'y avait-il dans ton assiette à midi ?" : the only question near food reporting; asks for description, not judgement.
17. q-0141 (older) "Qu'as-tu appris de quelqu'un ici, à cette table ?" : fine, but check it cannot read as ranking.
18. q-0080 "que tu aies trouvée", q-0081 "dont tu te souviennes" (subjunctive after a superlative) : verify grammar.
19. Typography of " ?" and apostrophes (see section 2).
20. A full agreement and grammar read of all 150 lines, written without a native check. Also the Quebec ear: "chouette", "rigoler", "rigolo", "patate", "frigo" are all understood but marked as France-colloquial in places.

## 7. Distribution check

Counts match de.json exactly (silly 25+3, imagine 22+7, today 20+6, memories 15+4, us 15+5, riddle 15+4, thanks 7+2);
ids q-0001..q-0150; categories in the same order; the answer field only on riddles. Validated with python3.

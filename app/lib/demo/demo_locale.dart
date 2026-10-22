/// The demo's French and Spanish prose: the tables `demo_english.dart` keeps for
/// English live here, so the demo speaks the app's language without a German fallback.
/// German needs no table: the demo's source strings are German.
library;

/// [code] is `de`, `en`, `fr` or `es`; unknown codes see the German source text.
const Map<String, Map<String, String>> demoTexts = {
  'fr': {
    // Schools and classes
    'Gemeinschaftsschule am Park': 'École du parc',
    'Grundschule Lindenhof': 'École primaire du Linde',
    'SAPh E': 'CE2',
    'Schuljahr 2026/27': 'Année scolaire 2026/27',
    'Klasse 5a': 'Classe de 5e a',
    // Subjects
    'Mathematik': 'Maths',
    'Deutsch': 'Allemand',
    'Förderunterricht': 'Soutien scolaire',
    'Sport': 'EPS',
    'Schwimmen': 'Natation',
    'Naturwissenschaften': 'Sciences',
    'Musik': 'Musique',
    'Gesellschaftswissenschaften': 'Histoire-géographie',
    'Bildende Kunst': 'Arts plastiques',
    'Kunst': 'Arts plastiques',
    'Religion / Lebenskunde': 'Religion / morale',
    'Englisch / Französisch': 'Anglais / espagnol',
    'Französisch / Englisch': 'Espagnol / anglais',
    'Sachunterricht': 'Découverte du monde',
    'Lernzeit': 'Étude',
    'FreiDay — Projektlernen': 'Projet',
    'FreiDay': 'Projet',
    // Rooms, equipment, lesson changes, care
    'Turnhalle': 'Gymnase',
    'Kunstraum': "Salle d'arts",
    'NaWi-Raum': 'Laboratoire',
    'Schwimmbad': 'Piscine',
    'Sportsachen': 'Affaires de sport',
    'Schwimmzeug': 'Maillot',
    'Frau Klein': 'Mme Klein',
    'fällt aus': 'annulé',
    'Hort': 'Garde',
    // Presence
    'Dienst': 'Bureau',
    'Büro Hamburg': 'Bureau à Hambourg',
    'Dienstreise Berlin': 'Déplacement à Lyon',
    'Oma': 'Mamie',
    'zu Hause': 'À la maison',
    'Büro': 'Bureau',
    'Homeoffice': 'Télétravail',
    // Appointments
    'Müll rausstellen': 'Sortir les poubelles',
    'Heizung wird gewartet': 'Entretien de la chaudière',
    'Turnen': 'Gymnastique',
    'TSV-Halle': 'Salle du TSV',
    'Zahnarzt': 'Dentiste',
    'Dr. Behrens': 'Dr Behrens',
    'Elternabend': 'Soirée parents',
    'Fotografin in der Schule': 'Photos à l’école',
    'Klavier': 'Piano',
    'Musikschule': 'Conservatoire',
    'Kinoabend': 'Soirée cinéma',
    'Fußballturnier': 'Tournoi de foot',
    'Sportplatz Ost': 'Terrain est',
    'Grillen bei Webers': 'Barbecue chez les Weber',
    'Oma & Opa kommen': 'Mamie et papi viennent',
    // Meals
    'Kürbissuppe': 'Soupe de potiron',
    'Nudelauflauf': 'Gratin de pâtes',
    'Chili sin Carne': 'Chili sin carne',
    'Fischstäbchen': 'Bâtonnets de poisson',
    'Nudeln mit Pesto': 'Pâtes au pesto',
    'Rinderbraten': 'Rôti de bœuf',
    'Gulaschsuppe': 'Soupe goulash',
    'Linseneintopf': 'Soupe de lentilles',
    'Pizza selbst gemacht': 'Pizza maison',
    'Hühnercurry': 'Curry de poulet',
    // Recipes
    'Fleisch würzen und scharf anbraten.\n'
            'Gemüse dazugeben und kurz mitrösten.\n'
            'Mit Brühe und Rotwein ablöschen und zwei Stunden schmoren.\n'
            'Soße abschmecken und mit dem Fleisch servieren.':
        'Assaisonner la viande et la saisir à feu vif.\n'
        'Ajouter les légumes et les faire revenir brièvement.\n'
        'Mouiller au bouillon et au vin rouge et laisser mijoter deux heures.\n'
        'Goûter la sauce et servir avec la viande.',
    'Nudeln in Salzwasser kochen.\n'
            'Pesto mit etwas Nudelwasser verrühren.\n'
            'Alles mischen und mit Parmesan servieren.':
        'Cuire les pâtes dans de l’eau salée.\n'
        'Mélanger le pesto avec un peu d’eau de cuisson.\n'
        'Mélanger le tout et servir avec du parmesan.',
    'Sonntag': 'Dimanche',
    'Ofen': 'Four',
    'schnell': 'rapide',
    'Rindfleisch': 'Bœuf',
    'Zwiebeln': 'Oignons',
    'Karotten': 'Carottes',
    'Rotwein': 'Vin rouge',
    'Rinderbrühe': 'Bouillon de bœuf',
    'Tomatenmark': 'Purée de tomates',
    'Salz': 'Sel',
    'nach Geschmack': 'selon le goût',
    'Nudeln': 'Pâtes',
    'Basilikumpesto': 'Pesto basilic',
    'Pinienkerne': 'Pignons',
    'Stück': 'pièces',
    'EL': 'c. à soupe',
    'optional': 'facultatif',
    // Chores and rewards
    'Tisch decken': 'Mettre la table',
    'Spülmaschine ausräumen': 'Vider le lave-vaisselle',
    'Spülmaschine': 'Lave-vaisselle',
    'Zimmer aufräumen': 'Ranger sa chambre',
    'Müll rausbringen': 'Sortir les poubelles',
    'Beim Kochen helfen': 'Aider à cuisiner',
    'Hilfe beim Einkaufen': 'Aide pour les courses',
    'Nachtrag vom Wochenende': 'Ajouté le week-end',
    'Samstagsfilm aussuchen': 'Choisir le film du samedi',
    '15 Minuten länger aufbleiben': 'Rester 15 minutes de plus',
    // Free day
    'Beweglicher Ferientag': 'Jour férié mobile',
  },
  'es': {
    // Schools and classes
    'Gemeinschaftsschule am Park': 'Colegio del parque',
    'Grundschule Lindenhof': 'Primaria del tilo',
    'SAPh E': '2.º primaria',
    'Schuljahr 2026/27': 'Curso 2026/27',
    'Klasse 5a': 'Clase 5a',
    // Subjects
    'Mathematik': 'Mates',
    'Deutsch': 'Alemán',
    'Förderunterricht': 'Refuerzo escolar',
    'Sport': 'Educación física',
    'Schwimmen': 'Natación',
    'Naturwissenschaften': 'Ciencias',
    'Musik': 'Música',
    'Gesellschaftswissenschaften': 'Geografía e historia',
    'Bildende Kunst': 'Plástica',
    'Kunst': 'Plástica',
    'Religion / Lebenskunde': 'Religión / ética',
    'Englisch / Französisch': 'Inglés / español',
    'Französisch / Englisch': 'Español / inglés',
    'Sachunterricht': 'Conocimiento del medio',
    'Lernzeit': 'Estudio',
    'FreiDay — Projektlernen': 'Proyecto',
    'FreiDay': 'Proyecto',
    // Rooms, equipment, lesson changes, care
    'Turnhalle': 'Gimnasio',
    'Kunstraum': 'Aula de plástica',
    'NaWi-Raum': 'Laboratorio',
    'Schwimmbad': 'Piscina',
    'Sportsachen': 'Cosas de deporte',
    'Schwimmzeug': 'Bañador',
    'Frau Klein': 'Sra. Klein',
    'fällt aus': 'cancelado',
    'Hort': 'Guardería',
    // Presence
    'Dienst': 'Oficina',
    'Büro Hamburg': 'Oficina de Hamburgo',
    'Dienstreise Berlin': 'Viaje a Madrid',
    'Oma': 'Abuela',
    'zu Hause': 'En casa',
    'Büro': 'Oficina',
    'Homeoffice': 'Teletrabajo',
    // Appointments
    'Müll rausstellen': 'Sacar la basura',
    'Heizung wird gewartet': 'Revisión de la calefacción',
    'Turnen': 'Gimnasia',
    'TSV-Halle': 'Pabellón del TSV',
    'Zahnarzt': 'Dentista',
    'Dr. Behrens': 'Dra. Behrens',
    'Elternabend': 'Reunión de padres',
    'Fotografin in der Schule': 'Fotos en el colegio',
    'Klavier': 'Piano',
    'Musikschule': 'Conservatorio',
    'Kinoabend': 'Noche de cine',
    'Fußballturnier': 'Torneo de fútbol',
    'Sportplatz Ost': 'Campo este',
    'Grillen bei Webers': 'Barbacoa en casa de los Weber',
    'Oma & Opa kommen': 'Vienen los abuelos',
    // Meals
    'Kürbissuppe': 'Sopa de calabaza',
    'Nudelauflauf': 'Lasaña de pasta',
    'Chili sin Carne': 'Chili sin carne',
    'Fischstäbchen': 'Palitos de pescado',
    'Nudeln mit Pesto': 'Pasta al pesto',
    'Rinderbraten': 'Asado de ternera',
    'Gulaschsuppe': 'Sopa de gulash',
    'Linseneintopf': 'Sopa de lentejas',
    'Pizza selbst gemacht': 'Pizza casera',
    'Hühnercurry': 'Curry de pollo',
    // Recipes
    'Fleisch würzen und scharf anbraten.\n'
            'Gemüse dazugeben und kurz mitrösten.\n'
            'Mit Brühe und Rotwein ablöschen und zwei Stunden schmoren.\n'
            'Soße abschmecken und mit dem Fleisch servieren.':
        'Sazonar la carne y dorarla a fuego fuerte.\n'
        'Añadir las verduras y rehogarlas brevemente.\n'
        'Desgla­sar con caldo y vino tinto y guisar dos horas.\n'
        'Probar la salsa y servir con la carne.',
    'Nudeln in Salzwasser kochen.\n'
            'Pesto mit etwas Nudelwasser verrühren.\n'
            'Alles mischen und mit Parmesan servieren.':
        'Cocer la pasta en agua salada.\n'
        'Mezclar el pesto con un poco de agua de cocción.\n'
        'Mezclar todo y servir con parmesano.',
    'Sonntag': 'Domingo',
    'Ofen': 'Horno',
    'schnell': 'rápido',
    'Rindfleisch': 'Ternera',
    'Zwiebeln': 'Cebollas',
    'Karotten': 'Zanahorias',
    'Rotwein': 'Vino tinto',
    'Rinderbrühe': 'Caldo de ternera',
    'Tomatenmark': 'Puré de tomate',
    'Salz': 'Sal',
    'nach Geschmack': 'al gusto',
    'Nudeln': 'Pasta',
    'Basilikumpesto': 'Pesto de albahaca',
    'Pinienkerne': 'Piñones',
    'Stück': 'uds.',
    'EL': 'cda.',
    'optional': 'opcional',
    // Chores and rewards
    'Tisch decken': 'Poner la mesa',
    'Spülmaschine ausräumen': 'Vaciar el lavavajillas',
    'Spülmaschine': 'Lavavajillas',
    'Zimmer aufräumen': 'Ordenar su habitación',
    'Müll rausbringen': 'Sacar la basura',
    'Beim Kochen helfen': 'Ayudar a cocinar',
    'Hilfe beim Einkaufen': 'Ayuda con la compra',
    'Nachtrag vom Wochenende': 'Añadido del fin de semana',
    'Samstagsfilm aussuchen': 'Elegir la película del sábado',
    '15 Minuten länger aufbleiben': 'Quedarse 15 minutos más',
    // Free day
    'Beweglicher Ferientag': 'Día festivo móvil',
  },
};

/// [code]'s subject short codes, as the timetable shows them.
const Map<String, Map<String, String>> demoShorts = {
  'fr': {
    'Ma': 'Ma',
    'D': 'Al',
    'Fö': 'Sout',
    'Sp': 'EPS',
    'Sw': 'Nat',
    'NaWi': 'SVT',
    'Mu': 'Mus',
    'GeWi': 'Hist-Géo',
    'BK': 'Arts',
    'Ku': 'Arts',
    'Rel/LK': 'Religion',
    'E/F': 'Ang/Es',
    'F/E': 'Es/An',
    'SU': 'Déc',
    'Lernzeit': 'Étude',
    'FreiDay': 'Proj',
  },
  'es': {
    'Ma': 'Mat',
    'D': 'Ale',
    'Fö': 'Apo',
    'Sp': 'EF',
    'Sw': 'Nat',
    'NaWi': 'CN',
    'Mu': 'Mús',
    'GeWi': 'Geo',
    'BK': 'Plás',
    'Ku': 'Plás',
    'Rel/LK': 'Rel',
    'E/F': 'In/Es',
    'F/E': 'Es/In',
    'SU': 'Con',
    'Lernzeit': 'Est',
    'FreiDay': 'Proy',
  },
};

/// The prose table for [code]; the German source strings for any other code.
Map<String, String> demoFor(String code) => demoTexts[code] ?? const {};

/// The subject short codes for [code]; the German codes for any other code.
Map<String, String> demoShortsFor(String code) => demoShorts[code] ?? const {};

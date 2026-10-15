import 'package:wuselwall/demo/demo_data.dart';

/// [de] as the demo shows it: unchanged in German, its English from the table below in
/// English. The demo's tables (the board, the timetables, meals and chores) stay in
/// German and keyed as they are; the text is translated where it is handed out.
String demoText(String de) => DemoData.english ? _texts[de] ?? de : de;

/// [demoText] for an optional value.
String? demoTextOrNull(String? de) => de == null ? null : demoText(de);

/// A subject's short code as the timetable shows it ("D" is "En" in English). Apart
/// from [demoText], because a code and a name can be the same word ("Lernzeit").
String demoShort(String code) =>
    DemoData.english ? _shorts[code] ?? code : code;

const _shorts = {
  'D': 'En',
  'Fö': 'Sup',
  'Sp': 'PE',
  'NaWi': 'Sci',
  'GeWi': 'Hum',
  'BK': 'Art',
  'Ku': 'Art',
  'Rel/LK': 'RE',
  'E/F': 'Fr/Es',
  'F/E': 'Es/Fr',
  'SU': 'Top',
  'Lernzeit': 'Study',
  'FreiDay': 'Proj',
};

const _texts = {
  // Schools and classes
  'Gemeinschaftsschule am Park': 'Parkside School',
  'Grundschule Lindenhof': 'Hollybrook Primary',
  'SAPh E': 'Year 2',
  'Schuljahr 2026/27': 'School year 2026/27',
  'Klasse 5a': 'Class 5a',
  // Subjects
  'Mathematik': 'Maths',
  'Deutsch': 'English',
  'Förderunterricht': 'Learning support',
  'Sport': 'PE',
  'Schwimmen': 'Swimming',
  'Naturwissenschaften': 'Science',
  'Musik': 'Music',
  'Gesellschaftswissenschaften': 'Humanities',
  'Bildende Kunst': 'Art',
  'Kunst': 'Art',
  'Religion / Lebenskunde': 'RE / Ethics',
  'Englisch / Französisch': 'French / Spanish',
  'Französisch / Englisch': 'Spanish / French',
  'Sachunterricht': 'Topic',
  'Lernzeit': 'Study time',
  'FreiDay — Projektlernen': 'Project day',
  'FreiDay': 'Project day',
  // Rooms, equipment, lesson changes, care
  'Turnhalle': 'Gym',
  'Kunstraum': 'Art room',
  'NaWi-Raum': 'Science lab',
  'Schwimmbad': 'Pool',
  'Sportsachen': 'PE kit',
  'Schwimmzeug': 'Swimming kit',
  'Frau Klein': 'Ms Clarke',
  'fällt aus': 'cancelled',
  // The care label as an English family would type it: short enough for a day column.
  'Hort': 'Club',
  // Presence
  'Dienst': 'Work shift',
  'Büro Hamburg': 'London office',
  'Dienstreise Berlin': 'Business trip to Leeds',
  'Oma': 'Grandma',
  'zu Hause': 'At home',
  'Homeoffice': 'Working from home',
  // Appointments
  'Müll rausstellen': 'Put the bins out',
  'Heizung wird gewartet': 'Boiler service',
  'Turnen': 'Gymnastics',
  'TSV-Halle': 'Sports hall',
  'Zahnarzt': 'Dentist',
  'Dr. Behrens': 'Dr Patel',
  'Elternabend': 'Parents’ evening',
  'Fotografin in der Schule': 'School photos',
  'Klavier': 'Piano',
  'Musikschule': 'Music school',
  'Kinoabend': 'Movie night',
  'Fußballturnier': 'Football tournament',
  'Sportplatz Ost': 'East playing field',
  'Grillen bei Webers': 'Barbecue at the Websters’',
  'Oma & Opa kommen': 'Grandma & Grandpa visit',
  // Meals
  'Kürbissuppe': 'Pumpkin soup',
  'Nudelauflauf': 'Pasta bake',
  'Chili sin Carne': 'Chilli sin carne',
  'Fischstäbchen': 'Fish fingers',
  'Nudeln mit Pesto': 'Pasta with pesto',
  'Rinderbraten': 'Roast beef',
  'Gulaschsuppe': 'Goulash soup',
  'Linseneintopf': 'Lentil stew',
  'Pizza selbst gemacht': 'Homemade pizza',
  'Hühnercurry': 'Chicken curry',
  // Recipes
  'Fleisch würzen und scharf anbraten.\n'
          'Gemüse dazugeben und kurz mitrösten.\n'
          'Mit Brühe und Rotwein ablöschen und zwei Stunden schmoren.\n'
          'Soße abschmecken und mit dem Fleisch servieren.':
      'Season the meat and sear it on a high heat.\n'
      'Add the vegetables and brown them briefly.\n'
      'Pour in the stock and red wine and braise for two hours.\n'
      'Season the gravy and serve it with the meat.',
  'Nudeln in Salzwasser kochen.\n'
          'Pesto mit etwas Nudelwasser verrühren.\n'
          'Alles mischen und mit Parmesan servieren.':
      'Cook the pasta in salted water.\n'
      'Stir the pesto with a little of the pasta water.\n'
      'Mix everything and serve with parmesan.',
  'Sonntag': 'Sunday',
  'Ofen': 'Oven',
  'schnell': 'quick',
  'Rindfleisch': 'Beef',
  'Zwiebeln': 'Onions',
  'Karotten': 'Carrots',
  'Rotwein': 'Red wine',
  'Rinderbrühe': 'Beef stock',
  'Tomatenmark': 'Tomato purée',
  'Salz': 'Salt',
  'nach Geschmack': 'to taste',
  'Nudeln': 'Pasta',
  'Basilikumpesto': 'Basil pesto',
  'Pinienkerne': 'Pine nuts',
  'Stück': 'pcs',
  'EL': 'tbsp',
  // Chores and rewards
  'Tisch decken': 'Set the table',
  'Spülmaschine ausräumen': 'Empty the dishwasher',
  'Spülmaschine': 'Dishwasher',
  'Zimmer aufräumen': 'Tidy your room',
  'Müll rausbringen': 'Take out the rubbish',
  'Beim Kochen helfen': 'Help with cooking',
  'Hilfe beim Einkaufen': 'Helped with the shopping',
  'Nachtrag vom Wochenende': 'Added from the weekend',
  'Samstagsfilm aussuchen': 'Pick the Saturday film',
  '15 Minuten länger aufbleiben': 'Stay up 15 minutes later',
};

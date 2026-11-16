// The bundled catalogue of holiday places for discovery (specs/30 "Discovery").
//
// The project's own compilation of well-known holiday places from general knowledge, with no
// licensed database behind it. It is weighted towards Europe and the Mediterranean as seen from
// Switzerland, Germany and Austria; islands and regions are units (Mallorca, Tessin), not
// resorts. Each place has a key, its name in the four languages of the app (the usual exonym
// where one exists), the ISO 3166-1 alpha-2 country, the coordinates of the usual centre (main
// town or airport) to two decimals, and tags. The apps pick one of these places as the home
// place, so a key is a stable name: never change one, add new places at the end of a group.
//
// destinations_test.ts checks the shape and, per country, that the coordinates lie inside a
// hand-written bounding box (a wrong sign on a longitude is the classic mistake).

export type Tag =
  | "sea"
  | "island"
  | "mountains"
  | "lake"
  | "city"
  | "countryside"
  | "north"
  | "long_haul";

export const TAGS: readonly Tag[] = [
  "sea",
  "island",
  "mountains",
  "lake",
  "city",
  "countryside",
  "north",
  "long_haul",
];

export type Lang = "de" | "en" | "fr" | "es";

export const LANGS: readonly Lang[] = ["de", "en", "fr", "es"];

export type Destination = {
  key: string;
  names: Record<Lang, string>;
  /** ISO 3166-1 alpha-2, upper case. */
  country: string;
  lat: number;
  lon: number;
  tags: Tag[];
};

function place(
  key: string,
  names: [de: string, en: string, fr: string, es: string],
  country: string,
  lat: number,
  lon: number,
  tags: Tag[],
): Destination {
  const [de, en, fr, es] = names;
  return { key, names: { de, en, fr, es }, country, lat, lon, tags };
}

// deno-fmt-ignore
export const DESTINATIONS: readonly Destination[] = [
  // ------------------------------------------------------------ Spain
  place("mallorca", ["Mallorca", "Mallorca", "Majorque", "Mallorca"], "ES", 39.70, 3.00, ["sea", "island"]),
  place("menorca", ["Menorca", "Menorca", "Minorque", "Menorca"], "ES", 40.00, 4.10, ["sea", "island"]),
  place("ibiza", ["Ibiza", "Ibiza", "Ibiza", "Ibiza"], "ES", 38.91, 1.43, ["sea", "island"]),
  place("costa_brava", ["Costa Brava", "Costa Brava", "Costa Brava", "Costa Brava"], "ES", 41.80, 3.05, ["sea"]),
  place("costa_del_sol", ["Costa del Sol", "Costa del Sol", "Costa del Sol", "Costa del Sol"], "ES", 36.55, -4.60, ["sea"]),
  place("costa_blanca", ["Costa Blanca", "Costa Blanca", "Costa Blanca", "Costa Blanca"], "ES", 38.54, -0.13, ["sea"]),
  place("andalusia", ["Andalusien", "Andalusia", "Andalousie", "Andalucía"], "ES", 37.40, -4.80, ["countryside"]),
  place("basque_country", ["Baskenland", "Basque Country", "Pays basque", "País Vasco"], "ES", 43.32, -1.98, ["sea", "countryside"]),
  place("galicia", ["Galicien", "Galicia", "Galice", "Galicia"], "ES", 42.88, -8.54, ["sea", "countryside"]),
  place("pyrenees", ["Pyrenäen", "Pyrenees", "Pyrénées", "Pirineos"], "ES", 42.70, 0.80, ["mountains"]),
  place("barcelona", ["Barcelona", "Barcelona", "Barcelone", "Barcelona"], "ES", 41.39, 2.17, ["city", "sea"]),
  place("madrid", ["Madrid", "Madrid", "Madrid", "Madrid"], "ES", 40.42, -3.70, ["city"]),
  place("valencia", ["Valencia", "Valencia", "Valence", "Valencia"], "ES", 39.47, -0.38, ["city", "sea"]),
  place("seville", ["Sevilla", "Seville", "Séville", "Sevilla"], "ES", 37.39, -5.98, ["city"]),
  place("tenerife", ["Teneriffa", "Tenerife", "Ténérife", "Tenerife"], "ES", 28.27, -16.60, ["sea", "island"]),
  place("gran_canaria", ["Gran Canaria", "Gran Canaria", "Grande Canarie", "Gran Canaria"], "ES", 27.96, -15.58, ["sea", "island"]),
  place("fuerteventura", ["Fuerteventura", "Fuerteventura", "Fuerteventura", "Fuerteventura"], "ES", 28.35, -14.00, ["sea", "island"]),
  place("lanzarote", ["Lanzarote", "Lanzarote", "Lanzarote", "Lanzarote"], "ES", 29.00, -13.60, ["sea", "island"]),
  place("la_palma", ["La Palma", "La Palma", "La Palma", "La Palma"], "ES", 28.68, -17.87, ["sea", "island"]),
  place("la_gomera", ["La Gomera", "La Gomera", "La Gomera", "La Gomera"], "ES", 28.10, -17.14, ["sea", "island"]),
  place("el_hierro", ["El Hierro", "El Hierro", "El Hierro", "El Hierro"], "ES", 27.75, -18.00, ["sea", "island"]),

  // ------------------------------------------------------------ Portugal
  place("algarve", ["Algarve", "Algarve", "Algarve", "Algarve"], "PT", 37.10, -8.20, ["sea"]),
  place("lisbon", ["Lissabon", "Lisbon", "Lisbonne", "Lisboa"], "PT", 38.72, -9.14, ["city", "sea"]),
  place("porto", ["Porto", "Porto", "Porto", "Oporto"], "PT", 41.15, -8.61, ["city"]),
  place("madeira", ["Madeira", "Madeira", "Madère", "Madeira"], "PT", 32.65, -16.95, ["sea", "island"]),
  place("azores", ["Azoren", "Azores", "Açores", "Azores"], "PT", 37.78, -25.50, ["island", "sea"]),

  // ------------------------------------------------------------ France
  place("paris", ["Paris", "Paris", "Paris", "París"], "FR", 48.86, 2.35, ["city"]),
  place("cote_d_azur", ["Côte d'Azur", "French Riviera", "Côte d'Azur", "Costa Azul"], "FR", 43.70, 7.25, ["sea"]),
  place("provence", ["Provence", "Provence", "Provence", "Provenza"], "FR", 43.80, 5.50, ["countryside"]),
  place("languedoc", ["Languedoc", "Languedoc", "Languedoc", "Languedoc"], "FR", 43.35, 3.20, ["sea", "countryside"]),
  place("brittany", ["Bretagne", "Brittany", "Bretagne", "Bretaña"], "FR", 48.20, -3.00, ["sea", "countryside"]),
  place("normandy", ["Normandie", "Normandy", "Normandie", "Normandía"], "FR", 49.18, -0.37, ["sea", "countryside"]),
  place("french_atlantic", ["Atlantikküste Frankreich", "French Atlantic coast", "Côte atlantique", "Costa atlántica francesa"], "FR", 44.65, -1.17, ["sea"]),
  place("corsica", ["Korsika", "Corsica", "Corse", "Córcega"], "FR", 42.15, 9.10, ["sea", "island"]),
  place("chamonix", ["Chamonix", "Chamonix", "Chamonix", "Chamonix"], "FR", 45.92, 6.87, ["mountains"]),
  place("alsace", ["Elsass", "Alsace", "Alsace", "Alsacia"], "FR", 48.08, 7.36, ["countryside"]),
  place("loire_valley", ["Loiretal", "Loire Valley", "Val de Loire", "Valle del Loira"], "FR", 47.39, 0.69, ["countryside"]),
  place("dordogne", ["Dordogne", "Dordogne", "Dordogne", "Dordoña"], "FR", 44.90, 0.90, ["countryside"]),

  // ------------------------------------------------------------ Italy
  place("sardinia", ["Sardinien", "Sardinia", "Sardaigne", "Cerdeña"], "IT", 40.10, 9.00, ["sea", "island"]),
  place("sicily", ["Sizilien", "Sicily", "Sicile", "Sicilia"], "IT", 37.60, 14.00, ["sea", "island"]),
  place("elba", ["Elba", "Elba", "Île d'Elbe", "Elba"], "IT", 42.78, 10.19, ["sea", "island"]),
  place("amalfi_coast", ["Amalfiküste", "Amalfi Coast", "Côte amalfitaine", "Costa Amalfitana"], "IT", 40.63, 14.60, ["sea"]),
  place("cinque_terre", ["Cinque Terre", "Cinque Terre", "Cinque Terre", "Cinque Terre"], "IT", 44.12, 9.72, ["sea"]),
  place("tuscany", ["Toskana", "Tuscany", "Toscane", "Toscana"], "IT", 43.45, 11.25, ["countryside"]),
  place("umbria", ["Umbrien", "Umbria", "Ombrie", "Umbría"], "IT", 43.00, 12.60, ["countryside"]),
  place("apulia", ["Apulien", "Apulia", "Pouilles", "Apulia"], "IT", 40.80, 17.20, ["sea", "countryside"]),
  place("calabria", ["Kalabrien", "Calabria", "Calabre", "Calabria"], "IT", 38.90, 16.50, ["sea"]),
  place("adriatic_riviera", ["Italienische Adria", "Adriatic Riviera", "Riviera adriatique", "Riviera adriática"], "IT", 44.06, 12.57, ["sea"]),
  place("lake_garda", ["Gardasee", "Lake Garda", "Lac de Garde", "Lago de Garda"], "IT", 45.65, 10.70, ["lake"]),
  place("lake_como", ["Comer See", "Lake Como", "Lac de Côme", "Lago de Como"], "IT", 46.00, 9.26, ["lake", "mountains"]),
  place("lake_maggiore", ["Lago Maggiore", "Lake Maggiore", "Lac Majeur", "Lago Mayor"], "IT", 45.95, 8.65, ["lake", "mountains"]),
  place("dolomites", ["Dolomiten", "Dolomites", "Dolomites", "Dolomitas"], "IT", 46.40, 11.85, ["mountains"]),
  place("south_tyrol", ["Südtirol", "South Tyrol", "Tyrol du Sud", "Tirol del Sur"], "IT", 46.65, 11.35, ["mountains"]),
  place("rome", ["Rom", "Rome", "Rome", "Roma"], "IT", 41.90, 12.50, ["city"]),
  place("milan", ["Mailand", "Milan", "Milan", "Milán"], "IT", 45.46, 9.19, ["city"]),
  place("venice", ["Venedig", "Venice", "Venise", "Venecia"], "IT", 45.44, 12.33, ["city", "sea"]),
  place("florence", ["Florenz", "Florence", "Florence", "Florencia"], "IT", 43.77, 11.26, ["city"]),
  place("naples", ["Neapel", "Naples", "Naples", "Nápoles"], "IT", 40.85, 14.27, ["city", "sea"]),

  // ------------------------------------------------------------ Switzerland
  place("ticino", ["Tessin", "Ticino", "Tessin", "Tesino"], "CH", 46.20, 8.95, ["lake", "mountains"]),
  place("engadin", ["Engadin", "Engadine", "Engadine", "Engadina"], "CH", 46.60, 9.80, ["mountains", "lake"]),
  place("zermatt", ["Zermatt", "Zermatt", "Zermatt", "Zermatt"], "CH", 46.02, 7.75, ["mountains"]),
  place("bernese_oberland", ["Berner Oberland", "Bernese Oberland", "Oberland bernois", "Oberland bernés"], "CH", 46.65, 7.85, ["mountains", "lake"]),
  place("davos", ["Davos", "Davos", "Davos", "Davos"], "CH", 46.80, 9.84, ["mountains"]),
  place("lake_geneva", ["Genfersee", "Lake Geneva", "Lac Léman", "Lago Lemán"], "CH", 46.45, 6.55, ["lake"]),
  place("lucerne", ["Luzern", "Lucerne", "Lucerne", "Lucerna"], "CH", 47.05, 8.31, ["city", "lake"]),

  // ------------------------------------------------------------ Germany
  place("sylt", ["Sylt", "Sylt", "Sylt", "Sylt"], "DE", 54.91, 8.32, ["sea", "island", "north"]),
  place("east_frisian_islands", ["Ostfriesische Inseln", "East Frisian Islands", "Îles de la Frise orientale", "Islas Frisias Orientales"], "DE", 53.71, 7.15, ["sea", "island", "north"]),
  place("north_sea_coast", ["Nordseeküste", "German North Sea coast", "Côte allemande de la mer du Nord", "Costa alemana del Mar del Norte"], "DE", 53.87, 8.70, ["sea", "north"]),
  place("baltic_sea_coast", ["Ostsee", "German Baltic coast", "Côte allemande de la Baltique", "Costa alemana del Báltico"], "DE", 54.15, 10.95, ["sea", "north"]),
  place("ruegen", ["Rügen", "Rügen", "Rügen", "Rügen"], "DE", 54.43, 13.40, ["sea", "island", "north"]),
  place("usedom", ["Usedom", "Usedom", "Usedom", "Usedom"], "DE", 53.95, 14.10, ["sea", "island", "north"]),
  place("black_forest", ["Schwarzwald", "Black Forest", "Forêt-Noire", "Selva Negra"], "DE", 48.00, 8.20, ["countryside", "mountains"]),
  place("allgaeu", ["Allgäu", "Allgäu", "Allgäu", "Algovia"], "DE", 47.60, 10.30, ["mountains"]),
  place("lake_constance", ["Bodensee", "Lake Constance", "Lac de Constance", "Lago de Constanza"], "DE", 47.60, 9.35, ["lake"]),
  place("harz", ["Harz", "Harz", "Harz", "Harz"], "DE", 51.80, 10.60, ["mountains", "countryside"]),
  place("mecklenburg_lakes", ["Mecklenburgische Seenplatte", "Mecklenburg Lake District", "Région des lacs du Mecklembourg", "Lagos de Mecklemburgo"], "DE", 53.40, 12.70, ["lake", "countryside", "north"]),
  place("berlin", ["Berlin", "Berlin", "Berlin", "Berlín"], "DE", 52.52, 13.40, ["city"]),
  place("hamburg", ["Hamburg", "Hamburg", "Hambourg", "Hamburgo"], "DE", 53.55, 9.99, ["city", "north"]),
  place("munich", ["München", "Munich", "Munich", "Múnich"], "DE", 48.14, 11.58, ["city"]),

  // ------------------------------------------------------------ Austria
  place("tyrol", ["Tirol", "Tyrol", "Tyrol", "Tirol"], "AT", 47.25, 11.40, ["mountains"]),
  place("arlberg", ["Arlberg", "Arlberg", "Arlberg", "Arlberg"], "AT", 47.13, 10.27, ["mountains"]),
  place("salzkammergut", ["Salzkammergut", "Salzkammergut", "Salzkammergut", "Salzkammergut"], "AT", 47.65, 13.50, ["lake", "mountains"]),
  place("woerthersee", ["Wörthersee", "Lake Wörthersee", "Wörthersee", "Wörthersee"], "AT", 46.63, 14.15, ["lake"]),
  place("vienna", ["Wien", "Vienna", "Vienne", "Viena"], "AT", 48.21, 16.37, ["city"]),
  place("salzburg", ["Salzburg", "Salzburg", "Salzbourg", "Salzburgo"], "AT", 47.80, 13.04, ["city", "mountains"]),

  // ------------------------------------------------------------ Greece, Cyprus, Malta
  place("crete", ["Kreta", "Crete", "Crète", "Creta"], "GR", 35.24, 24.81, ["sea", "island"]),
  place("rhodes", ["Rhodos", "Rhodes", "Rhodes", "Rodas"], "GR", 36.17, 28.00, ["sea", "island"]),
  place("corfu", ["Korfu", "Corfu", "Corfou", "Corfú"], "GR", 39.62, 19.92, ["sea", "island"]),
  place("kos", ["Kos", "Kos", "Cos", "Cos"], "GR", 36.89, 27.29, ["sea", "island"]),
  place("zakynthos", ["Zakynthos", "Zakynthos", "Zante", "Zante"], "GR", 37.78, 20.90, ["sea", "island"]),
  place("santorini", ["Santorin", "Santorini", "Santorin", "Santorini"], "GR", 36.39, 25.46, ["sea", "island"]),
  place("mykonos", ["Mykonos", "Mykonos", "Mykonos", "Míconos"], "GR", 37.45, 25.33, ["sea", "island"]),
  place("halkidiki", ["Chalkidiki", "Halkidiki", "Chalcidique", "Calcídica"], "GR", 40.25, 23.50, ["sea"]),
  place("peloponnese", ["Peloponnes", "Peloponnese", "Péloponnèse", "Peloponeso"], "GR", 37.50, 22.30, ["sea", "countryside"]),
  place("athens", ["Athen", "Athens", "Athènes", "Atenas"], "GR", 37.98, 23.73, ["city"]),
  place("cyprus", ["Zypern", "Cyprus", "Chypre", "Chipre"], "CY", 35.00, 33.20, ["sea", "island"]),
  place("malta", ["Malta", "Malta", "Malte", "Malta"], "MT", 35.90, 14.45, ["sea", "island"]),

  // ------------------------------------------------------------ Adriatic and Balkans
  place("dalmatia", ["Dalmatien", "Dalmatia", "Dalmatie", "Dalmacia"], "HR", 43.50, 16.44, ["sea"]),
  place("istria", ["Istrien", "Istria", "Istrie", "Istria"], "HR", 45.00, 13.90, ["sea"]),
  place("dubrovnik", ["Dubrovnik", "Dubrovnik", "Dubrovnik", "Dubrovnik"], "HR", 42.65, 18.09, ["city", "sea"]),
  place("plitvice", ["Plitvicer Seen", "Plitvice Lakes", "Lacs de Plitvice", "Lagos de Plitvice"], "HR", 44.88, 15.62, ["lake", "mountains"]),
  place("bled", ["Bleder See", "Lake Bled", "Lac de Bled", "Lago Bled"], "SI", 46.37, 14.11, ["lake", "mountains"]),
  place("ljubljana", ["Ljubljana", "Ljubljana", "Ljubljana", "Liubliana"], "SI", 46.06, 14.51, ["city"]),
  place("kotor_bay", ["Bucht von Kotor", "Bay of Kotor", "Bouches de Kotor", "Bahía de Kotor"], "ME", 42.42, 18.77, ["sea", "mountains"]),
  place("albanian_riviera", ["Albanische Riviera", "Albanian Riviera", "Riviera albanaise", "Riviera albanesa"], "AL", 40.10, 19.75, ["sea"]),
  place("bulgarian_black_sea", ["Bulgarische Schwarzmeerküste", "Bulgarian Black Sea coast", "Côte bulgare de la mer Noire", "Costa búlgara del Mar Negro"], "BG", 42.70, 27.70, ["sea"]),

  // ------------------------------------------------------------ Turkey, Egypt, North Africa, Gulf
  place("turkish_riviera", ["Türkische Riviera", "Turkish Riviera", "Riviera turque", "Riviera Turca"], "TR", 36.89, 30.70, ["sea"]),
  place("bodrum", ["Bodrum", "Bodrum", "Bodrum", "Bodrum"], "TR", 37.04, 27.43, ["sea"]),
  place("istanbul", ["Istanbul", "Istanbul", "Istanbul", "Estambul"], "TR", 41.01, 28.98, ["city"]),
  place("cappadocia", ["Kappadokien", "Cappadocia", "Cappadoce", "Capadocia"], "TR", 38.64, 34.83, ["countryside"]),
  place("hurghada", ["Hurghada (Rotes Meer)", "Hurghada (Red Sea)", "Hurghada (mer Rouge)", "Hurghada (Mar Rojo)"], "EG", 27.26, 33.81, ["sea"]),
  place("sharm_el_sheikh", ["Sharm el-Scheich", "Sharm El Sheikh", "Charm el-Cheikh", "Sharm el-Sheij"], "EG", 27.92, 34.33, ["sea"]),
  place("marrakech", ["Marrakesch", "Marrakech", "Marrakech", "Marrakech"], "MA", 31.63, -8.01, ["city"]),
  place("agadir", ["Agadir", "Agadir", "Agadir", "Agadir"], "MA", 30.43, -9.60, ["sea"]),
  place("djerba", ["Djerba", "Djerba", "Djerba", "Yerba"], "TN", 33.81, 10.85, ["sea", "island"]),
  place("hammamet", ["Hammamet", "Hammamet", "Hammamet", "Hammamet"], "TN", 36.40, 10.61, ["sea"]),
  place("cape_verde", ["Kap Verde", "Cape Verde", "Cap-Vert", "Cabo Verde"], "CV", 16.60, -22.93, ["sea", "island"]),
  place("dubai", ["Dubai", "Dubai", "Dubaï", "Dubái"], "AE", 25.20, 55.27, ["city", "sea"]),
  place("oman", ["Oman", "Oman", "Oman", "Omán"], "OM", 23.59, 58.41, ["sea", "countryside"]),

  // ------------------------------------------------------------ British Isles
  place("london", ["London", "London", "Londres", "Londres"], "GB", 51.51, -0.13, ["city"]),
  place("edinburgh", ["Edinburgh", "Edinburgh", "Édimbourg", "Edimburgo"], "GB", 55.95, -3.19, ["city", "north"]),
  place("scottish_highlands", ["Schottische Highlands", "Scottish Highlands", "Highlands écossais", "Tierras Altas de Escocia"], "GB", 57.40, -4.60, ["mountains", "countryside", "north"]),
  place("cornwall", ["Cornwall", "Cornwall", "Cornouailles", "Cornualles"], "GB", 50.27, -5.05, ["sea", "countryside"]),
  place("dublin", ["Dublin", "Dublin", "Dublin", "Dublín"], "IE", 53.35, -6.26, ["city"]),
  place("kerry", ["Südwestirland (Kerry)", "Southwest Ireland (Kerry)", "Sud-ouest de l'Irlande (Kerry)", "Suroeste de Irlanda (Kerry)"], "IE", 52.00, -9.70, ["sea", "countryside", "north"]),

  // ------------------------------------------------------------ Benelux
  place("amsterdam", ["Amsterdam", "Amsterdam", "Amsterdam", "Ámsterdam"], "NL", 52.37, 4.90, ["city"]),
  place("bruges", ["Brügge", "Bruges", "Bruges", "Brujas"], "BE", 51.21, 3.22, ["city"]),

  // ------------------------------------------------------------ The North
  place("copenhagen", ["Kopenhagen", "Copenhagen", "Copenhague", "Copenhague"], "DK", 55.68, 12.57, ["city", "north"]),
  place("jutland", ["Jütland (Nordsee)", "Jutland (North Sea)", "Jutland (mer du Nord)", "Jutlandia (Mar del Norte)"], "DK", 55.70, 8.40, ["sea", "north"]),
  place("bornholm", ["Bornholm", "Bornholm", "Bornholm", "Bornholm"], "DK", 55.12, 14.90, ["sea", "island", "north"]),
  place("stockholm", ["Stockholm", "Stockholm", "Stockholm", "Estocolmo"], "SE", 59.33, 18.07, ["city", "north"]),
  place("dalarna", ["Dalarna", "Dalarna", "Dalécarlie", "Dalarna"], "SE", 60.80, 14.80, ["lake", "countryside", "north"]),
  place("smaland", ["Småland", "Småland", "Småland", "Småland"], "SE", 57.20, 15.00, ["lake", "countryside", "north"]),
  place("gotland", ["Gotland", "Gotland", "Gotland", "Gotland"], "SE", 57.50, 18.50, ["sea", "island", "north"]),
  place("oslo", ["Oslo", "Oslo", "Oslo", "Oslo"], "NO", 59.91, 10.75, ["city", "north"]),
  place("norwegian_fjords", ["Norwegische Fjorde", "Norwegian fjords", "Fjords norvégiens", "Fiordos noruegos"], "NO", 61.20, 6.60, ["mountains", "sea", "north"]),
  place("lofoten", ["Lofoten", "Lofoten", "Lofoten", "Lofoten"], "NO", 68.20, 14.60, ["island", "sea", "mountains", "north"]),
  place("tromso", ["Tromsø", "Tromsø", "Tromsø", "Tromsø"], "NO", 69.65, 18.96, ["city", "north"]),
  place("helsinki", ["Helsinki", "Helsinki", "Helsinki", "Helsinki"], "FI", 60.17, 24.94, ["city", "north"]),
  place("finnish_lakes", ["Finnische Seenplatte", "Finnish Lakeland", "Région des lacs finlandais", "Región de los lagos de Finlandia"], "FI", 61.90, 28.80, ["lake", "countryside", "north"]),
  place("lapland", ["Lappland", "Lapland", "Laponie", "Laponia"], "FI", 66.50, 25.73, ["north", "countryside"]),
  place("iceland", ["Island", "Iceland", "Islande", "Islandia"], "IS", 64.15, -21.94, ["north", "countryside"]),
  place("faroe_islands", ["Färöer", "Faroe Islands", "Îles Féroé", "Islas Feroe"], "FO", 62.01, -6.77, ["north", "island"]),
  place("tallinn", ["Tallinn", "Tallinn", "Tallinn", "Tallin"], "EE", 59.44, 24.75, ["city", "north"]),
  place("riga", ["Riga", "Riga", "Riga", "Riga"], "LV", 56.95, 24.11, ["city", "north"]),

  // ------------------------------------------------------------ Central and Eastern Europe
  place("prague", ["Prag", "Prague", "Prague", "Praga"], "CZ", 50.08, 14.44, ["city"]),
  place("budapest", ["Budapest", "Budapest", "Budapest", "Budapest"], "HU", 47.50, 19.04, ["city"]),
  place("balaton", ["Plattensee", "Lake Balaton", "Lac Balaton", "Lago Balatón"], "HU", 46.85, 17.75, ["lake"]),
  place("krakow", ["Krakau", "Kraków", "Cracovie", "Cracovia"], "PL", 50.06, 19.94, ["city"]),
  place("gdansk", ["Danzig", "Gdańsk", "Gdańsk", "Gdansk"], "PL", 54.35, 18.65, ["city", "sea", "north"]),
  place("high_tatras", ["Hohe Tatra", "High Tatras", "Hautes Tatras", "Altos Tatras"], "SK", 49.15, 20.10, ["mountains"]),

  // ------------------------------------------------------------ Long haul
  place("phuket", ["Phuket", "Phuket", "Phuket", "Phuket"], "TH", 7.88, 98.39, ["sea", "island", "long_haul"]),
  place("koh_samui", ["Koh Samui", "Koh Samui", "Koh Samui", "Koh Samui"], "TH", 9.51, 100.01, ["sea", "island", "long_haul"]),
  place("bangkok", ["Bangkok", "Bangkok", "Bangkok", "Bangkok"], "TH", 13.76, 100.50, ["city", "long_haul"]),
  place("bali", ["Bali", "Bali", "Bali", "Bali"], "ID", -8.41, 115.19, ["sea", "island", "long_haul"]),
  place("maldives", ["Malediven", "Maldives", "Maldives", "Maldivas"], "MV", 3.20, 73.22, ["sea", "island", "long_haul"]),
  place("mauritius", ["Mauritius", "Mauritius", "Maurice", "Mauricio"], "MU", -20.30, 57.55, ["sea", "island", "long_haul"]),
  place("seychelles", ["Seychellen", "Seychelles", "Seychelles", "Seychelles"], "SC", -4.62, 55.45, ["sea", "island", "long_haul"]),
  place("zanzibar", ["Sansibar", "Zanzibar", "Zanzibar", "Zanzíbar"], "TZ", -6.16, 39.20, ["sea", "island", "long_haul"]),
  place("miami", ["Miami (Florida)", "Miami (Florida)", "Miami (Floride)", "Miami (Florida)"], "US", 25.78, -80.20, ["sea", "city", "long_haul"]),
  place("orlando", ["Orlando (Florida)", "Orlando (Florida)", "Orlando (Floride)", "Orlando (Florida)"], "US", 28.54, -81.38, ["city", "long_haul"]),
  place("los_angeles", ["Los Angeles (Kalifornien)", "Los Angeles (California)", "Los Angeles (Californie)", "Los Ángeles (California)"], "US", 34.05, -118.24, ["sea", "city", "long_haul"]),
  place("new_york", ["New York", "New York", "New York", "Nueva York"], "US", 40.71, -74.01, ["city", "long_haul"]),
  place("hawaii", ["Hawaii", "Hawaii", "Hawaï", "Hawái"], "US", 21.31, -157.86, ["sea", "island", "long_haul"]),
  place("canada_west", ["Westkanada (Rocky Mountains)", "Western Canada (Rocky Mountains)", "Ouest canadien (Rocheuses)", "Oeste de Canadá (Montañas Rocosas)"], "CA", 51.18, -115.57, ["mountains", "lake", "long_haul"]),
  place("vancouver", ["Vancouver", "Vancouver", "Vancouver", "Vancouver"], "CA", 49.28, -123.12, ["city", "sea", "long_haul"]),
  place("costa_rica", ["Costa Rica", "Costa Rica", "Costa Rica", "Costa Rica"], "CR", 9.93, -84.08, ["countryside", "sea", "long_haul"]),
  place("yucatan", ["Yucatán (Mexiko)", "Yucatán (Mexico)", "Yucatán (Mexique)", "Yucatán (México)"], "MX", 20.63, -87.07, ["sea", "long_haul"]),
  place("cuba", ["Kuba", "Cuba", "Cuba", "Cuba"], "CU", 23.15, -81.25, ["sea", "island", "long_haul"]),
  place("dominican_republic", ["Dominikanische Republik", "Dominican Republic", "République dominicaine", "República Dominicana"], "DO", 18.58, -68.40, ["sea", "long_haul"]),
  place("rio", ["Rio de Janeiro", "Rio de Janeiro", "Rio de Janeiro", "Río de Janeiro"], "BR", -22.91, -43.17, ["city", "sea", "long_haul"]),
  place("cape_town", ["Kapstadt", "Cape Town", "Le Cap", "Ciudad del Cabo"], "ZA", -33.92, 18.42, ["city", "sea", "long_haul"]),
  place("namibia", ["Namibia", "Namibia", "Namibie", "Namibia"], "NA", -22.56, 17.08, ["countryside", "long_haul"]),
  place("tokyo", ["Tokio", "Tokyo", "Tokyo", "Tokio"], "JP", 35.68, 139.69, ["city", "long_haul"]),
  place("kyoto", ["Kyoto", "Kyoto", "Kyoto", "Kioto"], "JP", 35.01, 135.77, ["city", "long_haul"]),
  place("sri_lanka", ["Sri Lanka", "Sri Lanka", "Sri Lanka", "Sri Lanka"], "LK", 6.03, 80.22, ["sea", "island", "long_haul"]),
  place("vietnam", ["Vietnam", "Vietnam", "Viêt Nam", "Vietnam"], "VN", 16.05, 108.20, ["sea", "long_haul"]),
  place("goa", ["Goa", "Goa", "Goa", "Goa"], "IN", 15.30, 74.00, ["sea", "long_haul"]),
  place("singapore", ["Singapur", "Singapore", "Singapour", "Singapur"], "SG", 1.35, 103.82, ["city", "long_haul"]),
  place("sydney", ["Sydney", "Sydney", "Sydney", "Sídney"], "AU", -33.87, 151.21, ["city", "sea", "long_haul"]),
  place("cairns", ["Cairns (Great Barrier Reef)", "Cairns (Great Barrier Reef)", "Cairns (Grande Barrière de corail)", "Cairns (Gran Barrera de Coral)"], "AU", -16.92, 145.77, ["sea", "long_haul"]),
  place("auckland", ["Auckland (Neuseeland)", "Auckland (New Zealand)", "Auckland (Nouvelle-Zélande)", "Auckland (Nueva Zelanda)"], "NZ", -36.85, 174.76, ["city", "sea", "long_haul"]),
  place("queenstown", ["Queenstown (Neuseeland)", "Queenstown (New Zealand)", "Queenstown (Nouvelle-Zélande)", "Queenstown (Nueva Zelanda)"], "NZ", -45.03, 168.66, ["mountains", "lake", "long_haul"]),
];

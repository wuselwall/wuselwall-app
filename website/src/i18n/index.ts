export type Lang = 'de' | 'en';

export const paths = {
  de: { home: '/', imprint: '/impressum/', privacy: '/datenschutz/' },
  en: { home: '/en/', imprint: '/en/imprint/', privacy: '/en/privacy/' },
} as const;

type Feature = { title: string; text: string };
type View = Feature & { shot: 'shopping-phone' | 'kid-shopping' | 'wall-child-week'; alt: string };

/**
 * Privacy policy paragraphs may hold inline HTML (links, emphasis) and these tokens,
 * filled in by Privacy.astro from config/site.ts: {operator} (name and address),
 * {email} (a mailto link), {logDays}, {github}, {docs}, {imprint}.
 */
type Section = { title: string; body: string[] };

export interface Strings {
  htmlLang: string;
  title: string;
  description: string;
  skip: string;
  nav: { label: string; features: string; selfHost: string; status: string; github: string };
  hero: {
    kicker: string;
    title: string;
    lead: string;
    primary: string;
    github: string;
    stores: string;
    storesSoon: string;
    shotAlt: string;
    phoneAlt: string;
  };
  badges: { iosAlt: string; androidAlt: string };
  featuresTitle: string;
  features: Feature[];
  viewsTitle: string;
  viewsLead: string;
  views: View[];
  selfHostTitle: string;
  selfHostLead: string;
  selfHostSteps: Feature[];
  selfHostNote: string;
  principlesTitle: string;
  principles: Feature[];
  statusTitle: string;
  statusLead: string;
  status: { label: string; state: string; done: boolean }[];
  faqTitle: string;
  faq: { q: string; a: string }[];
  openTitle: string;
  openText: string;
  openCta: string;
  docsCta: string;
  footer: { label: string; imprint: string; privacy: string; docs: string; source: string; license: string; langSwitch: string; note: string };
  legal: {
    imprintTitle: string;
    imprintDescription: string;
    operator: string;
    contact: string;
    email: string;
    phone: string;
    liability: string;
    liabilityText: string;
    trademarksTitle: string;
    trademarks: string[];
    placeholderWarning: string;
    privacyTitle: string;
    privacyDescription: string;
  };
  privacy: { updated: string; summaryTitle: string; summary: string[]; sections: Section[] };
}

const de: Strings = {
  htmlLang: 'de-CH',
  title: 'WuselWall – der Familienorganisator für zuhause',
  description:
    'WuselWall ist der Familienorganisator mit Wochentafel für die Küchenwand: gemeinsamer Kalender, Stundenpläne, Aufgaben, Essensplan und Einkaufsliste. Open Source, auf eurem eigenen Server.',
  skip: 'Zum Inhalt',
  nav: { label: 'Hauptnavigation', features: 'Funktionen', selfHost: 'Eigener Server', status: 'Stand', github: 'GitHub' },
  hero: {
    kicker: 'Open Source · Auf eurem eigenen Server · Für die ganze Familie',
    title: 'Alles, was bei euch zuhause wuselt – an einer Wand.',
    lead: 'Gemeinsamer Kalender, Stundenpläne, Aufgaben, Essensplan und Einkaufsliste. Auf dem Handy für die Eltern, als Wochentafel in der Küche, in kindgerechter Ansicht für die Kleinen.',
    primary: 'So funktioniert’s',
    github: 'Quellcode auf GitHub',
    stores: 'WuselWall herunterladen',
    storesSoon: 'Bald im App Store und bei Google Play.',
    shotAlt: 'Die Wochentafel auf einem Tablet: wer wo ist, die Termine der Woche und was es zu essen gibt, für jede Person in ihrer Farbe.',
    phoneAlt: 'Die Einkaufsliste auf dem Handy.',
  },
  badges: {
    iosAlt: 'Laden im App Store',
    androidAlt: 'Jetzt bei Google Play',
  },
  featuresTitle: 'Was WuselWall kann',
  features: [
    { title: 'Wochentafel für die Küche', text: 'Sieben Tage auf einen Blick, für ein Tablet an der Wand. Jede Person hat ihre Farbe, auch für Farbenblinde unterscheidbar.' },
    { title: 'Gemeinsamer Kalender', text: 'Termine für alle, mit Wiederholungen und Anwesenheit (Schicht, Reise). Per ICS-Feed lässt er sich in Outlook oder Apple Kalender abonnieren.' },
    { title: 'Stundenpläne', text: 'Der Stundenplan jedes Kindes als Muster, mit Ferien und Ausfällen. Morgens sieht man sofort, was eingepackt werden muss.' },
    { title: 'Aufgaben mit Punkten', text: 'Ämtli verteilen, Punkte sammeln, Belohnungen einlösen. Ohne Druck, mit Serien und Abzeichen für die Kinder.' },
    { title: 'Essensplan und Einkaufsliste', text: 'Was gibt es diese Woche? Die Zutaten landen auf der Einkaufsliste, die auch ohne Netz im Laden funktioniert.' },
    { title: 'Ein Gerät pro Person oder pro Raum', text: 'Eigene Geräte für die Erwachsenen, ein gemeinsames für die Küche, eines für die Kinder. Jedes Gerät lässt sich einzeln sperren.' },
  ],
  viewsTitle: 'Drei Ansichten, eine Familie',
  viewsLead: 'Dieselben Daten, für jeden so, wie es passt.',
  views: [
    { title: 'Für die Eltern', text: 'Schnell etwas auf die Einkaufsliste, Termine eintragen, Ämtli verteilen – auf dem Handy, auch ohne Netz.', shot: 'shopping-phone', alt: 'Die Einkaufsliste auf dem Handy, nach Abteilungen sortiert.' },
    { title: 'Für die Kinder', text: 'Große Knöpfe, klare Farben, das eigene Gesicht zum Antippen. Kinder brauchen kein Konto und keine E-Mail-Adresse.', shot: 'kid-shopping', alt: 'Die Kinderansicht der Einkaufsliste mit großen Kacheln und den Gesichtern der Familie.' },
    { title: 'Für die Wand', text: 'Ein Tablet in der Küche zeigt die ganze Woche. Ein Tipp auf ein Kind öffnet seinen Stundenplan, mit Vertretungen und Ausfällen.', shot: 'wall-child-week', alt: 'Der Stundenplan eines Kindes auf dem Wandtablet, mit einer Vertretung und einer ausfallenden Stunde.' },
  ],
  selfHostTitle: 'Auf eurem eigenen Server',
  selfHostLead: 'WuselWall ist kein Online-Dienst. Die App verbindet sich mit einem Server, den eure Familie selbst betreibt – wir sehen eure Daten nie.',
  selfHostSteps: [
    { title: 'Server einrichten', text: 'WuselWall läuft mit Docker auf einem NAS, einem Mini-PC oder einem gemieteten Server. Ein Skript richtet alles ein und zeigt am Ende einen QR-Code.' },
    { title: 'App verbinden', text: 'App installieren, QR-Code scannen, fertig. Die App hat keinen eingebauten Server und spricht nur mit eurem.' },
    { title: 'Familie einladen', text: 'Den Partner per Link einladen, das Küchen-Tablet mit einem Code verbinden. Wer eingeladen wird, muss keine Serveradresse kennen.' },
  ],
  selfHostNote: 'Noch in Arbeit: WuselWall steht noch nicht öffentlich in den App-Stores. Bis dahin führt die Anleitung Schritt für Schritt zum eigenen Server, bei Supabase oder zu Hause, und zur Web-App.',
  principlesTitle: 'Warum WuselWall anders ist',
  principles: [
    { title: 'Eure Daten bleiben bei euch', text: 'Termine, Stundenpläne und die Namen eurer Kinder liegen auf eurem Server, nicht bei uns. Keine Werbung, kein Tracking, kein Konto bei uns.' },
    { title: 'Ohne Druck', text: 'Punkte, Serien und Abzeichen statt Strafen. Keine Rangliste unter Geschwistern, kein Wettbewerb, wer das meiste Ämtli erledigt.' },
    { title: 'Zweisprachig und anpassbar', text: 'Deutsch und Englisch, von Anfang an. Alles, was eine Familie anders macht als die nächste, ist eine Einstellung.' },
  ],
  statusTitle: 'Wo wir stehen',
  statusLead: 'WuselWall entsteht Schritt für Schritt. Das ist der aktuelle Stand:',
  status: [
    { label: 'Geräte verbinden und Familie einrichten', state: 'fertig', done: true },
    { label: 'Einkaufsliste mit Offline-Modus', state: 'fertig', done: true },
    { label: 'Heute-Ansicht mit ersten Schritten', state: 'fertig', done: true },
    { label: 'Essensvorschläge aus eurem Verlauf', state: 'fertig', done: true },
    { label: 'Datenexport für die Familie', state: 'fertig', done: true },
    { label: 'Feiertage und Schulferien für Deutschland, Österreich, die Schweiz und Liechtenstein – bis zur Gemeinde', state: 'fertig', done: true },
    { label: 'Mehrere Schulen pro Familie', state: 'fertig', done: true },
    { label: 'Kalender abonnieren: Verein, Abfuhr, Schule', state: 'fertig', done: true },
    { label: 'Kalender und Wochentafel', state: 'als Nächstes', done: false },
    { label: 'Aufgaben und Punkte', state: 'als Nächstes', done: false },
    { label: 'Stundenplan und Essensplan', state: 'als Nächstes', done: false },
    { label: 'Eigener Server für jede Familie: Installation, App verbinden, ohne Server ausprobieren', state: 'als Nächstes', done: false },
  ],
  faqTitle: 'Häufige Fragen',
  faq: [
    { q: 'Was kostet WuselWall?', a: 'Nichts. Die App und die Server-Software sind Open Source unter der Apache-Lizenz 2.0. Ihr braucht nur einen Rechner, auf dem euer WuselWall-Server läuft.' },
    { q: 'Warum gibt es keinen WuselWall-Dienst zum Anmelden?', a: 'Weil die Daten eurer Familie nicht zu uns gehören. Wir entwickeln die App und die Server-Software, betreiben aber keinen Dienst für andere Familien. So kann bei uns auch nichts verloren gehen oder abfließen.' },
    { q: 'Was brauchen wir für einen eigenen Server?', a: 'Einen Rechner, der dauernd läuft und Docker kann, mit 8 GB Arbeitsspeicher: ein NAS (etwa Synology oder QNAP), einen Mini-PC oder einen gemieteten Server. Ohne eigenen Rechner geht es auch mit einem eigenen Projekt bei Supabase. Die <a href="/docs/server/">Anleitung</a> führt Schritt für Schritt durch beides. Ein Installationsskript, das alles auf einmal erledigt, folgt.' },
    { q: 'Können wir WuselWall ohne Server ausprobieren?', a: 'Bald: Die App bekommt eine Beispielfamilie, die ganz ohne Server auf dem Gerät läuft. Bis dahin zeigt die <a href="/docs/">Anleitung</a> jeden Bildschirm.' },
    { q: 'Werden wir getrackt?', a: 'Nein: keine Werbung, kein Tracking, keine Analyse durch uns. Zwei Stellen, an denen Google technische Daten erhält – die freiwillige Anmeldung mit Google und den QR-Scanner auf Android –, beschreibt die <a href="/datenschutz/">Datenschutzerklärung</a> genau.' },
  ],
  openTitle: 'Open Source',
  openText: 'Der gesamte Quellcode, die Spezifikation und die Entscheidungen dahinter sind öffentlich, unter der Apache-Lizenz 2.0. Lesen, ausprobieren, selbst betreiben oder mithelfen.',
  openCta: 'WuselWall auf GitHub',
  docsCta: 'Anleitung für die Familie',
  footer: {
    label: 'Fußzeile',
    imprint: 'Impressum',
    privacy: 'Datenschutz',
    docs: 'Anleitung',
    source: 'Quellcode',
    license: 'Apache-Lizenz 2.0',
    langSwitch: 'English',
    note: 'Ein Open-Source-Projekt für Familien',
  },
  legal: {
    imprintTitle: 'Impressum',
    imprintDescription: 'Anbieterkennzeichnung und Kontakt für WuselWall.',
    operator: 'Verantwortlich für diese Website',
    contact: 'Kontakt',
    email: 'E-Mail',
    phone: 'Telefon',
    liability: 'Haftung für Inhalte und Links',
    liabilityText:
      'Die Inhalte dieser Website werden mit Sorgfalt erstellt, für ihre Richtigkeit, Vollständigkeit und Aktualität wird jedoch keine Gewähr übernommen. Für Inhalte externer Websites, auf die verlinkt wird, sind ausschließlich deren Betreiber verantwortlich.',
    trademarksTitle: 'Marken',
    trademarks: [
      'Apple, das Apple-Logo, iPhone und iPad sind Marken der Apple Inc., die in den USA und weiteren Ländern eingetragen sind. App Store ist eine Dienstleistungsmarke der Apple Inc.',
      'Google Play und das Google Play-Logo sind Marken der Google LLC.',
      'GitHub und das GitHub-Logo sind Marken der GitHub, Inc.',
    ],
    placeholderWarning: 'Achtung: Die Angaben des Betreibers sind noch nicht ausgefüllt (website/src/config/site.ts).',
    privacyTitle: 'Datenschutzerklärung',
    privacyDescription: 'Wie WuselWall mit Daten umgeht: diese Website, die Apps und die Anmeldung mit Apple oder Google.',
  },
  privacy: {
    updated: 'Stand: 14. Oktober 2026',
    summaryTitle: 'Das Wichtigste in Kürze',
    summary: [
      'Wir betreiben keinen Dienst, auf dem die Daten Ihrer Familie liegen. Die App speichert alles auf dem WuselWall-Server, mit dem Ihre Familie sie verbunden hat.',
      'Diese Website setzt keine Cookies und lädt nichts von Dritten. Die Apps enthalten keine Werbung und kein Tracking, und wir erhalten keine Inhalte aus ihnen.',
      'Google erhält an zwei Stellen technische Daten: wenn Sie sich freiwillig mit Google anmelden, und beim Scannen eines QR-Codes auf Android. Beides ist unten genau beschrieben.',
    ],
    sections: [
      {
        title: 'Verantwortlich',
        body: [
          'Verantwortlich für diese Website und für die WuselWall-Apps, wie wir sie veröffentlichen: {operator}. E-Mail: {email}.',
          'Diese Erklärung folgt dem Schweizer Datenschutzgesetz (DSG) und, soweit sie anwendbar ist, der Datenschutz-Grundverordnung der EU (DSGVO).',
        ],
      },
      {
        title: 'Diese Website und die Anleitung',
        body: [
          'Die Website wuselwall.app und die Anleitung unter wuselwall.app/docs setzen keine Cookies, speichern nichts in Ihrem Browser und laden keine Schriften, Skripte oder Bilder von Dritten.',
          'Unser Webserver führt keine Zugriffsprotokolle: Wer welche Seite aufruft, wird nicht gespeichert. Nur wenn beim Ausliefern ein Fehler auftritt, hält er IP-Adresse, Zeitpunkt und aufgerufene Adresse in einem Fehlerprotokoll fest. Wir nutzen es nur, um Fehler zu beheben und Angriffe abzuwehren, führen es nicht mit anderen Daten zusammen und löschen es nach spätestens {logDays} Tagen.',
          'Die Website wird über Cloudflare ausgeliefert (Cloudflare, Inc., USA), das die Verbindung verschlüsselt, vor Missbrauch schützt und Inhalte zwischenspeichert. Cloudflare verarbeitet dabei Ihre IP-Adresse in unserem Auftrag und ist nach dem Data Privacy Framework (EU–USA und Schweiz–USA) zertifiziert. <a href="https://www.cloudflare.com/de-de/privacypolicy/" rel="noopener">Datenschutzerklärung von Cloudflare</a>.',
        ],
      },
      {
        title: 'Die Apps: Ihre Daten liegen auf Ihrem Server',
        body: [
          'WuselWall gibt es für iPhone und iPad, für Android und als Web-App. Alles, was Sie darin eingeben – Namen und Farben der Familienmitglieder, Termine, Stundenpläne, Aufgaben, Essenspläne, Einkaufslisten –, speichert die App auf dem WuselWall-Server, mit dem Ihre Familie sie verbunden hat, und als Zwischenspeicher auf Ihrem Gerät, damit sie auch ohne Netz funktioniert. Verantwortlich für diese Daten ist, wer den Server betreibt: oft Sie selbst oder jemand aus Ihrer Familie.',
          'Wir als Herausgeber der App erhalten keine dieser Daten. Die Apps enthalten keine Werbung und keine Tracking- oder Absturzberichtsdienste und verbinden sich nur mit Ihrem Server – ausgenommen die beiden Google-Bausteine, die unten beschrieben sind.',
          'Ihre Anmeldung legt die App im geschützten Speicher des Betriebssystems ab (Schlüsselbund auf iPhone und iPad, Keystore auf Android). Jedes Gerät hat seinen eigenen Zugang, den Erwachsene in der App jederzeit sperren können.',
        ],
      },
      {
        title: 'Feiertage und Schulferien',
        body: [
          'Damit die App Feiertage und Schulferien kennt, holt der WuselWall-Server die Daten aus dem öffentlichen Datensatz von OpenHolidays (openholidaysapi.org): einmal pro Woche und, wenn jemand in der App ein Land auswählt. Die App selbst verbindet sich nicht damit. Für diese Abfrage ist der Betreiber Ihres Servers verantwortlich.',
          'Dabei gehen nur Ländercodes und Datumsbereiche an OpenHolidays, dazu wie bei jeder Anfrage die IP-Adresse Ihres Servers. Nichts über Ihre Familie, ihre Mitglieder, Schulen oder Ihre Region wird übermittelt. Die Antworten liegen als öffentliche Daten auf dem Server, nicht bei uns. Die Daten stehen unter der Open Database License 1.0.',
        ],
      },
      {
        title: 'Kalender-Abos',
        body: [
          'Abonniert eure Familie einen Kalender von außen – etwa den Spielplan eines Vereins oder den Abfuhrkalender –, holt der WuselWall-Server die Datei unter der Adresse, die ihr eingegeben habt, etwa einmal pro Stunde. Die App selbst verbindet sich nicht damit. Für diese Abfragen ist der Betreiber eures Servers verantwortlich.',
          'Der Anbieter des Kalenders erfährt dabei die IP-Adresse eures Servers, den Zeitpunkt und die Kennung „WuselWall calendar-import“ im Anfragekopf. Nichts über eure Familie wird übermittelt, außer was in der Adresse selbst steht. Die vollständige Adresse sehen nur Eltern; alle anderen Geräte zeigen nur den Namen des Anbieters.',
        ],
      },
      {
        title: 'Kamera und QR-Codes',
        body: [
          'Die App fragt nach der Kamera nur, um QR-Codes zu scannen, etwa beim Verbinden eines Geräts. Die Bilder werden nicht gespeichert und nicht an Ihren Server oder an uns übertragen.',
          'Die Codes werden auf dem Gerät ausgewertet, auf Android ebenso wie auf iPhone und iPad. Dafür nutzt die App keinen Dienst eines Drittanbieters, und sie sendet dabei nichts nach außen.',
        ],
      },
      {
        title: 'Anmeldung mit Apple oder Google',
        body: [
          'Die Anmeldung mit Apple oder Google ist freiwillig; die Anmeldung mit E-Mail-Adresse geht immer. Ob sie angeboten wird, hängt vom Server ab: In der Regel läuft sie über den Browser und nur, wenn der Betreiber Ihres Servers das bei Apple und Google selbst eingerichtet hat – dann gelten auch seine Angaben.',
          'Wenn Sie sich mit Apple oder Google anmelden, erfährt der Anbieter, dass und wann Sie sich bei WuselWall anmelden. Der Server erhält eine Kennung Ihres Kontos, Ihre E-Mail-Adresse (bei Apple auf Wunsch eine Weiterleitungsadresse) und Ihren Namen. Mehr fragt WuselWall nicht ab, insbesondere keinen Zugriff auf Kalender oder Kontakte.',
          '<strong>Apple:</strong> Auf iPhone und iPad ist die Anmeldung Teil des Betriebssystems; die App enthält dafür keinen fremden Code. Auf Android und im Browser öffnet sich die Anmeldeseite von Apple.',
          '<strong>Google:</strong> Auf iPhone und iPad enthält die App dafür die Anmeldebibliothek von Google. Sie wird erst aktiv, wenn Sie „Mit Google anmelden“ tippen. Laut Googles eigener Angabe erhebt sie dann neben Name, E-Mail-Adresse und Kontokennung auch eine Gerätekennung und Nutzungsdaten, die Google auch für eigene Analysen verwendet – nicht aber für Tracking über Apps und Websites anderer Anbieter hinweg. Auf Android läuft die Anmeldung über die Google-Dienste des Geräts, im Browser über die Anmeldeseite von Google.',
          'Apple und Google verarbeiten diese Daten in eigener Verantwortung, auch in den USA: <a href="https://www.apple.com/de/legal/privacy/" rel="noopener">Datenschutz bei Apple</a>, <a href="https://policies.google.com/privacy?hl=de" rel="noopener">Datenschutzerklärung von Google</a>.',
        ],
      },
      {
        title: 'App Store und Google Play',
        body: [
          'Die Apps laden Sie über den App Store von Apple oder über Google Play. Dafür gelten deren Datenschutzbestimmungen. Wir erhalten von dort nur zusammengefasste Zahlen (etwa Downloads) und Absturzberichte von Personen, die der Weitergabe an Entwickler in ihren Geräteeinstellungen zugestimmt haben.',
          'Wer eine Testversion über TestFlight nutzt, teilt mit uns außerdem den Namen und die E-Mail-Adresse, mit der er eingeladen wurde, sowie Feedback, das er selbst sendet.',
        ],
      },
      {
        title: 'Wenn Sie uns schreiben',
        body: [
          'Schreiben Sie uns eine E-Mail, verwenden wir Ihre Adresse und Ihre Nachricht nur, um zu antworten, und löschen beides, wenn die Sache erledigt ist.',
        ],
      },
      {
        title: 'Wenn Sie selbst einen Server betreiben',
        body: [
          'WuselWall ist Open Source ({github}). Wer einen WuselWall-Server betreibt, ist für die Daten darauf verantwortlich und informiert die Familien, die ihn nutzen, selbst. Diese Erklärung gilt nicht für solche Server. Hinweise stehen in der {docs}.',
        ],
      },
      {
        title: 'Ihre Rechte',
        body: [
          'Sie können Auskunft über Ihre Daten verlangen, sie berichtigen oder löschen lassen, der Bearbeitung widersprechen und Ihre Daten in einem gängigen Format herausverlangen. Weil wir außer Server-Protokollen und E-Mails keine Daten über Sie haben, richten Sie Anfragen zu den Daten Ihrer Familie an den Betreiber Ihres Servers, alles andere an {email}.',
          'Sie können sich bei einer Datenschutzaufsicht beschweren: in der Schweiz beim Eidgenössischen Datenschutz- und Öffentlichkeitsbeauftragten (EDÖB), in der EU bei der Aufsichtsbehörde Ihres Landes.',
        ],
      },
      {
        title: 'Änderungen',
        body: [
          'Wenn sich WuselWall ändert, passen wir diese Erklärung an. Es gilt die Fassung auf dieser Seite; das Datum steht oben.',
        ],
      },
    ],
  },
};

const en: Strings = {
  htmlLang: 'en',
  title: 'WuselWall – the family organiser for your home',
  description:
    'WuselWall is the family organiser with a week board for the kitchen wall: shared calendar, school timetables, chores, meal plan and shopping list. Open source, on your own server.',
  skip: 'Skip to content',
  nav: { label: 'Main', features: 'Features', selfHost: 'Your own server', status: 'Status', github: 'GitHub' },
  hero: {
    kicker: 'Open source · On your own server · For the whole family',
    title: 'Everything that bustles around your home – on one wall.',
    lead: 'Shared calendar, school timetables, chores, meal plan and shopping list. On the phone for the parents, as a week board in the kitchen, in a child-friendly view for the little ones.',
    primary: 'How it works',
    github: 'Source on GitHub',
    stores: 'Get WuselWall',
    storesSoon: 'Coming soon to the App Store and Google Play.',
    shotAlt: 'The week board on a tablet: who is where, the week’s events and what’s for dinner, each person in their own colour.',
    phoneAlt: 'The shopping list on a phone.',
  },
  badges: {
    iosAlt: 'Download on the App Store',
    androidAlt: 'Get it on Google Play',
  },
  featuresTitle: 'What WuselWall does',
  features: [
    { title: 'A week board for the kitchen', text: 'Seven days at a glance, made for a tablet on the wall. Every person has a colour that colour-blind family members can tell apart.' },
    { title: 'Shared calendar', text: 'Events for everyone, with recurrence and presence (shifts, travel). Subscribe to it from Outlook or Apple Calendar through an ICS feed.' },
    { title: 'School timetables', text: 'Each child’s timetable as a pattern, with holidays and cancelled lessons. In the morning you see at once what has to go in the bag.' },
    { title: 'Chores with points', text: 'Hand out chores, collect points, redeem rewards. No pressure, with streaks and badges for the children.' },
    { title: 'Meal plan and shopping list', text: 'What’s for dinner this week? The ingredients land on the shopping list, which keeps working without a connection in the shop.' },
    { title: 'A device per person or per room', text: 'Personal devices for the adults, a shared one for the kitchen, one for the kids. Each device can be revoked on its own.' },
  ],
  viewsTitle: 'Three views, one family',
  viewsLead: 'The same data, shaped for whoever is looking.',
  views: [
    { title: 'For the parents', text: 'Add something to the shopping list, enter an event, hand out chores – on the phone, even without a connection.', shot: 'shopping-phone', alt: 'The shopping list on a phone, sorted by aisle.' },
    { title: 'For the children', text: 'Big buttons, clear colours, their own face to tap. Children need no account and no email address.', shot: 'kid-shopping', alt: 'The children’s view of the shopping list with large tiles and the family’s faces.' },
    { title: 'For the wall', text: 'A tablet in the kitchen shows the whole week. Tap a child to open their timetable, with substitutions and cancelled lessons.', shot: 'wall-child-week', alt: 'A child’s school timetable on the wall tablet, with a substitute lesson and a cancelled one.' },
  ],
  selfHostTitle: 'On your own server',
  selfHostLead: 'WuselWall is not an online service. The app connects to a server your family runs itself – we never see your data.',
  selfHostSteps: [
    { title: 'Set up the server', text: 'WuselWall runs with Docker on a NAS, a mini PC or a rented server. A script sets everything up and shows a QR code at the end.' },
    { title: 'Connect the app', text: 'Install the app, scan the QR code, done. The app has no built-in server and talks only to yours.' },
    { title: 'Invite the family', text: 'Invite your partner with a link, connect the kitchen tablet with a code. Whoever is invited never needs to know the server’s address.' },
  ],
  selfHostNote: 'Still in the works: WuselWall is not publicly in the app stores yet. Until then, the guide walks you step by step to your own server, at Supabase or at home, and to the web app.',
  principlesTitle: 'Why WuselWall is different',
  principles: [
    { title: 'Your data stays with you', text: 'Events, timetables and your children’s names live on your server, not with us. No ads, no tracking, no account with us.' },
    { title: 'No pressure', text: 'Points, streaks and badges instead of punishments. No ranking between siblings, no contest over who did the most chores.' },
    { title: 'Bilingual and adaptable', text: 'German and English from day one. Whatever one family does differently from the next is a setting.' },
  ],
  statusTitle: 'Where we are',
  statusLead: 'WuselWall is built step by step. This is the current state:',
  status: [
    { label: 'Connecting devices and setting up a family', state: 'done', done: true },
    { label: 'Shopping list with offline mode', state: 'done', done: true },
    { label: 'Today view with first steps', state: 'done', done: true },
    { label: 'Meal suggestions from your history', state: 'done', done: true },
    { label: 'Data export for the family', state: 'done', done: true },
    { label: 'Public and school holidays for Germany, Austria, Switzerland and Liechtenstein – down to the municipality', state: 'done', done: true },
    { label: 'Several schools per family', state: 'done', done: true },
    { label: 'Subscribe to club, bin and school calendars', state: 'done', done: true },
    { label: 'Calendar and week board', state: 'up next', done: false },
    { label: 'Chores and points', state: 'up next', done: false },
    { label: 'School timetable and meal plan', state: 'up next', done: false },
    { label: 'A server for every family: install, connect the app, try it without a server', state: 'up next', done: false },
  ],
  faqTitle: 'Questions',
  faq: [
    { q: 'What does WuselWall cost?', a: 'Nothing. The app and the server software are open source under the Apache License 2.0. All you need is a computer to run your WuselWall server on.' },
    { q: 'Why is there no WuselWall service to sign up to?', a: 'Because your family’s data does not belong with us. We build the app and the server software, but we run no service for other families. So nothing can get lost or leak on our side either.' },
    { q: 'What do we need for our own server?', a: 'A computer that is always on and runs Docker, with 8 GB of memory: a NAS (such as Synology or QNAP), a mini PC or a rented server. Without a machine of your own, a Supabase project of your own works too. The <a href="/docs/en/server/">guide</a> walks through both step by step. An install script that does it all at once will follow.' },
    { q: 'Can we try WuselWall without a server?', a: 'Soon: the app gets an example family that runs entirely on the device, without any server. Until then the <a href="/docs/en/">guide</a> shows every screen.' },
    { q: 'Are we being tracked?', a: 'No: no ads, no tracking, no analytics by us. The <a href="/en/privacy/">privacy policy</a> describes the two places where Google receives technical data – the optional sign-in with Google and the QR scanner on Android.' },
  ],
  openTitle: 'Open source',
  openText: 'All of the source code, the specification and the decisions behind it are public, under the Apache License 2.0. Read it, try it, run it yourself or help build it.',
  openCta: 'WuselWall on GitHub',
  docsCta: 'Guide for the family',
  footer: {
    label: 'Footer',
    imprint: 'Imprint',
    privacy: 'Privacy',
    docs: 'Guide',
    source: 'Source code',
    license: 'Apache License 2.0',
    langSwitch: 'Deutsch',
    note: 'An open-source project for families',
  },
  legal: {
    imprintTitle: 'Imprint',
    imprintDescription: 'Provider identification and contact for WuselWall.',
    operator: 'Responsible for this website',
    contact: 'Contact',
    email: 'E-mail',
    phone: 'Phone',
    liability: 'Liability for content and links',
    liabilityText:
      'The content of this website is prepared with care, but no guarantee is given for its accuracy, completeness or timeliness. The operators of external websites linked from here are solely responsible for their content.',
    trademarksTitle: 'Trademarks',
    trademarks: [
      'Apple, the Apple logo, iPhone and iPad are trademarks of Apple Inc., registered in the U.S. and other countries. App Store is a service mark of Apple Inc.',
      'Google Play and the Google Play logo are trademarks of Google LLC.',
      'GitHub and the GitHub logo are trademarks of GitHub, Inc.',
    ],
    placeholderWarning: 'Warning: the operator details are not filled in yet (website/src/config/site.ts).',
    privacyTitle: 'Privacy policy',
    privacyDescription: 'How WuselWall handles data: this website, the apps and signing in with Apple or Google.',
  },
  privacy: {
    updated: 'Last updated: 14 October 2026',
    summaryTitle: 'In short',
    summary: [
      'We run no service that holds your family’s data. The app stores everything on the WuselWall server your family connected it to.',
      'This website sets no cookies and loads nothing from third parties. The apps contain no ads and no tracking, and we receive nothing you enter in them.',
      'Google receives technical data in two places: when you choose to sign in with Google, and when you scan a QR code on Android. Both are described in detail below.',
    ],
    sections: [
      {
        title: 'Controller',
        body: [
          'Responsible for this website and for the WuselWall apps as we publish them: {operator}. E-mail: {email}.',
          'This statement follows the Swiss Federal Act on Data Protection (FADP) and, where it applies, the EU General Data Protection Regulation (GDPR).',
        ],
      },
      {
        title: 'This website and the guide',
        body: [
          'The website wuselwall.app and the guide at wuselwall.app/docs set no cookies, store nothing in your browser and load no fonts, scripts or images from third parties.',
          'Our web server keeps no access logs: who visits which page is not stored. Only when an error occurs while delivering a page does it record the IP address, time and address requested in an error log. We use it only to fix errors and fend off attacks, do not combine it with other data and delete it after {logDays} days at the latest.',
          'The website is delivered through Cloudflare (Cloudflare, Inc., USA), which encrypts the connection, protects against abuse and caches content. Cloudflare processes your IP address on our behalf and is certified under the Data Privacy Framework (EU–U.S. and Swiss–U.S.). <a href="https://www.cloudflare.com/privacypolicy/" rel="noopener">Cloudflare’s privacy policy</a>.',
        ],
      },
      {
        title: 'The apps: your data lives on your server',
        body: [
          'WuselWall is available for iPhone and iPad, for Android and as a web app. Everything you enter – family members’ names and colours, events, timetables, chores, meal plans, shopping lists – is stored by the app on the WuselWall server your family connected it to, and cached on your device so that it keeps working without a connection. Whoever runs that server is responsible for this data: often you or someone in your family.',
          'We, the publishers of the app, receive none of this data. The apps contain no ads and no tracking or crash-reporting services, and connect only to your server – except for the two Google components described below.',
          'The app keeps your sign-in in the operating system’s protected storage (the keychain on iPhone and iPad, the keystore on Android). Every device has its own access, which adults can revoke in the app at any time.',
        ],
      },
      {
        title: 'Public and school holidays',
        body: [
          'So that the app knows public and school holidays, your WuselWall server fetches the data from the public OpenHolidays dataset (openholidaysapi.org): once a week, and when someone in the app picks a country. The app itself does not connect to it. The operator of your server is responsible for this request.',
          'Only country codes and date ranges go to OpenHolidays, and, as with every request, the IP address of your server. Nothing about your family, its members, schools or region is sent. The answers are stored on the server as public data, not with us. The data is under the Open Database License 1.0.',
        ],
      },
      {
        title: 'Subscribed calendars',
        body: [
          'If your family subscribes to a calendar from outside – such as a club’s fixture list or the bin collection calendar –, your WuselWall server fetches the file from the address you entered, about once an hour. The app itself does not connect to it. The operator of your server is responsible for these requests.',
          'The calendar’s provider learns the IP address of your server, the time, and the identifier “WuselWall calendar-import” in the request header. Nothing about your family is sent, except what is in the address itself. Only guardians see the full address; every other device shows just the provider’s name.',
        ],
      },
      {
        title: 'Camera and QR codes',
        body: [
          'The app asks for the camera only to scan QR codes, for example when connecting a device. The images are not stored and are not sent to your server or to us.',
          'The codes are read on the device, on Android as well as on iPhone and iPad. The app uses no third-party service for this and sends nothing out while it reads them.',
        ],
      },
      {
        title: 'Signing in with Apple or Google',
        body: [
          'Signing in with Apple or Google is optional; signing in with an email address always works. Whether it is offered depends on the server: usually it runs through the browser, and only if your server’s operator has set it up with Apple and Google themselves – that operator’s information then applies too.',
          'When you sign in with Apple or Google, the provider learns that and when you sign in to WuselWall. The server receives an identifier for your account, your email address (with Apple, a relay address if you prefer) and your name. WuselWall asks for nothing more – in particular no access to calendars or contacts.',
          '<strong>Apple:</strong> on iPhone and iPad, signing in is part of the operating system; the app contains no third-party code for it. On Android and in the browser, Apple’s sign-in page opens.',
          '<strong>Google:</strong> on iPhone and iPad, the app contains Google’s sign-in library for this. It becomes active only when you tap “Sign in with Google”. According to Google’s own declaration, it then collects, besides name, email address and account identifier, a device identifier and usage data, which Google also uses for its own analytics – but not for tracking across other companies’ apps and websites. On Android, sign-in runs through the device’s Google services; in the browser, through Google’s sign-in page.',
          'Apple and Google process this data under their own responsibility, also in the USA: <a href="https://www.apple.com/legal/privacy/" rel="noopener">Apple’s privacy policy</a>, <a href="https://policies.google.com/privacy?hl=en" rel="noopener">Google’s privacy policy</a>.',
        ],
      },
      {
        title: 'App Store and Google Play',
        body: [
          'You download the apps from Apple’s App Store or Google Play, whose privacy policies apply. From them we receive only aggregated figures (such as downloads) and crash reports from people who agreed in their device settings to share them with developers.',
          'If you use a test version through TestFlight, you also share with us the name and email address you were invited with, and any feedback you send yourself.',
        ],
      },
      {
        title: 'If you write to us',
        body: [
          'If you send us an email, we use your address and your message only to reply, and delete both once the matter is settled.',
        ],
      },
      {
        title: 'If you run a server yourself',
        body: [
          'WuselWall is open source ({github}). Whoever runs a WuselWall server is responsible for the data on it and informs the families who use it. This statement does not apply to such servers. Advice is in the {docs}.',
        ],
      },
      {
        title: 'Your rights',
        body: [
          'You may ask for access to your data, have it corrected or erased, object to its processing and receive it in a common format. As we hold no data about you beyond server logs and emails, send requests about your family’s data to the operator of your server, and anything else to {email}.',
          'You may complain to a data protection authority: in Switzerland the Federal Data Protection and Information Commissioner (FDPIC), in the EU the supervisory authority of your country.',
        ],
      },
      {
        title: 'Changes',
        body: [
          'When WuselWall changes, we update this statement. The version on this page applies; its date is at the top.',
        ],
      },
    ],
  },
};

export const strings: Record<Lang, Strings> = { de, en };

/** The other language's URL for the same page, for hreflang and the footer switch. */
export function alternate(lang: Lang, page: 'home' | 'imprint' | 'privacy') {
  return paths[lang === 'de' ? 'en' : 'de'][page];
}

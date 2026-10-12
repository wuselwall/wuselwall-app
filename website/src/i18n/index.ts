export type Lang = 'de' | 'en';

export const paths = {
  de: { home: '/', imprint: '/impressum/', privacy: '/datenschutz/' },
  en: { home: '/en/', imprint: '/en/imprint/', privacy: '/en/privacy/' },
} as const;

type Feature = { title: string; text: string };

export interface Strings {
  htmlLang: string;
  title: string;
  description: string;
  nav: { features: string; status: string; openSource: string; webApp: string };
  hero: { kicker: string; title: string; lead: string; webApp: string; github: string; stores: string };
  badges: { ios: string; android: string; iosAlt: string; androidAlt: string };
  featuresTitle: string;
  features: Feature[];
  principlesTitle: string;
  principles: Feature[];
  statusTitle: string;
  statusLead: string;
  status: { label: string; state: string; done: boolean }[];
  openTitle: string;
  openText: string;
  openCta: string;
  docsCta: string;
  footer: { imprint: string; privacy: string; source: string; langSwitch: string; note: string };
  legal: {
    imprintTitle: string;
    imprintDescription: string;
    operator: string;
    contact: string;
    liability: string;
    liabilityText: string;
    placeholderWarning: string;
    privacyTitle: string;
    privacyDescription: string;
  };
}

const de: Strings = {
  htmlLang: 'de-CH',
  title: 'WuselWall – der Familienorganisator für zuhause',
  description:
    'WuselWall ist der Familienorganisator mit Wochenübersicht für die Küchenwand: gemeinsamer Kalender, Stundenpläne, Aufgaben, Essensplan und Einkaufsliste. Open Source, auf Wunsch auf dem eigenen Server.',
  nav: { features: 'Funktionen', status: 'Stand', openSource: 'Open Source', webApp: 'Web-App öffnen' },
  hero: {
    kicker: 'Open Source · Datensparsam · Für die ganze Familie',
    title: 'Alles, was bei euch zuhause wuselt – an einer Wand.',
    lead: 'Gemeinsamer Kalender, Stundenpläne, Aufgaben, Essensplan und Einkaufsliste. Auf dem Handy für die Eltern, als Wochentafel in der Küche, in kindgerechter Ansicht für die Kleinen.',
    webApp: 'Web-App öffnen',
    github: 'Quellcode auf GitHub',
    stores: 'WuselWall herunterladen',
  },
  badges: {
    ios: 'Laden im App Store',
    android: 'Jetzt bei Google Play',
    iosAlt: 'WuselWall im App Store laden',
    androidAlt: 'WuselWall bei Google Play laden',
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
  principlesTitle: 'Warum WuselWall anders ist',
  principles: [
    { title: 'Eure Daten gehören euch', text: 'Keine Werbung, kein Tracking, keine Analyse-Dienste. Ihr könnt WuselWall auf dem eigenen Server betreiben und eure Daten jederzeit exportieren.' },
    { title: 'Zweisprachig', text: 'Deutsch und Englisch, von Anfang an. Alles, was eine Familie anders macht als die nächste, ist eine Einstellung.' },
    { title: 'Gebaut für Kinder und Eltern', text: 'Drei Oberflächen: eine dichte für Erwachsene, eine große und einfache für Kinder, eine ruhige für die Wand.' },
  ],
  statusTitle: 'Wo wir stehen',
  statusLead: 'WuselWall entsteht Schritt für Schritt. Das ist der aktuelle Stand:',
  status: [
    { label: 'Geräte verbinden und Familie einrichten', state: 'fertig', done: true },
    { label: 'Einkaufsliste mit Offline-Modus', state: 'fertig', done: true },
    { label: 'Aufgaben und Punkte', state: 'als Nächstes', done: false },
    { label: 'Kalender und Wochentafel', state: 'geplant', done: false },
    { label: 'Stundenplan und Essensplan', state: 'geplant', done: false },
  ],
  openTitle: 'Open Source',
  openText: 'Der gesamte Quellcode, die Spezifikation und die Entscheidungen dahinter sind öffentlich. Lesen, ausprobieren, selbst betreiben oder mithelfen.',
  openCta: 'WuselWall auf GitHub',
  docsCta: 'Anleitung für die Familie',
  footer: {
    imprint: 'Impressum',
    privacy: 'Datenschutz',
    source: 'Quellcode',
    langSwitch: 'English',
    note: 'Ein Open-Source-Projekt für Familien.',
  },
  legal: {
    imprintTitle: 'Impressum',
    imprintDescription: 'Anbieterkennzeichnung und Kontakt für WuselWall.',
    operator: 'Verantwortlich für diese Website',
    contact: 'Kontakt',
    liability: 'Haftung für Inhalte und Links',
    liabilityText:
      'Die Inhalte dieser Website werden mit Sorgfalt erstellt, für ihre Richtigkeit, Vollständigkeit und Aktualität wird jedoch keine Gewähr übernommen. Für Inhalte externer Websites, auf die verlinkt wird, sind ausschließlich deren Betreiber verantwortlich.',
    placeholderWarning: 'Achtung: Die Angaben des Betreibers sind noch nicht ausgefüllt (website/src/config/site.ts).',
    privacyTitle: 'Datenschutzerklärung',
    privacyDescription: 'Wie WuselWall mit Daten umgeht: diese Website, die Web-App und die Apps.',
  },
};

const en: Strings = {
  htmlLang: 'en',
  title: 'WuselWall – the family organiser for your home',
  description:
    'WuselWall is the family organiser with a week board for the kitchen wall: shared calendar, school timetables, chores, meal plan and shopping list. Open source, self-hostable.',
  nav: { features: 'Features', status: 'Status', openSource: 'Open source', webApp: 'Open web app' },
  hero: {
    kicker: 'Open source · Privacy-minded · For the whole family',
    title: 'Everything that bustles around your home – on one wall.',
    lead: 'Shared calendar, school timetables, chores, meal plan and shopping list. On the phone for the parents, as a week board in the kitchen, in a child-friendly view for the little ones.',
    webApp: 'Open web app',
    github: 'Source on GitHub',
    stores: 'Get WuselWall',
  },
  badges: {
    ios: 'Download on the App Store',
    android: 'Get it on Google Play',
    iosAlt: 'Download WuselWall on the App Store',
    androidAlt: 'Get WuselWall on Google Play',
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
  principlesTitle: 'Why WuselWall is different',
  principles: [
    { title: 'Your data is yours', text: 'No ads, no tracking, no analytics services. You can run WuselWall on your own server and export your data at any time.' },
    { title: 'Bilingual', text: 'German and English from day one. Whatever one family does differently from the next is a setting.' },
    { title: 'Built for kids and parents', text: 'Three interfaces: a dense one for adults, a big simple one for children, a calm one for the wall.' },
  ],
  statusTitle: 'Where we are',
  statusLead: 'WuselWall is built step by step. This is the current state:',
  status: [
    { label: 'Connecting devices and setting up a family', state: 'done', done: true },
    { label: 'Shopping list with offline mode', state: 'done', done: true },
    { label: 'Chores and points', state: 'up next', done: false },
    { label: 'Calendar and week board', state: 'planned', done: false },
    { label: 'School timetable and meal plan', state: 'planned', done: false },
  ],
  openTitle: 'Open source',
  openText: 'All of the source code, the specification and the decisions behind it are public. Read it, try it, run it yourself or help build it.',
  openCta: 'WuselWall on GitHub',
  docsCta: 'Guide for the family',
  footer: {
    imprint: 'Imprint',
    privacy: 'Privacy',
    source: 'Source code',
    langSwitch: 'Deutsch',
    note: 'An open-source project for families.',
  },
  legal: {
    imprintTitle: 'Imprint',
    imprintDescription: 'Provider identification and contact for WuselWall.',
    operator: 'Responsible for this website',
    contact: 'Contact',
    liability: 'Liability for content and links',
    liabilityText:
      'The content of this website is prepared with care, but no guarantee is given for its accuracy, completeness or timeliness. The operators of external websites linked from here are solely responsible for their content.',
    placeholderWarning: 'Warning: the operator details are not filled in yet (website/src/config/site.ts).',
    privacyTitle: 'Privacy policy',
    privacyDescription: 'How WuselWall handles data: this website, the web app and the mobile apps.',
  },
};

export const strings: Record<Lang, Strings> = { de, en };

/** The other language's URL for the same page, for hreflang and the footer switch. */
export function alternate(lang: Lang, page: 'home' | 'imprint' | 'privacy') {
  return paths[lang === 'de' ? 'en' : 'de'][page];
}

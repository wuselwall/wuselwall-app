import { defineConfig } from 'vitepress'

const sidebar = (p: string, t: Record<string, string>) => [
  {
    text: t.start,
    items: [
      { text: t.concepts, link: `${p}/guide/concepts` },
      { text: t.install, link: `${p}/guide/install` },
      { text: t.setup, link: `${p}/guide/setup` },
      { text: t.who, link: `${p}/guide/who-are-you` },
    ],
  },
  {
    text: t.modules,
    items: [
      { text: t.calendar, link: `${p}/calendar/` },
      { text: t.feeds, link: `${p}/calendar/feeds` },
      { text: t.school, link: `${p}/school/` },
      { text: t.tasks, link: `${p}/tasks/` },
      { text: t.meals, link: `${p}/meals/` },
    ],
  },
  {
    text: t.shopping,
    items: [
      { text: t.add, link: `${p}/shopping/add` },
      { text: t.lists, link: `${p}/shopping/lists` },
      { text: t.store, link: `${p}/shopping/store` },
      { text: t.history, link: `${p}/shopping/history` },
    ],
  },
  {
    text: t.devices,
    items: [
      { text: t.wall, link: `${p}/guide/wall` },
      { text: t.household, link: `${p}/settings/household` },
      { text: t.members, link: `${p}/settings/members-devices` },
      { text: t.account, link: `${p}/settings/account` },
      { text: t.reminders, link: `${p}/settings/reminders` },
      { text: t.shortcuts, link: `${p}/settings/shortcuts` },
      { text: t.security, link: `${p}/settings/security` },
    ],
  },
  {
    text: t.server,
    items: [
      { text: t.serverOverview, link: `${p}/server/` },
      { text: t.serverSupabase, link: `${p}/server/supabase-cloud` },
      { text: t.serverHome, link: `${p}/server/home-server` },
      { text: t.serverRestore, link: `${p}/server/restore` },
      { text: t.serverExtras, link: `${p}/server/extras` },
    ],
  },
  { text: t.faq, link: `${p}/faq` },
]

// GitHub Pages custom domain: https://docs.wuselwall.app/.
// Keep a base override for local previews or an explicitly configured project URL.
const base = process.env.DOCS_BASE ?? '/'

export default defineConfig({
  title: 'WuselWall',
  base,
  cleanUrls: true,
  sitemap: { hostname: 'https://docs.wuselwall.app' },
  lastUpdated: true,
  // head is not rewritten with base, unlike links and images.
  head: [['link', { rel: 'icon', href: `${base}favicon.svg` }]],
  // Dead links fail the build: a screenshot or page that moved must be noticed.
  ignoreDeadLinks: false,
  themeConfig: {
    logo: '/logo.svg',
    search: { provider: 'local' },
    outline: { level: [2, 3] },
  },
  locales: {
    root: {
      label: 'Deutsch',
      lang: 'de',
      description: 'Anleitung für alle, die WuselWall zu Hause benutzen',
      themeConfig: {
        nav: [
          { text: 'Erste Schritte', link: '/guide/concepts' },
          { text: 'Kalender', link: '/calendar/' },
          { text: 'Stundenplan', link: '/school/' },
          { text: 'Aufgaben', link: '/tasks/' },
          { text: 'Essen', link: '/meals/' },
          { text: 'Einkaufsliste', link: '/shopping/add' },
          { text: 'Häufige Fragen', link: '/faq' },
        ],
        sidebar: sidebar('', {
          start: 'Erste Schritte', concepts: 'So funktioniert WuselWall', install: 'App installieren', setup: 'Anmelden und verbinden', who: 'Wer bist du?',
          modules: 'Module', calendar: 'Kalender', feeds: 'Familienkalender teilen', school: 'Stundenplan', tasks: 'Aufgaben', meals: 'Essen',
          shopping: 'Einkaufsliste', add: 'Artikel hinzufügen', lists: 'Mehrere Listen', store: 'Im Laden', history: 'Verlauf',
          devices: 'Geräte und Sicherheit', wall: 'Wandbildschirm und Kinder', household: 'Haushalt einstellen', members: 'Mitglieder und Geräte', account: 'Konto und Familie', reminders: 'Erinnerungen', shortcuts: 'Apps und KI-Assistenten', security: 'Sicherheit', faq: 'Häufige Fragen',
          server: 'Eigener Server', serverOverview: 'Überblick', serverHome: 'Server zu Hause', serverSupabase: 'Server bei Supabase', serverRestore: 'Backup zurückspielen', serverExtras: 'Extras',
        }),
        docFooter: { prev: 'Zurück', next: 'Weiter' },
        outlineTitle: 'Auf dieser Seite',
        lastUpdated: { text: 'Zuletzt geändert' },
        returnToTopLabel: 'Nach oben',
        sidebarMenuLabel: 'Menü',
        darkModeSwitchLabel: 'Design',
      },
    },
    en: {
      label: 'English',
      lang: 'en',
      link: '/en/',
      description: 'A guide for everyone who uses WuselWall at home',
      themeConfig: {
        nav: [
          { text: 'Getting started', link: '/en/guide/concepts' },
          { text: 'Calendar', link: '/en/calendar/' },
          { text: 'Timetable', link: '/en/school/' },
          { text: 'Tasks', link: '/en/tasks/' },
          { text: 'Meals', link: '/en/meals/' },
          { text: 'Shopping list', link: '/en/shopping/add' },
          { text: 'FAQ', link: '/en/faq' },
        ],
        sidebar: sidebar('/en', {
          start: 'Getting started', concepts: 'How WuselWall works', install: 'Installing the app', setup: 'Signing in and connecting', who: 'Who are you?',
          modules: 'Modules', calendar: 'Calendar', feeds: 'Sharing the family calendar', school: 'Timetable', tasks: 'Tasks', meals: 'Meals',
          shopping: 'Shopping list', add: 'Adding items', lists: 'Several lists', store: 'In the store', history: 'History',
          devices: 'Devices and security', wall: 'Wall display and kids', household: 'Household settings', members: 'Members and devices', account: 'Account and family', reminders: 'Reminders', shortcuts: 'Apps and AI assistants', security: 'Security', faq: 'FAQ',
          server: 'Your own server', serverOverview: 'Overview', serverHome: 'Server at home', serverSupabase: 'Server at Supabase', serverRestore: 'Restoring a backup', serverExtras: 'Extras',
        }),
      },
    },
  },
})

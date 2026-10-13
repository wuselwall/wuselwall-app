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
      { text: t.members, link: `${p}/settings/members-devices` },
      { text: t.security, link: `${p}/settings/security` },
    ],
  },
  { text: t.faq, link: `${p}/faq` },
]

// Published under https://wusel.example.org/docs/ (.github/workflows/docs.yml sets
// DOCS_BASE=/docs/); "/" for npm run docs:dev.
const base = process.env.DOCS_BASE ?? '/'

export default defineConfig({
  title: 'WuselWall',
  base,
  cleanUrls: true,
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
          { text: 'Einkaufsliste', link: '/shopping/add' },
          { text: 'Häufige Fragen', link: '/faq' },
        ],
        sidebar: sidebar('', {
          start: 'Erste Schritte', concepts: 'So funktioniert WuselWall', install: 'App installieren', setup: 'Einrichten', who: 'Wer bist du?',
          shopping: 'Einkaufsliste', add: 'Artikel hinzufügen', lists: 'Mehrere Listen', store: 'Im Laden', history: 'Verlauf',
          devices: 'Geräte und Sicherheit', wall: 'Wandbildschirm und Kinder', members: 'Mitglieder und Geräte', security: 'Sicherheit', faq: 'Häufige Fragen',
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
          { text: 'Shopping list', link: '/en/shopping/add' },
          { text: 'FAQ', link: '/en/faq' },
        ],
        sidebar: sidebar('/en', {
          start: 'Getting started', concepts: 'How WuselWall works', install: 'Installing the app', setup: 'Setting up', who: 'Who are you?',
          shopping: 'Shopping list', add: 'Adding items', lists: 'Several lists', store: 'In the store', history: 'History',
          devices: 'Devices and security', wall: 'Wall display and kids', members: 'Members and devices', security: 'Security', faq: 'FAQ',
        }),
      },
    },
  },
})

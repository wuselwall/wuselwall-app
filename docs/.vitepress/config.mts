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
      { text: t.rituals, link: `${p}/guide/rituals` },
      { text: t.wusel, link: `${p}/guide/wusel` },
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
    search: {
      provider: 'local',
      options: { locales: {
        fr: { translations: {
          button: { buttonText: 'Rechercher', buttonAriaLabel: 'Rechercher dans le guide' },
          modal: { displayDetails: 'Afficher les détails', resetButtonTitle: 'Effacer la recherche', backButtonTitle: 'Retour', noResultsText: 'Aucun résultat pour',
            footer: { selectText: 'sélectionner', selectKeyAriaLabel: 'Entrée', navigateText: 'naviguer', navigateUpKeyAriaLabel: 'Flèche vers le haut', navigateDownKeyAriaLabel: 'Flèche vers le bas', closeText: 'fermer', closeKeyAriaLabel: 'Échap' } },
        } },
        es: { translations: {
          button: { buttonText: 'Buscar', buttonAriaLabel: 'Buscar en la guía' },
          modal: { displayDetails: 'Mostrar detalles', resetButtonTitle: 'Borrar búsqueda', backButtonTitle: 'Volver', noResultsText: 'Sin resultados para',
            footer: { selectText: 'seleccionar', selectKeyAriaLabel: 'Intro', navigateText: 'navegar', navigateUpKeyAriaLabel: 'Flecha arriba', navigateDownKeyAriaLabel: 'Flecha abajo', closeText: 'cerrar', closeKeyAriaLabel: 'Escape' } },
        } },
      } },
    },
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
          { text: 'Module', items: [
            { text: 'Kalender', link: '/calendar/' },
            { text: 'Stundenplan', link: '/school/' },
            { text: 'Aufgaben', link: '/tasks/' },
            { text: 'Essen', link: '/meals/' },
            { text: 'Einkaufsliste', link: '/shopping/add' },
          ] },
          { text: 'Häufige Fragen', link: '/faq' },
        ],
        sidebar: sidebar('', {
          start: 'Erste Schritte', concepts: 'So funktioniert WuselWall', install: 'App installieren', setup: 'Anmelden und verbinden', who: 'Wer bist du?',
          modules: 'Module', calendar: 'Kalender', feeds: 'Familienkalender teilen', school: 'Stundenplan', tasks: 'Aufgaben', meals: 'Essen', rituals: 'Rituale', wusel: 'Wusel und Farben',
          shopping: 'Einkaufsliste', add: 'Artikel hinzufügen', lists: 'Mehrere Listen', store: 'Im Laden', history: 'Verlauf',
          devices: 'Geräte und Sicherheit', wall: 'Wandbildschirm und Kinder', household: 'Alle Einstellungen', members: 'Mitglieder und Geräte', account: 'Konto und Familie', reminders: 'Erinnerungen', shortcuts: 'Apps und Automationen', security: 'Sicherheit', faq: 'Häufige Fragen',
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
          { text: 'Modules', items: [
            { text: 'Calendar', link: '/en/calendar/' },
            { text: 'Timetable', link: '/en/school/' },
            { text: 'Tasks', link: '/en/tasks/' },
            { text: 'Meals', link: '/en/meals/' },
            { text: 'Shopping list', link: '/en/shopping/add' },
          ] },
          { text: 'FAQ', link: '/en/faq' },
        ],
        sidebar: sidebar('/en', {
          start: 'Getting started', concepts: 'How WuselWall works', install: 'Installing the app', setup: 'Signing in and connecting', who: 'Who are you?',
          modules: 'Modules', calendar: 'Calendar', feeds: 'Sharing the family calendar', school: 'Timetable', tasks: 'Tasks', meals: 'Meals', rituals: 'Rituals', wusel: 'Wusel and colours',
          shopping: 'Shopping list', add: 'Adding items', lists: 'Several lists', store: 'In the store', history: 'History',
          devices: 'Devices and security', wall: 'Wall display and kids', household: 'All settings', members: 'Members and devices', account: 'Account and family', reminders: 'Reminders', shortcuts: 'Apps and automations', security: 'Security', faq: 'FAQ',
          server: 'Your own server', serverOverview: 'Overview', serverHome: 'Server at home', serverSupabase: 'Server at Supabase', serverRestore: 'Restoring a backup', serverExtras: 'Extras',
        }),
      },
    },
    fr: {
      label: 'Français', lang: 'fr', link: '/fr/',
      description: 'Le guide de WuselWall pour toute la famille',
      themeConfig: {
        nav: [
          { text: 'Premiers pas', link: '/fr/guide/concepts' },
          { text: 'Modules', items: [
            { text: 'Calendrier', link: '/fr/calendar/' },
            { text: 'Emploi du temps', link: '/fr/school/' },
            { text: 'Tâches', link: '/fr/tasks/' },
            { text: 'Repas', link: '/fr/meals/' },
            { text: 'Courses', link: '/fr/shopping/add' },
          ] },
          { text: 'Questions', link: '/fr/faq' },
        ],
        sidebar: sidebar('/fr', {
          start: 'Premiers pas', concepts: 'Comment fonctionne WuselWall', install: 'Installer l’app', setup: 'Se connecter et rejoindre la famille', who: 'Qui êtes-vous ?',
          modules: 'Les espaces', calendar: 'Calendrier', feeds: 'Partager le calendrier', school: 'Emploi du temps', tasks: 'Tâches', meals: 'Repas', rituals: 'Rituels', wusel: 'Wusel et les couleurs',
          shopping: 'Courses', add: 'Ajouter des articles', lists: 'Plusieurs listes', store: 'Au magasin', history: 'Historique',
          devices: 'Appareils et sécurité', wall: 'Écran mural et enfants', household: 'Tous les paramètres', members: 'Membres et appareils', account: 'Compte et famille', reminders: 'Rappels', shortcuts: 'Apps et automatisations', security: 'Sécurité', faq: 'Questions fréquentes',
          server: 'Votre propre serveur', serverOverview: 'Vue d’ensemble', serverHome: 'Serveur à la maison', serverSupabase: 'Serveur chez Supabase', serverRestore: 'Restaurer une sauvegarde', serverExtras: 'Options du serveur',
        }),
        docFooter: { prev: 'Précédent', next: 'Suivant' },
        outline: { level: [2, 3], label: 'Sur cette page' },
        lastUpdated: { text: 'Dernière mise à jour' },
        returnToTopLabel: 'Retour en haut', sidebarMenuLabel: 'Menu', langMenuLabel: 'Changer de langue',
        darkModeSwitchLabel: 'Thème', lightModeSwitchTitle: 'Passer au thème clair', darkModeSwitchTitle: 'Passer au thème sombre',
        skipToContentLabel: 'Aller au contenu',
        notFound: { title: 'PAGE INTROUVABLE', quote: 'Cette page n’existe pas ou a été déplacée.', linkLabel: 'Accueil', linkText: 'Revenir à l’accueil' },
      },
    },
    es: {
      label: 'Español', lang: 'es', link: '/es/',
      description: 'La guía de WuselWall para toda la familia',
      themeConfig: {
        nav: [
          { text: 'Primeros pasos', link: '/es/guide/concepts' },
          { text: 'Módulos', items: [
            { text: 'Calendario', link: '/es/calendar/' },
            { text: 'Horario escolar', link: '/es/school/' },
            { text: 'Tareas', link: '/es/tasks/' },
            { text: 'Comidas', link: '/es/meals/' },
            { text: 'Compra', link: '/es/shopping/add' },
          ] },
          { text: 'Preguntas', link: '/es/faq' },
        ],
        sidebar: sidebar('/es', {
          start: 'Primeros pasos', concepts: 'Cómo funciona WuselWall', install: 'Instalar la app', setup: 'Iniciar sesión y conectar', who: '¿Quién eres?',
          modules: 'Secciones', calendar: 'Calendario', feeds: 'Compartir el calendario', school: 'Horario escolar', tasks: 'Tareas', meals: 'Comidas', rituals: 'Rituales', wusel: 'Wusel y los colores',
          shopping: 'Compra', add: 'Añadir productos', lists: 'Varias listas', store: 'En la tienda', history: 'Historial',
          devices: 'Dispositivos y seguridad', wall: 'Pantalla de pared y niños', household: 'Todos los ajustes', members: 'Miembros y dispositivos', account: 'Cuenta y familia', reminders: 'Recordatorios', shortcuts: 'Apps y automatizaciones', security: 'Seguridad', faq: 'Preguntas frecuentes',
          server: 'Tu propio servidor', serverOverview: 'Resumen', serverHome: 'Servidor en casa', serverSupabase: 'Servidor en Supabase', serverRestore: 'Restaurar una copia', serverExtras: 'Opciones del servidor',
        }),
        docFooter: { prev: 'Anterior', next: 'Siguiente' },
        outline: { level: [2, 3], label: 'En esta página' },
        lastUpdated: { text: 'Última actualización' },
        returnToTopLabel: 'Volver arriba', sidebarMenuLabel: 'Menú', langMenuLabel: 'Cambiar de idioma',
        darkModeSwitchLabel: 'Tema', lightModeSwitchTitle: 'Cambiar al tema claro', darkModeSwitchTitle: 'Cambiar al tema oscuro',
        skipToContentLabel: 'Ir al contenido',
        notFound: { title: 'PÁGINA NO ENCONTRADA', quote: 'Esta página no existe o se ha trasladado.', linkLabel: 'Inicio', linkText: 'Volver al inicio' },
      },
    },
  },
})

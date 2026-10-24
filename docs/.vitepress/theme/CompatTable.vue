<script setup lang="ts">
// The releases and how they fit together, from compat.data.mts (the release tags at build
// time), in the page's language.
//   <CompatTable />
import { computed } from 'vue'
import { useData } from 'vitepress'
import { data } from './compat.data.mts'

const labels = {
  de: {
    servers: 'Server', apps: 'Apps', version: 'Version', date: 'Datum', api: 'Schnittstelle',
    minApp: 'App mindestens', fits: 'Passt zu Servern mit Schnittstelle', none: 'Noch keine Veröffentlichung.',
  },
  en: {
    servers: 'Servers', apps: 'Apps', version: 'Version', date: 'Date', api: 'API',
    minApp: 'Oldest app', fits: 'Works with servers of API', none: 'No release yet.',
  },
  fr: {
    servers: 'Serveurs', apps: 'Apps', version: 'Version', date: 'Date', api: 'API',
    minApp: 'App au minimum', fits: 'Fonctionne avec les serveurs d’API', none: 'Pas encore de version.',
  },
  es: {
    servers: 'Servidores', apps: 'Apps', version: 'Versión', date: 'Fecha', api: 'API',
    minApp: 'App como mínimo', fits: 'Funciona con servidores de API', none: 'Aún no hay versiones.',
  },
} as const

const { lang } = useData()
const t = computed(() => labels[(['en', 'fr', 'es'] as const).find((c) => lang.value.startsWith(c)) ?? 'de'])
// An app speaks its own API version and the one before it (server_compat.dart).
const fits = (api: number) => (api > 1 ? `${api - 1}, ${api}` : `${api}`)
</script>

<template>
  <h4>{{ t.servers }}</h4>
  <p v-if="data.servers.length === 0">{{ t.none }}</p>
  <table v-else class="compat">
    <thead><tr><th>{{ t.version }}</th><th>{{ t.date }}</th><th>{{ t.api }}</th><th>{{ t.minApp }}</th></tr></thead>
    <tbody>
      <tr v-for="s in data.servers" :key="s.version">
        <td>{{ s.version }}</td><td>{{ s.date }}</td><td>{{ s.api }}</td><td>{{ s.minApp }}</td>
      </tr>
    </tbody>
  </table>
  <h4>{{ t.apps }}</h4>
  <p v-if="data.apps.length === 0">{{ t.none }}</p>
  <table v-else class="compat">
    <thead><tr><th>{{ t.version }}</th><th>{{ t.date }}</th><th>{{ t.fits }}</th></tr></thead>
    <tbody>
      <tr v-for="a in data.apps" :key="a.version">
        <td>{{ a.version }}</td><td>{{ a.date }}</td><td>{{ fits(a.api) }}</td>
      </tr>
    </tbody>
  </table>
</template>

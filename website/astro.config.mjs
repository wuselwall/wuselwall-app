import { defineConfig } from 'astro/config';
import node from '@astrojs/node';
import sitemap from '@astrojs/sitemap';

// Content pages are prerendered to HTML at build time; the Node server (standalone
// adapter) serves them and renders the few dynamic routes (/healthz) per request.
export default defineConfig({
  site: 'https://wuselwall.app',
  output: 'static',
  adapter: node({ mode: 'standalone' }),
  trailingSlash: 'always',
  build: { format: 'directory' },
  integrations: [
    sitemap({
      i18n: { defaultLocale: 'de', locales: { de: 'de-CH', en: 'en' } },
    }),
  ],
  server: { host: true, port: 4321 },
});

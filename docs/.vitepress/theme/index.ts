import type { Theme } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import CompatTable from './CompatTable.vue'
import Shot from './Shot.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('Shot', Shot)
    app.component('CompatTable', CompatTable)
  },
} satisfies Theme

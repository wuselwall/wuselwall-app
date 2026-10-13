<script setup lang="ts">
// A screenshot from docs/tools/screenshots.mjs in the page's language and the reader's
// theme: both images are in the page, CSS shows one (custom.css), and the hidden one is
// lazy, so it is only fetched when the reader switches.
//   <Shot name="shopping-phone" alt="…" />   <Shot name="wall-shopping" alt="…" wide />
import { computed } from 'vue'
import { useData, withBase } from 'vitepress'

const props = defineProps<{ name: string; alt: string; wide?: boolean }>()
const { lang } = useData()
const dir = computed(() => (lang.value.startsWith('en') ? 'en' : 'de'))
const src = (suffix: string) => withBase(`/screenshots/${dir.value}/${props.name}${suffix}.png`)
</script>

<template>
  <img class="shot shot-light" :class="{ wide }" :src="src('')" :alt="alt" loading="lazy">
  <img class="shot shot-dark" :class="{ wide }" :src="src('-dark')" :alt="alt" loading="lazy">
</template>

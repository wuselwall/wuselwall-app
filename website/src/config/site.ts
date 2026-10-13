// The one place that holds facts about the operator and the outside world. Everything
// marked TODO must be filled in before the site goes live: with LEGAL_STRICT=1 the build
// fails while any value still starts with "TODO".

export const site = {
  name: 'WuselWall',
  url: 'https://wusel.goomba.ch',
  // The Flutter web app, served by nginx beside this site (specs/10).
  webApp: '/app/',
  github: 'https://github.com/wuselwall/wuselwall-app',
  // The user documentation (docs/), also served by nginx; English under /docs/en/.
  docs: '/docs/',
  license: 'TODO: licence name (e.g. AGPL-3.0)',
  // Store listings. Assumed URLs until the apps are published (specs/16 step 7).
  stores: {
    ios: 'https://apps.apple.com/app/wuselwall/id0000000000',
    android: 'https://play.google.com/store/apps/details?id=ch.goomba.wuselwall',
  },
} as const;

export const legal = {
  operator: 'TODO: full name',
  street: 'TODO: street and number',
  city: 'TODO: postcode and city',
  country: 'TODO: country',
  email: 'TODO: contact e-mail',
  phone: '', // optional; leave empty to omit
} as const;

/** Keys of `legal` that still hold a placeholder. */
export const unfilledLegal: string[] = Object.entries(legal)
  .filter(([, v]) => v.startsWith('TODO'))
  .map(([k]) => k);

if (process.env.LEGAL_STRICT === '1' && unfilledLegal.length > 0) {
  throw new Error(`LEGAL_STRICT: fill in src/config/site.ts (${unfilledLegal.join(', ')})`);
}

// The one place that holds facts about the operator and the outside world. Everything
// marked TODO must be filled in before the site goes live: with LEGAL_STRICT=1 the build
// fails while any value still starts with "TODO".

export const site = {
  name: 'WuselWall',
  url: 'https://wuselwall.app',
  github: 'https://github.com/wuselwall/wuselwall-app',
  // The user documentation (docs/), also served by nginx; English under /docs/en/.
  docs: '/docs/',
  license: {
    name: 'Apache-2.0',
    url: 'https://github.com/wuselwall/wuselwall-app/blob/main/LICENSE',
  },
  // Store listings. Empty until the app is live there: the official badges may only
  // link to an app that is available in the store (Apple's badge licence), so the page
  // shows "coming soon" instead. Fill in the product page URLs on release.
  stores: {
    ios: '',
    android: '',
  },
} as const;

// A private, non-commercial open-source project: name, country and an e-mail address
// identify the controller (Art. 19 DSG, Art. 13 GDPR). Street, city and phone are
// optional and left empty on purpose; an empty value is simply not shown. A postal
// address becomes necessary if WuselWall is ever offered commercially (Art. 3 para. 1
// lit. s UWG).
export const legal = {
  operator: 'Daniel Huser',
  street: '',
  city: '',
  country: 'CH', // ISO 3166 code; pages show its name in their own language
  email: 'contact@wuselwall.app',
  phone: '',
  // How many days the web server keeps the website's access logs (visitors' IP
  // addresses). The privacy policy promises this number, so it must match the server's
  // log rotation.
  logRetentionDays: '30',
} as const;

/** The operator's country in the page's language ("Schweiz", "Switzerland"). */
export function countryName(lang: string): string {
  return new Intl.DisplayNames([lang], { type: 'region' }).of(legal.country) ?? legal.country;
}

/** Keys of `legal` that still hold a placeholder. */
export const unfilledLegal: string[] = Object.entries(legal)
  .filter(([, v]) => v.startsWith('TODO'))
  .map(([k]) => k);

if (process.env.LEGAL_STRICT === '1' && unfilledLegal.length > 0) {
  throw new Error(`LEGAL_STRICT: fill in src/config/site.ts (${unfilledLegal.join(', ')})`);
}

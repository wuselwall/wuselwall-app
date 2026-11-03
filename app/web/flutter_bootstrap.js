{{flutter_js}}
{{flutter_build_config}}
// CanvasKit always comes from this origin, never from Google's CDN, even in a build made
// without --no-web-resources-cdn (the docs' demo): the web app loads nothing from a third
// party (NFR-9), and the Content-Security-Policy in index.html allows scripts from 'self'
// only (security review 2026-11-01, F25). The symbol fonts' fallback shards come from
// this origin too (scripts/web-font-fallback.sh).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
    fontFallbackBaseUrl: new URL('font-fallback/', document.baseURI).href,
  },
});

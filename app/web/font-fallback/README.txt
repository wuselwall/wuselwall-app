This same-origin path is Flutter Web's font fallback namespace. The bootstrap points
fontFallbackBaseUrl here so missing glyphs never cause a request to an arbitrary
font CDN. No fallback font files are bundled in this directory yet; unsupported
glyphs may remain missing.

If a future language pack needs additional glyph coverage, add reviewed, pinned
font files at the exact paths expected by the Flutter engine and update this note.
Keep those files and requests on this origin; do not redirect this namespace to a
third-party CDN.

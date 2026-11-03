This same-origin path is Flutter Web's font fallback namespace. The bootstrap points
fontFallbackBaseUrl here so missing glyphs never cause a request to a third-party font
CDN. The browser fetches a shard only when text needs a glyph the bundled fonts lack
(an emoji, a Cyrillic or CJK name, a symbol).

The shards themselves (Noto fonts, SIL Open Font License 1.1, see OFL.txt) are not
checked in: scripts/web-font-fallback.sh copies them into every published web build,
pinned by SHA-256 in scripts/web-font-fallback.lock. A Flutter update that changes the
list fails that script until the lock is regenerated with --update.

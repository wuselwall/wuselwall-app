// The passkeys plugin initialises a JavaScript SDK at start-up and throws without it,
// which blanks the whole web build. Until the SDK is self-hosted (specs/16, step 5.7;
// no third-party origin, NFR-9) this no-op keeps the app starting; a passkey call then
// fails like any other error. A file of its own, not an inline script, so the
// Content-Security-Policy needs no 'unsafe-inline' for scripts.
window.PasskeyAuthenticator = window.PasskeyAuthenticator || { init() {} };

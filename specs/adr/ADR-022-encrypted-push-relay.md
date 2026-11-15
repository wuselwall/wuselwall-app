# ADR-022 — An optional encrypted push relay for self-hosted servers

**Status:** Accepted · 2026-11-15 · Not implemented · Answers Q47 and Q38;
amends [ADR-018](ADR-018-self-hosted-only.md), decisions 1 and 10, and its
2026-10-21 no-service rule only for push transport.

## Context

Local reminders can announce events the phone already knows about. Realtime can tell a
running app that somebody else changed something. Neither reaches a suspended or
terminated app reliably. A family asked for exactly that on 2026-11-14: when somebody
starts shopping, tell the other adults while they can still add something to the list.
[#242](https://github.com/wuselwall/wuselwall-app/issues/242) built the running-app part.
In [#243](https://github.com/wuselwall/wuselwall-app/issues/243#issuecomment-6894901234)
the owner answered on 2026-11-15: “yes, make push happen”. This meets Q47's condition of
a real case from use; continuing to wait for that case is no longer the decision.

The store app's APNs and FCM credentials belong to the project. Giving those credentials
to arbitrary self-hosted servers would let any operator send as the app. Each family
must still choose and run its own backend; push does not reopen WuselWall Cloud.

## Decision

1. **Build an optional, project-operated relay.** A family's server sends an encrypted
   notification and a device destination over HTTPS; the relay forwards it to the fixed
   platform provider. It holds the project's provider credentials. This is the sole
   exception to ADR-018's rule against running a service for others. It offers no
   household hosting, account service, server discovery or sync API. A server and app
   without push keep their existing Realtime, Today notices and local reminders.

2. **Q38: APNs directly for iOS; FCM for Android.** iOS needs neither Firebase registration
   nor a Google SDK for push. Android uses FCM's HTTP v1 sender and the necessary client
   messaging SDK, without Analytics, Crashlytics, delivery analytics or unrelated Firebase
   products. Two native transports and two credential lifecycles are an accepted cost of
   keeping iOS notifications out of Google's path. Android without the required Google
   services retains the existing local/Realtime behaviour; another transport is not part
   of this decision.

3. **Encrypt from the family's server to each receiving device.** The family's server is
   a trusted endpoint and already knows the data. Use a reviewed authenticated-encryption
   construction and separate device keys, provisioned over the authenticated server
   connection; decryption keys never reach the relay or provider. Notification text,
   type, member/list/event identifiers, navigation and any family server address belong
   inside the ciphertext. The outer envelope carries only the version, routing and
   cryptographic material and bounded delivery controls. Exact algorithms, key lifecycle,
   envelope limits and replay handling must be specified and tested in the implementation;
   this ADR does not approve an invented cryptographic protocol.

4. **Stateless means no persistent registry or message history at the relay.** Device
   registrations and a durable delivery outbox belong on the family's server. The relay
   processes tokens and ciphertext in memory, forwards synchronously, and returns the
   provider's result. It keeps no delivery queue, household database or notification
   archive. Short-lived bounded abuse-control counters and aggregate health metrics are
   allowed. Tokens, capabilities, ciphertext, request bodies and client/server addresses
   must be excluded from application, proxy and error logs. Provider credentials remain
   persistent secrets, with rotation and an outage/disable runbook.

   This is **content privacy, not anonymity**: the relay sees the sender's network address,
   destination token/platform, timing and size; Apple or Google sees its device token and
   delivery metadata, ciphertext and any generic alert fallback, and may queue messages
   until expiry. “No household data” means no plaintext household content or persistent
   family records at the relay, not zero processing of personal data. Privacy notices and
   store disclosures must say this before production traffic starts. Host the relay in
   the EU under NFR-8; this does not promise EU-only processing by APNs or FCM.

5. **Authorize destinations and bound abuse.** A token alone must not authorize an arbitrary
   caller to use the project's credentials. The implementation must prove registration
   authority, bind sending authorization to the receiving device and authorized sender,
   expire/renew that authorization and prevent cross-device token substitution. No
   app-wide secret in the public binary. Per-sender/device and global limits, bounded
   registration and send requests, fixed provider destinations and redacted errors are
   required. The relay never fetches a supplied server URL or accepts Supabase sessions
   or service-role keys. The concrete registration/capability protocol needs a security
   review before deployment; statelessness is not permission to run an open sender.

6. **A visible alert must work without the Flutter UI running or a server fetch.** iOS
   uses an APNs alert with `mutable-content` and a bundled notification service extension
   that decrypts with securely shared device key material. A generic localized fallback
   reveals no household content if the extension cannot finish. A silent background push
   alone does not meet the requirement. Android receives encrypted FCM data and decrypts
   and displays it locally within its bounded background execution window. High priority
   is reserved for time-sensitive, visible alerts. Permission, native fallback text and
   presentation cover DE/EN/FR/ES. Provider acceptance is not proof of delivery; expired,
   invalid and replayed content must not be presented as a current family event.

7. **Start with the shopping-trip notice.** Only the other adults' opted-in personal
   phones, respecting `notify.shopping_start`, device consent/OS permission and existing
   notification preferences. No shopper, child, kiosk or web delivery in this slice.
   Transactional outbox creation on the family's server ensures dispatch after commit
   without a connected client. Retries are bounded by the trip's usefulness; the client
   and Realtime path share a notification identity to avoid duplicate alerts. Taps use
   the already selected server, revalidate the notice and never establish a session or
   switch servers. Sign-out, revocation, account/family deletion, server change and token
   rotation retire registrations and keys and invalidate stale pending work.

   Reward requests and verified chores are later consumers, separately implemented and
   opted in. Digest policy remains [#143](https://github.com/wuselwall/wuselwall-app/issues/143).
   Scheduled event, morning and packing reminders remain local.

## Alternatives considered

- **Local/Realtime only:** built and retained as fallback; does not meet the closed-phone
  shopping request.
- **Provider credentials on every family server:** exposes the store app's sending
  authority to every operator. Separate signed app builds per family are not a practical
  store distribution route.
- **FCM for both platforms:** less sender/client integration, but adds Google to the iOS
  push path. Q38's existing APNs-direct preference is retained.
- **A relay with plaintext notifications or a persistent device database:** easier routing
  and presentation, but creates avoidable central access to family content or records.

## Consequences and delivery

The project takes on availability, abuse response, provider credentials and operating
costs for one small service. Push remains best effort: permission, Focus/Doze, connectivity,
provider expiry and force-stop behaviour can prevent or delay presentation. Today remains
the source of current notices. The family server retries transient errors from its own
outbox; a relay failure must never fail or roll back a shopping action.

**Decision completed; implementation still open in
[#274](https://github.com/wuselwall/wuselwall-app/issues/274).** That issue owns the
portable server contract and RLS tests, native integrations and signing, relay protocol
review and operations, all four guides, and physical iOS/Android closed-phone evidence.
New capability discovery and API-version compatibility must preserve previous apps and
servers. Deployment, credentials and publication are separate from this decision PR;
no relay endpoint or operator infrastructure is designated here.

The separate marketing repository tracks localized public-progress and privacy changes
in [website #19](https://github.com/wuselwall/wuselwall-website/issues/19) before activation;
an approved decision must not be advertised as shipped push.

### Platform references

- [Apple: modifying content in newly delivered notifications](https://developer.apple.com/documentation/usernotifications/modifying-content-in-newly-delivered-notifications)
  documents the alert/`mutable-content` extension, decryption and timeout fallback.
- [Apple: sending requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)
  documents best-effort delivery and expiry.
- [Firebase: message types](https://firebase.google.com/docs/cloud-messaging/customize-messages/set-message-type)
  distinguishes data from notification messages and transport encryption from E2EE.
- [Firebase: Android message priority](https://firebase.google.com/docs/cloud-messaging/android-message-priority)
  documents processing limits, visible alerts and deprioritization.
- [Firebase: receiving messages in Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
  documents registration, permission and Android force-stop limitations.

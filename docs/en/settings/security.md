# Security

Sign-in and security settings exist only on a parent's **personal phone**: **Settings → Account & security → Sign-in** and **Settings → Account & security → Security**.

## Sign-in

This lists the ways you can sign in: the **code by email**, which is always there when your server sends email, and a **password** (see [Account and family](/en/settings/account#password)). On a server without email, only the password is listed.

<Shot name="settings-sign-in" alt="Settings → Sign-in" />

- **Password**: **Set password** or **Change password** sets one up.

## Two-factor sign-in

On top of the password, WuselWall asks for a **6-digit code** from an authenticator app at every sign-in (your password manager's app, or one from Google, Microsoft or Aegis, for example).

1. Next to **Two-factor sign-in**, tap **Turn on**.
2. Scan the QR code with the authenticator app.
3. Enter the 6-digit code the app shows.

From then on every new sign-in asks for the code; without it a phone sees **none** of the household's data. **Turn off** takes it back.

## Parent PIN

The 6-digit PIN you enter on shared devices ([Who are you?](/en/guide/who-are-you)). Here you set a **new PIN** — even if the old one is **locked** after too many wrong tries. Only your own, signed-in phone may do this.

## Passkey

With a **passkey** you sign in by fingerprint or face instead of a password. Not every device supports it.

## Good to know

- **Password**: at least 10 characters; a whole sentence is better.
- **Lost phone**: **block** it at once from another device (see [Members and devices](/en/settings/members-devices#block-a-device)).
- **Your data** lives on the server your family chose. If you use Supabase or another hosting provider, that provider hosts it; WuselWall runs no data service for your family.

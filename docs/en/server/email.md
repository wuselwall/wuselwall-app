# Email (optional)

A WuselWall server works **with or without email**. Without it, everyone signs up and signs in with their email address and a password. With it, the server sends a **six-digit sign-in code**, so nobody needs to remember a password.

| | Without email | With email |
|---|---|---|
| **Signing up** | Email address and password. The app opens on **New account** | A code by email; a password is optional |
| **Forgotten password** | A guardian gives you a one-time code ([below](#forgotten-password)) | A code by email |
| **Invitations** | By link, QR code or invitation code | The same, and an invitation that names your address finds you on its own |
| **Who else sees something** | Nobody | The mail provider sees addresses and codes |

On a server without email, nobody checks the address: anyone could type any address. That is fine, because an account on its own sees nothing. Only an invitation or the setup code lets it into a family. For the same reason, a server without email never hands an invitation to an account just because the addresses match.

You can switch email on or off at any time. Accounts keep their password; once email is on, they can also sign in with a code. The app notices the change the next time it starts.

## Setting it up {#setup}

### Server at home or rented

On the server, in the directory of the `wuselwall` tool ([Server at home](/en/server/home-server)):

```bash
./wuselwall mail smtp --gmail --user familie.miller@gmail.com
```

The tool asks for the password. It never appears in the command line or in the shell's history. For any other provider, give its server instead of `--gmail`:

```bash
./wuselwall mail smtp --host smtp.example.org --port 587 --user wuselwall@example.org
```

`--sender` sets a sender address that differs from the user name, and `--name` sets the sender's name (default: WuselWall). The tool writes the values into `stack/.env` and restarts only sign-in. Then:

| Command | What it does |
|---|---|
| `./wuselwall mail test you@example.org` | Sends a test message through the server you entered. If it fails, the tool says so |
| `./wuselwall mail` | Shows whether and how the server sends mail |
| `./wuselwall mail off` | No more email: sign-in with password only |

The **email language** is chosen separately, with `./wuselwall language` ([Server at home](/en/server/home-server#email-language)).

### At Supabase

Create five more repository secrets in your copy on GitHub ([Server at Supabase](/en/server/supabase-cloud#mail)), then run **deploy-supabase** again:

| Secret | Gmail |
|---|---|
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | your Gmail address |
| `SMTP_PASS` | the app password (below) |
| `SMTP_SENDER` | your Gmail address |

Without these secrets, the workflow sets up the server without email. Delete them and run it again to switch email off.

## With Gmail {#gmail}

A Gmail account is the quickest way to send the codes: no domain, no DNS records, free. Google requires an **app password** for it, a separate 16-letter password just for WuselWall.

1. **Use an account of its own.** Take a Gmail address that exists only for the family server, for example `familie.miller.wuselwall@gmail.com`. An app password opens the whole mailbox: whoever reads `stack/.env` could read and send that account's mail. A separate account keeps your own mail out of it.
2. **Turn on 2-Step Verification.** At [myaccount.google.com](https://myaccount.google.com/) → **Security** → **2-Step Verification**. Without it, Google offers no app passwords.
3. **Create the app password.** Open [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords), enter a name such as `WuselWall` and tap **Create**. Google shows 16 letters in four groups. Copy them; Google shows them only once.
4. **Enter it on the server.**

   ```bash
   ./wuselwall mail smtp --gmail --user familie.miller.wuselwall@gmail.com
   ./wuselwall mail test you@example.org
   ```

   At the prompt, paste the 16 letters (the spaces don't matter). At Supabase, they go into `SMTP_PASS`.
5. **Try it.** In the app, **Continue with email** now asks for a code by email.

Good to know:

- **Sender:** the codes always come from the Gmail address. Gmail replaces any other sender, unless it is set up in Gmail as a "Send mail as" address.
- **Limits:** Gmail sends about 500 messages a day ([Google](https://support.google.com/mail/answer/22839)). A family needs a handful.
- **Changing the Google password** revokes every app password. The codes then stop arriving: create a new app password and run `./wuselwall mail smtp --gmail …` again.
- **Not available** with 2-Step Verification by security keys only, with Google's Advanced Protection, and for most work or school accounts ([Google](https://support.google.com/mail/answer/185833)). Google Workspace has its own SMTP relay for that.
- **Google sees** the addresses and the codes, as any mail provider does.

## Other providers {#providers}

| Provider | Works? |
|---|---|
| **Your mailbox** at a provider such as GMX, web.de, Posteo, mailbox.org or Infomaniak | Usually yes: server, port (`587`) and user name are on the provider's help pages; the password is the mailbox's, or an app password where the provider offers one. Some providers want access for mail programs switched on in the mailbox settings first |
| **Outlook.com, Hotmail** | No. Microsoft accepts only its own sign-in (OAuth) for sending, no password |
| **A service for transactional mail** (for example Scaleway Transactional Email, Brevo, Mailjet) | Yes, with a domain of your own: add the records the provider names (SPF, DKIM, DMARC), or the mails land in spam. More work to set up, the best delivery |

Port `587` is the usual one; `465` works too. Names are examples, not recommendations; WuselWall is not affiliated with any of these providers.

**Scaleway with the WuselWall function:** instead of SMTP, the server can also hand its mails to Scaleway's interface. At home, put `SCW_SECRET_KEY`, `SCW_PROJECT_ID` and `MAIL_FROM` into `stack/.env` before the installation; at Supabase, they are secrets of the same names.

## Forgotten password without email {#forgotten-password}

1. A **guardian** opens **Settings → Family → Members** on their own phone, taps **Reset password** next to the person's name and confirms with **Create code**.
2. The app shows an **8-character code**. It works **once**, for **10 minutes**. Hand it over in person, not by message.
3. On the device of the person who forgot: **Continue with email** → **Sign in** → **Forgot your password?** Then the email address, the code and a new password of at least 10 characters.

If two-factor sign-in is on for the account, it still asks for the authenticator's code: the reset code replaces only the password.

**The only guardian forgot?** Whoever runs the server creates the same code:

- At home or rented: `./wuselwall password address@example.org`
- At Supabase: in the dashboard under **SQL Editor**: `select app.password_reset_issue_for_email('address@example.org') ->> 'code';`

Both work for every account except shared devices, and both are recorded in the family's log.

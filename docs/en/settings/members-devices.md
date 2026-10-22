# Members and devices

This belongs to the **guardians**. On your phone, open the cog at the top right (**Settings**).

<Shot name="settings-phone" alt="Settings with members and devices" />

## Basic or Advanced {#view}

At the top of the settings you choose the view. **Basic** is the default and shows what matters most: household settings, usual week, reminders, language, appearance, getting started, members and devices, and on your own phone also **Delete account**. **Advanced** also shows sharing the family calendar, outside calendars, apps and AI assistants, the server, the data export, sign-in, security, and leaving the family.

Whatever is hidden **still applies**. The view only changes what you see, and WuselWall remembers it for each device. The same goes for **Household settings**.

## Invite an adult

Invite a person who should take part in the family with their own account. Under **Members**, tap **Invite an adult**:

1. Enter the **name** and choose the **role**: **Guardian** sees everything and approves rewards. **Member** does tasks but does not approve rewards (for example an au pair or grandparents).
2. Optionally an **email address**. If the person signs in with exactly this address, they find the invitation by themselves.
3. Tap **Create invitation**.

<Shot name="invite-sheet" alt="Invitation for Oma Ruth with code, QR code and share" />

WuselWall then shows the **code**, your family's **server**, a **QR code** and the **link**. Tap **Share** to send them, for example in a message. The link and the QR code name the server: the person taps the link or scans the QR code, and WuselWall opens directly with the invitation, without choosing a server. Whoever only has the code enters it in WuselWall, together with the server if asked; see [Signing in and connecting](/en/guide/setup#_3-joining-a-family).

An invitation is valid for **7 days** and works **once**. Open invitations appear directly in the invited member’s row with their expiry date: **Share again** sends it once more, **Withdraw** cancels it.

Once the person has joined, **every guardian** gets a notice on the **Today** tab ("Sarah joined"). **Got it** hides it, **Members** leads to the list. Notices disappear on their own after 14 days.

If you left out the email address, the code is all there is. The person then has to enter it in the app.

For an existing **member** without an account, invite them from the member list with **Invite**.

::: tip No account needed
Children do not need an invitation. Add them as a member with a name, and connect their device as described under [Connect a device](#connect-a-device).
:::

## Add member

With the icon next to **Members** you add a person by **name** only, for example a child or someone who is not on WuselWall. WuselWall gives the next free **colour** automatically.

## Reset two-factor

If another guardian has lost their second factor, tap **Reset two-factor** next to their name. Then they can sign in without the second factor and set it up again (see [Security](/en/settings/security#two-factor-sign-in)).

## Connect a device

To connect a kids' tablet, a shared tablet or the wall display: under **Devices**, tap **Connect a device**, scan the QR code or type in the code the new device shows, and choose the kind and a name. The whole process is shown under [Signing in and connecting](/en/guide/setup#_4-connecting-a-family-tablet-or-wall-display).

<Shot name="pair-approve" alt="A guardian's phone: check the device and connect it" />

You do not need to type the code: the new device shows a QR code that you scan with your phone's camera. It also contains the server; WuselWall opens right at the confirmation. If the link belongs to a different server than the one you are signed in on, the app does not follow it by itself but tells you so.

Older devices with an older version of WuselWall still get a code from **Create a code for an older device**. This option goes away with the next version.

## Block a device

If a phone is lost or a tablet is handed on: in the device list, tap **Block**. The device loses access **at once**, even if it is open. Blocked devices stay in the list so that you can see what happened.

When you sign in with your account on a new phone, your other phones show the notice "New sign-in: Daniel's iPhone" on the **Today** tab. **Devices** leads to the device list, where **Block** shuts out a device that is not yours.

On your own phone you can also sign yourself out with **Sign out this device**.

## Server {#server}

Under **Advanced**, this shows which server the app talks to, with its **QR code**. A new device scans it at the question **Which server?** and is then connected to the same server.

You only need **Change server** when your family moves to another server. The device signs out and forgets everything stored on it, including shopping it could not send yet. On shared devices WuselWall asks for a guardian's PIN first.

## Export data

Guardians can save all data of your family as one zip file, for example for a move to another server. It is under **Family** at the bottom of the settings (**Advanced** view), with **Export data**, and only from a guardian's own phone.

The file contains what you entered: members, appointments, timetables, tasks, recipes, shopping lists and so on. Passwords, PINs and sign-in data are **not** included, and devices appear only with their name and date.

The zip file holds one JSON file per kind of data in the `tables` folder, plus `export.json`, which says what is included and how many entries each file has. After a few years with WuselWall the export can take a minute; keep the app open until it is done. An older server gives you a single JSON file instead.

Leaving and deleting a family is described under [Account and family](/en/settings/account).

## Outside calendars

You subscribe to calendars from clubs or the town under **Settings → Advanced → Add outside calendars**. How this works and what to note is described under [Calendar](/en/calendar/#outside-calendars).

## Show Getting started again

If you hid the **Getting started** card on the Today tab, bring it back under **Settings → Getting started**. The card shows what is still missing: inviting adults, connecting a tablet, setting up the wall display, setting the PIN, subscribing to calendars, entering the timetable and switching on reminders (see [Reminders](/en/settings/reminders)).

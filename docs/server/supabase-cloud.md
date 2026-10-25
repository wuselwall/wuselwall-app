# Server bei Supabase einrichten

WuselWall läuft auf [Supabase](https://supabase.com/). Supabase vermietet solche Server auch fertig eingerichtet, also braucht euer Familienserver keinen eigenen Rechner und keine Domain. Das Projekt gehört **euch**: Ihr habt das Supabase-Konto, und ihr allein entscheidet über die Daten. Wir haben keinen Zugriff darauf.

Die Daten liegen damit bei **Supabase Inc.**, einer US-Firma. Gespeichert werden sie in einem Rechenzentrum, das ihr beim Anlegen wählt. Nehmt eines in Europa, etwa Frankfurt oder Zürich.

::: warning Noch nicht ganz erprobt
Auf Supabase ist WuselWall noch nicht vollständig durchgetestet. Wenn ein Schritt scheitert, meldet es bitte auf [GitHub](https://github.com/wuselwall/wuselwall-app/issues). Eure Daten gehören nicht in die Meldung.
:::

## Free oder Pro?

| | Free | Pro (etwa 25 US-Dollar im Monat) |
|---|---|---|
| **Pause** | Das Projekt **pausiert nach 7 Tagen ohne Aktivität**. Danach geht nichts mehr, bis du es im Dashboard wieder startest | Keine Pause |
| **Backups** | Keine | Täglich, 7 Tage lang |
| **Platz** | 500 MB Datenbank, für eine Familie lange genug | Mehr als genug |

**Free** reicht zum Ausprobieren. Für den Alltag nehmt **Pro**: Ein pausierter Server legt den Wandbildschirm still, und ohne Backup ist ein Fehler endgültig. Die aktuellen Preise stehen auf [supabase.com/pricing](https://supabase.com/pricing).

## 1. Projekt anlegen

1. Leg ein Konto bei Supabase an und im [Dashboard](https://supabase.com/dashboard) ein neues Projekt, z. B. „WuselWall Familie Muster“.
2. Wähle als **Region** ein Rechenzentrum in Europa.
3. Vergib ein starkes **Datenbank-Passwort** und leg es in den Passwort-Manager.

Die **Projekt-ID** steht danach in der Adresse des Projekts: `https://<projekt-id>.supabase.co`, 20 Buchstaben und Ziffern. Das ist alles, was die App später wissen muss.

## 2. WuselWall aufs Projekt bringen

Das erledigt ein vorbereiteter Ablauf auf GitHub, in eurer eigenen Kopie von WuselWall. Ihr installiert nichts.

1. Leg ein Konto bei [GitHub](https://github.com/) an, falls ihr keines habt.
2. Öffne [github.com/wuselwall/wuselwall-app](https://github.com/wuselwall/wuselwall-app) und tippe auf **Fork**. Das ist eure Kopie.
3. Erzeuge bei Supabase ein **Access Token**: Profilbild → **Account preferences → Access Tokens → Generate new token**.
4. In eurer Kopie auf GitHub: **Settings → Secrets and variables → Actions → New repository secret**. Lege diese an:

   | Name | Wert |
   |---|---|
   | `SUPABASE_ACCESS_TOKEN` | das Access Token aus Schritt 3 |
   | `SUPABASE_PROJECT_ID` | die Projekt-ID |
   | `SUPABASE_DB_PASSWORD` | das Datenbank-Passwort |
   | `WUSELWALL_SETUP_TOKEN` | ein Satz eurer Wahl aus Buchstaben und Ziffern, z. B. `KuchenAmSonntag2026`. Ihr braucht ihn einmal, um die Familie zu gründen |
   | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_SENDER` | der SMTP-Zugang eures Mail-Anbieters, fünf Secrets; `SMTP_SENDER` ist die Absenderadresse. Statt SMTP geht Scaleway: `SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `MAIL_FROM`. Warum das Pflicht ist, steht unter [E-Mail-Versand](#e-mail-versand) |

5. Öffne den Reiter **Actions**. In einer Kopie sind die Abläufe zuerst ausgeschaltet: Tippe auf **I understand my workflows, go ahead and enable them**. Dann **deploy-supabase → Run workflow**. Wähle bei **language** die Sprache der Anmelde-Mails: `de` (Standard), `en`, `fr` oder `es`. Setze den Haken bei **web**, wenn ihr die Web-App wollt (Schritt 4), und tippe auf **Run workflow**. Der Haken **without mail** ist nur fürs Ausprobieren ohne Mail-Versand.

Nach ein paar Minuten ist der Lauf grün. In seiner Zusammenfassung steht die Adresse eures Servers. Der Ablauf richtet die Datenbank ein, stellt Anmeldung und Datenzugriff ein, lädt die Server-Funktionen hoch, wählt die Mail-Templates und Betreffzeilen in der gewählten E-Mail-Sprache und plant die nächtlichen Aufträge. Zum Schluss prüft er den Server: Antwortet er der App, erreichen die vier Aufträge ihre Funktionen, sind Anmeldung und Mail-Versand eingestellt? Scheitert eine Prüfung, wird der Lauf rot und nennt den Grund.

::: tip Geheimnisse bleiben geheim
Die Protokolle eurer Kopie kann jeder sehen, die Secrets nicht: GitHub blendet sie überall aus. Den Satz für die Familiengründung speichert der Server nur als Fingerabdruck.

Das Access Token darf alles in eurem Supabase-Konto. Wer vorsichtig ist, löscht es nach dem Lauf bei Supabase und legt für das nächste Update ein neues an.
:::

## E-Mail-Versand {#e-mail-versand}

Wer sich anmeldet, bekommt einen Code per Mail, auch ihr selbst beim ersten Mal. Der eingebaute Mail-Versand von Supabase schickt aber nur an die Adressen eures eigenen Supabase-Kontos und nur ein paar Mails pro Stunde. Darum braucht der Server einen Mail-Anbieter, bevor die Familie beitritt:

- **SMTP:** ein Transaktions-Mail-Dienst eurer Wahl, am besten einer in Europa. Trag seine Zugangsdaten als die fünf `SMTP_`-Secrets ein. Was ein guter Anbieter ist und welche DNS-Einträge er braucht, steht in den [Extras](/server/extras#e-mail).
- **Scaleway:** wie beim Server zu Hause schickt dann die WuselWall-Funktion die Mails über Scaleway Transactional Email. Secrets: `SCW_SECRET_KEY`, `SCW_PROJECT_ID` und `MAIL_FROM` (optional `SCW_REGION`, `MAIL_FROM_NAME`).

Ohne eines von beiden bricht der Lauf ab. Nur zum Ausprobieren setzt du den Haken **without mail**: Dann kommen Codes nur an die Adressen eures Supabase-Kontos. Trag die Secrets nach und starte den Lauf erneut, bevor die anderen beitreten.

## 3. Die App verbinden

Öffne WuselWall. Auf die Frage **Mit welchem Server?** gibst du die **Projekt-ID** ein und tippst auf **Verbinden**. Dann **Neue Familie anlegen** mit dem Satz aus `WUSELWALL_SETUP_TOKEN` ([Neue Familie anlegen](/guide/setup#_3-neue-familie-anlegen-nur-einmal)).

<Shot name="setup-server" alt="Die Frage nach dem Server" />

## 4. Die Web-App

Solange WuselWall nicht in den Stores steht, benutzt ihr die Web-App. Mit dem Haken bei **web** veröffentlicht GitHub sie für euch unter `https://<euer-github-name>.github.io/wuselwall-app/`. Dafür stellst du einmal in eurer Kopie unter **Settings → Pages** die **Source** auf **GitHub Actions**. Beim ersten Öffnen fragt die Web-App nach dem Server, wie die App.

GitHub sieht dabei, wer die Web-App aufruft, aber nicht eure Daten: Die gehen direkt vom Browser zu Supabase. Wer das nicht will, lädt die Web-App aus einem [Server-Release](https://github.com/wuselwall/wuselwall-app/releases) zu einem Webspace eurer Wahl hoch.

## Updates

Neue WuselWall-Versionen holst du in eure Kopie: auf GitHub **Sync fork → Update branch**. Danach **Actions → deploy-supabase → Run workflow**, wie beim ersten Mal. Um Postgres, Sicherheitsupdates und HTTPS kümmert sich Supabase.

Kommst du von einer Version mit Anmeldung über Apple oder Google? Lies zuerst [Update von einer Version mit Apple- und Google-Anmeldung](/server/extras#social-stilllegen).

## Backups

Mit **Pro** sichert Supabase jeden Tag und behält die Sicherungen 7 Tage. Zurückspielen kannst du sie im Dashboard unter **Database → Backups**. Eine eigene Kopie, etwa einmal im Monat, beschreibt [Backup zurückspielen](/server/restore#bei-supabase).

::: details Lieber mit der Kommandozeile?
Mit Node.js und dem Repository auf dem Laptop geht dasselbe in einem Terminal. Die Befehle und Einstellungen stehen der Reihe nach in `.github/workflows/deploy-supabase.yml`: `supabase link`, `supabase db push`, die Management API (Data API, und Auth über `scripts/hosted-auth-config.mjs`), `supabase secrets set`, `supabase functions deploy`, das SQL aus `infra/jobs/schedule.sql` und die Prüfung am Ende.
:::

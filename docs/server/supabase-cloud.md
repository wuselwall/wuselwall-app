# Server bei Supabase einrichten

WuselWall läuft auf [Supabase](https://supabase.com/). Supabase vermietet solche Server auch fertig eingerichtet, also braucht ihr keinen eigenen Rechner und keine Domain. Das Projekt gehört **euch**: Ihr habt das Supabase-Konto, und ihr allein entscheidet über die Daten. Wir haben keinen Zugriff darauf.

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

5. Öffne den Reiter **Actions**. In einer Kopie sind die Abläufe zuerst ausgeschaltet: Tippe auf **I understand my workflows, go ahead and enable them**. Dann **deploy-supabase → Run workflow**. Setze den Haken bei **web**, wenn ihr die Web-App wollt (Schritt 4), und tippe auf **Run workflow**.

Nach ein paar Minuten ist der Lauf grün. In seiner Zusammenfassung steht die Adresse eures Servers. Der Ablauf richtet die Datenbank ein, stellt Anmeldung und Datenzugriff ein, lädt die Server-Funktionen hoch und plant die nächtlichen Aufträge.

::: tip Geheimnisse bleiben geheim
Die Protokolle eurer Kopie kann jeder sehen, die Secrets nicht: GitHub blendet sie überall aus. Den Satz für die Familiengründung speichert der Server nur als Fingerabdruck.

Das Access Token darf alles in eurem Supabase-Konto. Wer vorsichtig ist, löscht es nach dem Lauf bei Supabase und legt für das nächste Update ein neues an.
:::

## 3. Die App verbinden

Öffne WuselWall. Auf die Frage **Mit welchem Server?** gibst du die **Projekt-ID** ein und tippst auf **Verbinden**. Dann **Neue Familie anlegen** mit dem Satz aus `WUSELWALL_SETUP_TOKEN` ([Neue Familie anlegen](/guide/setup#_3-neue-familie-anlegen-nur-einmal)).

<Shot name="setup-server" alt="Die Frage nach dem Server" />

## 4. Die Web-App

Solange WuselWall nicht in den Stores steht, benutzt ihr die Web-App. Mit dem Haken bei **web** veröffentlicht GitHub sie für euch unter `https://<euer-github-name>.github.io/wuselwall-app/`. Dafür stellst du einmal in eurer Kopie unter **Settings → Pages** die **Source** auf **GitHub Actions**. Beim ersten Öffnen fragt die Web-App nach dem Server, wie die App.

GitHub sieht dabei, wer die Web-App aufruft, aber nicht eure Daten: Die gehen direkt vom Browser zu Supabase. Wer das nicht will, lädt die Web-App aus einem [Server-Release](https://github.com/wuselwall/wuselwall-app/releases) zu einem Webspace eurer Wahl hoch.

## Updates

Neue WuselWall-Versionen holst du in eure Kopie: auf GitHub **Sync fork → Update branch**. Danach **Actions → deploy-supabase → Run workflow**, wie beim ersten Mal. Um Postgres, Sicherheitsupdates und HTTPS kümmert sich Supabase.

Kommt ihr von einer Version mit Anmeldung über Apple oder Google, lies vorher [Update von einer Version mit Apple- und Google-Anmeldung](/server/extras#social-stilllegen).

## Backups

Mit **Pro** sichert Supabase jeden Tag und behält die Sicherungen 7 Tage. Zurückspielen kannst du sie im Dashboard unter **Database → Backups**. Eine eigene Kopie, etwa einmal im Monat, beschreibt [Backup zurückspielen](/server/restore#bei-supabase).

::: details Lieber mit der Kommandozeile?
Mit Node.js und dem Repository auf dem Laptop geht dasselbe in einem Terminal. Die Befehle und Einstellungen stehen der Reihe nach in `.github/workflows/deploy-supabase.yml`: `supabase link`, `supabase db push`, zwei Aufrufe der Management API (Data API und Auth), `supabase secrets set`, `supabase functions deploy` und das SQL aus `infra/jobs/schedule.sql`.
:::

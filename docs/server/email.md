# E-Mail (freiwillig)

Ein WuselWall-Server läuft **mit oder ohne E-Mail**. Ohne meldet sich jede und jeder mit E-Mail-Adresse und Passwort an. Mit E-Mail schickt der Server einen **sechsstelligen Anmelde-Code**, und niemand muss sich ein Passwort merken.

| | Ohne E-Mail | Mit E-Mail |
|---|---|---|
| **Konto anlegen** | E-Mail-Adresse und Passwort. Die App öffnet mit **Neues Konto** | Ein Code per Mail; ein Passwort ist freiwillig |
| **Passwort vergessen** | Ein Erziehungsberechtigter gibt dir einen Einmal-Code ([unten](#passwort-vergessen)) | Ein Code per Mail |
| **Einladungen** | Per Link, QR-Code oder Einladungscode | Genauso, und eine Einladung, die deine Adresse nennt, findet dich von selbst |
| **Wer sonst etwas sieht** | Niemand | Der Mail-Anbieter sieht Adressen und Codes |

Auf einem Server ohne E-Mail prüft niemand die Adresse: Man könnte jede beliebige eintippen. Das ist in Ordnung, denn ein Konto allein sieht nichts. Erst eine Einladung oder der Einrichtungs-Code bringt es in eine Familie. Aus demselben Grund gibt ein Server ohne E-Mail eine Einladung nie einem Konto, nur weil die Adresse passt.

Ihr könnt die E-Mail jederzeit ein- oder ausschalten. Die Konten behalten ihr Passwort; ist E-Mail an, geht zusätzlich der Code. Die App merkt die Änderung beim nächsten Start.

## Einrichten {#einrichten}

### Server zu Hause oder gemietet

Auf dem Server, im Verzeichnis des Werkzeugs `wuselwall` ([Server zu Hause](/server/home-server)):

```bash
./wuselwall mail smtp --gmail --user familie.mueller@gmail.com
```

Das Werkzeug fragt nach dem Passwort. Es landet weder in der Befehlszeile noch im Verlauf der Shell. Für einen anderen Anbieter nennst du statt `--gmail` dessen Server:

```bash
./wuselwall mail smtp --host smtp.example.org --port 587 --user wuselwall@example.org
```

`--sender` setzt eine Absenderadresse, die vom Benutzernamen abweicht, `--name` den Absendernamen (Standard: WuselWall). Das Werkzeug schreibt die Werte in `stack/.env` und startet nur die Anmeldung neu. Danach:

| Befehl | Was er tut |
|---|---|
| `./wuselwall mail test du@example.org` | Schickt eine Testnachricht über den eingetragenen Server. Klappt es nicht, sagt das Werkzeug es |
| `./wuselwall mail` | Zeigt, ob und wie der Server Mails verschickt |
| `./wuselwall mail off` | Keine E-Mail mehr: Anmeldung nur mit Passwort |

Die **E-Mail-Sprache** wählst du getrennt davon, mit `./wuselwall language` ([Server zu Hause](/server/home-server#email-sprache)).

### Bei Supabase

Leg in deiner Kopie auf GitHub fünf weitere Repository-Secrets an ([Server bei Supabase](/server/supabase-cloud#e-mail-versand)) und starte **deploy-supabase** noch einmal:

| Secret | Gmail |
|---|---|
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | deine Gmail-Adresse |
| `SMTP_PASS` | das App-Passwort (unten) |
| `SMTP_SENDER` | deine Gmail-Adresse |

Ohne diese Secrets richtet der Workflow den Server ohne E-Mail ein. Löschst du sie und startest ihn erneut, ist die E-Mail wieder aus.

## Mit Gmail {#gmail}

Ein Gmail-Konto ist der schnellste Weg zu den Codes: keine Domain, keine DNS-Einträge, kostenlos. Google verlangt dafür ein **App-Passwort**, ein eigenes Passwort aus 16 Buchstaben nur für WuselWall.

1. **Nimm ein eigenes Konto.** Am besten eine Gmail-Adresse, die es nur für den Familienserver gibt, etwa `familie.mueller.wuselwall@gmail.com`. Ein App-Passwort öffnet das ganze Postfach: Wer `stack/.env` liest, könnte die Mails dieses Kontos lesen und verschicken. Mit einem eigenen Konto bleibt deine private Post draußen.
2. **Schalte die Bestätigung in zwei Schritten ein.** Unter [myaccount.google.com](https://myaccount.google.com/) → **Sicherheit** → **Bestätigung in zwei Schritten**. Ohne sie bietet Google keine App-Passwörter an.
3. **Leg das App-Passwort an.** Öffne [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords), gib einen Namen wie `WuselWall` ein und tippe **Erstellen**. Google zeigt 16 Buchstaben in vier Gruppen. Kopiere sie; Google zeigt sie nur einmal.
4. **Trag es auf dem Server ein.**

   ```bash
   ./wuselwall mail smtp --gmail --user familie.mueller.wuselwall@gmail.com
   ./wuselwall mail test du@example.org
   ```

   Bei der Frage nach dem Passwort fügst du die 16 Buchstaben ein (die Leerzeichen sind egal). Bei Supabase kommen sie in `SMTP_PASS`.
5. **Probier es aus.** In der App fragt **Mit E-Mail fortfahren** jetzt nach einem Code per Mail.

Gut zu wissen:

- **Absender:** Die Codes kommen immer von der Gmail-Adresse. Gmail ersetzt jeden anderen Absender, außer er ist in Gmail als Adresse unter „Senden als“ eingerichtet.
- **Grenzen:** Gmail verschickt etwa 500 Nachrichten am Tag ([Google](https://support.google.com/mail/answer/22839?hl=de)). Eine Familie braucht eine Handvoll.
- **Änderst du das Google-Passwort**, widerruft Google alle App-Passwörter. Dann kommen keine Codes mehr: neues App-Passwort anlegen und `./wuselwall mail smtp --gmail …` noch einmal ausführen.
- **Nicht verfügbar** bei Bestätigung in zwei Schritten nur mit Sicherheitsschlüsseln, beim Erweiterten Sicherheitsprogramm von Google und für die meisten Arbeits- oder Schulkonten ([Google](https://support.google.com/mail/answer/185833?hl=de)). Google Workspace hat dafür ein eigenes SMTP-Relay.
- **Google sieht** die Adressen und die Codes, wie jeder Mail-Anbieter.

## Andere Anbieter {#andere-anbieter}

| Anbieter | Geht das? |
|---|---|
| **Dein Postfach** bei einem Anbieter wie GMX, web.de, Posteo, mailbox.org oder Infomaniak | Meist ja: Server, Port (`587`) und Benutzername stehen in der Hilfe des Anbieters; das Passwort ist das des Postfachs oder ein App-Passwort, wo es eines gibt. Manche Anbieter wollen, dass du den Zugriff für Mailprogramme vorher in den Postfach-Einstellungen einschaltest |
| **Outlook.com, Hotmail** | Nein. Microsoft nimmt zum Versenden nur noch seine eigene Anmeldung (OAuth) an, kein Passwort |
| **Ein Dienst für transaktionale Mails** (etwa Scaleway Transactional Email, Brevo, Mailjet) | Ja, mit eigener Domain: Trag die Einträge ein, die der Anbieter nennt (SPF, DKIM, DMARC), sonst landen die Mails im Spam. Mehr Aufwand, dafür die beste Zustellung |

Port `587` ist üblich, `465` geht auch. Die Namen sind Beispiele, keine Empfehlungen; WuselWall ist mit keinem dieser Anbieter verbunden.

**Scaleway mit der WuselWall-Funktion:** Statt über SMTP kann der Server seine Mails auch an die Schnittstelle von Scaleway geben. Zu Hause trägst du dafür vor der Installation `SCW_SECRET_KEY`, `SCW_PROJECT_ID` und `MAIL_FROM` in `stack/.env` ein, bei Supabase sind es gleichnamige Secrets.

## Passwort vergessen, ohne E-Mail {#passwort-vergessen}

1. Ein **Erziehungsberechtigter** öffnet auf dem eigenen Handy **Einstellungen → Familie → Mitglieder**, tippt neben dem Namen der Person auf **Passwort zurücksetzen** und bestätigt mit **Code erstellen**.
2. Die App zeigt einen **Code aus 8 Zeichen**. Er gilt **einmal**, **10 Minuten** lang. Gib ihn persönlich weiter, nicht per Nachricht.
3. Auf dem Gerät der Person, die es vergessen hat: **Mit E-Mail fortfahren** → **Anmelden** → **Passwort vergessen?** Dann die E-Mail-Adresse, den Code und ein neues Passwort mit mindestens 10 Zeichen.

Ist für das Konto die Zwei-Faktor-Anmeldung an, fragt sie weiterhin nach dem Code aus der Authenticator-App: Der Rücksetz-Code ersetzt nur das Passwort.

**Der einzige Erziehungsberechtigte hat es vergessen?** Dann erstellt der Betreiber des Servers denselben Code:

- Zu Hause oder gemietet: `./wuselwall password adresse@example.org`
- Bei Supabase: im Dashboard unter **SQL Editor**: `select app.password_reset_issue_for_email('adresse@example.org') ->> 'code';`

Beides geht für jedes Konto außer geteilten Geräten, und beides steht im Protokoll der Familie.

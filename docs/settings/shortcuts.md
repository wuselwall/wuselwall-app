# Siri und Kurzbefehle

Mit der **Kurzbefehle**-App auf dem iPhone sprichst du mit WuselWall über Siri: „Hey Siri, Einkaufsliste“ – „Was brauchst du?“ – „Milch und zwei Gurken“ – „Milch und Gurken (2×) sind auf der Liste.“ Dafür braucht es keine zusätzliche App, nur einen **Schlüssel** aus WuselWall.

<Shot name="shortcuts" alt="Einstellungen → Siri und Kurzbefehle mit zwei Schlüsseln" />

## Was ein Schlüssel darf

Ein Schlüssel gehört zu **einer Person**. Ein Kurzbefehl mit diesem Schlüssel handelt als diese Person: Er hakt ihre Aufgaben ab und nennt ihre Punkte.

- Er kann **lesen**: den Tag, das Essen, den Stundenplan, wer da ist, die Punkte.
- Er kann **hinzufügen**: Dinge auf die Einkaufsliste setzen und eine eigene Aufgabe abhaken.
- Er kann **nichts löschen und nichts verwalten**: keine Termine ändern, keine Punkte korrigieren, keine Einstellungen. Das gilt auch für den Schlüssel eines Erziehungsberechtigten.
- Pro Tag trägt ein Schlüssel höchstens 100-mal etwas ein. Falls ein Kurzbefehl versehentlich in einer Schleife läuft, ist damit Schluss.

## Einen Schlüssel erstellen

1. Öffne **Einstellungen → Siri und Kurzbefehle** und tippe auf **Neuer Schlüssel**.
2. Gib ihm einen **Namen**, zum Beispiel „iPhone“.
3. Als Erziehungsberechtigte·r wählst du unter **Für wen?** die Person. Alle anderen erstellen ihren eigenen Schlüssel auf dem eigenen Handy.
4. Tippe auf **Schlüssel erstellen**.

Der Schlüssel wird **nur einmal** angezeigt, zusammen mit der **Adresse** eures Servers. Kopiere beides. Wer den Schlüssel hat, kann als diese Person lesen und hinzufügen. Behandle ihn deshalb wie ein Passwort. Die Kurzbefehle-App synchronisiert ihn über iCloud auf deine anderen Apple-Geräte.

## Der erste Kurzbefehl: Einkaufsliste

1. Öffne die **Kurzbefehle**-App und tippe auf **+**.
2. Füge die Aktion **Nach Eingabe fragen** hinzu. Frage: „Was brauchst du?“
3. Füge **Inhalte von URL abrufen** hinzu:
   - **URL:** die Adresse aus WuselWall mit `/shopping` am Ende, also etwa `https://api.example.org/functions/v1/shortcuts/shopping`
   - **Methode:** POST
   - **Header:** Schlüssel `Authorization`, Wert `Bearer ` (mit Leerzeichen) und dahinter dein Schlüssel
   - **Hauptteil der Anfrage:** JSON, Feld `text` mit dem Wert **Angegebene Eingabe**
4. Füge **Ergebnis anzeigen** hinzu (oder **Text sprechen**, wenn Siri die Antwort vorlesen soll).
5. Nenne den Kurzbefehl **Einkaufsliste**. Ab jetzt reicht „Hey Siri, Einkaufsliste“.

WuselWall versteht Mengen: „2 Liter Milch“ wird Milch mit „2 l“, „3 Äpfel“ wird Äpfel (3×). Mehrere Dinge trennst du mit „und“ oder Komma. Steht etwas schon auf der Liste, wird es gezählt statt doppelt eingetragen.

## Alle Kurzbefehle

Jeder Kurzbefehl ist gleich gebaut wie oben: **Inhalte von URL abrufen** mit Methode POST, dem Header `Authorization` und einem JSON-Hauptteil. Nur das Ende der Adresse und die Felder ändern sich.

| Kurzbefehl | Adresse endet auf | Felder im JSON | Antwort, zum Beispiel |
|---|---|---|---|
| Einkaufsliste | `/shopping` | `text`: was auf die Liste soll; `list`: eine andere Liste als die Standardliste (optional) | „Milch ist auf der Liste.“ |
| Was steht heute an? | `/today` | `day`: „morgen“, ein Wochentag oder ein Datum (optional) | „Heute: 08:30 Zahnarzt (Emma). Essen heute: Abendessen: Spaghetti.“ |
| Was gibt es zu essen? | `/meals` | `day` (optional) | „Essen heute: Abendessen: Spaghetti. Julia kocht.“ |
| Meine Punkte | `/points` | – | „Du hast 42 Punkte.“ |
| Aufgabe erledigt | `/chore` | `text`: welche Aufgabe | „Erledigt: Spülmaschine ausräumen. 2 Punkte dazu.“ |
| Schule | `/school` | `text`: die Frage, etwa „Hat Emma morgen Sport?“ | „Ja, Emma hat morgen Sport in der 3. Stunde (09:55–10:40).“ |
| Wann ist … wieder da? | `/presence` | `text`: die Frage, etwa „Wann ist Julia wieder da?“ | „Julia ist auf Reise bis Freitag, 23. Oktober und am Samstag, 24. Oktober wieder da.“ |

Für **Schule** und **Wann ist … wieder da?** lässt du den Kurzbefehl wie beim Einkauf zuerst **Nach Eingabe fragen** und schickst die ganze Frage als `text`. WuselWall sucht darin den Namen, den Tag und das Fach. Ohne Tag meint **Schule** den nächsten Tag, denn gepackt wird meist am Abend vorher. Steht kein Name in der Frage, gilt sie für dich selbst.

**Aufgabe erledigt** hakt nur eigene Aufgaben ab, und solche, die noch niemandem zugeteilt sind. Passen mehrere Aufgaben, fragt WuselWall nach, statt zu raten. Ohne `text` zählt der Kurzbefehl auf, was noch offen ist.

::: tip Sprache
Die Antworten kommen in der Sprache des iPhones, wenn es Deutsch, Englisch, Französisch oder Spanisch ist, sonst in der Sprache des Haushalts. Mit dem Feld `lang` (`de`, `en`, `fr` oder `es`) legst du sie fest.
:::

## Einen Schlüssel sperren

Ist ein Handy weg oder braucht jemand den Kurzbefehl nicht mehr, tippe in der Liste auf **Sperren**. Das wirkt sofort: Der Kurzbefehl antwortet dann nur noch, dass er nicht mehr gilt. Die Liste zeigt, wann ein Schlüssel zuletzt benutzt wurde. Verlässt jemand die Familie, werden die Schlüssel dieser Person automatisch gesperrt.

Erziehungsberechtigte sehen und sperren alle Schlüssel der Familie, alle anderen ihre eigenen. Der [Datenexport](/settings/members-devices#daten-exportieren) enthält jeden Schlüssel mit Namen und Datum, aber nicht den Schlüssel selbst.

## KI-Assistenten (MCP)

Ein KI-Assistent, der **MCP** spricht (das Model Context Protocol, zum Beispiel Claude), kann mit einem eigenen Schlüssel in WuselWall **nachlesen**: „Was steht diese Woche an?“, „Was gibt es am Donnerstag zu essen?“, „Wann hat Emma morgen Schluss?“. Er kann **nichts eintragen, ändern oder löschen**.

Wähle beim Erstellen **Assistent** statt **Siri**. Einen Schlüssel für einen Assistenten bekommen nur Erwachsene. Er erscheint in der Liste unter **KI-Assistenten** und wird gesperrt wie jeder andere Schlüssel.

::: warning Was der Assistent liest, verlässt euren Server
Der Assistent liest die Woche der ganzen Familie: Termine, wer wann weg ist, die Stundenpläne der Kinder, Aufgaben, Punkte, Essen, Rezepte und die Einkaufsliste. Diese Daten gehen an den Anbieter des Assistenten und unterliegen dessen Datenschutzbedingungen. Überlegt deshalb gemeinsam, ob ihr das wollt.
:::

Der Assistent findet diese Abfragen: Wochenübersicht, Termine, Aufgaben, Essensplan, Einkaufsliste, Punkte, Rezepte, Stundenplan und wer zu Hause ist. Jede Antwort nennt die Personen beim Namen.

**Verbinden:** Trage im Assistenten einen MCP-Server mit der Adresse aus WuselWall ein, also etwa `https://api.example.org/functions/v1/mcp`, und schicke den Schlüssel als Header `Authorization: Bearer wwa_…`. In Claude Code geht das so:

```sh
claude mcp add --transport http wuselwall https://api.example.org/functions/v1/mcp \
  --header "Authorization: Bearer wwa_…"
```

Assistenten, die sich nur per OAuth anmelden können und keinen eigenen Header erlauben, lassen sich noch nicht verbinden. Eine Anmeldung mit Zustimmungsseite kommt zusammen mit dem Eintragen über Assistenten.

::: info Ohne iPhone
Ein Kurzbefehl ist eine gewöhnliche Web-Anfrage. Jede App, die eine Anfrage mit einem Header schicken kann, funktioniert genauso.
:::

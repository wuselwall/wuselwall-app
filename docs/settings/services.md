# Wetter und Karten

Für die [Reisen](/trips/) kann WuselWall Dienste von Dritten fragen: wie warm es an einem Ort typischerweise ist, wie das Wetter in den nächsten Tagen wird, wo ein Ort liegt und wie lange die Fahrt dauert. Das ist **ganz freiwillig**. Alles andere an den Reisen funktioniert ohne diese Dienste, und ohne sie fragt euer Server niemanden.

Das können die Dienste ergänzen:

- **Typisches Klima**: wie warm, wie regnerisch und wie sonnig ein Ort in einem Monat meistens ist, am Meer auch die Wassertemperatur. Das zeigt [Wohin?](/trips/#discover)
- **Vorhersage**: das Wetter am Reiseziel in den Tagen vor und während der Reise
- **Ortssuche**: ein Reiseziel oder euren Ort für Zuhause beim Namen finden
- **Fahrzeit**: wie lange die Fahrt von zuhause mit dem Auto dauert
- **Kartenbild**: ein kleines Bild des Reiseziels auf der Seite der Reise

Wo ihr es einschaltet: **Einstellungen → Kalender & Schule → Teilen und Verbindungen → Wetter und Karten**. Das können nur Eltern. Alle anderen Erwachsenen sehen die Seite und den Hinweis **Das kann ein Elternteil ändern**.

<Shot name="settings-services" alt="Die Seite Wetter und Karten mit dem Ort für Zuhause und dem Anbieter Open-Meteo, eingeschaltet, mit Knopf Testen" />

## Drei Versprechen {#promises}

1. **Alles ist aus, bis ein Elternteil es einschaltet.** Ein neuer Server fragt keinen Wetter- und keinen Kartendienst. Schaltet ihr einen Anbieter wieder aus, stoppt jeder Aufruf sofort.
2. **Nur euer Server fragt den Anbieter**, nie ein Handy und nie die Wand. Euer Telefon spricht nur mit eurem Server. Ein Kartenbild holt der Server und reicht es weiter.
3. **Ein Anbieter erfährt nur, was die Frage braucht:**
   - den Ort, den ihr ansehnt oder sucht: seine Koordinaten oder den Text der Suche
   - für eine Fahrzeit auch euren Ort für Zuhause, auf etwa einen Kilometer gerundet
   - und unvermeidlich die Internetadresse eures Servers

   **Nichts über eure Familie**: keine Namen, kein Konto, keine Termine, keine Reisedaten.

Euer Server merkt sich die Antworten, damit dieselbe Frage nicht noch einmal gestellt wird: das typische Klima fünf Jahre, einen gefundenen Ort 90 Tage, eine Fahrzeit und ein Kartenbild 30 Tage, eine Vorhersage 3 Stunden. Dieser Speicher enthält nur öffentliche Angaben zu Orten, nichts von eurer Familie.

## Die Anbieter {#providers}

Jeder Anbieter ist ein eigenes Angebot mit eigenen Bedingungen. Auf der Seite steht bei jedem, was er kann, ob er einen Schlüssel braucht und was er erhält (**Es erhält: …**).

| Anbieter | Schlüssel | Kann |
|---|---|---|
| **Open-Meteo** | nein, gratis | Typisches Klima, Vorhersage, Ortssuche |
| **MET Norway** | nein, gratis | Vorhersage |
| **OpenStreetMap Nominatim** | nein, gratis | Ortssuche |
| **OpenWeather** | ja, eigener Schlüssel, gratis möglich | Vorhersage (für etwa fünf Tage), Ortssuche |
| **Meteostat** | ja, eigener Schlüssel, gratis möglich | Typisches Klima |
| **openrouteservice** | ja, eigener Schlüssel, gratis möglich | Fahrzeit, Ortssuche |
| **Google Maps Platform** | ja, eigener Schlüssel, kann kosten | Ortssuche, Fahrzeit, Kartenbild |

- **Ohne Schlüssel** könnt ihr sofort loslegen. Mit **Open-Meteo** habt ihr Klima, Vorhersage und Ortssuche in einem Anbieter.
- **Mit eigenem Schlüssel** meldet ihr euch beim Anbieter an und tragt den Schlüssel in WuselWall ein (siehe [unten](#keys)). Auf der Karte des Anbieters führt **Schlüssel holen** zur richtigen Seite.
- Eine **Fahrzeit** gibt es nur mit **openrouteservice** oder **Google Maps Platform**, ein **Kartenbild** nur mit **Google Maps Platform**; beide brauchen einen Schlüssel. Nur für die Fahrzeit erhält der Anbieter auch euren Ort für Zuhause, gerundet.
- **Die Bedingungen nehmt ihr selbst an.** Manche kostenlosen Angebote gelten nur für private Nutzung, Open-Meteo zum Beispiel nach Angaben des Anbieters nur für nicht kommerzielle. Ein Angebot mit Schlüssel kann kosten; über Preise sagt WuselWall nichts zu. Eine kleine Obergrenze pro Tag schützt euren Schlüssel vor einer Schleife, ist aber kein Schutz vor Kosten.
- Unter jedem Kartenbild und jeder Vorhersage steht die Quellenangabe des Anbieters.

::: warning Ehrlich gesagt
Die Anbieter mit Schlüssel sind nach ihrer Dokumentation gebaut, nicht mit eurem Schlüssel erprobt. Funktioniert einer mit eurem Schlüssel nicht, sagt es der Knopf **Testen** (siehe [unten](#test)).
:::

## Den Ort für Zuhause festlegen {#home}

Oben auf der Seite steht **Zuhause**. Der Ort ist für die Entfernungen in **Wohin?** und für die Fahrzeit da. Tippe auf **Festlegen**, gib den **Namen des Ortes** ein und tippe auf **Suchen**; ein Treffer legt den Ort fest. Dafür muss ein Anbieter mit **Ortssuche** eingeschaltet sein. Ohne ihn trägst du **Breitengrad** und **Längengrad** von Hand ein, mit zwei Nachkommastellen.

Gespeichert wird der Ort auf etwa einen Kilometer gerundet. Mit **Ändern** setzt du einen neuen, mit **Vergessen** verschwinden die Entfernungen, bis ein neuer festgelegt ist.

## Einen Schlüssel eintragen {#keys}

Ein Anbieter mit Schlüssel zeigt zuerst **Braucht zuerst einen Schlüssel**. Hol den Schlüssel beim Anbieter, tippe ihn in das Feld **Schlüssel** und wähle **Schlüssel speichern und einschalten**.

- **Ein Schlüssel wird nur geschrieben, nie gelesen.** Er wird einmal getippt und auf eurem Server gespeichert. Danach zeigt die Seite nur noch seine letzten vier Zeichen: **Schlüssel gespeichert …1234**. Kein Gerät kann ihn auslesen, auch nicht eures.
- Er steht **nicht im Datenexport** der Familie und in keinem Protokoll. Ein Backup eures Servers enthält ihn, wie die anderen Geheimnisse des Servers.
- **Ersetzen** tauscht ihn aus. **Entfernen** löscht ihn und schaltet den Anbieter aus.

## Reihenfolge und Testen {#test}

Unter **Eingeschaltet** steht der Knopf **Testen**. Er macht einen kleinen echten Aufruf und antwortet mit **Funktioniert** oder nennt den Grund. Probiere ihn gleich nach dem Eintragen eines Schlüssels aus.

In der Ansicht **Erweitert** (oben rechts) kommt mehr dazu:

- **Verwendet für**: Haken für das, was der Anbieter bei euch tun soll. So kann ein Anbieter zum Beispiel nur die Vorhersage liefern.
- **Früher fragen** und **Später fragen**: Wo mehrere Anbieter dasselbe können, **gewinnt der erste in dieser Reihenfolge, der antwortet**. Antwortet er nicht, kommt der nächste dran.
- Wie viele **Aufrufe heute** es schon waren.

## Warum es beim ersten Mal dauert {#slow}

Der kostenlose Dienst von Open-Meteo erlaubt nur wenige Klima-Abfragen: ungefähr **drei Orte pro Minute**, zwanzig pro Stunde und achtundvierzig pro Tag. Euer Server hält sich daran. Darum füllt sich die Liste in **Wohin?** beim ersten Mal nur langsam: Oben steht „Klimawerte werden geladen: noch 12 Orte“, und die Seite fragt alle halbe Minute nach. Gibt es eine Weile nichts Neues, hört sie auf und sagt „Weitere Werte folgen später“.

Dann ist alles in Ordnung. Schau später noch einmal nach. Weniger Orte gehen schneller: Mit ein, zwei **Wünschen** (zum Beispiel **Meer**) sind es weniger Orte, die gefragt werden müssen. Danach ist es schnell: Die Werte sind **Durchschnitte** und bleiben fünf Jahre gespeichert, für alle Familien auf eurem Server.

## Wenn der Dienst nicht antwortet {#no-answer}

Bei einem Anbieter steht unter **Letzter Aufruf** der Grund, wenn es nicht geklappt hat:

- **Der Anbieter hat den Schlüssel abgelehnt.** Der Schlüssel stimmt nicht oder ist abgelaufen. Mit **Ersetzen** trägst du einen neuen ein.
- **Das Kontingent beim Anbieter ist vorerst aufgebraucht.** Warte, bis es sich erneuert, oder nimm einen weiteren Anbieter dazu.
- **Der Anbieter hat nicht rechtzeitig geantwortet** und **Der Anbieter hat diesmal nicht funktioniert.** Das kommt vor. Versuche es später noch einmal mit **Testen**.
- **Dieser Anbieter braucht einen Schlüssel.** Trage zuerst einen ein.

Sind mehrere Anbieter eingeschaltet, fragt der Server den nächsten. Die Seite einer Reise zeigt nie einen Fehler: Was ein Dienst nicht liefert, fehlt einfach, und alles andere geht weiter.

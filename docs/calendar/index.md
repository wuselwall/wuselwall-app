# Kalender

Der Kalender ist die Startseite der Erwachsenen: alle Termine der Familie und, wer wo ist, auf einen Blick.

<Shot name="calendar-week" alt="Wochenansicht des Kalenders mit Anwesenheit oben und Terminen darunter" wide />

## Ansichten

Titel, Datumsnavigation, Ansichtswahl und Einstellungen teilen sich eine kompakte Leiste. Auf dem Handy wählst du unter **Kalenderansicht** zwischen **Tag**, **3 Tage** und **Woche**; das Kalendersymbol führt zu **Heute**.

<Shot name="calendar-phone" alt="Kalender auf dem Handy mit Datumsnavigation und Ansichtsmenü in einer Leiste" />

Oben wählst du **Tag**, **3 Tage** oder **Woche**. Mit **Zurück**, **Weiter** und **Heute** blätterst du. Ganz oben bleiben zwei Zeilen immer sichtbar:

- **Anwesenheit**: eine Zeile pro Person. Dort steht, wer arbeitet, im Homeoffice ist, unterwegs ist, weg ist, frei hat oder betreut wird.
- **Ganztägig**: Termine, die den ganzen Tag gelten.

Darunter stehen die Termine nach Uhrzeit.

## Termin anlegen

Tippe auf **Neuer Termin**. Du kannst:

- einen **Titel**, einen **Ort** und **Notizen** eintragen
- zwischen **Termin** und **Anwesenheit** wählen. Anwesenheit hat sechs Zustände: Arbeit, Homeoffice, Unterwegs, Weg, Frei und Betreuung
- den Termin **ganztägig** machen oder **Beginn** und **Ende** setzen
- unter **Wer** Personen auswählen. Ist niemand ausgewählt, gilt der Termin für die ganze Familie
- **Noch nicht sicher** ankreuzen, wenn noch unklar ist, ob er stattfindet
- **Auf dem Küchendisplay zeigen** ankreuzen. Was neue Termine standardmäßig tun, legt ihr unter [Haushalt einstellen](/settings/household) fest

<Shot name="calendar-editor" alt="Editor für einen neuen Termin mit Titel, Wer und Wiederholung" />

### Wiederholen

Unter **Wiederholung** wählst du **Täglich**, **Wöchentlich**, **Alle 2 Wochen** oder **Monatlich**. Für Schichtpläne gibt es **Bestimmte Tage (Dienstplan)**: Du tippst im Monatsraster die Tage an, an denen gearbeitet wird. Mit **Ende der Wiederholung** setzt du ein Datum oder eine Anzahl von Malen.

Änderst oder löschst du einen Termin einer Wiederholung, fragt WuselWall: **Nur dieser Termin** oder **Alle Termine der Serie**.

## Termine bis …

Tippe auf die Überschrift eines Tages, um **Termine bis** zu setzen: Ab dieser Uhrzeit bist du nicht verfügbar. Das erscheint auf der Küchenwand, zum Beispiel als „Termine bis 17“. Es zeigt nur die Uhrzeit, keine Termine und keine Details. Mit **Für die ganze Woche übernehmen (Mo–Fr)** gilt es für jeden Werktag der Woche.

## Übliche Woche

Unter **Einstellungen → Übliche Woche** tragt ihr für jeden Wochentag ein, wo ihr normalerweise seid, zum Beispiel montags im Büro und an den anderen Tagen im Homeoffice. Tippe auf einen Tag, wähle den Ort und tippe auf **Übernehmen**. Mit **Dienstag bis Freitag wie Montag** gilt der Montag für die ganze Arbeitswoche. Ein Tag mit **Nichts eingetragen** bleibt auf der Küchenwand leer, so wie meist das Wochenende. Zum Schluss tippst du auf **Speichern**.

Danach tragt ihr nur noch Abweichungen ein. Eine normale Woche bleibt leer. An einem Feiertag zeigt die Küchenwand keinen üblichen Ort.

## Kinder und Termine

Ob Kinder Termine anlegen und ändern dürfen, legt ihr unter [Haushalt einstellen](/settings/household) fest. Fremde Termine löschen bleibt Sache der Erziehungsberechtigten.

## Termine in Outlook oder auf dem iPhone

Der Familienkalender lässt sich als **Abo** in Outlook oder auf dem iPhone anzeigen, nur zum Lesen. Siehe [Den Familienkalender teilen](/calendar/feeds).

## Kalender von außen {#kalender-von-aussen}

Termine von außen kommen mit einem **Abo** in den Familienkalender: der Spielplan des Vereins, der Abfuhrkalender der Gemeinde, Schulveranstaltungen. Ihr braucht dafür nur die Adresse des Kalenders, meist eine Datei, die auf **.ics** endet. Adressen mit **webcal://** gehen auch.

Abos verwaltet ein Erziehungsberechtigter unter **Einstellungen → Erweitert → Kalender von außen hinzufügen**. **Kalender abonnieren** öffnet das Formular mit Name, Adresse, Farbe, **Für wen?** (ohne Auswahl gilt der Kalender für die ganze Familie) und **Auf dem Küchendisplay zeigen**. Die Termine erscheinen im Kalender in der Farbe des Kalenders, mit einem Abo-Symbol. Sie sind nur zum Lesen: Änderungen kommen von der Quelle.

Euer Server holt jeden Kalender etwa einmal pro Stunde. Mit **Jetzt aktualisieren** geht es sofort. Schlägt der Abruf fehl, steht der Grund bei dem Kalender, zum Beispiel „Die Adresse ist gerade nicht erreichbar“.

Wissenswert:

- Es gehen nur Adressen mit **https://**. Adressen, die auf Rechner im eigenen Netz zeigen, nimmt WuselWall nicht an.
- Ein Kalender darf höchstens 2 MB groß sein. Der Abruf bricht nach 15 Sekunden ab.
- Alle Geräte des Haushalts sehen nur den Rechnernamen der Adresse, zum Beispiel „abfuhr.example.de“. Die ganze Adresse sehen nur Erziehungsberechtigte, wenn sie den Kalender bearbeiten. Enthält sie einen geheimen Schlüssel, gilt sie wie ein Passwort.
- Im Abo für Outlook und iPhone erscheinen Termine von außen nur, wenn du beim Abo **Kalender von außen einschließen** anhakst. Siehe [Den Familienkalender teilen](/calendar/feeds).

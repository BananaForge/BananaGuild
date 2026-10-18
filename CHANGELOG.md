# Changelog

Die Version steht in `BananaGuild.toc` (`## Version`) und wird im Fenster rechts unten angezeigt.
Bei jeder Änderung am Addon wird sie hochgezählt.

## 1.11.0
- Gildenstatistik überarbeitet. „Klassen": Donut-Diagramm mit der Gesamtzahl der Chars in der Mitte, rechts eine Rangliste mit Balken (Anzahl und Prozent) und darunter die Rollenverteilung (Tank, Heal, DD, unbekannt) aus den Specs der Notizen. Mouse-over auf einem Segment oder einer Zeile zeigt die Klasse mit Mitgliederzahl, wie viele einen Spec eingetragen haben und jeden Spec mit seiner Anzahl. Ein Klick öffnet die Specs dieser Klasse.
- „Specs pro Klasse": Klasse über neun Buttons wählen, dann zeigt ein einziges Diagramm nur die Specs dieser Klasse (Mouse-over mit Anzahl, Anteil und Rolle), rechts die Specs mit Balken.
- Glattere Optik: Die runden Kanten, das Loch und der goldene Rand kommen aus einer kleinen Bilddatei (Media\donut.tga), die Segmente haben feine Trennlinien. Das Zeichnen verteilt sich auf ein paar Bilder, es gibt keinen Ruckler.

## 1.10.0
- Neue Gildenstatistik: Im Mitglieder-Reiter öffnet der Button „Klassen- & Spec-Statistik" (unten rechts) ein Fenster mit zwei Diagrammen. „Klassen": klassisches Tortendiagramm der Klassen in Klassenfarben mit Anzahl und Prozent. „Specs pro Klasse": innen die Klassen, außen als Ring die Specs jeder Klasse (hellere/dunklere Töne der Klassenfarbe, dazu „Spec unbekannt" für Mitglieder ohne Spec in der Notiz). Die Legende zeigt die Zahlen. Das Fenster aktualisiert sich, wenn sich die Gildenliste ändert.
- Die Diagramme werden ohne Bilddateien aus farbigen Streifen gezeichnet (ca. 700 bzw. 1500 kleine Flächen, einmalig beim Öffnen und bei Änderungen).

## 1.9.0
- Interessenten-Popups (Flüster und Scanner) zeigen jetzt Infos zum Spieler: Stufe, Klasse (in Klassenfarbe), Rasse, Gilde und Zone. Das Addon fragt sie per /who ab (still: nichts im Chat, das Freundefenster bleibt zu), höchstens eine Abfrage alle 5 Sekunden. Bis die Antwort da ist, steht „Infos werden abgefragt ...", danach die Daten, bei Offline oder ohne Antwort „Keine Infos gefunden". Antworten werden 15 Minuten gemerkt, „Andere Variante" fragt nicht neu.

## 1.8.1
- Neuzugang-Fenster und Begrüßungs-Popup erscheinen jetzt zuverlässig: Bisher kamen sie nur, wenn gerade die automatische Gildensuche lief. Jetzt bekommt sie, wer das neue Mitglied eingeladen hat (auch von Hand oder per Rechtsklick), oder wer gerade rekrutiert, wenn niemand als Einlader bekannt ist. Hat jemand anderes eingeladen, kommt das Fenster nur bei dem.
- Wird die Beitrittsmeldung im Chat verpasst, erkennt das Addon den Neuzugang an der Gildenliste.
- Mit `/bgd join Name` lässt sich das Fenster (Notiz + Begrüßung) jederzeit von Hand öffnen.

## 1.8.0
- Addons & Analytics: Die Infotexte unten und die graue Zeile „Gildenmitglieder ... mit Daten erfasst ... außerhalb gesehen" sind entfernt. Stattdessen steht unten „Accounts: X und Chars: Y". Chars = alle Gildenmitglieder, Accounts = Zahl der verschiedenen Mains laut Gildennotiz (Chars ohne gültige Notiz zählen einzeln, Tooltip erklärt das). Die Liste hat dafür drei Zeilen mehr.
- Der Selbsttest-Button ist aus der Fußzeile in die Einstellungen (Seite „Allgemein", unten) gewandert. `/bgd selftest` funktioniert weiter.

## 1.7.3
- Notiz-Fenster: Neuer Beruf Juwelenschleifen (Kürzel `JC`, auch `Juwelenschleifer`, `Juwe` u.a. werden erkannt). Die Berufe stehen als ausgeschriebener Name in kleiner Schrift auf den Buttons (Sprache wie im Addon), in die Notiz kommt weiterhin das kurze Kürzel. Mouse-over zeigt beide Namen, das Kürzel und ob Haupt- oder Nebenberuf.
- Mouse-over bei den Specs: Name in Deutsch und Englisch sowie die Rolle (Tank, Heiler, Schaden) mit kurzer Erklärung, immer in beiden Sprachen.

## 1.7.2
- Notiz-Fenster: Der Main eines Twinks wird nicht mehr getippt, sondern aus einer aufklappbaren Liste aller Gildenmitglieder gewählt (A-Z, mit Level, scrollbar per Mausrad oder Schieber, 10 Zeilen sichtbar). Nicht angeboten werden das Mitglied selbst und Mitglieder, deren Notiz sie als Twink ausweist. Beim erneuten Öffnen springt die Liste zum gewählten Namen.

## 1.7.1
- Neue Textart „Alles abfragen" (5 Varianten): fragt Berufe, Spec und Twinks/Main in einer Flüsternachricht. Vierter Eintrag im Rechtsklick-Menü der Mitglieder-Liste, Text im Reiter Texte editierbar.

## 1.7.0
- Mitglieder-Reiter: Filter „Nur online". Die Spaltenköpfe Name, Lvl, Beruf, Spec und Rolle sind klickbar und sortieren (nochmal klicken kehrt um, Pfeil zeigt die Spalte). Name sortiert A-Z / Z-A mit Mains und Twinks zusammen, die anderen Spalten zeigen eine flache Liste. Leere Werte stehen immer unten.
- Rechtsklick auf ein Mitglied in der Liste öffnet ein kleines Menü: „Berufe abfragen", „Spec abfragen", „Twink-Infos abfragen". Das Addon flüstert dem Mitglied einen freundlichen Text (nur wenn es online ist).
- Reiter Texte: drei neue Textarten „Berufe-Frage", „Spec-Frage", „Twink-Frage", wie alle anderen mit 5 editierbaren Varianten (zufällig, nie dieselbe zweimal hintereinander).
- Einstellungen aufgeräumt: Abschnitte „Meldungen", „Rekrutieren & Neuzugänge", „Allgemein", „Abgleich" mit Trennlinien, Überschrift überlappt die Seitenbuttons nicht mehr, Beschriftungen passen in ihre Felder.

## 1.6.1
- Mitglieder-Reiter: „Alle markieren" und „Keine markieren" stehen unter der Liste. Der Button „Mit Gilde abgleichen" ist hier entfernt (der Abgleich läuft weiter automatisch beim Öffnen des Fensters, manuell unter Einstellungen > „Jetzt synchronisieren"). Die Suche ist dafür breiter.
- Das Hauptfenster hat einen dunkleren, besser lesbaren Hintergrund (nicht komplett undurchsichtig).

## 1.6.0
- Rang ändern für einen oder viele Mitglieder, hoch und runter: Zielrang über ein aufklappbares Auswahlmenü (alle Ränge unterhalb deines eigenen). Vorschau mit Haken pro Mitglied („Name: Initiant -> Member (3 Schritte hoch)"), Seitenwechsel bei vielen. Wer auf deinem Rang oder darüber steht, wird übersprungen. Degradieren braucht eine zusätzliche Bestätigung (Haken). Im Verlauf steht ein Eintrag pro Änderung, am Ende eine Zusammenfassung im Chat.
- Mitglieder-Reiter: Checkbox vor jedem Mitglied, „Alle sichtbaren markieren", „Keine" und „Rang für Markierte ändern ...". Neuer Rangfilter (aufklappbar) neben der Suche, damit sich zum Beispiel alle Initianten schnell markieren lassen.
- Degradieren nutzt wie das Befördern die passende Client-Funktion (`GuildDemoteByName`, `GuildDemote` oder `/gdemote`); der Selbsttest zeigt sie an.

## 1.5.2
- Beförderung repariert: Manche Clients haben `GuildPromote` nicht (Fehler „attempt to call global GuildPromote"). Das Addon sucht jetzt selbst die passende Funktion (`GuildPromoteByName`, `GuildPromote`, zuletzt der Slash-Befehl `/gpromote`), meldet verständlich, wenn keine da ist, und der Selbsttest zeigt, welche genutzt wird.
- Alle Popup-Fenster (Notiz, Beförderung, Rang ändern, Meldungen) haben einen undurchsichtigen Hintergrund und kommen beim Öffnen nach vorn.
- Die „Eigene Notiz" im Notiz-Fenster bleibt in deinem Addon und wird nicht abgeglichen (Beschriftung korrigiert).

## 1.5.1
- Manuelle Beförderung: Im Mitglieder-Reiter öffnet „Rang ändern ..." ein Fenster, in dem du für jedes Mitglied einen höheren Zielrang wählst (nur Ränge über dem aktuellen und unter deinem eigenen). Das Addon befördert Schritt für Schritt, genau wie bei der automatischen Erinnerung.
- Mitglieder-Detail aufgeräumt: Beigetreten und Eingeladen von stehen als kleine, nicht mehr editierbare Schrift oben rechts neben dem Namen. Das freie Notizfeld liegt jetzt im Fenster „Notiz bearbeiten ..." (wird beim Schließen gespeichert). Speichern-Button und grauer Hinweistext unten entfallen.

## 1.5.0
- Mains, Twinks, Berufe und Spec werden aus der öffentlichen Gildennotiz gelesen: `[MAIN] [AL+VZ] [Retri]` bzw. `[TWINK Name] [..] [..]` (Kurzform `[T Name]`). Die Notiz gewinnt, die alte Zuordnung bleibt als Ersatz. Fehler (unbekanntes Kürzel, Main nicht in der Gilde, Main ist selbst Twink) werden im Detail angezeigt.
- Mitglieder-Liste mit Spalten Name, Level, Beruf, Spec, Rolle (Tank/Heal/DD). Der Rang steht im Detailbereich. Filter „Nur ohne gültige Notiz".
- Neuzugang-Fenster beim Rekrutierer und „Notiz bearbeiten ..." im Mitglieder-Reiter: Main/Twink, Berufe (auch keiner), Spec, Live-Vorschau mit Zeichenzähler, Notiz wird per Klick ins Gildenfenster geschrieben (braucht das Gildenrecht, sonst lässt sich die Notiz kopieren). Das Addon prüft nach dem Schreiben, ob die Notiz angekommen ist.
- Beförderung: nach einstellbarer Zeit (Standard 4 Wochen) auf dem Startrang (Standard Initiant) erinnert ein Fenster alle mit Beförderungsrecht. Ein Klick befördert Schritt für Schritt bis zum Zielrang (Standard Member), einzeln oder alle. Nur Mitglieder auf dem Startrang werden angefasst. Einstellungen: Seite „Beförderung". Im Verlauf steht pro Beförderung ein Eintrag.
- Beitrittsdatum: Wer vor dem Addon schon in der Gilde war, zählt ab dem Tag, an dem das Addon die Person zum ersten Mal gesehen hat (als „geschätzt" markiert, im Detailbereich änderbar).
- Neue Einstellungen: Fenster für Neuzugänge, Beförderungs-Erinnerung (auch im Instanzmodus einzeln erlaubbar). Selbsttest prüft Notizen, Notiz- und Beförderungsrecht, Start-/Zielrang.

## 1.4.1
- Reiter „Gildensuche": Die Such-Nachricht hat jetzt ebenfalls 5 Varianten (Variante 1 = bisheriger Text, dazu 4 neue deutsche). Bei aktiver Suche wird bei jedem Post zufällig eine andere Variante genutzt, nie dieselbe zweimal hintereinander. Varianten einzeln oder alle 5 zurücksetzbar. Ein eigener bisheriger Text wird als Variante 1 übernommen.

## 1.4.0
- Reiter „Texte" überarbeitet: Jede Textart (Willk. Gilde, Witzig, GZ, Antwort DE/EN, Kontakt DE/EN) hat genau 5 einzeln editierbare Varianten. Beim Senden wird zufällig eine gewählt, nie zweimal dieselbe hintereinander. Zurücksetzen pro Variante oder alle 5, Vorschau inklusive.
- Die Willkommens-Flüsternachricht und ihr Button sind entfernt; Willkommen heißt jetzt nur noch Begrüßung im Gildenchat (Popup/Auto-Willkommen bleiben).
- Der jeweils andere Sprachtext (Antwort/Kontakt EN bei DE-Oberfläche und umgekehrt) ist im Reiter ausgegraut, wird für Flüsterer dieser Sprache aber weiter automatisch genutzt.
- Antworttexte enthalten keinen Discord-Link mehr.
- Flüster-Popup: Antwort + Einladen, Nur Antwort, Andere Variante, Nur einladen, Sprache wechseln, Ignorieren. Die Variante wird beim Öffnen vorgewürfelt, der Tooltip zeigt den genauen Text.
- Bestehende eigene Texte werden als Variante 1 übernommen.

## 1.3.0
- Neuer Instanz-/Raid-Modus (Einstellungen → Reiter „Instanzmodus"): In Instanzen, Schlachtfeldern und Raids sind alle Popups, Chat-Meldungen und Töne von BananaGuild automatisch stumm. Einzelne Meldungen (Levelup, Stufe 60, Interessenten, Scanner, Willkommen, Rekrutierer-Konflikt) lassen sich individuell trotzdem erlauben.
- Verpasste Interessenten-Popups werden nach dem Verlassen nachgeholt, dazu gibt es optional eine Zusammenfassung im Chat.

## 1.2.0
- Verlauf wird jetzt mit der Gilde synchronisiert (Beitritte, Austritte, Kicks, Einladungen, Beförderungen, Levelups). Doppelte Einträge werden erkannt, Interessenten-Einträge bleiben privat.
- Die Versionsnummer im Fenster wird bei jeder Änderung hochgezählt.

## 1.1.0
- Zwei-Wege-Sync für Main/Twink-Daten (Zeitstempel, nur Neueres wird übertragen): automatisch bei jedem Öffnen des Fensters und per Button „Jetzt synchronisieren" in den Einstellungen.
- Willkommens-Popup und automatische Willkommensnachricht nur noch bei dem Spieler, der gerade rekrutiert.
- GZ-Popup einstellbar: bei jeder Stufe oder nur bei gewählten vollen 10er-Stufen (10–60).
- Flüster-Antworten getrennt für Deutsch und Englisch mit automatischer Spracherkennung; Popup-Buttons mittig und gleichmäßig angeordnet.
- Support-Button wie in den anderen Banana-Addons (Herz-Symbol, Danke-Fenster mit Lumihunt).
- Korrektur: Listen-/Text-Auswahlbuttons zeigten immer die letzte Liste (Lua-5.0-Schleifenvariable).
- Korrektur: Addons, die nach BananaGuild laden, wurden fälschlich als deaktiviert gemeldet.
- Start unabhängig vom Ordnernamen; Diagnose über `/bgd`.

## 1.0.0
- Erste Version: Addon-Übersicht & Analytics, Levelup-/Stufe-60-Meldungen, Main/Twink-Verwaltung, Verlauf, Auto-Gildensuche mit Rekrutierer-Sperre, Flüster-Popup, Channel-Scanner, Rechtsklick-Einladen, Willkommensnachricht, DE/EN, Selbsttest.

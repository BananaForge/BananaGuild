# Changelog

Die Version steht in `BananaGuild.toc` (`## Version`) und wird im Fenster rechts unten angezeigt.
Bei jeder Änderung am Addon wird sie hochgezählt.

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

# Changelog

Die Version steht in `BananaGuild.toc` (`## Version`) und wird im Fenster rechts unten angezeigt.
Bei jeder Änderung am Addon wird sie hochgezählt.

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

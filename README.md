# BananaGuild – Gildenmanager (WoW 1.12 / OctoWoW)

Dashboard für Gildenleitung & Recruiting. / Dashboard for guild leaders & recruiting.

## Installation (OctoLauncher)

GitHub-Link zum Installieren: **https://github.com/bananaforge/bananaguild**

Der Ordnername ist egal (`BananaGuild`, `bananaguild`, `BananaGuild-main` …) – das Addon findet ihn selbst. Falls nichts passiert: `/bgd` tippen, es meldet dann, was nicht geladen wurde.

Ingame: `/bgd` (oder `/bananaguild`, oder Minimap-Button). **Als Erstes im Reiter „Texte" deinen Discord-Link eintragen!**

## Funktionen

| Bereich | Was es macht |
|---|---|
| **Addons & Analytics** | Zeigt, wer in der Gilde BananaCraft / BananaBank / Banana Lootline / Bananaloot / BananaGuild installiert hat und ob es läuft (Version, zuletzt gesehen, Logins, Anteil, 7/30-Tage-Aktivität). |
| **Levelup-Hinweis** | Chat-Meldung + kleines Fenster mit **GZ-Button** (zufälliger GZ-Spruch in den Gildenchat). In den Einstellungen wählbar: bei **jeder Stufe** oder **nur bei den vollen 10er-Stufen** (10, 20 … 60, jede einzeln an-/abschaltbar). |
| **Stufe 60** | Große Bildschirmanzeige mit BananaGuild-Logo + Spielername. |
| **Mitglieder & Twinks** | Mains, Twinks, Berufe und Spec kommen aus der **öffentlichen Gildennotiz** (siehe unten), nichts wird doppelt gepflegt und nichts muss dafür synchronisiert werden. Liste mit Name, Level, Beruf, Spec, Rolle. Beitrittsdatum, wer hat eingeladen und eine eigene Notiz bleiben zusätzlich pflegbar und synchronisierbar. |
| **Mitglieder-Liste** | Spalten anklicken zum Sortieren, Filter für Suche, Rang, „Nur online" und „Ohne gültige Notiz". Rechtsklick auf ein Mitglied: per Flüstern nach Berufen, Spec oder Twinks fragen (Texte im Reiter Texte). |
| **Neuzugang-Fenster** | Bei dem, der das neue Mitglied eingeladen hat (oder gerade rekrutiert), öffnet sich nach dem Beitritt ein Fenster (von Hand: `/bgd join Name`): Main/Twink (mit Mainname), bis zu 2 Hauptberufe (oder bewusst keiner), Spec. Das Addon setzt die Gildennotiz im richtigen Format, mit Zeichenzähler (max. 31). Dazu optional die Begrüßung im Gildenchat. Dasselbe Fenster gibt es im Mitglieder-Reiter über „Notiz bearbeiten ...". |
| **Beförderung** | Nach einstellbarer Zeit (Standard 4 Wochen) auf dem Startrang (Standard Initiant) meldet sich ein Fenster bei allen mit Beförderungsrecht. Ein Klick befördert Schritt für Schritt bis zum Zielrang (Standard Member). Angefasst werden nur Mitglieder, die gerade auf dem Startrang stehen. Alles einstellbar unter Einstellungen > Beförderung. Manuell (hoch und runter, auch für mehrere): Mitglieder per Checkbox markieren (Rangfilter + „Alle sichtbaren markieren") und „Rang für Markierte ändern ..." wählen, Zielrang im Auswahlmenü, Vorschau mit Haken, Degradieren mit Extra-Bestätigung. Nur Ränge unterhalb deines eigenen. |
| **Verlauf** | Beitritte, Einladungen, Beförderungen/Degradierungen, Kicks, Austritte, Levelups. |
| **Gildensuche (Auto-Recruiting)** | Postet deine Nachricht im frei wählbaren Minutenabstand in `/4` (in Instanzen in `/5`). Nur **eine** Person der Gilde kann gleichzeitig werben; sonst Warnung + Option, der Person etwas Witziges zu flüstern. |
| **Flüster-Popup** | Meldet sich jemand per Flüstern, erscheint ein Popup: Antwort + Einladen, Nur Antwort, Andere Variante, Nur einladen, Sprache wechseln, Ignorieren. |
| **Scanner** | Filtert `/4` und `/5` nach Spielern, die (deutsch oder englisch) eine Gilde suchen, ignoriert werbende Gilden, Popup mit Kontakt-Nachricht + Einladen. Schlagwörter sind editierbar, es gibt ein Testfeld. |
| **Rechtsklick-Einladen** | Rechtsklick auf einen Namen im Chat → „In Gilde einladen". |
| **Willkommen** | Popup (oder automatisch) mit Begrüßung im Gildenchat (zufällige von 5 Varianten) – **nur bei dem Spieler, der gerade rekrutiert**, nicht bei jedem mit dem Addon. |
| **Sync** | Main/Twink-Daten, Beitrittsdatum, Einlader und der **Verlauf** (Beitritte, Austritte, Kicks, Einladungen, Beförderungen, Levelups; doppelte Einträge werden erkannt, Interessenten bleiben privat) werden mit allen Gildenmitgliedern abgeglichen: automatisch bei jedem Öffnen des Fensters (im Hintergrund, max. alle 90 s) und per Button „Jetzt synchronisieren" in den Einstellungen. Es wird nur Neueres übertragen (Zeitstempel pro Charakter bzw. Eintrag, der neueste Stand gewinnt), angenommen nur von Rängen bis zur eingestellten Grenze. |
| **Instanz-/Raid-Modus** | In Instanzen, Schlachtfeldern und Raids sind alle Popups, Meldungen und Töne automatisch stumm. In den Einstellungen (Seite „Instanzmodus") kann jede Meldungsart einzeln trotzdem erlaubt werden; verpasste Interessenten kommen nach dem Verlassen nachgeholt. |
| **Selbsttest** | Prüft API, Gilde, Channels, Texte, Hooks, Übersetzungen, Laufzeitfehler. |

Alle Texte sind editierbar (je 5 Varianten, zufällig und nie zweimal dieselbe hintereinander), alle Funktionen einzeln ein-/ausschaltbar (Reiter *Einstellungen*), die Sprache DE/EN oben rechts umschaltbar. Herz-Symbol oben rechts (Danke-Fenster mit Charakter Lumihunt, wie in den anderen Banana-Addons), Version + Selbsttest unten rechts.

### Format der Gildennotiz

```
[MAIN] [AL+VZ] [Retri]            Main, Berufe, Spec
[TWINK Bananenbank] [KO] [Frost]  Twink von Bananenbank (Kurzform: [T Bananenbank])
```

1. Klammer = Rolle (Pflicht), 2. = Berufe (optional, `-` = keine), 3. = Spec (optional). Gross/Klein und Leerzeichen sind egal, getrennt wird mit `+`, `,`, `/` oder Leerzeichen. Mehr als 31 Zeichen lässt WoW nicht zu, deshalb gibt es Kürzel (Berufe: AL SM VZ IN KR LE BB KS SN JC KO EH AN; Specs je Klasse, z.B. Retri, Prot, Holy, Resto, Eule, Katze, Baer). Die längeren deutschen und englischen Namen werden ebenfalls erkannt. Die Notiz gewinnt immer; Charaktere ohne Notiz behalten ihre alte Zuordnung als Ersatz.

### Slash-Befehle

`/bgd` Fenster · `/bgd selftest` · `/bgd who` (Addon-Abfrage) · `/bgd recruit start|stop` · `/bgd gz [Name]` · `/bgd welcome <Name>` · `/bgd test60 [Name]` · `/bgd testlevel [Name]` · `/bgd lang de|en`

## Wie die Addon-Analytics funktionieren (und wo ihre Grenzen sind)

* Jeder Client mit **BananaPresence.lua** meldet **einmal pro Login** (nach ~20 s) unsichtbar über den Gilden-Addon-Kanal (`SendAddonMessage`, Präfix `BGLD`): `H;craft=1.0,bank=2.1,guild=1.0.0`. Das Dashboard speichert Version, letzten Login und die Tage in `BananaGuildDB`.
* **„Jetzt abfragen"** schickt ein `Q`; alle gerade Online-Nutzer antworten zufällig verzögert.
* BananaGuild erkennt die anderen Banana-Addons **lokal** über `IsAddOnLoaded`/`GetAddOnInfo` (Ordnernamen siehe `BG.TRACKED` in `Core.lua`) – dadurch melden BananaGuild-Nutzer auch ihre anderen Addons, ohne dass diese geändert werden müssen.
* **Grenze:** Gesehen werden nur Spieler, die BananaGuild oder die `BananaPresence.lua` haben. Wer nur ein altes BananaBank ohne die Datei hat und kein BananaGuild, ist unsichtbar. Offline-Spieler erscheinen mit den zuletzt gespeicherten Daten.
* **Optionaler Welt-Ping** (Einstellungen, standardmäßig **AUS**): einmal pro Login `~BGP~craft=1.0,...` in den Welt-Channel (`/4`). Clients mit BananaGuild/BananaPresence filtern die Nachricht aus **allen** Chatfenstern, Spieler ohne sehen den kurzen Text. Dadurch sieht man auch Nutzer außerhalb der Gilde (Zahl „außerhalb der Gilde gesehen").

### BananaPresence in die anderen Addons einbauen

1. `BananaPresence.lua` in den Ordner des Addons kopieren und **als erste Datei** in dessen `.toc` eintragen. (Die erste geladene Kopie gewinnt, weitere werden ignoriert.)
2. Irgendwo beim Laden des Addons:
   ```lua
   if BananaPresence then BananaPresence.Register("bank", "BananaBank", "1.2.0") end
   ```
   Schlüssel: `craft`, `bank`, `lootline`, `loot` (`guild` = BananaGuild).
3. Optional in der eigenen UI eine Checkbox für den Welt-Ping: `BananaPresence.SetWorldPing(true/false)`.

## Technik / Kompatibilität

Reines Lua 5.0 / Interface 11200 (kein `#`, `%`, `string.match`, …). Unsichtbare Nachrichten nutzen **nie** das Zeichen `|` (Chat-Escape), sondern `;`.

Zusammenarbeit der Gilde: Gildensuche-Sperre = Herzschlag alle 45 s, gilt 110 s; wer zuerst gestartet hat, gewinnt. Level-Ups werden über den Gildenkanal sofort gemeldet (bei Nutzern) und sonst aus der Gildenliste erkannt (alle 20 s abgefragt).

---

## English summary

Install via OctoLauncher from `https://github.com/bananaforge/bananaguild`; the folder name does not matter. Open with `/bgd`. Set your Discord link in the *Texts* tab first.

Features: addon-usage overview/analytics for BananaCraft / BananaBank / Banana Lootline / Bananaloot, level-up notice with GZ button, full-screen level-60 splash with the logo, main/twink manager with join/invite/promote history, timed auto-recruiting in `/4` (`/5` in instances) with a single-recruiter lock over the guild addon channel (funny whispers to the other recruiter), whisper popup with predefined replies, `/4` `/5` scanner for players looking for a guild (German + English, editable keywords), right-click "Invite to guild", welcome message with Discord link, DE/EN switch, support window, version + self test. All texts are editable and every feature can be toggled.

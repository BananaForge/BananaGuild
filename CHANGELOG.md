# Changelog

Die Version steht in `BananaGuild.toc` (`## Version`) und wird im Fenster rechts unten angezeigt.
Bei jeder Änderung am Addon wird sie hochgezählt.

## 2.1.0
- Daten-Fenster: Die **Berufe** sind größer geschrieben (Schriftgröße 10 statt 8, vier Knöpfe pro Reihe).
- **Spec und Zweit-Spec in einer Reihe**: Es gibt nur noch eine Spec-Reihe. Der erste Klick wählt den Spec, der zweite den Zweit-Spec (am Knopf steht „(2)"), ein dritter ersetzt den Zweit-Spec. Wer den ersten abwählt, schiebt den zweiten nach oben, „leer" löscht beide. Die Reihe „Zweit-Spec" ist entfernt.
- **Die Notiz ist jetzt eine gemeinsame Notiz**: Jeder Offizier sieht und bearbeitet sie (bis 60 Zeichen), sie wird wie die anderen Daten unter den Offizieren abgeglichen (Nachricht `N`, eigener Zeitstempel, nur von Offiziersrängen angenommen, Sonderzeichen werden maskiert) und steht im Mitglieder-Reiter im Detailbereich. Alte private Notizen werden beim Start automatisch in die gemeinsame Notiz übernommen. Export/Import und der Abgleich für neu angemeldete Offiziere enthalten die Notizen.
- Die angezeigte Flüster-Antwort im Fenster ist entfernt (die Antwort kommt im Chat), das Fenster ist dadurch deutlich niedriger.

## 2.0.0
- **Mitgliederdaten nur noch im Addon, keine Gildennotiz mehr.** Main/Twink, Berufe, Spec und Zweit-Spec werden im Fenster „Daten bearbeiten" (Neuzugang-Fenster) eingetragen und im Addon gespeichert. Es gibt keine 31-Zeichen-Grenze, keine Notiz-Vorschau und keinen Zeichenzähler mehr, statt dessen eine Statuszeile („✓ Daten vollständig" bzw. „Es fehlt noch: ..."). Bearbeiten dürfen Offiziere (Rang wie beim Begrüßungs-Popup) und alles darüber, das Notiz-Recht ist nicht mehr nötig.
- **Sync unter den Offizieren:** Jeder Eintrag geht an alle Offiziere mit dem Addon (Nachricht `M`, nur von Offiziersrängen angenommen, neuere Daten gewinnen). Wer neu online kommt, fragt (`MQ`) und ein Offizier schickt ihm alles Bekannte (`MS`). Main/Twink läuft weiter über den bisherigen Abgleich.
- **Einmaliger Import der alten Notizen** beim ersten Scan nach dem Update: Main/Twink, Berufe und Spec werden übernommen, die Notizen selbst bleiben unberührt und werden nie mehr geändert. Notizen, die sich nicht (vollständig) lesen lassen, listet ein **Popup** mit den Charakternamen, mit einem Knopf, der jeden Charakter samt Notiztext in den Chat schreibt. Später jederzeit über Einstellungen > Daten („Aus Gildennotizen importieren").
- Neue Einstellungs-Seite **Daten**: Import der Notizen, Export und Import der Addon-Daten als Text (Sicherung, auch für neue Offiziere), Zahlen zu den vorhandenen Daten.
- Entfernt: Schreiben der Gildennotiz, Notiz-Vorschau, Zeichenzähler und die automatische Auswertung der Antworten („Vorschlag aus der Antwort"). Die Nachfrage-Knöpfe und die Anzeige der letzten Antworten bleiben.
- Statistik, Mitgliederliste, Accounts-Zähler und Neuling Check lesen jetzt die Addon-Daten („Daten ok / fehlen" statt „Notiz ok / fehlt", „Ohne Daten" statt „Ohne gültige Notiz"). Der Zweit-Spec zieht aus 1.24 automatisch in die neuen Daten um.

## 1.24.0
- Dual-Spec umgebaut: Es wird **nichts mehr automatisch ausgelesen** (die Talent-Erkennung aus 1.23 ist entfernt). Stattdessen fragt der Einlader / Rekrutierer / Offizier den Spieler wie gewohnt nach den Specs und trägt den **Zweit-Spec** im Neuzugang-Fenster (auch über „Notiz bearbeiten ...") von Hand ein: neue Zeile „Zweit-Spec" mit denselben Knöpfen wie beim Spec, darunter „keiner". Der Zweit-Spec kommt **nicht** in die Gildennotiz, sondern bleibt im Addon, es gibt also kein Zeilenlängen-Problem.
- Der Eintrag wird an alle Offiziere mit dem Addon weitergegeben (Nachricht `D`, nur von Offiziersrängen angenommen, Entfernen wird mitgeschickt). Wer neu online kommt, fragt (`DQ`) und ein Offizier schickt ihm alles Bekannte (`DS`).
- Antworten-Auswertung: Nennt ein Spieler zwei Specs („Prot und Waffen"), schlägt das Fenster den ersten als Spec und den zweiten als Zweit-Spec vor.
- Mitglieder-Reiter zeigt „Zweit-Spec: ..." im Detailbereich; Statistik > Rollen hat weiter den Haken „Beide Specs zählen".
- Entfernt: automatisches Auslesen der Talente, die Ticker und die Nachrichten der automatischen Meldung.

## 1.23.1
- Fix: In 1.23.0 konnte die Statistik beim Wechsel zwischen den Ansichten (Klassen, Specs pro Klasse) mit einem Lua-Fehler abbrechen. Behoben.

## 1.23.0
- Dual-Spec: Das Addon erfasst die Specs eines Charakters, ohne etwas in die Gildennotiz zu schreiben. Jeder Client liest die Talente seines eigenen Charakters (WoW 1.12 liefert nur die eigenen) und merkt sich die zwei zuletzt gespielten Specs. Sobald jemand beide einmal gespielt hat, kennt das Addon beide. Die Daten gehen automatisch an alle, die BananaGuild nutzen (Nachricht `D`, beim Login und bei jedem Wechsel, zusätzlich alle 30 Minuten). Wer neu online kommt, fragt (`DQ`), und ein Offizier schickt ihm die bekannten Daten aller anderen (`DS`, nur von Offiziersrängen angenommen).
- Mitglieder-Reiter: Im Detailbereich steht „Specs (Addon): Schutz / Heilig", der gerade aktive Spec in Gold.
- Statistik > Rollen: Neuer Haken „Beide Specs zählen". Wer zwei Rollen spielen kann (z. B. Tank und Heal), zählt bei beiden mit; so siehst du, wie viele Tanks, Heiler und DDs ihr wirklich habt. Die Prozente beziehen sich dann auf die Zahl der Charaktere (Summe über 100). Ohne Spec in der Notiz nutzt die Statistik jetzt den vom Addon gemeldeten aktiven Spec, dadurch sinkt die Zahl „unbekannt".
- Hinweis: Beim Druiden wählt das Addon bei Wildheit-Talenten „Katze", außer die Notiz nennt „Bär". Neue Datei `Dual.lua`.

## 1.22.1
- Einstellungen > Beförderung: Die Zeilen „Neulinge prüfen nach ... Wochen", „Auf Inaktiv setzen nach ... Tagen offline" und Start-/Zielrang überlagerten sich. Neu angeordnet, jede Zeile hat ihren eigenen Platz.

## 1.22.0
- Neuling Check: Zwei Ansichten oben im Fenster, **Befördern (N)** und **Auf Inaktiv setzen (M)**. In „Auf Inaktiv setzen" stehen alle Mitglieder des Startrangs (Initiant), die länger als N Tage (Standard 20) nicht mehr online waren. Pro Zeile „-> Inaktiv", unten „Alle auf Inaktiv" (zweimal klicken zum Bestätigen). Es wird der Rang aus dem Inaktiv-Fenster verwendet, die Beförderung läuft Schritt für Schritt wie sonst, die Bank-Info-Whisper gibt es dabei nicht.
- „Befördern" zeigt nur noch die, die nicht zu lange offline waren; „Alle befördern" und „Alle Online befördern" gelten nur für diese Liste. Wer lange offline war und wieder online kommt, steht sofort wieder bei „Befördern" (das Popup aus 1.20.0 meldet ihn).
- Die tägliche Erinnerung öffnet den Neuling Check auf der Liste, in der etwas steht, also auch wenn nur Inaktiv-Kandidaten da sind.
- Einstellungen > Beförderung: „Auf Inaktiv setzen nach [20] Tagen offline" (0 schaltet die Ansicht aus), daneben wie bisher die Wochen bis zur Beförderung.
- Fix: Die rote Bestätigungszeile nach dem ersten Klick auf einen Sammelknopf zeigte keine Zahl.

## 1.21.1
- Statistik: Neuer Haken „Rang „Inaktiv" ausblenden" oben links im Statistik-Fenster. Ist er gesetzt, zählen die Mitglieder auf dem Inaktiv-Rang (Name aus den Einstellungen des Inaktiv-Fensters, Standard „Inaktiv") in keiner Statistik mit (Klassen, Specs pro Klasse, Rollen). Unter dem Titel steht dann, wie viele ausgeblendet sind. Die Einstellung wird gespeichert.

## 1.21.0
- Statistik > Rollen: Neuer Aktivitäts-Regler („Offline höchstens: ..."). Stufen 1, 2, 3, 5, 7, 10, 14, 21, 30, 60 Tage oder „alle". Es zählen nur Charaktere, die online sind oder höchstens so lange offline waren, zusammen mit dem Level-Bereich. So siehst du, wie die wirklich aktiven Leute aufgestellt sind. Charaktere ohne Offline-Angabe werden bei aktivem Filter nicht mitgezählt (die Info-Zeile sagt, wie viele).
- Umschaltbar „Nach Rolle" (Tank / Heal / DD / unbekannt) oder „Nach Klasse": Das Kuchendiagramm, die Zeilen und die Namensliste zeigen dann die Klassen der Auswahl in Klassenfarben. Mouse-over auf einer Klasse zeigt, wie sie sich auf Tank / Heal / DD aufteilt; die Namensliste gruppiert Klasse, dann Rolle, dann Namen.
- Das Statistik-Fenster ist etwas höher (600 statt 524), damit Zeilen und Namensliste Platz haben. Auch die Einstellungen werden gespeichert (Bereich, Aktivität, Ansicht).

## 1.20.0
- Neuling Check: Automatisches Popup, sobald jemand aus der Liste online ist (kommt online oder ist beim Login schon online, ca. 35 Sekunden nach dem Login). Oben groß „Neuling Check", darunter Name in Klassenfarbe, Stufe, Klasse und Tage in der Gilde, dazu der Knopf „Zu Member befördern" (befördert genau diese Person, danach geht wie gewohnt die Bank-Info per Flüstern raus), „Neuling Check öffnen" und „Später" (heute nicht mehr melden). Pro Person höchstens alle 2 Stunden; sind mehr als drei gleichzeitig online, gibt es ein Sammel-Popup mit „Neuling Check öffnen". Nur für Spieler mit Beförderungsrecht, im Instanzmodus wie die anderen Beförderungs-Meldungen unterdrückt.
- Abschaltbar unter Einstellungen > Beförderung („Popup, wenn ein Neuling online ist").
- Popups können eine große Überschrift haben.

## 1.19.2
- Das BananaGuild-Hauptfenster kommt jetzt beim Öffnen und beim Anklicken nach vorn (auch vor andere Addon-Fenster wie BananaBank). Vorher konnten sich Teile beider Fenster ineinander mischen, wenn sie gleichzeitig offen waren.

## 1.19.1
- Rollen-Statistik: Unter dem Diagramm steht jetzt eine Liste mit den Namen. Oben die Rolle (Tank, Heal, DD, unbekannt) mit Anzahl, darunter je Klasse in Klassenfarbe die Charaktere. Bei langen Listen scrollt sie (Mausrad oder Balken).
- Die drei Knöpfe oben (Klassen, Specs pro Klasse, Rollen) sind etwas schmaler, damit der Schließen-Knopf oben rechts nicht mehr überdeckt wird.

## 1.19.0
- Statistik: Neuer Knopf „Rollen" neben „Klassen" und „Specs pro Klasse". Er zeigt ein Kuchendiagramm (Donut) mit der Rollenverteilung Tank / Heal / DD / unbekannt für einen frei wählbaren Level-Bereich, damit Low-Level- und Level-Charaktere die Auswertung nicht verfälschen (Standard Level 40 bis 60). Zwei Felder für „Level von ... bis ..." und Schnellknöpfe „Ab 40", „Ab 50", „Nur 60" und „Alle"; der Bereich wird gespeichert.
- Mouse-over auf einer Rolle (Segment oder Zeile) zeigt, aus welchen Klassen und Specs sie besteht, z. B. „Krieger (Schutz): 4". Die Rolle kommt aus dem Spec in der Gildennotiz; ohne Spec zählt der Charakter als „unbekannt".

## 1.18.0
- Gildensuche: Neue Wunschliste. Offiziere haken die gesuchten Klassen (9) und Rollen (Tank, Heiler, DD) an. Ist nichts oder alles angehakt, werden wie bisher die allgemeinen Suchtexte gepostet. Sonst postet die Suche nur noch Texte für genau diese Auswahl: 1 Klasse, 2-4 Klassen, 5+ Klassen, nur Rollen oder Rollen + Klassen, je 10 Varianten (50 neue Texte, lockerer Ton). Platzhalter: `{klassen}` (Priester, Druiden und Magier), `{klassen_oder}`, `{klasse}`, `{klasse_akk}` und `{guild}`. Wird die Nachricht mit der Liste länger als 255 Zeichen, steht „viele Klassen" statt der Aufzählung.
- Die Wunschliste wird an alle Rekrutierer synchronisiert: Offiziere (bis zum Sync-Rang oder dem Offiziersrang der Einstellungen) ändern sie, andere Addon-Nutzer übernehmen sie automatisch, auch beim Login. Die Seite zeigt, wer sie zuletzt geändert hat.
- Flüster- und Scanner-Popup kontrollieren die Klasse des Interessenten: „Gesuchte Klasse: Magier" in Gold, „Gesuchte Rolle möglich: Tank, Heiler" in Grün oder „Achtung: Priester wird aktuell nicht gesucht (gesucht: ...)" in Orange.
- Die Seite Gildensuche ist jetzt reine Steuerung: der Texteditor ist entfernt, die Texte stehen nur noch im Reiter Texte.
- Reiter Texte komplett neu: Links die Textarten nach Themen (Gildensuche, Begrüßung, Interessenten, Mitglieder) mit Anzahl, in der Mitte die Varianten als scrollbare Liste (Nummer, Textanfang, Länge, geänderte Varianten grün markiert), darunter der Editor mit Zeichenzähler, Platzhalter-Knöpfen zum Einfügen und Live-Vorschau. Einzelne Varianten lassen sich ausschalten (werden beim Zufall übersprungen). Neu im Reiter: die allgemeinen Suchtexte und die fünf Klassen-Suchtexte.
- Discord-Link und Gildenname sind von der Texte-Seite nach Einstellungen > Gilde umgezogen, mit Hinweis, ob der Link eingetragen ist.

## 1.17.0
- GZ- und Levelup-Funktion entfernt, ist jetzt Teil von BananaBank: Levelup-Hinweis mit GZ-Button, Stufe-60-Anzeige, GZ-Texte und die zugehörigen Einstellungen (GZ-Modi, Schalter „Levelup-Hinweis", „Stufe 60", „auch für mich selbst"), die Befehle `/bgd gz`, `/bgd test60`, `/bgd testlevel` sowie die Levelup-Meldungen im Instanzmodus. Alte gespeicherte GZ-Daten werden beim Start verworfen. Alte Levelup-Einträge im Verlauf bleiben sichtbar, neue entstehen hier nicht mehr.
- Das Addon zeigt weiterhin die Stufe der Mitglieder (Mitgliederliste, Neuling Check, Statistik).

## 1.16.3
- Neuling Check: Dauerhafter Hinweis unten links („Sammel-Knöpfe: zum Bestätigen zweimal klicken") und Tooltips an „Alle Online befördern" / „Alle befördern".
- Bank-Info-Whisper: Das Addon versucht den Whisper jetzt nach jeder Beförderung immer (das Online-Kennzeichen der Gildenliste kann ein paar Sekunden alt sein) und schreibt „Bank-Info an NAME geflüstert." in den Chat. Fehlt der Text, kommt ein Hinweis.

## 1.16.2
- Neuling Check: Nach dem ersten Klick auf „Alle Online befördern" / „Alle befördern" steht unten in Rot, dass man nochmal klicken muss (10 Sekunden Zeit statt 6), damit nicht der Eindruck entsteht, der Knopf tue nichts.

## 1.16.1
- Neuling Check: „Alle befördern" und „Alle Online befördern" brauchen jetzt einen zweiten Klick innerhalb von 6 Sekunden („Sicher? N befördern"), damit niemand versehentlich befördert wird. Der Einzel-Knopf „-> Member" befördert wie bisher nur diese eine Person.

## 1.16.0
- Neuling Check: Wer online ist, steht oben, danach nach „zuletzt online" (zuletzt gesehen zuerst). Neuer Button „Alle Online befördern (N)": befördert alle Online-Mitglieder der Liste, und zwar zuerst der neue Rang, danach bekommt jeder eine Flüster-Nachricht über den Zugriff auf die Bananenbank (Rezepte und BoEs zum halben AH-Preis, Addon-Download im Discord-Channel BananaForge-Addons).
- Neuer Text im Reiter Texte: „Bank-Info" mit 3 humorvollen Varianten, editierbar. Die Flüster-Nachricht wird nach jeder Beförderung über den Neuling Check gesendet, wenn der Spieler online ist; abschaltbar unter Einstellungen > Beförderung („Nach Beförderung Bank-Info flüstern").
- „Bald fällig" zeigt nur noch den nächsten Tag mit allen Namen in einer Zeile (kein „... und N weitere" mehr).
- Texte-Reiter: Fünf Knöpfe pro Reihe, damit der neue Text passt; Texte mit weniger als 5 Varianten zeigen nur so viele Variantenknöpfe wie vorhanden.

## 1.15.1
- Neuling Check: Das Fenster ist größer und die Zeilen passen jetzt (Name und „Notiz ok / fehlt" oben, Stufe / Beitritt / zuletzt online darunter, nichts läuft mehr über den Rand). Bei mehr Mitgliedern als Platz gibt es einen Scrollbalken (auch Mausrad). Der Text „+ N" überlagerte sich mit „Bald fällig" und ist weg, „Bald fällig" zeigt bei Bedarf „... und N weitere". „vor 1 Tagen" heißt jetzt „vor 1 Tag", „in 1 Tagen" „in 1 Tag".

## 1.15.0
- Die Nachfrage-Texte per Flüstern (Berufe, Spec, Twinks, „Alles fragen") sind neu geschrieben und klingen lockerer und menschlicher: kürzer, ohne „kurze Frage von der Gildenleitung" und Umfrage-Floskeln, teils klein geschrieben. Deutsch und Englisch. Eigene Änderungen bleiben vorn stehen, unveränderte alte Standardtexte werden ersetzt.

## 1.14.0
- Alle GZ- und Begrüßungstexte (20 GZ, 30 Rekrutierung mit Discord, 20 Rollenspiel) sind neu und klingen lockerer und menschlicher: kürzer, oft klein geschrieben, weniger Pathos und Ausrufezeichen, unterschiedliche Satzanfänge, der Discord-Ablauf in einem lockeren Satz statt als Liste. Nur Deutsch, bei englischer Oberfläche werden die deutschen Texte genutzt.
- Eigene Änderungen an diesen Texten bleiben vorn stehen, unveränderte alte Standardtexte (1.13.x) werden ersetzt.

## 1.13.4
- Neuzugang-/Notiz-Fenster: Der „Vorschlag aus der Antwort" verschwindet, sobald die Felder schon genau das zeigen (vorher blieb er nach dem Übernehmen stehen). Unter „Antwort" stehen jetzt bis zu die letzten drei Antworten (der Vorschlag wird aus allen der letzten 30 Minuten gelesen, vorher sah man nur die letzte, z. B. nur „oki"). Mehr Platz zwischen Vorschlag und den unteren Knöpfen, Vorschlag-Knopf breiter.

## 1.13.3
- Neuling Check: „Niemand ist gerade fällig." steht jetzt oben im leeren Listenbereich und nicht mehr unten über dem Block „Bald fällig".

## 1.13.2
- Die Sperre gegen doppelte Begrüßungen ist entfernt: Mehrere Offiziere dürfen im Gildenchat Hallo sagen, damit mehr los ist. Es gibt keine Meldung „Bereits begrüßt von ..." mehr, keine Abstimmung zwischen den Clients und keine Zufallsverzögerung. Einzige Regel bleibt: Der Gruß mit Discord-Link kommt nur vom Einlader / Rekrutierer, Offiziere senden immer einen Rollenspiel-Text.

## 1.13.1
- Korrektur der Begrüßungs-Logik: Das Neuzugang-Fenster (Main/Twink, Berufe, Spec) bekommt nur noch, wer das neue Mitglied eingeladen hat (bzw. rekrutiert). Offiziere (Einstellungen > Beförderung, „Begrüßungs-Popup für Offiziere ab Rang", Standard Offiziere) bekommen stattdessen ein kleines Popup mit einem Rollenspiel-Gruß zum schnellen Absenden. Niemand wird doppelt begrüßt (wie in 1.13.0).
- Der Einlader / Rekrutierer sendet immer den Gruß mit Discord-Link. Die 30 Texte wurden neu geschrieben und erklären den Ablauf im Discord: Regeln im Willkommenschat akzeptieren, kurz vorstellen, Klasse wählen (Rolle vom Bot), Rolle Banane von den Offizieren nach der Vorstellung. Ein Teil erwähnt die Gildenaddons BananaBank / BananaCraft. Alle bleiben deutlich unter der Chat-Grenze. Eigene Änderungen an den alten Rekrutierungs-Texten bleiben vorn erhalten. Ohne echten Discord-Link wird der Rollenspiel-Gruß genutzt.
- GZ-Einstellung: Die Auswahl einzelner Stufen (5, 10, 15 ... 60) entfällt, die drei Modi reichen.

## 1.13.0
- GZ-Einstellung: Statt „jeder Stufe / nur gewählte 10er" gibt es drei Checkboxen, von denen genau eine aktiv ist: „Bei jedem Level" (Standard), „In 5er-Stufen" und „In 10er-Stufen". Darunter lassen sich die Stufen 5, 10, 15 ... 60 einzeln abwählen (gilt für die 5er- bzw. 10er-Stufen). Einmalig werden bestehende Einstellungen auf „Bei jedem Level" zurückgesetzt.
- 20 Varianten für GZ und Begrüßung (alle anderen Texte bleiben bei 5). Im Reiter Texte wählst du sie in einem scrollbaren Auswahlmenü „Variante 1-20". Alle 20 GZ-Texte enthalten die Stufe `{level}`. Selbst geänderte alte Varianten bleiben vorn stehen, unveränderte Standardtexte werden durch die neuen ersetzt, der Rest wird mit neuen Standardtexten aufgefüllt (deutsch und englisch).
- Zwei Begrüßungs-Texte: „Willk. Rekrutierung" (mit Discord-Link, bei einem Teil auch mit Hinweis auf BananaBank / BananaCraft) wird genutzt, wenn bei dir die automatische Gildensuche läuft und ein Discord-Link eingetragen ist. Sonst kommt „Willk. Rollenspiel" (freundlich, ohne Link). Alte Begrüßungen mit `{discord}` wandern in die Rekrutierungs-Texte. Ist noch der Platzhalter-Link eingetragen, wird der Rollenspiel-Text genutzt und im Chat ein Hinweis gezeigt. Der Discord-Link ist mit https://discord.gg/KNPPqHh8H vorbelegt (ein eigener Link bleibt erhalten).
- Neuzugang-Fenster für alle Offiziere (Einstellungen > Beförderung: „Fenster für neue Mitglieder ab Rang", Standard Offiziere) und immer für den Einlader. Es wird nie doppelt begrüßt: Jede gesendete Begrüßung meldet das Addon an alle anderen (Nachricht `W`), deren Begrüßen-Knopf verschwindet („Bereits begrüßt von ..."), geplante Auto-Begrüßungen werden abgebrochen. Die Auto-Begrüßung wartet 3-5 Sekunden zufällig und prüft vorher noch einmal.
- „Beförderungen" heißt jetzt **Neuling Check**: Das Fenster zeigt alle Initianten, die mindestens N Wochen (Standard jetzt 2, bestehende Einstellung bleibt) in der Gilde sind, mit Stufe, Beitrittsdatum und Tagen, zuletzt online und Notiz ok / fehlt. Dazu der Block „Bald fällig" (wer in den nächsten 7 Tagen so weit ist). „-> Member" befördert einzeln, „Alle befördern" alle.
- Neuzugang-Fenster mit Nachfragen: Buttons „Alles fragen", „Berufe fragen", „Spec fragen", „Twinks fragen" flüstern dem Spieler eine zufällige Frage aus dem Reiter Texte. Seine Flüster-Antworten (30 Minuten) erscheinen im Fenster, das Addon liest daraus einen Vorschlag (Berufe, Spec, Main/Twink) und zeigt ihn an. „Vorschlag übernehmen" trägt ihn in die Felder ein, übernommen wird erst mit den normalen Knöpfen.

## 1.12.0
- Mitglieder-Reiter: Oben stehen jetzt zwei Ansichten, „Übersicht" (wie bisher) und „Nach Eintrittsdatum". Die neue Ansicht zeigt Name, Level, Beigetreten, Offline-Dauer und Rang, standardmäßig die neuesten Mitglieder zuerst. Alle Spaltenköpfe sind klickbar (Eintrittsdatum, Offline-Zeit, Rang, Name, Level). Der Filter „Offline ab N Tagen" zeigt nur lange Abwesende. Die Offline-Zeit ist grau, ab der Hälfte des Grenzwerts orange und ab dem Grenzwert rot, wer online ist, steht als „online" da. Im Detailbereich steht „Zuletzt online: vor 3 Monaten".
- Neuer Button „Inaktive ...": Fenster mit allen Mitgliedern, die mindestens N Tage offline waren (Standard 30 bzw. 90, einstellbar). Zwei Aktionen: „Auf Inaktiv setzen" (Zielrang wählbar, Schritt für Schritt wie bei der Beförderung) und „Aus der Gilde entfernen" (einzeln nacheinander, nur mit zusätzlicher Bestätigung, vor jedem Entfernen wird noch einmal geprüft). Vorschau mit Haken pro Mitglied, längste Abwesenheit zuerst. Es werden nur Mitglieder unterhalb des eigenen Ranges angeboten.
- Woher die Offline-Zeit kommt: aus der Gildenliste („Zuletzt online"), wenn der Client sie liefert. Sonst zählt das Addon ab dem Tag, an dem es ein Mitglied zuletzt online gesehen hat (der Selbsttest zeigt, welche Quelle genutzt wird).
- Der Button „Klassen- & Spec-Statistik" heißt jetzt „Statistik".

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

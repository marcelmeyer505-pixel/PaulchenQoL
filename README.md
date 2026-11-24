# Paulchen QoL v0.12.0

## Deutsch / English

Paulchen QoL now offers **German and English**. By default, the addon follows the World of Warcraft client locale: `deDE` uses German, while `enUS`, `enGB` and other client locales use English. You can override this independently of your game client in **Paulchen Settings → Language**:

- **Automatic / Automatisch** – follow the game client
- **German / Deutsch** – always use German UI text and companion speech
- **English / Englisch** – always use English UI text and companion speech

You can also enter `/pq lang auto`, `/pq lang de`, or `/pq lang en` in chat. The selection is saved globally in `PaulchenQoLSettings.language`, and the interface reloads after a change to refresh existing text labels.

The German and English companion lines share the same dialogue IDs, context requirements and cooldowns. Names supplied by the game or entered by players stay as entered. For an in-combat language change, use `/reload` after combat.

The test `tests/localization_fixture.lua` checks automatic selection, language overrides, both versions of every companion line and their placeholders.

Paulchen ist ein Hordevogel mit Headset für **World of Warcraft: Forever** (Interface `16001`). Er kommentiert Ereignisse mit einer von fünf Illustrationen. Die Übersicht mit Reise-Check, die sortierbare Taschenliste mit Vormerkungen, die Markierung des günstigsten Stapels und der Flugtimer gehören ebenfalls zum Addon.

**Paulchens Buffwächter** prüft eigene, Gruppen- und Raidbuffs im neuen Reiter **Buffs**. Er unterscheidet grün **vorhanden**, rot **fehlt** und grau **unbekannt**. Geschützte, nicht lesbare, tote, ausgeloggte oder entfernte Spieler werden niemals allein deswegen als ungebufft gemeldet. Buffsymbole bieten Tooltips; Raidmitglieder erscheinen in einer scrollbaren Übersicht. Aura-Ereignisse werden 0,2 Sekunden gebündelt und betreffen normalerweise nur den geänderten Spieler. Roster-/Fähigkeitsänderungen und bewusste Checks erneuern die ganze Übersicht. Während der Reiter offen ist, werden unbekannte oder inzwischen entfernte Spieler alle zwei Sekunden gezielt nachgeprüft.

### Buffwächter einrichten

Unter **Einstellungen → Buffwächter einstellen** oder im Buff-Reiter lassen sich eigene Prüfung, Gruppenprüfung, Raidprüfung, Automeldungen, lokale Kommentare und der Reiter separat schalten. Kernfamilien sind Wildnis, Seelenstärke, Intelligenz und Paladinsegen. Göttlicher Wille und Schattenschutz starten als optionale Familien ausgeschaltet. Ohne passenden Buffgeber verlangt „Automatisch“ keinen Buff. Intelligenz und Wille werden automatisch nur für Manaklassen verlangt. **Anforderungen pro Klasse** bietet für jede Familie **Automatisch / Pflicht / Aus** und für Segen die Auswahl einer bestimmten Variante oder eines beliebigen Segens. „Pflicht“ ist eine bewusste Anforderung, auch ohne automatisch erkannten Buffgeber; eine insgesamt ausgeschaltete Familie bleibt ausgeschaltet.

Eigene erlernte Fähigkeiten werden über die verfügbaren Zauberbuch-APIs geprüft. Einzel- und Gruppenvarianten sowie klassische Ränge gehören zur gleichen Familie. Zusätzliche Forever-Ränge können anhand desselben lokalisierten Namens aus dem modernen Zauberbuch erkannt werden. Fremde Zauberbücher und Talente lassen sich damit nicht zuverlässig ermitteln: Nicht bestätigte Talentbuffs wie Göttlicher Wille oder ein gezielt verlangter Segen der Könige bleiben im automatischen Modus unbekannt, statt eine fehlende Fähigkeit zu erfinden. Die Wildnis-Erinnerung verwendet denselben Prüfer und denselben bisherigen Erinnerungsschlüssel; es laufen keine zwei persönlichen Warnsysteme parallel.

### Gruppenchat und Kommentare

Nach einem **erfolgreichen eigenen Wildniszauber** wartet Paulchen ungefähr eine Sekunde nach dem letzten unmittelbar folgenden Zauber und prüft den aktuellen Gruppenstand erneut. Nur Druiden, die in einer Gruppe sind, lösen diesen Automatikbericht aus. Er ist für normale Gruppen anfangs aktiv; **automatische Raidmeldungen sind anfangs aus**. Fehlgeschlagene oder fremde Zauber senden nichts. Änderungen der Gruppe und Einstellungen verwerfen noch ausstehende Meldungen. Der Chat-Abstand ist zwischen 60 und 600 Sekunden einstellbar; identische Zustandsberichte werden zusätzlich unterdrückt. Letzter erfolgreicher Bericht und Cooldown werden pro Charakter gespeichert und überleben `/reload`.

Berichte nennen sicher fehlende Buffs und kennzeichnen unvollständige Prüfungen ausdrücklich. Eine Meldung umfasst höchstens 250 UTF-8-Bytes; bei langen Raidlisten werden Mengen und ein Verweis auf die Detailansicht verwendet. Der Kanal folgt der aktuellen Gruppe (Gruppe, Raid oder Instanzgruppe). Lokale freche Kommentare verwenden Paulchens vorhandene Prioritäten, 15-Sekunden-Sprechblasen und Kategorie-Cooldowns; der Gruppenchat bleibt sachlich. Einzelne unbekannte Auren können alle noch nicht erkannten Familien eines Spielers unbekannt machen. Lesbar vorhandene Buffs dürfen trotzdem als vorhanden angezeigt werden.

Bei aktiven Kampf-/Client-/Chatrestriktionen wird nichts gesendet. Moderne Chat-API und Legacy-Fallback werden nur nach Verfügbarkeitsprüfung verwendet; nach einem abgelehnten Aufruf gibt es keine Wiederholungsversuche über andere APIs. **Bericht übernehmen** öffnet ein lokales Kopierfeld mit dem aktuellen Bericht und passendem Chatpräfix. Du kannst ihn selbst einfügen und senden. Der Buffwächter wirkt keine Zauber und führt keine geschützten Aktionen aus. Die Prüfung im echten Forever-Client bleibt erforderlich; siehe [Buffwächter-Prüfbericht](BUFFWATCHER_TESTS.md).

**Paulchens Logbuch** zeigt die letzten zehn Kämpfe, eigene DPS mit Durchschnitt, Crit-Rekorde, Gegnerprofile sowie EP-Statistiken und Farmrunden. Die Kompaktansicht zeigt zwei wählbare Kennzahlen und die Steuerung für Farmrunden. **Paulchen Upgrades** vergleicht Ausrüstung inklusive manuell geplanter Charakterstufe, Spalten, Filtern und Loot-Alarm. Der Auktionsscan liefert Marktangebote an das Upgrade-Fenster.

**Upgrades → Statprofile** bietet 28 Startprofile für die neun Klassen in Forever. Katze und Bär haben eigene Profile. Wähle die Spezialisierung und passe die Punkte pro Attribut an. Paulchen speichert deine Auswahl und Änderungen pro Charakter. Der Profilname steht oben im Upgrade-Fenster und neben dem Vergleich im Item-Tooltip. Die Vorgaben sind Ausgangswerte für die Ausrüstungssuche.

**Feral Katze** startet mit 1,90 Punkten pro Beweglichkeit, 0,80 pro Stärke, 0,40 pro Angriffskraft und 5,60 pro Nahkampfwaffen-DPS. Dazu kommen 10,20 pro Prozent Krit, 8,77 pro Prozent Trefferchance, 4,78 pro Prozent Angriffstempo, 0,85 pro Waffenkundewertung und 0,13 pro Rüstungsdurchschlag.

Ein Upgrade-Suchlauf startet beim Login, nach `/reload` oder mit **Aktualisieren**. Änderungen an Ausrüstung, Taschen, Statprofil, Suchstufe oder Inhaltsfreigaben markieren die letzte Liste als veraltet. Beim nächsten Suchlauf übernimmt Paulchen unveränderte Wertungen für bekannte Items und Varianten. Die Statuszeile zeigt **neu bewertet** und **übernommen**.

Diese Regeln gelten auch in Dungeons und Raids. Ein laufender Suchlauf pausiert im Kampf und setzt danach an derselben Stelle fort. Der Loot-Alarm bewertet einzelne Drops direkt.

Sichere Rüstungs- und Schmuckwertungen einschließlich ihrer Varianten werden pro Charakter dauerhaft gespeichert. WoW sichert sie beim Ausloggen oder mit `/reload`. Bei gleicher Ausrüstung, Stufe, Spezialisierung und Gewichtung werden sie auch beim nächsten Login wiederverwendet. Ein passender älterer Punktespeicher wird übernommen. Waffenabhängige Vergleiche bleiben in der Sitzung; neue mögliche Waffen-/Nebenhand-Kombinationen aktualisieren diese Werte gezielt. Normale Waffen-Skillsteigerungen ohne Änderung der Nutzbarkeit verwerfen keine Wertungen.

Echte Ausrüstungs-, Stufen-, Profil- oder Gewichtungsänderungen erneuern den Vergleichsstand. Neue Itemdaten verwerfen nur die Wertungen des betroffenen Items und seiner Varianten. Fundorte, Queststatus, Taschenbesitz und Auktionsangebote werden bei jedem Check frisch aus den verfügbaren Quellen ermittelt. Verkauftes oder entferntes Inventar bleibt dadurch nicht als Taschenfundort stehen. Die Wiederverwendung ändert keine Stat-Gewichtungen und keine Gegenstandsaktionen.

Der Ausrüstungsvergleich nutzt die Itemwerte des WoW-Clients. Die Suche berücksichtigt deine Taschen, aktive Questbelohnungen, die geladene AH-Übersicht und gespeicherte Auktionsscans. Polestar, AtlasLoot und Forever Dungeon Journal können zusätzliche Fundorte beitragen. Im Reiter **Instanzen** erscheint derselbe Fundort einmal. Wenn AtlasLoot eine Dropchance für den Boss kennt, wird sie übernommen.

Im Quellenfilter **Auktionshaus** zeigt Paulchen für handelbare BoE-Upgrades ohne erfasstes Angebot **[PREIS] TSM-Schätzpreis** an, sofern TSM für die Itemvariante einen `DBMinBuyout` liefert. Der Wert gibt das günstigste Angebot aus dem letzten TSM-Datenstand pro Stück an. Bei einem konkreten Angebot zeigt die Zeile dessen Preis. Falls TSM ebenfalls einen Wert liefert, steht er zusätzlich im Tooltip. Rechtsklick startet die AH-Suche nach dem Item. **Nur Paulchens Scanner** in den Preiseinstellungen schaltet TSM auch hier ab.

Der Quellenfilter **Undermine Real** zeigt verfügbare Upgrades vom Händler Pix Xizzix in Beutebucht, die der optionale Polestar-Codex als Händlerquelle meldet.

Unter **Spielinhalte** kannst du **PvP-Händler** pro Charakter freischalten. Der Haken ist anfangs aus und gilt beim nächsten Klick auf **Aktualisieren**. Mit dem Quellenfilter **PvP-Händler** siehst du anschließend die vom Polestar-Codex erfassten Ehren- und Schlachtfeldhändler. Ein bekannter PvP-Rang steht beim Fundort im Tooltip.

**Upgrades → Spielinhalte** speichert die Freigaben pro Charakter. Für den aktuell gemeldeten Serverstand starten Geschmolzener Kern, Onyxia, Pechschwingenhort, Zul'Gurub, beide Ahn'Qiraj-Raids, Naxxramas und weitere Raids ausgeschaltet. UBRS und die normalen Dungeons bleiben verfügbar. Klassische Weltbosse haben einen eigenen Schalter und bleiben zunächst eingeschaltet; ihre Verfügbarkeit wurde nicht bestätigt. Sobald ein Inhalt auf deinem Server öffnet, kannst du ihn hier aktivieren. Die Freigaben werden nicht automatisch aus dem Kalender erkannt; AtlasLoot meldet momentan bereits sämtliche klassischen Phasen als offen.

Geschlossene Quellen einschließlich bekannter zugehöriger Rufbelohnungen, Raid-Item-Abgaben und Questketten werden herausgefiltert. Das betrifft auch Quests, die außerhalb des Raids angeboten werden, etwa „Eine Sammlung von Köpfen“. Ein pauschaler BoE-/AH-Hinweis hebt die Sperre nicht auf. Tatsächlich vorhandene Taschenitems, gespeicherte konkrete AH-Angebote und nachgewiesene alternative offene Dungeonquellen bleiben sichtbar. Gespeicherte Angebote können inzwischen verkauft sein. Freigaben ändern die Fundorte; bereits berechnete Stat-Wertungen bleiben wiederverwendbar.

Bekannt gesperrte Items werden bereits aus der Such-Kandidatenliste entfernt, bevor Paulchen ihre Itemdaten lädt, fehlende Daten anfordert oder Punkte vergleicht. Das gilt auch für gemerkte Varianten, Katalogeinträge und zusätzliche Codex-Kandidaten. Die Statuszeile zeigt die Zahl **gesperrt übersprungen**; diese Items zählen nicht als fehlende Daten. Vorher werden konkrete Taschen-/AH-Nachweise und offene alternative Dropquellen anhand lokaler Fundortdaten berücksichtigt. Änderungen unter „Spielinhalte“ gelten beim nächsten Suchlauf.

Auswahlknöpfe und Sortierspalten im Upgradefenster verwenden Blizzard-Pfeilgrafiken statt Unicode-Pfeilzeichen, damit die Forever-Schriften keine Kästchen anzeigen.

### Content availability data

`Modules/Upgrades/Content.lua` contains factual item IDs, quest IDs and release memberships derived from the installed AtlasLootClassic dungeon/faction tables and Polestar Forever item/quest records (2026-11-20), plus explicit release rules. It does not embed their Lua implementation, textures, item descriptions or complete loot/stat databases. The local generator and test scripts remain outside the install package. Runtime source metadata supplements these memberships. Neither addon is required to filter the packaged known IDs. No new license for Paulchen QoL is assigned by this change.

The membership list is not an authoritative Forever server-release API. New/custom items, moved acquisition sources or future data-provider changes may need additional rules. Character reputation, completed prerequisites and equipment eligibility are still checked separately where source data is available; enabling a raid does not grant reputation or complete its quests.

Im Auktionshaus blendet **Filter → Nur Upgrades** Treffer aus, die auf deiner aktuellen Charakterstufe keine Verbesserung gegenüber der angelegten Ausrüstung sind. Der Vergleich nutzt dein aktives Paulchen-Profil. Das Häkchen wirkt auf die geladenen Suchtreffer und lässt sich jederzeit umschalten. Wenn der Server noch weitere Treffer hat, kannst du sie über **Weitere Angebote laden** abrufen. Beim Zurücksetzen der AH-Filter geht das Häkchen aus.

**Upgrade %** zeigt die prozentuale Änderung der Ausrüstungspunkte. **Gold pro %** teilt den Preis aus der AH-Übersicht durch die gewonnenen Prozentpunkte. Angebote ohne berechenbares Plus zeigen dort einen Strich. Ein Klick auf **Upgrade %** sortiert die größten Verbesserungen zuerst, ein Klick auf **Gold pro %** die günstigsten Steigerungen zuerst. Ein weiterer Klick kehrt die Richtung um. Die Sortierung umfasst die bereits geladenen Suchtreffer.

**Exportieren** kopiert die gefilterte und sortierte Ergebnisliste als tabulatorgetrennten Text (TSV) in ein markiertes Textfeld. Der Export umfasst alle Treffer und aktivierten Zusatzspalten. Mit **Strg+C** kopierst du den Text und fügst ihn in Excel oder Google Sheets ab Zelle A1 ein. Preise aus dem Auktionshaus stehen in Kupfer, Dezimalzahlen verwenden ein Komma.

Die Tooltip-Zeile lässt sich im Statprofil-Fenster abschalten. Die Upgrade-Tabelle zeigt separate Spalten für Wertungspunkte und Prozentwerte. Setboni und zufällige Auslöseeffekte fließen derzeit nicht in die Punkte ein.

Während du den Tooltip eines Upgrade-Treffers liest, bleibt die angezeigte Liste stabil. Die Suche läuft im Hintergrund weiter; sobald du die Zeile mit der Maus verlässt, werden neue Treffer einsortiert. Bewusstes Filtern, Sortieren und Scrollen wirkt weiterhin sofort und zeigt den Tooltip des tatsächlich angezeigten Gegenstands.

Die Suche begrenzt ihre Arbeit pro Schritt und fragt fehlende Daten in kleinen Gruppen ab. Beim Warten ohne neue Treffer wird nur der Suchstatus aktualisiert. Nachgeladene Daten verwerfen nur die betroffenen Vergleichswerte; Ausrüstungsänderungen aktualisieren weiterhin den vollständigen Vergleich. Fehlgeschlagene oder abgelaufene Datenanfragen werden für fünf Minuten pro Charakter, Client-Build und Realm vorgemerkt. Bereits verfügbare Daten werden trotzdem verwendet; eine erfolgreiche Nachlademeldung hebt die Vormerkung auf.

Die abschließende Nachladephase wartet höchstens 20 Sekunden auf weitere unbekannte Daten. Bereits gelieferte Daten werden weiterhin bewertet. Bleiben Lücken, erscheint ausdrücklich ein **Teilergebnis** mit der Zahl der Items ohne vollständige Daten. Mit **Aktualisieren** kann die Suche weitere Daten laden; die kurzzeitig vorgemerkten Ausfälle werden dabei übersprungen. Eine unvollständige Suche ist kein Nachweis, dass es keine weiteren Upgrades gibt.

## Übersicht

Der erste Reiter zeigt den Reise-Check mit freien Taschenplätzen, niedrigster Haltbarkeit und Ruhestein samt Heimatort und Abklingzeit. Die Bereiche darunter werden bei geöffneter Übersicht jede Sekunde aktualisiert:

- **Das steht gerade an**: fehlendes Mal der Wildnis, nutzbarer Immergrünbeutel, Reparaturbedarf und fast volle Taschen. Die Hinweise öffnen das Zauberbuch oder die passende Suche in Paulchens Taschen. Spielaktionen bleiben beim Spieler.
- **Deine Sitzung**: Spielzeit, Tode, EP, EP pro Stunde und Goldbilanz. Gold ist die Nettoänderung des Geldbestands einschließlich Ausgaben. Zeit, Goldbilanz und Tode bleiben über `/reload` erhalten; ein echter Login beginnt eine neue Sitzung. Die EP-Werte stammen direkt aus dem Logbuch.
- **Bis zum nächsten Level**: Fortschrittsbalken, fehlende EP, geschätzte Restzeit und benötigte Gegner nach den erfassten Gegner-EP. Die EP-Rate wird nach einer Minute berechnet. Maximalstufe, EP-Stopp und unvollständig erfasste Stufenwechsel werden berücksichtigt.
- **Aktuelle Farmrunde**: Gebiet, aktive Laufzeit, EP und Mengen-Zielfortschritt. **Start**, **Pause**, **Fortsetzen** und **Stopp** steuern dieselbe Runde wie das Logbuch. **Ziel / Details** öffnet die Einstellungen der Farmrunde im Logbuch.
- **Standort**: Gebiet, Untergebiet und Koordinaten, sofern der Client sie bereitstellt. **Kopieren** öffnet ein markiertes Textfeld für Strg+C; **Karte** schaltet die Weltkarte um.
- **Bestes bekanntes Upgrade**: stärkster aktuell nutzbarer Treffer nach Upgrade-Prozent (freie Slots zuerst), mit aktivem Statprofil und Suchstatus. **Anzeigen** öffnet den passenden Treffer im Upgradefenster. **Neu prüfen** startet einen weiteren Check.

Der Upgrade-Check startet nach jedem Login und `/reload` automatisch im Hintergrund. Er wartet auf bekannte Ausrüstungsdaten, nutzt die vorhandenen Quellen und den Punktecache und läuft in kleinen Schritten. Im Kampf pausiert er; danach wird die Suche neu gestartet. Ausrüstungs-, Stufen- und Profilwechsel aktualisieren den Vergleich auch bei geschlossenem Fenster. Der Check öffnet kein Fenster und löst keinen Vollscan des Auktionshauses aus. Eine manuell höher eingestellte Suchstufe bleibt im Upgradefenster nutzbar; die Übersicht zeigt nur auf der aktuellen Charakterstufe verwendbare Treffer.

Unten stehen die Vormerkungen für **Behalten** (einschließlich Tank- und DPS-Ausrüstung), **Auktionshaus** und **Händler** als Zusammenfassung. Der Händlerwert umfasst verkaufbare vorgemerkte Gegenstände. **Taschen öffnen** wechselt direkt vom Hauptfenster in die neue Taschenliste. Die Gegenstandsliste bleibt ausschließlich in den Taschen. Die Übersicht passt ihren Maßstab an die verfügbare Bildschirmhöhe an; das kompakte Logbuch behält seine eigene Größe.

## Taschen als Liste

Die normale Taschentaste öffnet **Paulchens Taschen**, eine verschiebbare Liste aller mitgeführten Gegenstände. Gleiche Gegenstandsvarianten erscheinen zusammen in einer Zeile mit Gesamtanzahl und addiertem Händlerwert. Beispielsweise werden 20 und 11 Runenstoff als 31 Runenstoff angezeigt. Unterschiedliche Verzauberungen, Sockel, Zufallsattribute und Bonusvarianten bleiben getrennt. Die Suche findet Namen, Gegenstandsarten und Item-IDs. Klicke auf **Gegenstand**, **Anzahl**, **Händler**, **Marktwert** oder **Differenz**, um auf- oder absteigend zu sortieren. Die Sortierung betrifft nur die Anzeige und bleibt pro Charakter gespeichert.

Taschen und Bank zeigen den Marktwert des gesamten Stapels und die prozentuale Abweichung zum Händlerwert. Positive Abweichungen sind grün, negative rot. Fehlt ein AH-Preis oder ist der Händlerwert null, erscheint die Differenz als grauer Strich. Beim Überfahren des Marktwerts siehst du Stück- und Gesamtpreise, die Quelle und bei Scannerpreisen den Scanzeitpunkt. Der Vergleich zeigt Bruttowerte vor Auktionsgebühren. Der tatsächliche Verkaufserlös kann abweichen.

Unter **Taschen / Preise** in den Einstellungen oder über **Preise** in Taschen und Bank wählst du die Quelle. **Automatisch** und **TradeSkillMaster bevorzugen** verwenden zuerst TSMs DBMarket, wenn die optionale Erweiterung geladen ist und einen gültigen Wert meldet. Andernfalls zeigt Paulchen passende gespeicherte Sofortkaufangebote aus seinem Scanner. Dieser erfasst Ausrüstung. **Nur Paulchens Scanner** schaltet TSM als Preisquelle ab. Das Fenster zeigt den Quellenstatus und bietet **Preise neu abfragen**. Preise werden pro Variante bis zu 60 Sekunden zwischengespeichert. [TSM-Dokumentation zu DBMarket](https://support.tradeskillmaster.com/en_US/custom-strings/which-price-sources-can-i-use-and-what-do-they-mean)

**Questitems ausblenden** ist anfangs angehakt. Entferne den Haken, um Questgegenstände wieder in der Liste zu sehen. Die Auswahl bleibt pro Charakter gespeichert und gilt auch bei der Suche. Die Anzeige freier Taschenplätze berücksichtigt weiterhin alle belegten Plätze.

Die Liste ordnet Gegenstände in **Ausrüstung**, **Verbrauchbares**, **Handwerksmaterial**, **Rezepte**, **Taschen**, **Schlüssel**, **Questgegenstände**, **Plunder** und **Sonstiges**. Nur Kategorien mit Treffern erscheinen. Klicke auf eine Überschrift, um sie ein- oder auszuklappen; die Zahl daneben zählt die zusammengefassten Gegenstandszeilen. Der Zustand wird pro Charakter gespeichert. Die gewählte Spaltensortierung gilt innerhalb jeder Kategorie. Eine Suche zeigt passende Kategorien zunächst aufgeklappt; dortige Änderungen gelten nur für die laufende Suche. Beim Leeren der Suche kehrt der gespeicherte Zustand zurück.

Am Gegenstandssymbol funktionieren die normalen Taschenaktionen: Rechtsklick zum Benutzen, Ausrüsten oder Verkaufen beim Händler, Ziehen zum Verschieben sowie die üblichen Umschalt-Klicks. Aktionen betreffen jeweils einen echten Stapel. Bei mehreren Stapeln nennt der Tooltip sowohl die Gesamtmenge als auch Menge und Platz des Stapels für die nächste Aktion. Nach einer Änderung wird die Gruppe aktualisiert. Oben rechts neben der Suche steht dein aktuelles Geld mit Gold-, Silber- und Kupfermünzsymbolen; Änderungen werden automatisch übernommen. Leere Plätze erscheinen nicht in der Liste. Der Händlerwert gilt für die gesamte angezeigte Gruppe; noch nicht geladene Preise zeigen **…**. Die bisherige Markierung des günstigsten entfernbaren Stapels unterstützt auch zusammengefasste Zeilen.

Mit **Standardtaschen** schaltest du auf deine bisherige Taschenansicht zurück. `/ptaschen` aktiviert die Liste wieder. Bank, Schlüsselbund und Gildenbank behalten ihre eigene Ansicht. Es werden keine Gegenstände automatisch verkauft, gelöscht oder umsortiert.

Ein **Rechtsklick auf den Text einer Gegenstandszeile** öffnet die Vormerkungen. Standardmäßig gibt es **Behalten**, **DPS-Ausrüstung**, **Tank-Ausrüstung**, **AH** und **Händler** sowie **Ohne Markierung**. Bestehende Vormerkungen bleiben erhalten. Die Markierung steht neben dem Gegenstandsnamen und lässt sich über ihren Namen suchen. Am Item-Symbol bleiben die üblichen Gegenstandsaktionen aktiv. Die Übersicht und die Markierung des günstigsten entfernbaren Stapels werden nach einer Änderung aktualisiert.

Über **Kategorien** legst du eigene Vormerkungen an und bearbeitest die Namen und Farben vorhandener Kategorien. Wähle eine Farbe im Farbwähler oder gib einen Hex-Code wie `#4DA6FF` ein. Die Kategorien werden pro Charakter gespeichert. Beim Umbenennen oder Umfärben bleiben zugewiesene Gegenstände in ihrer Kategorie. Eigene Kategorien kannst du dort auch löschen. Ihre Gegenstände werden wieder automatisch einsortiert.

Ziehe eine eigene Kategorie im Kategorienfenster am Griff rechts neben ihrem Namen vor oder hinter eine andere eigene Kategorie. Beim Ziehen kannst du mit dem Mausrad zwischen den Seiten blättern. Die Reihenfolge gilt für die Taschenliste und das Rechtsklickmenü und wird pro Charakter gespeichert.

Beim Bankier stehen **Paulchens Bank** links und **Paulchens Taschen** rechts. Du kannst beide Listen an einer Titelleiste zusammen verschieben. Die Anordnung passt sich der Bildschirmgröße an. Die Bank übernimmt deine Kategorien, Farben und Reihenfolge. Suche, Spaltensortierung und eingeklappte Kategorien werden getrennt geführt. **Standardbank** gibt die normale Bankoberfläche frei, etwa zum Verwalten der Fächer.

Mit geöffneter Bank nimmst du in der Taschenliste **Einlagern** neben einem Kategorienamen. Das verschiebt alle Stapel dieser Kategorie, auch wenn ein Suchfilter nur einen Teil davon anzeigt. Paulchen füllt passende Bankstapel auf und nutzt anschließend freie Plätze. Das Ergebnis steht unten im Fenster.

In **Paulchens Bank** holst du über **Auslagern** alle Stapel einer Kategorie aus deinen persönlichen Bankfächern zurück. Paulchen füllt passende Taschenstapel auf und nutzt freie Plätze, die den Gegenstand aufnehmen können. Passt nur ein Teil in deine Taschen, bleibt der Rest in der Bank.

Wenn beide Listen offen sind, kannst du eine ganze Kategorie am Griff neben **Einlagern** oder **Auslagern** in das jeweils andere Fenster ziehen. Das Zielfenster leuchtet beim Darüberziehen auf. Beim Loslassen startet dieselbe Übertragung wie beim Klick auf den Button.

Markierte Gegenstände erscheinen oben in einer eigenen aufklappbaren Kategorie mit dem Namen ihrer Vormerkung. Kategorienkopf, Farbstreifen und farbiger Namenszusatz verwenden die Markierungsfarbe. Der Zeilenhintergrund ist dezent getönt. Die Seltenheitsfarbe des eigentlichen Itemnamens und der Quest-Rahmen bleiben erhalten. Gleiche Stapel bleiben zusammengefasst und werden innerhalb ihrer Gruppe nach der gewählten Spalte sortiert. Beim Markieren wird die Zielkategorie aufgeklappt und der Gegenstand in den sichtbaren Bereich geholt. **Ohne Markierung** stellt die normale Gegenstandskategorie und Zeilenfarbe wieder her. Der Filter „Questitems ausblenden“ gilt auch für markierte Gegenstände.

## Installation

1. Beende WoW. Entpacke die ZIP in `World of Warcraft/_forever_/Interface/AddOns`.
2. Prüfe, dass die Datei `PaulchenQoL/PaulchenQoL.toc` direkt im entpackten Addon-Ordner liegt.
3. Starte WoW und aktiviere **Paulchen QoL** in der Addon-Liste. Paulchen erscheint standardmäßig unten rechts und lässt sich mit der linken Maustaste ziehen.
4. Ein Linksklick auf Paulchen oder den Minimap-Knopf öffnet das Hauptfenster mit den Reitern **Übersicht**, **Logbuch** und **Upgrades**. Ein Rechtsklick auf den Minimap-Knopf bietet direkten Zugriff auf die Module. Die Einstellungen erreichst du per Rechtsklick auf den Begleiter oder mit `/paulchen`.

Der Logbuch-Reiter verwendet die ursprüngliche Größe des Logbuchs mit einer schmalen Reiterleiste darüber. **Kompakt** öffnet die verschiebbare Mini-Leiste. Sie kann gleichzeitig mit dem Hauptfenster sichtbar sein und bleibt offen, wenn du dort den Reiter wechselst oder das Hauptfenster schließt. Das **+** der Mini-Leiste öffnet den Logbuch-Reiter.

Die Weltkarte zeigt gelbe Fragezeichen für abgabebereite Quests mit bekannten Abgabepunkten. Dicht beieinanderliegende Abgaben teilen sich ein Fragezeichen mit Anzahl. Beim Darüberfahren siehst du die Questnamen. Die Karte aktualisiert sich bei Änderungen im Questlog sowie beim Wechsel zwischen Gebiets-, Kontinent- und Weltkarte. Paulchen verwendet Blizzard-Koordinaten und bei Bedarf die Abgabeorte aus dem installierten Polestar-Kodex.

### Wechsel von den bisherigen Einzel-Addons

Die Vorlagen in `PaulchenQoL/Migration` stellen jeweils die gespeicherten Daten der früheren Einzel-Addons bereit. Schließe WoW und kopiere aus jeder Vorlage die beiden Dateien in den gleichnamigen bestehenden Ordner unter `Interface/AddOns`. Die drei in der Addon-Liste als Datenübernahme gekennzeichneten Einträge müssen beim ersten Login des jeweiligen Charakters aktiv sein. Beim Einloggen übernimmt Paulchen die alten Daten. Nach dem Ausloggen speichert WoW sie unter Paulchen QoL. Sobald das für alle relevanten Charaktere erfolgt ist, können die drei Einträge deaktiviert werden.

Für die Live-Crits unter Windows liegt das Hilfsprogramm in `PaulchenQoL/Modules/DTL/CritLive.py`. Ein bestehender Autostart muss auf diesen Pfad zeigen. Die bisherige `CritLive.sqlite3` enthält die Rekorde und die Lesepositionen des Kampfprotokolls. Sie kann bei beendetem Hilfsprogramm mit umziehen. Das Hilfsprogramm benötigt Python 3. Das WoW-Addon aktiviert das Kampfprotokoll beim Einloggen.

Die Begleitoptionen und der Auktionscache sind accountweit. Merkliste, Flugzeiten, Logbuchdaten und Upgrade-Einstellungen werden pro Charakter gespeichert.

## Befehle

| Befehl | Aktion |
|---|---|
| `/paulchen` oder `/pq` | Einstellungen öffnen |
| `/pq show` | Begleiter einblenden |
| `/pq hide` | Begleiter ausblenden |
| `/pq reset` | Position unten rechts wiederherstellen |
| `/pq comfort` oder `/pq komfort` | Komfort-Einstellungen öffnen |
| `/pq map` oder `/pq karte` | Weltkarte öffnen oder schließen |
| `/pq test` | Einen zufälligen Testkommentar ausgeben |
| `/pq debug` | Debugmeldungen ein- oder ausschalten |
| `/pqol` | Paulchen-Hauptfenster öffnen oder schließen |
| `/pq buffs` | Buffwächter-Reiter öffnen |
| `/pq buffs check` | Buffcheck erneuern, Ergebnis lokal ausgeben und Reiter öffnen |
| `/pq buffs say` | Frischen Bericht bewusst im Gruppenchat ausgeben; bei Einschränkungen Kopierfeld öffnen |
| `/pq buffs debug` | Lokale Buffdiagnose umschalten und Zustände ausgeben |
| `/logbuch` oder `/dtl` | Logbuch-Reiter öffnen oder das Hauptfenster schließen |
| `/logbuch mini` | Kompaktansicht ein- oder ausblenden |
| `/logbuch crits`, `/logbuch xp`, `/logbuch farm` | Crit-Rekorde, EP oder Farmrunden öffnen |
| `/pu` oder `/paulchenupgrades` | Upgrade-Reiter öffnen oder das Hauptfenster schließen |
| `/pah` | Bei geöffnetem Auktionshaus einen Vollscan starten |

Die Unterbefehle von `/pq` funktionieren auch mit `/paulchen`. Falls Paulchen gerade ausgeblendet ist, landet der Testkommentar im eigenen Chatfenster.

## Einstellungen

- **Eigener Level-up-Sound** spielt beim Stufenaufstieg die mitgelieferte Datei `Sounds/level-up.mp3` ab und schaltet den Blizzard-Levelaufstiegsklang während der Sitzung stumm. In den Einstellungen lässt sich die Datei testen und auf den WoW-Klang zurückschalten. Die Lautstärke folgt den Soundeffekten. Die Audiodatei stammt vom Benutzer.
- **Paulchen anzeigen**, **Textblasen** und **Kommentare** lassen sich separat schalten. Mit ausgeschalteten Kommentaren bleiben Flugzeit und Händlerwert bei eingeschalteten Textblasen verfügbar.
- **Größe** reicht von 64 bis 256 Pixel und startet bei 128. **Deckkraft** reicht von 20 bis 100 Prozent. Die Blase passt sich dem Text an und wechselt je nach Position die Seite.
- **Spontanes Geplapper** startet eingeschaltet. Die **Häufigkeit** legt zufällige Abstände von 5–8 Minuten, 3–6 Minuten oder rund 1½–3½ Minuten fest. Ereignisse und praktische Hinweise können zusätzlich zu Wort kommen. Wichtige Hinweise verschieben Geplapper, wenn sie gerade angezeigt wurden.
- **Situationskommentare** schaltet Reaktionen auf bestätigte Spielereignisse ein oder aus. Paulchen wählt aus einem gemeinsamen Pool in seinem Ton und bezieht die letzten 40 Zeilen in die Auswahl ein. Die Illustrationen reagieren auch bei ausgeblendeten Textblasen.
- **Reparaturhinweise** sind anfangs aktiv. Unter 40 % Haltbarkeit eines ausgerüsteten Teils erinnert Paulchen ans Reparieren. Unter 20 % kann er früher erneut warnen. Für Reparaturhinweise gilt ansonsten eine Pause von 25 Minuten. Beim Händler prüft Paulchen dessen Reparaturfunktion.
- **Pausenerinnerungen** sind anfangs aus. Nach dem Einschalten können Hinweise um Stunde 1, 2, 3 und 4 sowie danach alle zwei Stunden erscheinen, jeweils einmal pro Spielsitzung. Überholte Hinweise fallen weg.
- **Im Kampf ausblenden** ist anfangs aktiv. Kommentare pausieren bei Kämpfen, laufenden Bossbegegnungen, Ladebildschirmen und geschützten Zuständen. Nach dem Kampf kann höchstens ein wichtiger, noch aktueller Ereigniskommentar nachkommen. Eine AFK-Phase erhält höchstens eine Ansprache und keinen Rückstau.
- **Erinnerungen speichern** erfasst Tode, Stufen, Gebietsbesuche, zuletzt gesprochene Zeilen und erkannte Questabgaben pro Charakter. Das Abschalten pausiert persönliche Aufzeichnungen. Spielzeit, bereits ausgegebene Pausenhinweise und der Reparaturabstand bleiben als Sitzungsdaten für ein `/reload` erhalten.
- **Debugmodus** zeigt verarbeitete Dialogkategorien und erkannte Modulfehler im eigenen Chatfenster.
- **Separate Modul-Minimapknöpfe** blendet bei verfügbaren Minimap-Bibliotheken die zusätzlichen Knöpfe für Logbuch und Upgrades ein. Deren gespeicherte Positionen und Sichtbarkeit werden übernommen.
- **Reithandschuhe automatisch wechseln** legt beim Aufmounten die Handschuhe der Vorhut aus den Taschen an und stellt beim Abmounten die zuvor getragenen Handschuhe wieder her. Der Wechsel erfolgt außerhalb des Kampfes und deine vorherigen Handschuhe werden pro Charakter gespeichert. Wechselst du sie während des Reitens von Hand, übernimmt Paulchen erst beim nächsten Aufmounten wieder.

Der automatische Wechsel der Reithandschuhe und das Zurückwechseln unterbrechen die Upgrade-Suche nicht. Für Itempunkte, Tooltip-Vergleich und die Upgrade-Suche gelten währenddessen die gemerkten normalen Handschuhe. Das gilt auch für den Login oder Reload im Sattel. Manuelle Ausrüstungswechsel fließen beim nächsten Suchlauf in die Liste ein.

### Komfort

Unter **Einstellungen → Komfort** findest du kategorisierte Optionen mit Suche. Grauverkauf und Quest-Automatik sind pro Charakter einschaltbar und laufen direkt über die Forever-Schnittstellen.

Unter **Weltkarte & Erkundung** findest du den kompakten Kartenrahmen, Maus- und Spielerkoordinaten, das Gebietsmenü und die weiterhin standardmäßig aktiven Questabgaben. Flugpunkte, Portale und Übergänge verwenden die Forever-Kartendaten und bekannte Wegpunkte. Paulchen kann beim Laufen weitere Übergänge speichern. Boote, Zeppeline, Bahnen, Orte der anderen Fraktion, Instanzeingänge, Geistheiler, ungefähre Gebiets- und Angelstufen sowie erkundete und unerforschte Teilgebiete lassen sich separat einblenden.

Über **Kartenoptionen** auf der Weltkarte kannst du Fenster- und Vollbildgröße getrennt setzen und die Schlachtfeldkarte anpassen. Wenn **Karte verschieben** aktiv ist, ziehst du die Paulchen-Leiste und speicherst beide Positionen getrennt. Unter **Tastenbelegung → Paulchen QoL** kannst du eine Taste für die Karte am eigenen Standort vergeben. Kartenrahmen, Navigation und Zusatzmarker laufen ohne Leatrix. Die Erkundungsansicht verwendet die Originaltexturen des installierten Forever-Clients anhand der [WorldMapOverlay-Daten für Build 1.60.1.70959](https://wago.tools/db2/WorldMapOverlay?build=1.60.1.70959).

Ein Linksklick auf einen **Instanzeingang** öffnet die Innenkarte mit Route und Bossmarkern im Reiter **Instanzen** von Paulchen QoL. Per Rechtsklick kommst du zu Instanzquests und Bossbeute. Eng benachbarte Eingänge bieten eine Auswahl der Flügel. Die Bossreihenfolge zeigt die Anzahl der aktuell tragbaren Upgrades je Boss. Ein Klick auf den Namen oder Kartenmarker öffnet seine Beute, absteigend nach Upgrade-Prozent für dein aktives Statprofil sortiert. Im Reiter kannst du außerdem zwischen Ebenen wechseln und bekannte Questorte öffnen. `/pq instanzen` öffnet denselben Reiter.

Der Instanzführer und seine Fundorte für Upgrades funktionieren bei deaktiviertem DungeonJournal, Forever DungeonRoutes und AtlasLoot. Die Karte verwendet nach Möglichkeit die Texturen des WoW-Clients. Bei fehlender Kartenart zeigt Paulchen die Route schematisch. Weitere Angaben zur Herkunft der Daten stehen in [INSTANCE_DATA.md](INSTANCE_DATA.md).

In bekannten Instanzen startet die normale Kartentaste mit der Innenkarte samt Route und Bossmarkern. Der Spielerpfeil folgt Position und Blickrichtung, sofern Forever diese Werte freigibt. Bei bekannter Position ohne Blickrichtung erscheint ein Punkt. Fehlen die Koordinaten, umrandet Paulchen den vom Client gemeldeten Raum, sofern er in den Kartendaten vorkommt. **Weltkarte** wechselt zur Außenansicht, **Instanzkarte** wieder zurück. Über **Flügel** und die Pfeile kannst du den Abschnitt und die Ebene manuell wählen. In **Komfort → Weltkarte & Erkundung** kannst du das automatische Öffnen der Innenkarte umschalten.

**Live-Minimap** zeigt in der mit **M** geöffneten Innenkarte die WoW-Minimap mit Norden oben. Bei lesbaren Spielerkoordinaten liegen nahe Routenabschnitte und Bosse direkt darüber. Fehlen die Koordinaten, öffnet **Position setzen** die Etagenkarte. Bleib stehen und klick auf deinen Standort, um die Route am Spielermarker auszurichten. Beim Weiterlaufen bleiben Route und Bossmarker an der letzten Ausrichtung sichtbar und werden als veraltet markiert. **Ganze Etage** zeigt Route und Bosse auf der Etagenkarte in Minimap-Optik. Beim Wechsel oder Schließen kehrt die Minimap mit ihrem vorherigen Zoom und ihrer vorherigen Ausrichtung ins HUD zurück.

Reisemarker und Instanzeingänge liegen über dem Kartennebel. Fehlen Flugpunkte in den Live-Daten, ergänzt Paulchen bekannte Standorte aus den [Flugpunktdaten des Forever-Clients](https://wago.tools/db2/TaxiNodes?build=1.60.1.70959). Instanzeingänge sind auch auf der Azeroth-Übersicht verfügbar. Für Flugpunkte lässt sich das unter **Flugpunkte auch auf der Azeroth-Übersicht** einschalten. Falls Titan Panel Koordinaten auf derselben Karte anzeigt, blendet Paulchen die entsprechenden Titan-Labels aus, solange seine eigene Anzeige aktiv ist.

Kleine runde Marker bündeln nahe Reisepunkte und Instanzeingänge auf Übersichtskarten. Ein Rechtsklick auf einen Reise-Sammelmarker öffnet seine Ziele. Auf Gebietskarten werden Reisepunkte einzeln angezeigt. Eng benachbarte Eingänge bleiben über die Flügelauswahl erreichbar.

Paulchen verwendet für Eingänge, Flugpunkte, Portale, Geistheiler und Übergänge dieselben WoW-Symbole wie Leatrix Maps. Für Boote, Zeppeline und Bahnen verwendet Paulchen vorhandene Client-Symbole.

- **Händler & Taschen** verkauft bei eingeschalteter Automatik nur graue, lesbar bewertete Gegenstände aus den mitgeführten Taschen. Behalten, DPS, Tank, AH und eigene Kategorien schützen den vorgemerkten Gegenstand. Für unmarkierte graue Gegenstände und die Vormerkung **Händler** gelten die normalen Verkaufsregeln. Die optionale Chat-Zusammenfassung zählt bestätigte Verkäufe.
- **Quests & Dialoge** bietet getrennte Schalter für normale, tägliche und wöchentliche Quests, Abgaben und einzelne NPC-Dialoge per Alt. Quests mit mehr als einer Belohnung zur Wahl, Kosten sowie normalen oder vorgemerkten Abgabeitems bleiben zur manuellen Prüfung offen.
- Mit **Umschalt** beim Ansprechen kannst du die Automatik überspringen.

## Ereignisse

Paulchen kommentiert Reisen, Rastorte und längere Ruhephasen sowie die bisherigen Ereignisse vom Einloggen bis zur Questabgabe. Bei erneut besuchten Gebieten greift er auf tatsächlich gespeicherte Tode zurück. Neue Reaktionen gibt es außerdem für abgeschlossene Kategorien-Transfers, bestätigte Boss-Siege, vom Client gemeldete Dungeonabschlüsse und ausgewertete Bereitschaftschecks.

Bei nachweislich eigener Beute kann Paulchen seltene Gegenstände kommentieren. Einen Hinweis auf besonders wertvolle Beute gibt es bei handelbaren Gegenständen, wenn TSM oder Paulchens Scanner für die erhaltene Menge einen Preis von mindestens 20 Gold liefern. Der Hinweis basiert auf einem Referenzpreis.

Sprüche, Testkommentare und vorübergehende Statusmeldungen beim kleinen Paulchen bleiben 15 Sekunden sichtbar. Flugzeit und Händlerwert werden während der Anzeige aktualisiert. Der Reise-Check zeigt diese Informationen weiterhin, solange sie relevant sind.

Die Erinnerung an den Immergrünbeutel bleibt bis zur Benutzung sichtbar, solange der Beutel und die Zutaten in deinen Taschen sind. Paulchen meldet außerdem, wenn auf deinem Druiden das erlernte Mal der Wildnis fehlt. Die Gruppenversion Gabe der Wildnis zählt ebenfalls. Offene Erinnerungen können zusammen in einer Sprechblase stehen und erscheinen auch im Reise-Check.

Bei einem `/reload` bleiben Sitzungszeit und bereits ausgelöste Tipps erhalten. Zonenwechsel setzen die Uhr ebenfalls weiter fort. Beim nächsten echten Login beginnt eine neue Sitzung.

## Bekannte Grenzen

- Queststatistiken basieren auf dem Client-Ereignis `QUEST_TURNED_IN`. Wiederbelebungen werden aus dem Wechsel vom Tod bzw. Geistzustand zum lebenden Charakter erkannt. Fehlende bzw. geschützte Zustandsinformationen können einzelne Reaktionen verhindern.
- Paulchen speichert besuchte Gebiete seit der Installation bzw. seit dem Einschalten der Erinnerungen. Die Liste umfasst erkannte Gebietswechsel dieses Charakters.
- Polestar kann zusätzliche Ausrüstungs-Fundorte, Quest-Routen und Flugschätzungen liefern. Das Logbuch verwendet bei Bedarf Blizzards Schadensanzeige. Bagnon wird für die Taschenmarkierung neben der Blizzard-Ansicht unterstützt.
- Die fünf Illustrationen werden je nach Stimmung bzw. Kommentar gewechselt. Alle Spielaktionen bleiben beim Spieler.

## Tests

Geprüft wurden die Lua-5.1-Syntax, die Datenübernahme und Modulzugänge mit simulierten WoW-Events, die bisherigen QoL-, DTL-, Upgrade- und Auktionsabläufe und der laufende Crit-Import aus einem Testprotokoll. Die Integration im Forever-Client lässt sich nach einem vollständigen Neustart prüfen.

`python tests/test_companion_life.py` spielt alle 180 bisherigen Standardsprüche durch und simuliert unter anderem zwölf Stunden Reisezeit, Kampf, AFK, Reparaturen, Pausenhinweise und frische Lua-Sitzungen nach einem Reload.

Für die Ingame-Prüfung in Forever stehen diese Abläufe aus.

1. Bei **Normal** mehrere Minuten reiten, questen und an einem Rastort bleiben. Im Kampf und beim Laden still bleiben, nach der Rückkehr nur aktuelle Reaktionen anzeigen und den Grafikwechsel nach 15 Sekunden prüfen.
2. Mit beschädigter Ausrüstung einen Händler mit Reparaturfunktion besuchen und tatsächlich reparieren. Die Schwellen unter 40 und 20 Prozent separat prüfen.
3. **Pausenerinnerungen** einschalten, eine Stundenschwelle erreichen und anschließend `/reload` ausführen. Der bereits angezeigte Hinweis darf sich innerhalb derselben Sitzung nicht wiederholen.
4. Eigene seltene Beute mit und ohne verfügbaren AH-Preis prüfen. Im Gruppenspiel einen Bereitschaftscheck, bestätigten Bosssieg und einen Dungeonabschluss beobachten.

`python tests/test_auction_prices.py` prüft die Preisquellen, Cache-Ablauf, spätes Laden der TSM-API, ungültige Preise, Gegenstandsvarianten und simulierte Neuladungen mit Lua 5.1 (Lupa). Für den Clienttest mit TSM einen bekannten DBMarket-Artikel und in **Nur Paulchens Scanner** ein passendes gescanntes Ausrüstungsteil in Taschen und Bank vergleichen. Händler- und Marktwert müssen jeweils zur Stückzahl passen. Beim Bankier beide Listen öffnen, nach **Marktwert** und **Differenz** sortieren und einen Kategorien-Transfer prüfen. Anschließend bei deaktiviertem TSM neu laden und den Ersatzpreis sowie die gespeicherte Einstellung prüfen.

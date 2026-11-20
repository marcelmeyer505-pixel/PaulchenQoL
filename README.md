# Paulchen QoL v0.7.7

Paulchen ist ein Hordevogel mit Headset für **World of Warcraft: Forever** (Interface `16001`). Er kommentiert Ereignisse mit einer von fünf Illustrationen. Die Übersicht mit Reise-Check, die sortierbare Taschenliste mit Vormerkungen, die Markierung des günstigsten Stapels und der Flugtimer gehören ebenfalls zum Addon.

**Paulchens Logbuch** zeigt die letzten zehn Kämpfe, eigene DPS mit Durchschnitt, Crit-Rekorde, Gegnerprofile sowie EP-Statistiken und Farmrunden. Die Kompaktansicht zeigt zwei wählbare Kennzahlen und die Steuerung für Farmrunden. **Paulchen Upgrades** vergleicht Ausrüstung inklusive manuell geplanter Charakterstufe, Spalten, Filtern und Loot-Alarm. Der Auktionsscan liefert Marktangebote an das Upgrade-Fenster.

**Upgrades → Statprofile** bietet 28 Startprofile für die neun Klassen in Forever. Katze und Bär haben eigene Profile. Wähle die Spezialisierung und passe die Punkte pro Attribut an. Paulchen speichert deine Auswahl und Änderungen pro Charakter. Der Profilname steht oben im Upgrade-Fenster und neben dem Vergleich im Item-Tooltip. Die Vorgaben sind Ausgangswerte für die Ausrüstungssuche.

**Feral Katze** startet mit 1,90 Punkten pro Beweglichkeit, 0,80 pro Stärke, 0,40 pro Angriffskraft und 5,60 pro Nahkampfwaffen-DPS. Dazu kommen 10,20 pro Prozent Krit, 8,77 pro Prozent Trefferchance, 4,78 pro Prozent Angriffstempo, 0,85 pro Waffenkundewertung und 0,13 pro Rüstungsdurchschlag.

Die Upgrade-Suche prüft bei unverändertem Vergleichsstand nur neue oder geänderte Items neu. Vorhandene Wertungen werden übernommen, einschließlich bereits bewerteter Taschenitems und konkreter Zufallsvarianten. Die Statuszeile zeigt **neu bewertet** und **übernommen**. Gleichbleibende Stapelzahlen oder andere Taschenplätze lösen keine neue Suche aus. Neue Ausrüstung in den Taschen bekommt einen gebündelten Nachlauf; eine laufende Suche wird dafür erst beendet.

Sichere Rüstungs- und Schmuckwertungen einschließlich ihrer Varianten werden pro Charakter dauerhaft gespeichert. WoW sichert sie beim Ausloggen oder mit `/reload`. Bei gleicher Ausrüstung, Stufe, Spezialisierung und Gewichtung werden sie auch beim nächsten Login wiederverwendet. Ein passender älterer Punktespeicher wird übernommen. Waffenabhängige Vergleiche bleiben in der Sitzung; neue mögliche Waffen-/Nebenhand-Kombinationen aktualisieren diese Werte gezielt. Normale Waffen-Skillsteigerungen ohne Änderung der Nutzbarkeit verwerfen keine Wertungen.

Echte Ausrüstungs-, Stufen-, Profil- oder Gewichtungsänderungen erneuern den Vergleichsstand. Neue Itemdaten verwerfen nur die Wertungen des betroffenen Items und seiner Varianten. Fundorte, Queststatus, Taschenbesitz und Auktionsangebote werden bei jedem Check frisch aus den verfügbaren Quellen ermittelt. Verkauftes oder entferntes Inventar bleibt dadurch nicht als Taschenfundort stehen. Die Wiederverwendung ändert keine Stat-Gewichtungen und keine Gegenstandsaktionen.

Der Ausrüstungsvergleich nutzt die Itemwerte des WoW-Clients. Die Suche berücksichtigt deine Taschen, aktive Questbelohnungen, die geladene AH-Übersicht und gespeicherte Auktionsscans. Polestar, AtlasLoot und Forever Dungeon Journal können zusätzliche Fundorte beitragen. Im Reiter **Instanzen** erscheint derselbe Fundort einmal. Wenn AtlasLoot eine Dropchance für den Boss kennt, wird sie übernommen.

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

Unten stehen die Vormerkungen für **Behalten** (einschließlich Katze und Bär), **Auktionshaus** und **Händler** als Zusammenfassung. Der Händlerwert umfasst verkaufbare vorgemerkte Gegenstände. **Taschen öffnen** wechselt direkt vom Hauptfenster in die neue Taschenliste. Die Gegenstandsliste bleibt ausschließlich in den Taschen. Die Übersicht passt ihren Maßstab an die verfügbare Bildschirmhöhe an; das kompakte Logbuch behält seine eigene Größe.

## Taschen als Liste

Die normale Taschentaste öffnet **Paulchens Taschen**: eine verschiebbare Liste aller mitgeführten Gegenstände. Gleiche Gegenstandsvarianten erscheinen zusammen in einer Zeile mit Gesamtanzahl und addiertem Händlerwert. Beispielsweise werden 20 und 11 Runenstoff als 31 Runenstoff angezeigt. Unterschiedliche Verzauberungen, Sockel, Zufallsattribute und Bonusvarianten bleiben getrennt. Die Suche findet Namen, Gegenstandsarten und Item-IDs. Klicke auf **Gegenstand**, **Anzahl**, **Qualität**, **Händler / Gesamt** oder **Tasche**, um auf- oder absteigend zu sortieren. Die Sortierung betrifft nur die Anzeige und bleibt pro Charakter gespeichert.

**Questitems ausblenden** ist anfangs angehakt. Entferne den Haken, um Questgegenstände wieder in der Liste zu sehen. Die Auswahl bleibt pro Charakter gespeichert und gilt auch bei der Suche. Die Anzeige freier Taschenplätze berücksichtigt weiterhin alle belegten Plätze.

Die Liste ordnet Gegenstände in **Ausrüstung**, **Verbrauchbares**, **Handwerksmaterial**, **Rezepte**, **Taschen**, **Schlüssel**, **Questgegenstände**, **Plunder** und **Sonstiges**. Nur Kategorien mit Treffern erscheinen. Klicke auf eine Überschrift, um sie ein- oder auszuklappen; die Zahl daneben zählt die zusammengefassten Gegenstandszeilen. Der Zustand wird pro Charakter gespeichert. Die gewählte Spaltensortierung gilt innerhalb jeder Kategorie. Eine Suche zeigt passende Kategorien zunächst aufgeklappt; dortige Änderungen gelten nur für die laufende Suche. Beim Leeren der Suche kehrt der gespeicherte Zustand zurück.

Am Gegenstandssymbol funktionieren die normalen Taschenaktionen: Rechtsklick zum Benutzen, Ausrüsten oder Verkaufen beim Händler, Ziehen zum Verschieben sowie die üblichen Umschalt-Klicks. Aktionen betreffen jeweils einen echten Stapel. Bei mehreren Stapeln nennt der Tooltip sowohl die Gesamtmenge als auch Menge und Platz des Stapels für die nächste Aktion. Nach einer Änderung wird die Gruppe aktualisiert. Oben rechts neben der Suche steht dein aktuelles Geld mit Gold-, Silber- und Kupfermünzsymbolen; Änderungen werden automatisch übernommen. Leere Plätze erscheinen nicht in der Liste. Der Händlerwert gilt für die gesamte angezeigte Gruppe; noch nicht geladene Preise zeigen **…**. Die bisherige Markierung des günstigsten entfernbaren Stapels unterstützt auch zusammengefasste Zeilen.

Mit **Standardtaschen** schaltest du auf deine bisherige Taschenansicht zurück. `/ptaschen` aktiviert die Liste wieder. Bank, Schlüsselbund und Gildenbank behalten ihre eigene Ansicht. Es werden keine Gegenstände automatisch verkauft, gelöscht oder umsortiert.

Ein **Rechtsklick auf den Text einer Gegenstandszeile** öffnet die Vormerkungen **Behalten**, **Katze**, **Bär**, **AH** und **Händler** sowie **Ohne Markierung**. Bestehende Vormerkungen bleiben erhalten. Die Markierung steht neben dem Gegenstandsnamen und lässt sich über ihren Namen suchen. Am Item-Symbol bleiben die üblichen Gegenstandsaktionen aktiv. Die Übersicht und die Markierung des günstigsten entfernbaren Stapels werden nach einer Änderung aktualisiert.

Markierte Gegenstände erscheinen oben in einer eigenen aufklappbaren Kategorie mit dem Namen ihrer Vormerkung. Kategorienkopf, Farbstreifen und farbiger Namenszusatz verwenden die Markierungsfarbe; der Zeilenhintergrund ist dezent getönt. **Behalten** ist grün, **Katze/Bär** goldfarben, **AH** hellblau und **Händler** lachsfarben. Die Seltenheitsfarbe des eigentlichen Itemnamens und der Quest-Rahmen bleiben erhalten. Gleiche Stapel bleiben zusammengefasst und werden innerhalb ihrer Gruppe nach der gewählten Spalte sortiert. Beim Markieren wird die Zielkategorie aufgeklappt und der Gegenstand in den sichtbaren Bereich geholt. **Ohne Markierung** stellt die normale Gegenstandskategorie und Zeilenfarbe wieder her. Der Filter „Questitems ausblenden“ gilt auch für markierte Gegenstände.

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
| `/pq test` | Einen zufälligen Testkommentar ausgeben |
| `/pq debug` | Debugmeldungen ein- oder ausschalten |
| `/pqol` | Paulchen-Hauptfenster öffnen oder schließen |
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
- **Häufigkeit** legt für normale Kommentare eine Mindestpause von 90, 60 oder 45 Sekunden fest. Wichtige Ereignisse können früher zu Wort kommen. Pro Ereignis gilt zusätzlich eine eigene Abklingzeit.
- **Sarkasmus** bietet **Lieb**, **Frech** und **Gnadenlos**. Stimmungen steuern die Illustration und können die Wortwahl abmildern.
- **Im Kampf ausblenden** ist anfangs aktiv. Dialoge pausieren im Kampf. Nach dem Kampf verarbeitet Paulchen relevante, noch aktuelle Meldungen aus einer Warteschlange mit höchstens fünf Einträgen.
- **Erinnerungen speichern** erfasst Tode insgesamt und pro Sitzung, erreichte Stufen, Gebietsbesuche, zuletzt gesprochene Zeilen und erkannte Questabgaben pro Charakter. Das Abschalten pausiert die Erfassung. Vorhandene Daten stehen beim Wiedereinschalten wieder zur Verfügung.
- **Debugmodus** zeigt verarbeitete Dialogkategorien und erkannte Modulfehler im eigenen Chatfenster.
- **Separate Modul-Minimapknöpfe** blendet bei verfügbaren Minimap-Bibliotheken die zusätzlichen Knöpfe für Logbuch und Upgrades ein. Deren gespeicherte Positionen und Sichtbarkeit werden übernommen.
- **Questabgaben auf der Weltkarte** schaltet die zusätzlichen Fragezeichen ein oder aus. Die Einstellung ist standardmäßig aktiv.
- **Reithandschuhe automatisch wechseln** legt beim Aufmounten die Handschuhe der Vorhut aus den Taschen an und stellt beim Abmounten die zuvor getragenen Handschuhe wieder her. Der Wechsel erfolgt außerhalb des Kampfes und deine vorherigen Handschuhe werden pro Charakter gespeichert. Wechselst du sie während des Reitens von Hand, übernimmt Paulchen erst beim nächsten Aufmounten wieder.

Der automatische Wechsel der Reithandschuhe und das Zurückwechseln starten keinen neuen Upgrade-Suchlauf und unterbrechen keinen laufenden. Für Itempunkte, Tooltip-Vergleich und die Upgrade-Suche gelten währenddessen weiterhin die gemerkten normalen Handschuhe. Das gilt auch für den regulären Login-/Reload-Check im Sattel. Manuelle Ausrüstungswechsel werden weiterhin neu verglichen.

## Ereignisse

Paulchen reagiert beim Einloggen, bei einem Levelaufstieg, beim Tod, nach der Wiederbelebung, beim Gebietswechsel, bei erkannten Questabgaben, beim AFK-Gehen, bei der Rückkehr und bei knappen Taschenplätzen. Gelegentlich meldet er sich in ruhigen Situationen. Jede Kategorie hat 15 deutsche Sprüche. Einige zusätzliche Zeilen setzen eine tatsächlich gespeicherte Pause oder mehrere Tode voraus.

Sprüche, Testkommentare und vorübergehende Statusmeldungen beim kleinen Paulchen bleiben 15 Sekunden sichtbar. Flugzeit und Händlerwert werden während der Anzeige aktualisiert. Der Reise-Check zeigt diese Informationen weiterhin, solange sie relevant sind.

Die Erinnerung an den Immergrünbeutel bleibt bis zur Benutzung sichtbar, solange der Beutel und die Zutaten in deinen Taschen sind. Paulchen meldet außerdem, wenn auf deinem Druiden das erlernte Mal der Wildnis fehlt. Die Gruppenversion Gabe der Wildnis zählt ebenfalls. Offene Erinnerungen können zusammen in einer Sprechblase stehen und erscheinen auch im Reise-Check.

Bei einem `/reload` bleibt die Sitzung mit ihrem Todeszähler erhalten. Der nächste echte Login beginnt eine neue Sitzung.

## Bekannte Grenzen

- Queststatistiken basieren auf dem Client-Ereignis `QUEST_TURNED_IN`. Wiederbelebungen werden aus dem Wechsel vom Tod bzw. Geistzustand zum lebenden Charakter erkannt. Fehlende bzw. geschützte Zustandsinformationen können einzelne Reaktionen verhindern.
- Paulchen speichert besuchte Gebiete seit der Installation bzw. seit dem Einschalten der Erinnerungen. Die Liste umfasst erkannte Gebietswechsel dieses Charakters.
- Polestar kann zusätzliche Ausrüstungs-Fundorte, Quest-Routen und Flugschätzungen liefern. Das Logbuch verwendet bei Bedarf Blizzards Schadensanzeige. Bagnon wird für die Taschenmarkierung neben der Blizzard-Ansicht unterstützt.
- Die fünf Illustrationen werden je nach Stimmung bzw. Kommentar gewechselt. Alle Spielaktionen bleiben beim Spieler.

## Tests

Geprüft wurden die Lua-5.1-Syntax, die Datenübernahme und Modulzugänge mit simulierten WoW-Events, die bisherigen QoL-, DTL-, Upgrade- und Auktionsabläufe und der laufende Crit-Import aus einem Testprotokoll. Die Integration im Forever-Client lässt sich nach einem vollständigen Neustart prüfen.

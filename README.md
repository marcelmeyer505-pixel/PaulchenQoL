# Paulchen QoL v0.3.7

Paulchen ist ein Hordevogel mit Headset für **World of Warcraft: Forever** (Interface `16001`). Er kommentiert Ereignisse mit einer von fünf Illustrationen. Der Reise-Check, die Taschen-Merkliste, die Markierung des günstigsten Stapels und der Flugtimer gehören ebenfalls zum Addon.

**Paulchens Logbuch** zeigt die letzten zehn Kämpfe, eigene DPS mit Durchschnitt, Crit-Rekorde, Gegnerprofile sowie EP-Statistiken und Farmrunden. Die Kompaktansicht zeigt zwei wählbare Kennzahlen und die Steuerung für Farmrunden. **Paulchen Upgrades** vergleicht Ausrüstung inklusive manuell geplanter Charakterstufe, Spalten, Filtern und Loot-Alarm. Der Auktionsscan liefert Marktangebote an das Upgrade-Fenster.

Das Bewertungsprofil **Feral Katze** verwendet 1,90 Punkte pro Beweglichkeit auf der Ausrüstung, 0,80 pro Stärke, 0,40 pro Angriffskraft und 5,60 pro Waffen-DPS. Die Beweglichkeit berücksichtigt die vom Spieler beobachtete Verdopplung in Katzengestalt. Dazu kommen 10,20 pro Prozent Krit, 8,77 pro Prozent Trefferchance, 4,78 pro Prozent Angriffstempo, 0,85 pro Waffenkundewertung und 0,13 pro Rüstungsdurchschlag. Beim ersten Login mit Version 0.3.7 wird die Beweglichkeitsgewichtung im vorhandenen Profil angepasst. Der feste AP-Bonus der Katzengestalt trägt bei allen Items gleich viel bei.

## Installation

1. Beende WoW. Entpacke die ZIP in `World of Warcraft/_forever_/Interface/AddOns`.
2. Prüfe, dass die Datei `PaulchenQoL/PaulchenQoL.toc` direkt im entpackten Addon-Ordner liegt.
3. Starte WoW und aktiviere **Paulchen QoL** in der Addon-Liste. Paulchen erscheint standardmäßig unten rechts und lässt sich mit der linken Maustaste ziehen.
4. Ein Linksklick auf Paulchen oder den Minimap-Knopf öffnet das Hauptfenster mit den Reitern **Reise & Taschen**, **Logbuch** und **Upgrades**. Ein Rechtsklick auf den Minimap-Knopf bietet direkten Zugriff auf die Kompaktansicht, Farmrunden und den Auktionsscan. Die Einstellungen erreichst du per Rechtsklick auf den Begleiter oder mit `/paulchen`.

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

## Ereignisse

Paulchen reagiert beim Einloggen, bei einem Levelaufstieg, beim Tod, nach der Wiederbelebung, beim Gebietswechsel, bei erkannten Questabgaben, beim AFK-Gehen, bei der Rückkehr und bei knappen Taschenplätzen. Gelegentlich meldet er sich in ruhigen Situationen. Jede Kategorie hat 15 deutsche Sprüche. Einige zusätzliche Zeilen setzen eine tatsächlich gespeicherte Pause oder mehrere Tode voraus.

Sprüche, Testkommentare und vorübergehende Statusmeldungen beim kleinen Paulchen bleiben 15 Sekunden sichtbar. Flugzeit und Händlerwert werden während der Anzeige aktualisiert. Der Reise-Check zeigt diese Informationen weiterhin, solange sie relevant sind.

Die Erinnerung an den Immergrünbeutel bleibt bis zur Benutzung sichtbar, solange der Beutel und die Zutaten in deinen Taschen sind. Paulchen meldet außerdem, wenn auf deinem Druiden das erlernte Mal der Wildnis fehlt. Die Gruppenversion Gabe der Wildnis zählt ebenfalls. Offene Erinnerungen können zusammen in einer Sprechblase stehen und erscheinen auch im Reise-Check.

Bei einem `/reload` bleibt die Sitzung mit ihrem Todeszähler erhalten. Der nächste echte Login beginnt eine neue Sitzung.

## Bekannte Grenzen

- Queststatistiken basieren auf dem Client-Ereignis `QUEST_TURNED_IN`. Wiederbelebungen werden aus dem Wechsel vom Tod bzw. Geistzustand zum lebenden Charakter erkannt. Fehlende bzw. geschützte Zustandsinformationen können einzelne Reaktionen verhindern.
- Paulchen speichert besuchte Gebiete seit der Installation bzw. seit dem Einschalten der Erinnerungen. Die Liste umfasst erkannte Gebietswechsel dieses Charakters.
- Die Ausrüstungsbewertung benötigt **Polestar**. Polestar kann auch zusätzliche Flugschätzungen liefern. Das Logbuch verwendet bei Bedarf Blizzards Schadensanzeige ohne Details. Bagnon wird für die Taschenmarkierung neben der Blizzard-Ansicht unterstützt.
- Die fünf Illustrationen werden je nach Stimmung bzw. Kommentar gewechselt. Alle Spielaktionen bleiben beim Spieler.

## Tests

Geprüft wurden die Lua-5.1-Syntax, die Datenübernahme und Modulzugänge mit simulierten WoW-Events, die bisherigen QoL-, DTL-, Upgrade- und Auktionsabläufe und der laufende Crit-Import aus einem Testprotokoll. Die Integration im Forever-Client lässt sich nach einem vollständigen Neustart prüfen.

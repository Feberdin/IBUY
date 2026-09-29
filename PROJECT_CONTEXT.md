# Projekt-Kontext: IBUY

## Kurzbeschreibung
IBUY ist ein World-of-Warcraft-Addon fuer Vendor-Kaeufe. Es beobachtet das geoeffnete Haendlerfenster, kauft konfigurierte Item-IDs nach Prioritaet, bietet einen Testmodus, persistentes Debug-Logging und kleine UI-Helfer direkt am Vendor-Fenster. Retail- und Classic-Unterstuetzung ist im Projekt vorgesehen; einzelne Vendor-Filterpfade sollten auf beiden Clients praktisch gegengeprueft werden.

## Pfade
- Projektpfad: `/Applications/World of Warcraft/_anniversary_/Interface/AddOns/IBUY`
- Repository: `IBUY`
- Git-Remote: `git@github.com:Feberdin/IBUY.git`
- Branch: `main`

## Technischer Stack
- Lua
- World of Warcraft AddOn API
- TOC-basierte AddOn-Struktur
- Git / GitHub
- CurseForge-Release-Workflow ausserhalb des Codes

## Wichtige Dateien und Verzeichnisse
- [IBUY.toc](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/IBUY.toc): AddOn-Metadaten, Interface-Versionen, geladene Dateien.
- [IBUY.lua](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/IBUY.lua): Hauptlogik fuer Vendor-Scan, Kaufverhalten, UI, Debug-Log und kleine Extras.
- [IBUY_Tests.lua](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/IBUY_Tests.lua): einfache Ingame-Selftests ueber Slash-Command.
- [README.md](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/README.md): kompakter Einstieg und Befehlsuebersicht.
- [SUMMARY.md](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/SUMMARY.md): kurze Projekt-Zusammenfassung.
- [DESCRIPTION.en.md](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/DESCRIPTION.en.md): englische Kurzbeschreibung fuer Plattformen.
- [DESCRIPTION.de.md](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/DESCRIPTION.de.md): deutsche Kurzbeschreibung.
- [sounds/README.txt](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/sounds/README.txt): Hinweise fuer lokales Sound-Easter-Egg.
- `ASSETS/`: Projektlogo-Dateien.
- `release/`: lokale ZIP-Artefakte fuer Release-Uploads; kein Quellcode.

## Lokales Setup
- Voraussetzungen:
  - installierter WoW-Client (Retail oder Classic)
  - Zugriff auf den AddOns-Ordner des Clients
  - Git fuer Repo-Arbeit
- Abhaengigkeiten installieren:
  - kein externer Paketmanager erkannt
  - keine Projekt-Dependencies ausser der WoW-Laufzeitumgebung
- Konfiguration vorbereiten:
  - AddOn-Ordner `IBUY` in `Interface/AddOns` platzieren
  - optional lokales Soundfile `sounds/heftig.ogg` verwenden
  - optional Debug-Log spaeter ueber `SavedVariables` aktivieren
- Starten:
  - WoW starten
  - AddOn aktivieren
  - Vendor oeffnen und `/ibuy start` nach Bedarf verwenden
- Testen:
  - `/reload`
  - `/ibuy selftest`
  - manuelle Vendor-Tests laut [CONTRIBUTING.md](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/CONTRIBUTING.md)
- Build:
  - kein formaler Build-Prozess aus Projektdateien ableitbar
  - Release-ZIP-Erzeugung ist als lokales Artefakt vorhanden, aber nicht als dokumentierter Projektbefehl fest verankert

## Bekannte Befehle
- Installation:
  - AddOn-Ordner `IBUY` in `Interface/AddOns` ablegen
- Entwicklung:
  - `/reload`
  - `/ibuy start`
  - `/ibuy stop`
  - `/ibuy add <itemID>`
  - `/ibuy remove <itemID>`
  - `/ibuy list`
- Tests:
  - `/ibuy selftest`
  - manuelle Vendor-Szenarien
- Build:
  - zu pruefen; kein offizieller Projektbefehl dokumentiert
- Linting:
  - keiner erkannt
- Deployment:
  - CurseForge-/GitHub-Release-Prozess ist extern; keine dedizierten Projektskripte im Repo

## Konfiguration und Secrets
- Vorhandene Konfigurationsdateien:
  - `IBUY.toc`
  - `.gitignore`
- Beispiel-/Hilfsdateien:
  - `sounds/README.txt`
- Lokale Dateien ausserhalb des Repos, die auf dem neuen Mac relevant sein koennen:
  - `WTF/Account/<ACCOUNT>/SavedVariables/IBUY.lua` fuer gespeicherte Einstellungen und Debug-Logs
  - optional `sounds/heftig.ogg`, falls das Easter Egg lokal angepasst werden soll
- `.env`-Dateien oder vergleichbare Secret-Dateien:
  - keine erkannt

## Git-Status
- Branch: `main`
- Remote: `git@github.com:Feberdin/IBUY.git`
- Uncommitted changes: ja
- Letzte Commits:
  - `78e1710` Bump version to 1.0.2
  - `ac6394e` Improve full Retail + TBC compatibility for merchant UI and filtering
  - `a992926` Release 1.0.1: add Retail interface compatibility
  - `1c05cc3` Polish GitHub project metadata, docs, and branding assets
  - `f74f125` Initial IBUY addon with vendor auto-buy, debug log, and UI
- Offene lokale Aenderungen:
  - `README.md`: Dokumentation fuer Retail/Classic-Unterstuetzung aktualisiert
  - `DESCRIPTION.de.md`: lokale Modus-/Dateirechte-Aenderung vorhanden
  - `DESCRIPTION.en.md`: lokale Modus-/Dateirechte-Aenderung vorhanden
  - `LICENSE`: lokale Modus-/Dateirechte-Aenderung vorhanden

## Offene Enden
- Kein CI/CD-Workflow im Repo dokumentiert.
- Kein offizieller Build-/Release-Skript im Projekt dokumentiert.
- Vendor-Filter/Overlay sollte in Retail und Classic praktisch gegengeprueft werden, trotz vorhandener Kompatibilitaetslogik.
- Release-Artefakte liegen lokal in `release/`; Herkunft und Zielprozess sind nicht als Projektkommando dokumentiert.
- `SUMMARY.md` beschreibt aktuell WoW Classic; mit Retail-Support eventuell angleichen.
- `DESCRIPTION.en.md`, `DESCRIPTION.de.md` und `LICENSE` haben lokale, noch uncommittete Modus-Aenderungen.

## Empfohlene naechste Schritte
1. Retail-Client und Classic-Client jeweils einmal manuell gegen Vendor-UI, Auto-Buy und Debug-Log testen.
2. Offiziellen Release-Prozess als `docs/RELEASE.md` oder Script dokumentieren, damit GitHub- und CurseForge-Updates reproduzierbar sind.
3. Offene lokale Aenderungen an `DESCRIPTION.*` und `LICENSE` bewusst pruefen und entweder committen oder rueckgaengig machen.
4. Optional `SUMMARY.md` und Plattformbeschreibungen einheitlich auf Retail + Classic anpassen.

## Hinweise fuer macOS-Umzug
- Benoetigte Tools:
  - WoW-Client (Retail und/oder Classic)
  - Git
- Benoetigte Paketmanager:
  - keiner projektspezifisch erkannt
- Manuell zu uebertragende Dateien:
  - der gesamte Projektordner
  - optional `WTF/Account/<ACCOUNT>/SavedVariables/IBUY.lua` fuer Einstellungen und Debug-Logs
- Lokale Daten:
  - SavedVariables liegen ausserhalb des Repos
  - Release-ZIP-Dateien in `release/` sind lokale Artefakte, nicht Quellcode
- Konfigurationsdateien:
  - keine `.env`-Dateien erkannt
  - lokale Sounddatei `sounds/heftig.ogg` vorhanden und fuer das Easter Egg relevant
- SSH/Git-Zugriff:
  - Git-Remote nutzt SSH (`git@github.com:Feberdin/IBUY.git`), daher muessen SSH-Schluessel auf dem neuen Mac eingerichtet sein
- Moegliche Stolperfallen:
  - WoW-Installationspfade unterscheiden sich zwischen Clients
  - SavedVariables muessen separat uebernommen werden, wenn Einstellungen erhalten bleiben sollen
  - CurseForge-/Release-Zugangsdaten liegen nicht im Projekt und muessen auf dem neuen Mac separat vorhanden sein

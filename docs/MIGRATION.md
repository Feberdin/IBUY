# Migration

## Ziel
Dieses Projekt fuer einen neuen Mac so vorbereiten, dass die AddOn-Entwicklung und die lokale Nutzung in WoW schnell wieder funktionieren.

## Was uebertragen werden sollte
- gesamter Projektordner `IBUY`
- optional `WTF/Account/<ACCOUNT>/SavedVariables/IBUY.lua`
- optional lokales Soundfile `sounds/heftig.ogg`, falls das Easter Egg weiter genutzt werden soll

## Was separat vorbereitet werden muss
- WoW Retail und/oder WoW Classic Installation
- Git-Zugriff ueber SSH fuer `git@github.com:Feberdin/IBUY.git`
- eventuelle CurseForge-Release-Zugangsdaten ausserhalb des Repos

## Bekannte Stolperfallen
- SavedVariables liegen ausserhalb des Repos und gehen ohne separate Uebernahme verloren.
- Unterschiedliche WoW-Installationspfade koennen AddOn-Tests verlangsamen.
- Release-ZIP-Dateien in `release/` sind nur lokale Artefakte.
- Retail-/Classic-Kompatibilitaet ist implementiert, sollte aber nach dem Umzug einmal praktisch geprueft werden.

## Nach dem Umzug pruefen
1. Repo am Zielort vorhanden
2. AddOn in `Interface/AddOns` eingebunden
3. `/reload` funktioniert ohne Lua-Fehler
4. `/ibuy selftest` laeuft
5. Vendor-UI und Auto-Buy in dem genutzten WoW-Client getestet

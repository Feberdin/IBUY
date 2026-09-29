# Setup

## Voraussetzungen
- installierter WoW-Client (Retail oder Classic)
- Zugriff auf den AddOns-Ordner des Clients
- Git fuer Repo-Arbeit

## AddOn lokal einrichten
1. Projektordner `IBUY` nach `Interface/AddOns` kopieren.
2. WoW starten.
3. AddOn `IBUY` im AddOn-Menue aktivieren.

## Erster Funktionstest
1. Im Spiel `/reload` ausfuehren.
2. Einen Vendor oeffnen.
3. Optional ein Zielitem setzen:
   - `/ibuy add 16224`
4. Auto-Buy starten:
   - `/ibuy start`

## Tests
- Ingame-Selftest:
  - `/ibuy selftest`
- Manuelle Vendor-Tests:
  - siehe [CONTRIBUTING.md](/Applications/World%20of%20Warcraft/_anniversary_/Interface/AddOns/IBUY/CONTRIBUTING.md)

## Debug-Log
- Aktivieren:
  - `/ibuy logfile on`
- Gespeicherter Pfad:
  - `WTF/Account/<ACCOUNT>/SavedVariables/IBUY.lua`

## Zu pruefen
- Kein offizieller Build-/Packaging-Befehl aus Projektdateien dokumentiert.
- Retail- und Classic-Client nach Umzug jeweils praktisch gegen Vendor-UI pruefen.

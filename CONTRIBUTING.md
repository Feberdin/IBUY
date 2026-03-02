# Contributing

## Ziel
Beitraege sollen klein, nachvollziehbar und risikoarm sein.

## Lokaler Ablauf (3 Zeilen)
1. Addon im WoW AddOns-Ordner aktualisieren.
2. Spiel neu laden (`/reload`) und Vendor-Szenarien pruefen.
3. `/ibuy selftest` und manuelle Vendor-Tests durchfuehren.

## Style
- Klare Funktionsnamen
- Keine still geschluckten Fehler
- Kommentare erklaeren Absicht und nicht nur Syntax

## Tests
- Happy Path: Zielitem vorhanden, Kauf erfolgt.
- Edge Cases: Item nicht da, kein Gold, ausverkauft.
- Negativtests: ungueltige Item-ID, Testmodus-Limit erreicht.

## PR-Check
- README aktualisiert, falls Nutzerverhalten geaendert wurde.
- Keine Aenderungen an fremden Addon-Ordnern.

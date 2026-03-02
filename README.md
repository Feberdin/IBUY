# IBUY

IBUY ist ein kleines World of Warcraft Classic Addon fuer Vendor-Kaeufe mit Prioritaet, Testmodus und optionalem Auto-Refresh.

## Features
- Auto-Kauf fuer eine priorisierte Liste von Item-IDs
- Testmodus:
  - erste 2 Kaeufe sind echt
  - danach nur Log-Ausgabe: "Wuerde kaufen..."
- Bedienpanel direkt am Vendor-Fenster
- Gefilterte, tabellarische IBUY-Zielitemliste (irrelevante Vendor-Items werden in der IBUY-Tabelle ausgeblendet)
- Optional: Linkes Vendorfenster auf deine Zielitems filtern (statt kompletter Blizzard-Liste)
- Optionaler Auto-Refresh-Versuch durch erneutes Ansprechen des aktuell anvisierten Vendors

## Quickstart
1. Stelle sicher, dass der Ordner `IBUY` in `Interface/AddOns` liegt.
2. Spiel starten, Addon aktivieren.
3. Beim Vendor:
   - Ziel-ID(s) eintragen (z. B. `16224`)
   - `IBUY Start` klicken

## Konfiguration
- Standard-Zielitem: `16224`
- Testmodus ist standardmaessig aktiv.
- Slash-Befehl: `/ibuy`

### Wichtige Befehle
- `/ibuy start`
- `/ibuy stop`
- `/ibuy add 16224`
- `/ibuy remove 16224`
- `/ibuy list`
- `/ibuy test on`
- `/ibuy test off`
- `/ibuy debug on`
- `/ibuy debug off`
- `/ibuy logfile on`
- `/ibuy logfile off`
- `/ibuy logclear`
- `/ibuy logtail 30`
- `/ibuy logpath`
- `/ibuy selftest`

## Troubleshooting
- Problem: Es wird nichts gekauft.
  - Pruefen:
    - Vendor-Fenster ist offen
    - `IBUY Start` aktiv
    - Item-ID in `/ibuy list` vorhanden
    - Item ist beim Vendor aktuell verfuegbar
    - genug Gold vorhanden
- Problem: Rezept erscheint nicht sofort.
  - Auto-Refresh im IBUY-Panel aktivieren (ohne Fenster-Loop).
  - Falls noetig, Button `Vendor neu ansprechen` verwenden und Vendor im Target behalten.
- Hinweis zur Filterung:
  - Option `In Tabelle nur aktuell relevante Vendor-Zielitems` filtert links die Vendorliste auf deine Zielitems.
  - Die rechte IBUY-Tabelle bleibt als vollstaendige Uebersicht deiner Watchlist erhalten.
- Problem: Zu viele Log-Meldungen.
  - `/ibuy debug off` setzen.

## Logs und Debug
- Chat-Prefix: `[IBUY]`
- Debug aktivieren mit `/ibuy debug on`
- Persistente Debug-Datei aktivieren mit `/ibuy logfile on`
- Dateiort: `WTF/Account/<ACCOUNT>/SavedVariables/IBUY.lua` (Schluessel `IBUY_DB.debugLog`)
- Wichtig: SavedVariables werden bei `/reload`, Logout oder Spielende geschrieben.

## Security / Rechte
- IBUY speichert nur lokale Addon-Konfiguration in `SavedVariables` (`IBUY_DB`).
- Keine externen Netzverbindungen.
- Keine Secrets erforderlich.

## Testen
- Ingame-Test:
  - Vendor oeffnen
  - `/ibuy selftest` fuer Kernlogik
  - Testmodus mit guenstigem Vendor-Item (z. B. Item-ID `27860`) pruefen

## Lizenz-Hinweis
- Aktuell ohne separate Lizenzdatei. Bei Veroeffentlichung bitte Lizenz ergaenzen (z. B. MIT).

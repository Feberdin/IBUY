# IBUY

Auto-buy selected vendor items in WoW Classic with priority rules, a safe test mode, and practical debug tooling.

## Why IBUY
Busy vendors are hard to click reliably when many players stand on top of the NPC.
IBUY keeps checking the merchant list and buys your configured target items as soon as they are available.

## Features
- Priority-based auto-buy for configured item IDs
- Test mode: first 2 purchases are real, then log-only (`Would buy ...`)
- Vendor panel UI with start/stop and settings
- Optional vendor refresh helper
- Persistent debug log in `SavedVariables`
- Easter egg support (`HEFTIG` button + custom local sound file)

## Quickstart
1. Install the `IBUY` folder in `Interface/AddOns`.
2. Start WoW and enable `IBUY`.
3. Open a vendor and run:
   - `/ibuy add 16224`
   - `/ibuy start`

## Commands
- `/ibuy start`
- `/ibuy stop`
- `/ibuy add <itemID>`
- `/ibuy remove <itemID>`
- `/ibuy list`
- `/ibuy test on|off`
- `/ibuy debug on|off`
- `/ibuy logfile on|off`
- `/ibuy logclear`
- `/ibuy logtail <n>`
- `/ibuy logpath`
- `/ibuy postvideo`
- `/ibuy finishmsg on|off`
- `/ibuy heftig`
- `/ibuy selftest`

## Debug Log
- Enable: `/ibuy logfile on`
- Path: `WTF/Account/<ACCOUNT>/SavedVariables/IBUY.lua`
- Key: `IBUY_DB.debugLog`
- Note: SavedVariables are written on `/reload`, logout, or game exit.

## HEFTIG Sound
Expected file path:
- `Interface\\AddOns\\IBUY\\sounds\\heftig.ogg`

## Project Summary
- English: see [DESCRIPTION.en.md](DESCRIPTION.en.md)
- German: see [DESCRIPTION.de.md](DESCRIPTION.de.md)

## License
MIT (recommended for release).

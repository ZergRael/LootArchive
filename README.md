# LootArchive

**WoW classic addon used to keep an history of raid loot distributions of your guild**

I got tired of copy-pasting every item on every raid in a spreadsheet, and usual raid loot addons are not convenient for the simple loot history I need.

_This addon is currently in beta state, expect issues you may want to [report](https://github.com/ZergRael/LootArchive/issues) !_

Responds to console with **/la** and a minimap button.

## Features

- Active playername guessing based on current raid roster (accented characters begone !)
- Sync database on login with other guild members
- Configurable announce channels
- Configurable string patterns for loot announce and distribution
- Configurable database size
- Display loots history in a sortable table

![](https://img.thetabx.net/788C8.png)

- Also filterable by item or player name

![](https://img.thetabx.net/mN0yt.png)

- CSV / Excel export
- Live database synchronization on loot distribution
- Editable rows for typo fixes or late redistribution

## Commands

- /la add (item ID or item link)
  - Adds an item to current distribution and ask for rolls in raid
- /la give (playername) (_reason_)
  - Gives current item to a raid player (with optional reason)
- /la give (item ID or item link) (playername) (_reason_)
  - Gives an item to a raid player (with optional reason), skiping rolls calls
- /la giveexact (item ID or item link) (playername) (_reason_)
  - Gives an item to a player (with optional reason), without trying to guess playername (this allow out of raid distribution if necessary)
- /la toggle
  - Shows or hide GUI (minimap button may be more practical)

## Todo

- One way database synchronization based on guild ranks to disallow spoofing
- Anything you would like ? Please create an [issue on Github](https://github.com/ZergRael/LootArchive/issues)

## Known issues

## Contribution

You can help this project by adding [translations](https://www.curseforge.com/wow/addons/lootarchive/localization) and [reporting issues](https://github.com/ZergRael/LootArchive/issues).

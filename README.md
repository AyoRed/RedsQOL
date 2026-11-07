# Reds QOL

A quality-of-life addon for WoW Forever by Red, with a dark brown and amber settings panel.

- Attack-range warnings, with facing and line-of-sight messages.
- Cursor rings and animated trails.
- Loot sparkles for quest objects, herbs, ore and lootable corpses.
- Trainer spell lists and level-up reminders.
- Themed dungeon journal with quests, boss abilities, loot and maps for four dungeons.
- Campfire reminders, bonus tracking, timer ring and warning sounds.
- Customizable top bar with clock, FPS/latency and shortcuts.
- Movable QOL displays and a one-click Reload UI button.
- Normal dragging of Blizzard windows such as spellbook and talents, separate from QOL placement.

## Install and update

Use Red's UI Updater to install or update Reds QOL automatically:
https://github.com/AyoRed/RedsUI/releases/latest

For manual installation, download `RedsQOL-1.1.0.zip` from this repository's Releases and extract the `RedsQOL` folder into your game's `Interface/AddOns` directory. Restart WoW after a first installation.

## Controls

- `/rqol` or left-click the minimap button: settings.
- Right-click the minimap button or choose **Unlock & move QOL displays**: position Campfire, Top Bar, Range Warning and Reload UI. Click **Lock position** when finished.
- `/rjournal`: dungeon journal (also available as a section in settings).
- `/rtrainer`: trainer spell list.
- `/rcamp`: Campfire settings.

Movers are visible only while unlocked. QOL placement does not edit Blizzard or Ellesmere HUD frames. Blizzard window dragging works separately during normal play.

Campfire settings are imported on first use when the standalone Reds Campfire Buffs addon is enabled. Disable the original full RedsUI to avoid overlapping functionality.

Bundled sound credits are retained in `Sounds.lua`. This project does not grant redistribution rights beyond those of its respective authors.

Reds QOL 1.1.0

Quality-of-life tools and the dungeon journal extracted from RedsUI.
/rqol: settings. /rjournal: Dungeon Journal. /rtrainer: trainer spell list.
The journal is also a section in the QOL window and uses its brown/amber theme.

Journal includes Wailing Caverns, Ragefire Chasm, Ruins of Lordaeron and Hall of
Thanes, with faction-aware quests, prerequisite chains, objectives, rewards,
boss ability notes, loot tooltips and dungeon maps with boss portraits.
Quest map links open the normal Blizzard map. QOL does not replace the world map.
Custom map artwork is credited in the journal: Santiago Reyes / Atlas de Azeroth:
Forever, with the original artwork and watermark preserved.

Right-click the minimap button to move QOL displays; Lock position when done.
Normal Blizzard window dragging (spellbook, talents) is separate from placement.
The Reload UI button can be positioned with the other QOL displays.

Source and downloads: https://github.com/AyoRed/RedsQOL
Bundled sound credits are retained in Sounds.lua. Disable full RedsUI to avoid
overlapping functionality. Original RedsUI project files remain unchanged.

1.1.1: Added the missing Ruins of Lordaeron quests (six Horde, four Alliance), item-started quests, rewards, pickup details and Horde prerequisite chains.

1.2.0: Expand any quest to see its required steps, givers and clickable map actions. Pin pickup locations on the existing Blizzard map; right-click a pin to remove it. Multiple pins are saved. Item-started quests use the dungeon map, with exact markers only where known. Optional breadcrumbs are no longer treated as required; Hidden Enemies is added to RFC.

1.2.1: Quest pickup pins have a subtle amber halo that pulses while visible, on both the world map and journal dungeon maps. The icon itself stays steady.

1.2.2: Both quest pickup map views now use the same custom amber arrow with a red center stripe, dark outline, gentle vertical bounce and brighter pulsing halo.

1.2.3: OpenMap compatibility: pickup markers use its stitched coordinate projection, sit above its artwork and keep their display size across zoom changes.

1.2.4: Pickup coordinates now use an unscaled canvas anchor separate from the arrow's zoom scaling. Only the selected pickup is marked; old saved pins are cleared once. A fixed dot and smaller halo identify the actual location while the arrow bounces above it.

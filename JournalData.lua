-- Dungeon maps and their bosses.
--   Map art: the game's own dungeon map tiles (both clients ship them though their maps list has no dungeons): 4 across and 3 down,
--   256 pixels each, numbered 1-12 row by row, of which the top-left 1002 by 668 is the map. Or one picture (art) with its size.
--   Bosses: where each stands (0-1 across and down the map), its model for the portrait, its abilities (with a spell for the icon)
--   and its loot (item ids; only those the client knows are shown, so one list serves both clients).
--   [instance map id] = { tiles = { 12 file ids } or art = path, w, h (the map's size in the art), texH (the art's full height),
--                         credit, bosses = { { npc, name, display, x, y, note, abilities = { { name, spell, text } }, loot = { ids } } } }
-- Wailing Caverns' positions, models and loot are the game's own encounter records; the tips are Red's. Ragefire Chasm and Ruins of
-- Lordaeron come from Red's Forever Dungeon Maps.
local _, ns = ...
local A = ns.Atlas

local function Tiles(first, second, rest)
	-- (tile 1, then 2-9, then 10-12: the files are numbered in that order)
	local t = { first }
	for i = 0, 7 do t[#t + 1] = second + i end
	for i = 0, 2 do t[#t + 1] = rest + i end
	return t
end

-- Quests: { id, name, level, min (level to take it), side ("Horde", "Alliance", or nil for both), giver, at = { map, x, y } where the
-- giver stands (any of the game's maps: zone, city or continent), item (started by an item instead), goal (in Red's words),
-- rewards = { item ids }, pre = { the quests needed first, in order: { id, name, giver, at } }, ends (where it's handed in when that
-- isn't the giver) }. Ids and places are public facts (warcraft.wiki.gg, checked against the game's own maps).
local TB, BARRENS, KALIMDOR, DARNASSUS = 1456, 1413, 1414, 1457
local TONGA = { "Tonga Runetotem", { BARRENS, 0.522, 0.319 } }
local HAMUUL = { "Arch Druid Hamuul Runetotem", { TB, 0.786, 0.286 } }
local WC_CAVE = { KALIMDOR, 0.5187, 0.5550 }   -- (the cave above the entrance)
local FALLA = { BARRENS, 0.482, 0.328 }        -- (the mountaintop above the dungeon)

-- the Fanglords' shared spells
local BOLT = { "Lightning Bolt", 9532, "Nature damage on the target. Interrupt it when you can." }
local SLUMBER = { "Druid's Slumber", 8040, "Puts a player to sleep. Dispel it, or any damage wakes them." }
local HEAL = { "Healing Touch", 23381, "A large heal. Always interrupt it." }

A.DungeonMapData = {
	-- Wailing Caverns
	[43] = {
		card = 608229,   -- (the game's dungeon journal picture, Interface\EncounterJournal\UI-EJ-DungeonButton-WailingCaverns)
		tiles = Tiles(448454, 448458, 448455),
		quests = {
			{ id = 914, name = "Leaders of the Fang", level = 22, min = 10, side = "Horde", giver = "Nara Wildmane", at = { TB, 0.756, 0.314 },
				goal = "Bring Nara the four Fanglords' gems: Cobrahn, Anacondra, Pythas and Serpentis.", rewards = { 6505, 6504, 270018 },
				pre = {
					{ 886, "The Barrens Oases", HAMUUL[1], HAMUUL[2] },
					{ 870, "The Forgotten Pools", TONGA[1], TONGA[2] },
					{ 877, "The Stagnant Oasis", TONGA[1], TONGA[2] },
					{ 880, "Altered Beings", TONGA[1], TONGA[2] },
					{ 1489, "Hamuul Runetotem", TONGA[1], TONGA[2] },
					{ 1490, "Nara Wildmane", HAMUUL[1], HAMUUL[2] } } },
			{ id = 962, name = "Serpentbloom", level = 18, min = 14, side = "Horde", giver = "Apothecary Zamah", at = { TB, 0.228, 0.209 },
				goal = "Pick 10 Serpentbloom in the caverns. Each one picked wakes a snake.", rewards = { 10919, 270008, 270009 } },
			{ id = 1486, name = "Deviate Hides", level = 17, min = 13, giver = "Nalpak", at = WC_CAVE,
				goal = "Bring Nalpak 20 Deviate Hides from the creatures inside.", rewards = { 6480, 918 } },
			{ id = 1487, name = "Deviate Eradication", level = 21, min = 15, giver = "Ebru", at = WC_CAVE,
				goal = "Slay 7 each of Deviate Ravagers, Vipers, Shamblers and Dreadfangs.", rewards = { 6476, 8071, 6481 } },
			{ id = 959, name = "Trouble at the Docks", level = 18, min = 14, giver = "Crane Operator Bigglefuzz", at = { BARRENS, 0.631, 0.376 },
				goal = "Take back the 99-Year-Old Port from Mad Magglish, hiding in the caverns." },
			{ id = 1491, name = "Smart Drinks", level = 18, min = 13, giver = "Mebok Mizzyrix", at = { BARRENS, 0.624, 0.376 },
				goal = "Bring Mebok 6 Wailing Essence from the ectoplasms inside.",
				pre = { { 865, "Raptor Horns", "Mebok Mizzyrix", { BARRENS, 0.624, 0.376 } } } },
			{ id = 6981, name = "The Glowing Shard", level = 26, min = 15, item = "Glowing Shard, dropped by Mutanus the Devourer",
				goal = "Take the shard to Falla Sagewind on the mountaintop above the caverns.", ends = { "Falla Sagewind", FALLA } },
			{ id = 3369, name = "In Nightmares", level = 25, min = 15, side = "Horde", giver = "Falla Sagewind", at = FALLA,
				goal = "Take the Nightmare Shard to Hamuul Runetotem on Elder Rise, Thunder Bluff.", rewards = { 10657, 10658 },
				pre = { { 6981, "The Glowing Shard", "Glowing Shard (from Mutanus)", nil } }, ends = HAMUUL },
			{ id = 3370, name = "In Nightmares", level = 25, min = 15, side = "Alliance", giver = "Falla Sagewind", at = FALLA,
				goal = "Take the Nightmare Shard to Mathrengyl Bearwalker in Darnassus.", rewards = { 10657, 10658 },
				pre = { { 6981, "The Glowing Shard", "Glowing Shard (from Mutanus)", nil } }, ends = { "Mathrengyl Bearwalker", { DARNASSUS, 0.354, 0.084 } } },
		},
		bosses = {
			{ npc = 3671, name = "Lady Anacondra", display = 4313, x = 0.306, y = 0.430, abilities = {
				BOLT, SLUMBER, HEAL,
				{ "Thorns Aura", 8148, "Melee attackers take Nature damage. Melee keep an eye on their health." } },
				loot = { 6446, 10412, 5404, 273088, 273098 } },
			{ npc = 3670, name = "Lord Pythas", display = 4214, x = 0.191, y = 0.395, abilities = {
				BOLT, SLUMBER, HEAL,
				{ "Thunderclap", 8147, "Nature damage around him that slows attacks and movement. Ranged stay back." } },
				loot = { 6473, 6472, 273089, 253938 } },
			{ npc = 3669, name = "Lord Cobrahn", display = 4213, x = 0.167, y = 0.568, abilities = {
				BOLT, SLUMBER, HEAL,
				{ "Serpent Form", 7965, "At 45% health he turns into a serpent: harder, slower hits. The healer gets ready." },
				{ "Poison", 744, "Nature damage over time. Cure it when you can." } },
				loot = { 10410, 6460, 6465, 253908, 252778 } },
			{ npc = 3653, name = "Kresh", display = 5126, x = 0.385, y = 0.361, note = "Swims the river; he may not be where the map shows.", abilities = {
				{ "Crushing Bite", nil, "Lowers the tank's armor for a while. Otherwise an easy fight." } },
				loot = { 6447, 13245, 273084 } },
			{ npc = 3674, name = "Skum", display = 4203, x = 0.623, y = 0.744, abilities = {
				{ "Chained Bolt", 6254, "Lightning that jumps between players standing close. Spread out." } },
				loot = { 6449, 6448, 273137, 253944 } },
			{ npc = 3673, name = "Lord Serpentis", display = 4215, x = 0.616, y = 0.539, abilities = { BOLT, SLUMBER, HEAL },
				loot = { 6459, 5970, 10411, 6469, 273087 } },
			{ npc = 5775, name = "Verdan the Everliving", display = 4256, x = 0.555, y = 0.465, abilities = {
				{ "Grasping Vines", 8142, "Knocks down and roots everyone near him. Ranged and healers stay out of reach." } },
				loot = { 6631, 6630, 6629, 253938 } },
			{ npc = 3654, name = "Mutanus the Devourer", display = 4088, x = 0.346, y = 0.137,
				note = "Comes at the end of the Disciple of Naralex's ritual, once the four Fanglords are dead.", abilities = {
				{ "Naralex's Nightmare", 7967, "Puts a player to sleep. Dispel it, or any damage wakes them." },
				{ "Terrify", 7399, "Sends a player running in fear. A fear ward or tremor totem helps." },
				{ "Thundercrack", 8150, "Nature damage and a stun to everyone near him. Ranged and healers stay back." } },
				loot = { 6627, 6463, 6461 } },
		},
	},
	-- Ragefire Chasm
	[389] = {
		card = 608211,   -- (UI-EJ-DungeonButton-RagefireChasm)
		tiles = Tiles(449736, 449740, 449737),
		-- (Horde only: the Alliance have no Ragefire Chasm quests in the Classic game. where: the giver is inside the dungeon, which has no
		-- spot on the world map.)
		quests = {
			{ id = 5723, name = "Testing an Enemy's Strength", level = 15, min = 9, side = "Horde", giver = "Rahauro", at = { TB, 0.704, 0.296 },
				goal = "Slay 8 Ragefire Troggs and 8 Ragefire Shamans in the chasm, then report back to Rahauro." },
			{ id = 5722, name = "Searching for the Lost Satchel", level = 16, min = 9, side = "Horde", giver = "Rahauro", at = { TB, 0.704, 0.296 },
				goal = "Find Maur Grimtotem's body in the chasm and search it.", ends = { "Maur Grimtotem", nil, "inside Ragefire Chasm" } },
			{ id = 5724, name = "Returning the Lost Satchel", level = 16, min = 10, side = "Horde", giver = "Maur Grimtotem", where = "Inside Ragefire Chasm",
				goal = "Carry the Grimtotem Satchel back to Rahauro in Thunder Bluff.", rewards = { 15452, 15453, 270003 },
				pre = { { 5722, "Searching for the Lost Satchel", "Rahauro", { TB, 0.704, 0.296 } } }, ends = { "Rahauro", { TB, 0.704, 0.296 } } },
			{ id = 5761, name = "Slaying the Beast", level = 16, min = 9, side = "Horde", giver = "Neeru Fireblade", at = { 1454, 0.496, 0.504 },
				goal = "Slay Taragaman the Hungerer in the chasm and bring his heart to Neeru.",
				pre = { { 5726, "Hidden Enemies", "Thrall", { 1454, 0.3174, 0.3782 } } } },
			-- (an Undercity quest: Varimathras sends you for a book from the chasm; Forever's quest list has it with these rewards)
			{ id = 5725, name = "The Power to Destroy...", level = 16, min = 9, side = "Horde", giver = "Varimathras", at = { 1458, 0.566, 0.924 },
				goal = "Bring Spells of Shadow and Incantations from the Nether, found in the chasm, to Bragor Bloodfist in the Undercity.",
				rewards = { 15449, 15450, 15451 }, ends = { "Bragor Bloodfist", nil, "Undercity" } },
		},
		bosses = {
			{ npc = 11517, name = "Oggleflint", display = 11611, x = 696 / 1002, y = 432 / 668, abilities = {
				{ "Cleave", nil, "Hits the tank and anyone beside them. Keep him facing away from the group." } },
				loot = { 272996, 272998, 272999 } },
			{ npc = 11520, name = "Taragaman the Hungerer", display = 7970, x = 408 / 1002, y = 385 / 668, abilities = {
				{ "Fire Nova", nil, "Fire damage to everyone near him. Keep the group healthy and don't pull extra enemies." },
				{ "Uppercut", nil, "A melee hit that knocks back. Tank him away from edges and lava." } },
				loot = { 14145, 14148, 14149 } },
			{ npc = 11518, name = "Jergosh the Invoker", display = 11429, x = 343 / 1002, y = 546 / 668, abilities = {
				{ "Immolate", nil, "Fire damage, then more over time. Interrupt the cast or dispel the magic." },
				{ "Curse of Weakness", nil, "Lowers physical damage dealt. Remove the curse when your group can." } },
				loot = { 14147, 14150, 14151 } },
			{ npc = 11519, name = "Bazzalan", display = 2007, x = 545 / 1002, y = 196 / 668, abilities = {
				{ "Sinister Strike", nil, "An extra melee hit that pressures the tank. Keep heals ready." },
				{ "Deadly Poison", nil, "Poison damage over time. Cure poison and control the adds nearby." } },
				loot = { 273003, 273007, 273005 } },
		},
	},
	-- Ruins of Lordaeron (WoW Forever)
	[2999] = {
		forever = true,   -- (only in WoW Forever)
		art = "Interface\\AddOns\\RedsQOL\\Media\\Dungeons\\RuinsOfLordaeron", w = 1024, h = 683, texH = 1024,
		credit = "Map: Santiago Reyes - Atlas de Azeroth: Forever",
		bosses = {
			{ npc = 250483, name = "Witherfang", display = 144189, x = 0.668, y = 0.36, abilities = {
				{ "Leech Poison", nil, "Poison on the tank. Remove it and keep the patrol apart from nearby packs." } },
				loot = { 271201, 271202, 271203 } },
			{ npc = 250660, name = "The Baron", display = 144188, x = 0.615, y = 0.65, abilities = {
				{ "Knockout", nil, "A hard hit, then a stun. Keep the tank healthy." } },
				loot = { 271205, 271206, 271204 } },
			{ npc = 256035, name = "Viktor the Vile", display = 139455, x = 0.60, y = 0.73, note = "Optional.", abilities = {
				{ "Chimney event", nil, "Five waves of enemies come before Viktor. Save mana between waves." },
				{ "Leech Poison", nil, "Remove the poison when you can." } },
				loot = { 271218, 271211, 271212 } },
			{ npc = 250631, name = "The Abandoned", display = 138667, x = 0.395, y = 0.665, abilities = {
				{ "Statue event", nil, "Three waves of enemies come before the boss." },
				{ "Frost Nova / Chilled", nil, "Roots and slows players nearby." },
				{ "Life Drain", nil, "Stun the cast when you can." } },
				loot = { 271208, 271207, 271216 } },
			{ npc = 256097, name = "Bjork", display = 144170, x = 0.345, y = 0.22, abilities = {
				{ "Anti-Magic Shield", nil, "Blocks magic for a short while. Don't pull the ghouls nearby." } },
				loot = { 271209, 271210, 271217 } },
			{ npc = 250657, name = "Rath'mael", display = 144175, x = 0.52, y = 0.60, abilities = {
				{ "Flamestrike", nil, "Move out of the fire on the ground. Stun the cast when you can." } },
				loot = { 271215, 271214, 271213 } },
		},
	},

	-- The Hall of Thanes (WoW Forever, Ironforge): who is inside, their models and their loot are the game's own records (public ids). Each boss's abilities are read from
	-- the game's own Adventure Guide the first time the page is opened (A.BossAbilities, Atlas\DungeonMaps.lua), so they are the game's words.
	[3065] = {
		forever = true,   -- (only in WoW Forever)
		-- (the map is Santiago Reyes's, Atlas de Azeroth: Forever, unchanged apart from its size, with his watermark; credited on the map)
		art = "Interface\\AddOns\\RedsQOL\\Media\\Dungeons\\HallOfThanes", w = 1024, h = 683, texH = 1024,
		credit = "Map: Santiago Reyes - Atlas de Azeroth: Forever",
		-- (the tips are Red's own words, from what the dungeon guides on Method and Warcraft Tavern agree on; ids, models and loot are the game's own records)
		-- Quests: ids and places are public facts (warcraft.wiki.gg and the dungeon guides; they agree on the order). Rewards are named in the goal: their item ids are not in the data yet.
		quests = {
			{ id = 96403, name = "Important Heirlooms", level = 15, min = 10, side = "Alliance", giver = "Thom Filch", at = { 1455, 0.324, 0.448 },
				goal = "Find 8 Dwarven Heirlooms inside the Hall of Thanes (in urns and chests) and bring them back to Thom Filch. Choose the Dwarven Tome or Tomb Robber's Gloves." },
			{ id = 96394, name = "The Restless Dead", level = 15, min = 10, side = "Alliance", giver = "Afadra Dunwall", at = { 1455, 0.330, 0.480 },
				goal = "Slay 15 Enraged Apparitions and 10 Tormented Souls in the Hall of Thanes, then report to Afadra Dunwall. Choose the Dusty Belt or Cryptwalker Bracers." },
			{ id = 96395, name = "An Ancient Grudge", level = 15, min = 10, giver = "Ghostly Attendant", where = "Inside the Hall of Thanes, in Anvilmar's Rest",
				goal = "Kill Faldrim Anvilmar, the first boss, then go back to the Ghostly Attendant. Choose the Catacomb Cloak or Deepgrave Trousers." },
			{ id = 98423, name = "The Treaty of Understanding", level = 16, min = 9, side = "Alliance", item = "The Treaty tablet, found in a vault behind a door in the Reliquary of Kings (Durgen's room)",
				goal = "Take the Treaty of Understanding to King Magni Bronzebeard in Ironforge.", ends = { "King Magni Bronzebeard", { 1455, 0.394, 0.558 } } },
			{ id = 96393, name = "Old Ironforge Incursion", level = 16, min = 9, side = "Alliance", giver = "Earthseer Farsen", at = { 1426, 0.648, 0.584 },
				goal = "Go into the Hall of Thanes, take Durgen Dirgehammer's head and bring it to King Magni Bronzebeard in Ironforge. Choose the Calibrated Blunderbuss, Ironforge Greathammer or Deepblaze.",
				pre = {
					{ 96408, "A Visitor to Dun Morogh (a first step you can skip)", "Beldin Steelgrill", { 1426, 0.504, 0.490 } },
					{ 96392, "Farsen's Watch", "Earthseer Farsen", { 1426, 0.648, 0.584 } },
					{ 96390, "Nip 'Em in the Bud", "Earthseer Farsen", { 1426, 0.648, 0.584 } },
					{ 96391, "Underground Map", "the Dark Iron Map, dropped by a Dark Iron Spy", { 1426, 0.648, 0.584 } } },
				ends = { "King Magni Bronzebeard", { 1455, 0.394, 0.558 } } },
		},		bosses = {
			{ npc = 261306, name = "Faldrim Anvilmar", display = 142826, x = 0.505, y = 0.667, encounter = 3493, note = "The undead dwarf in his tomb, Anvilmar's Rest.",
				abilities = {
					{ "Pulling the tomb", nil, "The ghosts around his tomb are the real danger: clear them first, so you never pull him with them." },
					{ "Mind Blast", nil, "A shadow blast. It can be interrupted, but you don't have to." },
					{ "Anvilmar's Curse", nil, "On the tank, for a long time: slows attacks and casting by about a fifth. Remove it if you can; the fight is fine with it on." } },
				loot = { 271097, 271096, 270227 } },
			{ npc = 261316, name = "Magmatus", display = 1070, x = 0.694, y = 0.45, encounter = 3495, note = "A fire elemental in a cavern, with a Dark Iron Summoner beside him.",
				abilities = {
					{ "Kill the Summoner first", nil, "Pull Magmatus away and have the damage dealers drop the Dark Iron Summoner before anything else." },
					{ "Fire Nova", nil, "Fire damage all around him. Ranged players stay out of melee range; healers heal everyone there, not just the tank." },
					{ "Combust", nil, "Fire damage on a random player that keeps burning. Healers watch for it." } },
				loot = { 270230, 271095, 270231 } },
			{ npc = 261311, name = "Plunder", display = 142840, x = 0.51, y = 0.36, encounter = 3494, note = "A stone guardian that patrols the hallway.",
				abilities = {
					{ "Pulling him", nil, "Pull him away from other enemies, to a corner, and tank him with your back to a wall." },
					{ "Knock Away", nil, "Throws players back. Stand so nobody is sent into another pack." } },
				loot = { 270228, 270229, 271098 } },
			{ npc = 261319, name = "Durgen Dirgehammer", display = 142837, x = 0.51, y = 0.18, encounter = 3496, note = "The last boss, in the Reliquary of Kings, with two Lesser Stone Golems.",
				abilities = {
					{ "Clear the room first", nil, "Dark Iron Looters surround him: kill them all before the pull, or they join in." },
					{ "Fear", nil, "Scatters the group for several seconds. A Shaman can drop a Tremor Totem before the pull." },
					{ "Rend", nil, "A bleed on the tank that ticks hard. Healers keep the tank topped up." },
					{ "Kill order", nil, "The guides disagree: some burn Durgen first, others kill the two Lesser Stone Golems first. The golems hit hard, so don't leave them long." } },
				loot = { 270256, 270261, 270260 } },
		},
	},
}
-- Ruins quest IDs, factions, levels, reward IDs and pickup locations checked against
-- the installed ForeverDungeonJournal data; objectives restated for Reds QOL.
-- Horde prerequisite chains also checked against the current Wowhead quest update.
local RUINS_QUESTS={
 {id=95250,name="Abominable Creatures",level=21,min=16,side="Alliance",giver="Captain Truman",where="Inside the dungeon, beside the entrance",
  goal="Defeat The Baron and take his head back to Captain Truman at the entrance.",rewards={279864,279865,279867}},
 {id=97288,name="Unending Torment",level=21,min=16,side="Horde",item="Abominable Head, looted from The Baron",
  goal="Bring the head to Master Apothecary Faranell in Undercity. The equipment choices come from a later step of this chain.",ends={"Master Apothecary Faranell",{1458,.488,.693}}},
 {id=92401,name="A Frightened Request",level=22,min=15,side="Horde",giver="Tabitha Heartweaver",at={1421,.445,.430},
  goal="Search the ruins for Edward Heartweaver, then return to Tabitha at the Sepulcher.",rewards={251485,251486}},
 {id=95195,name="Bloodied Insignia",level=22,min=16,side="Alliance",item="Bloodied Insignia, dropped by undead inside the dungeon",
  goal="Gather 10 insignias from the dungeon's undead and deliver them to General Marcus Jonathan in Stormwind.",ends={"General Marcus Jonathan",nil,"Stormwind City"},rewards={279868,279869}},
 {id=95189,name="Crest of Lordaeron",level=22,min=16,side="Alliance",item="Crest of Lordaeron, found inside the dungeon",
  goal="Look for the crest in the dungeon's rooms and towers; its location can vary. Deliver it to Lady Dena Kennedy in Stormwind.",ends={"Lady Dena Kennedy",nil,"Stormwind City"},rewards={280567}},
 {id=95204,name="Crest of Lordaeron",level=22,min=16,side="Horde",item="Crest of Lordaeron, found inside the dungeon",
  goal="Find the crest inside the ruins and bring it to Oran Snakewrithe in Undercity. Its spawn location varies.",ends={"Oran Snakewrithe",nil,"Undercity"},rewards={280567}},
 {id=92421,name="Light's Justice",level=22,min=15,side="Horde",giver="Morbin Lightbane",at={1458,.579,.895},
  goal="Collect 25 Intact Limbs from the ruins for Morbin Lightbane in Undercity.",rewards={279874,279875}},
 {id=92415,name="Remember That I Love You",level=22,min=15,side="Alliance",item="Blood-Stained Letter, found in the dungeon graveyard",
  goal="Take the letter from the graveyard to Orphan Matron Nightingale in Stormwind.",ends={"Orphan Matron Nightingale",nil,"Stormwind City"},rewards={279870}},
 {id=95216,name="The New Plague",level=22,min=16,side="Horde",giver="Theodore Griffs",at={1458,.465,.716},
  goal="Retrieve the Highly Toxic Strain from Witherfang for Theodore Griffs. First finish the three A Recipe For Death quests.",rewards={279876,279877},
  pre={{447,"A Recipe For Death","Apothecary Renferrel",{1421,.428,.409}},
       {450,"A Recipe For Death","Master Apothecary Faranell",{1458,.488,.693}},
       {451,"A Recipe For Death","Apothecary Renferrel",{1421,.428,.409}}}},
 {id=92422,name="The Wrath of Rath'mael",level=22,min=15,side="Horde",giver="Deathguard Kristof",at={1420,.652,.602},
  goal="Defeat Rath'mael and report to Deathguard Kristof. First finish Linnea's two Rear Guard Patrol quests.",rewards={251533,251534},
  pre={{356,"Rear Guard Patrol","Deathguard Linnea",{1420,.655,.603}},
       {99156,"Rear Guard Patrol","Deathguard Linnea",{1420,.655,.603}}}}
}

A.DungeonMapData[2999].quests=RUINS_QUESTS

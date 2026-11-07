-- The dungeon journal: a page in Red's menu (Dungeon journal). Dungeons down the left; the one you pick on the right, as Overview (its
-- quests, then its bosses as cards with the gear they drop) or Map (the dungeon's own map with its bosses standing on it).
-- Nothing here runs until the page is shown. The dungeons, bosses, gear and quests are the map addon's (Atlas\Data\DungeonMaps.lua).
local _, ns = ...
local Menu = _G.RedsQOL
local UI = Menu.UI
local Text = UI.Text
local J = {}
Menu.Journal = J

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local MEDIA = "Interface\\AddOns\\RedsQOL\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local ACCENT = { 1, 0.6, 0.15 }
local GREEN = { 0.42, 0.86, 0.42 }
local RED = { 1, 0.4, 0.3 }
local AMBER = { 1, 0.82, 0.45 }
local GREY = { 0.72, 0.67, 0.6 }
local LIST_W = 232
local TILE, ACROSS, DOWN = 256, 4, 3

local function Atlas() return ns.Atlas end
local function Clean() return Menu.db and Menu.db.menuLook == "clean" end

-- Facts ----------------------------------------------------------------------------------------------------------------------
local function About(id)
	local A = Atlas()
	for _, e in ipairs(A.PlaceData and A.PlaceData.dungeons or {}) do
		if e[5] == id then return e[6], e[7], e[8] end
	end
	for _, e in ipairs(A.PlaceData and A.PlaceData.foreverDungeons or {}) do
		if e[4] == id then return e[5], e[6], e[7] end
	end
	return GetRealZoneText and GetRealZoneText(id) or "Dungeon"
end
local function Levels(lo, hi) return lo and lo > 0 and (lo == hi and tostring(lo) or (lo .. "-" .. hi)) or "" end
local function Dungeons()
	local A, list = Atlas(), {}
	for id, d in pairs(A and A.DungeonMapData or {}) do
		if not d.forever or (A.Caps and A.Caps.forever) then
			local name, lo, hi = About(id)
			list[#list + 1] = { id = id, data = d, name = name or "Dungeon", lo = lo or 0, hi = hi or 0 }
		end
	end
	table.sort(list, function(a, b) if a.lo ~= b.lo then return a.lo < b.lo end return a.name < b.name end)
	return list
end
local function ItemInfo(id)
	local get = C_Item and C_Item.GetItemInfo or GetItemInfo
	if get then return get(id) end
end
local function Known(id)
	local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
	return instant and instant(id) ~= nil
end
local requested = {}
local function Ask(id)
	if not requested[id] and C_Item and C_Item.RequestLoadItemDataByID then requested[id] = true; C_Item.RequestLoadItemDataByID(id) end
end
local function Done(id)
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) end
	return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(id) or false
end
local function InLog(id)
	if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then local i = C_QuestLog.GetLogIndexForQuestID(id); if i and i > 0 then return true end end
	if GetQuestLogIndexByID then local i = GetQuestLogIndexByID(id); if i and i > 0 then return true end end
	return false
end
local function Objectives(id)
	local list = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
	return list or {}
end
local function Progress(id)
	local out = {}
	for _, o in ipairs(Objectives(id)) do
		if o.text and o.text ~= "" then out[#out + 1] = (o.finished and "|cff66dd66" or "|cffffd27a") .. o.text .. "|r" end
	end
	return #out > 0 and table.concat(out, "\n") or nil
end
local function Ready(id)
	if C_QuestLog and C_QuestLog.ReadyForTurnIn then local ok, r = pcall(C_QuestLog.ReadyForTurnIn, id); if ok and r then return true end end
	local list = Objectives(id)
	if #list == 0 then return false end
	for _, o in ipairs(list) do if not o.finished then return false end end
	return true
end
local function PlaceName(map) local info = map and C_Map and C_Map.GetMapInfo(map); return info and info.name or "" end
local function Pending(q)
	if not q.pre or Done(q.id) or InLog(q.id) then return end
	for i, p in ipairs(q.pre) do if not Done(p[1]) then return p, i, #q.pre end end
end
-- a quest's words, colour, and where it sorts (in your log first, finished last)
local function State(q)
	if Done(q.id) then return "Complete", GREEN, 5 end
	if InLog(q.id) then if Ready(q.id) then return "Turn in", GREEN, 1 end return "In log", AMBER, 1 end
	if q.min and UnitLevel("player") < q.min then return "Level " .. q.min, RED, 4 end
	local _, i, n = Pending(q)
	if i then return "Step " .. i .. " of " .. n .. " first", RED, 3 end
	return q.item and "Drops inside" or "Pick up", { 0.93, 0.93, 0.95 }, 2
end
local function MyQuests(d)
	local out, faction = {}, UnitFactionGroup("player")
	for _, q in ipairs(d.quests or {}) do if not q.side or q.side == faction then out[#out + 1] = q end end
	return out
end
local function QuestCount(d)
	local list = MyQuests(d)
	if #list == 0 then return end
	local done = 0
	for _, q in ipairs(list) do if Done(q.id) then done = done + 1 end end
	return done, #list
end
local function Portrait(tex, display)
	tex:SetTexture(SKULL)
	if display and SetPortraitTextureFromCreatureDisplayID then pcall(SetPortraitTextureFromCreatureDisplayID, tex, display) end
end

-- State ------------------------------------------------------------------------------------------------------------------------
local sel, tab = nil, "overview"
local opened = {}   -- quests whose details are open
local ui = {}
local list = {}

-- Show on map: the map window opens on the place (the map addon does the rest).
function J.ShowOnMap(at,title,who) Atlas().ShowOnMap(at,title,who) end

-- Small helpers ----------------------------------------------------------------------------------------------------------------
local function Line(parent, a, b, h, r, g, bl, al)
	local t = parent:CreateTexture(nil, "ARTWORK"); t:SetColorTexture(r, g, bl, al); t:SetHeight(h)
	t:SetPoint(a[1], a[2], a[3], a[4]); t:SetPoint(b[1], b[2], b[3], b[4])
	return t
end
local function Link(parent, label, size)
	local b = CreateFrame("Button", nil, parent)
	b.text = Text(b, label, size or 11, GREY); b.text:SetPoint("RIGHT")
	b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.95, 0.85) end)
	b:SetScript("OnLeave", function(self) self.text:SetTextColor(GREY[1], GREY[2], GREY[3]) end)
	function b.Set(text) b.text:SetText(text); b:SetSize(b.text:GetStringWidth() + 4, 16) end
	b.Set(label)
	return b
end
local function ItemButton(parent, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.border = b:CreateTexture(nil, "OVERLAY"); b.border:SetAllPoints(); b.border:SetTexture(WHITE); b.border:SetVertexColor(1, 1, 1, 0)
	b:SetHighlightTexture(WHITE); b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
	b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.item); GameTooltip:Show() end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		local link = select(2, ItemInfo(self.item))
		if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
	end)
	return b
end
local function SetItem(b, id)
	b.item = id
	local name, _, quality, _, _, _, _, _, _, icon = ItemInfo(id)
	if not name then Ask(id) end
	b.icon:SetTexture(icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
	return name, quality
end

-- The right side: Overview ---------------------------------------------------------------------------------------------------
local qrows, bcards, heads = {}, {}, {}
local function Head(i, y, width, label)
	local h = heads[i]
	if not h then
		h = CreateFrame("Frame", nil, ui.body); h:SetHeight(18)
		h.text = Text(h, "", 10, GREY); h.text:SetPoint("LEFT")
		h.rule = Line(h, { "BOTTOMLEFT", h, "BOTTOMLEFT", 0, -1 }, { "BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, -1 }, 1, 1, 1, 1, 0.12)
		heads[i] = h
	end
	h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetWidth(width); h.text:SetText(label); h:Show()
	return 24
end

local function QuestRow(i)
	local r = qrows[i]
	if r then return r end
	r = CreateFrame("Button", nil, ui.body)
	r.hover = r:CreateTexture(nil, "BACKGROUND"); r.hover:SetAllPoints(); r.hover:SetColorTexture(1, 1, 1, 0)
	r.stripe = r:CreateTexture(nil, "BORDER"); r.stripe:SetPoint("TOPLEFT"); r.stripe:SetPoint("BOTTOMLEFT"); r.stripe:SetWidth(2); r.stripe:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	r.hair = Line(r, { "BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0 }, 1, 1, 1, 1, 0.07)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(14, 14); r.icon:SetPoint("TOPLEFT", 10, -8)
	r.name = Text(r, "", 13); r.name:SetPoint("TOPLEFT", 32, -6); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	r.sub = Text(r, "", 10, GREY); r.sub:SetPoint("TOPLEFT", 32, -23); r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
	r.state = Text(r, "", 11); r.state:SetPoint("TOPRIGHT", -12, -7); r.state:SetJustifyH("RIGHT")
	r.map = Link(r, "Show on map", 10); r.map:SetPoint("TOPRIGHT", -12, -22)
	r.map:SetScript("OnClick", function(self) J.ShowOnMap(self.at, self.title, self.who) end)
	r.detail = Text(r, "", 11, { 0.86, 0.86, 0.88 }); r.detail:SetPoint("TOPLEFT", 32, -44); r.detail:SetJustifyH("LEFT"); r.detail:SetJustifyV("TOP"); r.detail:SetSpacing(3)
	r.rewards = {}
	r:SetScript("OnEnter", function(self) self.hover:SetColorTexture(1, 1, 1, 0.035) end)
	r:SetScript("OnLeave", function(self) self.hover:SetColorTexture(1, 1, 1, 0) end)
	r:SetScript("OnClick", function(self) opened[self.qid] = not opened[self.qid] or nil; J.FillOverview() end)
	qrows[i] = r
	return r
end
local function FillQuestRow(r, q, y, width)
	local A = Atlas()
	local state, colour = State(q)
	local done, inLog = Done(q.id), InLog(q.id)
	r.qid = q.id
	r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(width)
	r.stripe:SetShown(inLog)
	r.icon:SetTexture(done and "Interface\\RaidFrame\\ReadyCheck-Ready" or inLog and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon")
	local lr, lg, lb = A.LevelColour(q.level)
	r.name:SetText(q.name .. "  " .. string.format("|cff%02x%02x%02x", lr * 255, lg * 255, lb * 255) .. q.level .. "|r")
	r.name:SetTextColor(done and GREEN[1] or 0.95, done and GREEN[2] or 0.94, done and GREEN[3] or 0.92)
	r.name:SetWidth(width - 190)
	r.state:SetText(state); r.state:SetTextColor(colour[1], colour[2], colour[3])
	local side = q.side == "Horde" and "  |cffe65a4dHorde|r" or q.side == "Alliance" and "  |cff5a9ae6Alliance|r" or ""
	r.sub:SetText((q.item and ("From an item: " .. q.item) or (q.giver .. "  ·  " .. (q.at and PlaceName(q.at[1]) or q.where or ""))) .. side)
	r.sub:SetWidth(width - 190)
	local at = (not q.item) and q.at or nil
	r.map.at, r.map.title, r.map.who = at, q.name, q.giver
		-- ("Show on map" needs Red's Map, which is retired: the link shows only if that map is running)
		local A = Atlas(); local H = A and A.Host
		r.map:SetShown(at ~= nil)
	local h = 40
	local open = opened[q.id]
	r.detail:SetShown(open and true or false)
	local shown = 0
	if open then
		local out = {}
		if q.goal then out[#out + 1] = q.goal end
		if inLog then local pr = Progress(q.id); if pr then out[#out + 1] = pr end end
		if q.pre then
			out[#out + 1] = "|cff9aa0abSteps|r"
			for i, s in ipairs(q.pre) do
				out[#out + 1] = (Done(s[1]) and "|TInterface\\RaidFrame\\ReadyCheck-Ready:11:11|t " or ("|cff9aa0ab" .. i .. ".|r ")) .. s[2] .. "  |cff9aa0ab" .. s[3] .. (s[4] and (", " .. PlaceName(s[4][1])) or "") .. "|r"
			end
			out[#out + 1] = (done and "|TInterface\\RaidFrame\\ReadyCheck-Ready:11:11|t " or ("|cff9aa0ab" .. (#q.pre + 1) .. ".|r ")) .. q.name
		end
		if q.ends then out[#out + 1] = "|cff9aa0abHand in to|r " .. q.ends[1] .. "  |cff9aa0ab" .. (q.ends[2] and PlaceName(q.ends[2][1]) or q.ends[3] or "") .. "|r" end
		if q.rewards then
			local known = false
			for _, id in ipairs(q.rewards) do if Known(id) then known = true end end
			out[#out + 1] = "|cff9aa0ab" .. (#q.rewards > 1 and "Reward (choose one)" or "Reward") .. (known and "" or "  not known on this game client yet") .. "|r"
		end
		r.detail:SetWidth(width - 48); r.detail:SetText(table.concat(out, "\n"))
		h = 44 + r.detail:GetStringHeight() + 6
		if q.rewards then
			for _, id in ipairs(q.rewards) do
				if Known(id) then
					shown = shown + 1
					local b = r.rewards[shown]
					if not b then b = ItemButton(r, 24); r.rewards[shown] = b end
					local _, quality = SetItem(b, id)
					local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
					b.border:SetVertexColor(c and c.r or 1, c and c.g or 1, c and c.b or 1, 0)
					b:ClearAllPoints(); b:SetPoint("TOPLEFT", 32 + (shown - 1) * 30, -h); b:Show()
				end
			end
			if shown > 0 then h = h + 30 end
		end
		h = h + 4
	end
	for i = shown + 1, #r.rewards do r.rewards[i]:Hide() end
	r:SetHeight(h); r:Show()
	return h
end

local function BossCard(i)
	local c = bcards[i]
	if c then return c end
	c = CreateFrame("Frame", nil, ui.body, "BackdropTemplate")
	c:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	c:SetBackdropColor(.12, .065, .025, .8); c:SetBackdropBorderColor(.65, .34, .12, .7)
	c.num = Text(c, "", 11, GREY); c.num:SetPoint("TOPLEFT", 12, -13)
	c.name = Text(c, "", 14, { 0.96, 0.94, 0.92 }); c.name:SetPoint("TOPLEFT", 30, -11); c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false)
	c.none = Text(c, "No gear listed for this boss on this game client.", 10, GREY); c.none:SetPoint("TOPLEFT", 12, -40)
	c.rows = {}
	bcards[i] = c
	return c
end
-- a boss's abilities, a line each (the name, then what to do): from the dungeon's data, or the game's own guide for it
local function AbilityLine(c, i)
	c.abil = c.abil or {}
	local fs = c.abil[i]
	if fs then return fs end
	fs = Text(c, "", 10, { 0.8, 0.8, 0.82 }); fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetWordWrap(true)
	c.abil[i] = fs
	return fs
end
local function LootRow(c, i)
	local r = c.rows[i]
	if r then return r end
	r = ItemButton(c, 24)
	-- (the whole row is the button: the picture sits at its left, the name beside it)
	r.icon:ClearAllPoints(); r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT", 1, 0)
	r.name = Text(r, "", 12); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	c.rows[i] = r
	return r
end
local function FillBossCard(c, b, index, x, y, w)
	c.num:SetText(index); c.name:SetText(b.name); c.name:SetWidth(w - 44)
	c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, -y); c:SetWidth(w)
	-- the abilities first, under the name
	local top = 40
	local A = Atlas()
	local abilities = (A and A.BossAbilities) and A.BossAbilities(b) or {}
	local na = 0
	for i, ab in ipairs(abilities) do
		if i > 8 then break end
		na = i
		local fs = AbilityLine(c, i)
		fs:SetWidth(w - 24)
		fs:SetText("|cffd8b878" .. tostring(ab[1]) .. "|r" .. ((ab[3] and ab[3] ~= "") and ("  " .. ab[3]) or ""))
		fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 12, -top); fs:Show()
		top = top + (fs:GetStringHeight() or 12) + 5
	end
	for i = na + 1, #(c.abil or {}) do c.abil[i]:Hide() end
	if na > 0 then top = top + 4 end
	local n = 0
	for _, id in ipairs(b.loot or {}) do
		if Known(id) then
			n = n + 1
			local r = LootRow(c, n)
			local name, quality = SetItem(r, id)
			local col = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
			r.name:SetText(name or ("Item " .. id)); r.name:SetTextColor(col and col.r or 1, col and col.g or 1, col and col.b or 1)
			r.name:SetWidth(w - 70)
			r:SetSize(w - 24, 24); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 12, -(top + (n - 1) * 28)); r:Show()
		end
	end
	for i = n + 1, #c.rows do c.rows[i]:Hide() end
	c.none:ClearAllPoints(); c.none:SetPoint("TOPLEFT", 12, -top)
	c.none:SetShown(n == 0)
	local h = top + (n == 0 and 18 or n * 28) + 8
	c:SetHeight(h); c:Show()
	return h
end

function J.FillOverview()
	if not (ui.body and sel) then return end
	local A = Atlas()
	local d = A.DungeonMapData[sel]
	if not d then return end
	local width = math.max(420, (ui.scroll:GetWidth() or 600) - 6)
	ui.body:SetWidth(width)
	local y, nh = 0, 0
	local quests = MyQuests(d)
	table.sort(quests, function(a, b)
		local _, _, ra = State(a); local _, _, rb = State(b)
		if ra ~= rb then return ra < rb end
		return a.level < b.level
	end)
	local done = 0
	for _, q in ipairs(quests) do if Done(q.id) then done = done + 1 end end
	nh = nh + 1
	if #quests == 0 then
		y = y + Head(nh, y, width, "QUESTS")
		if not ui.noQuests then ui.noQuests = Text(ui.body, "", 11, GREY); ui.noQuests:SetJustifyH("LEFT") end
		ui.noQuests:ClearAllPoints(); ui.noQuests:SetPoint("TOPLEFT", 0, -y)
		ui.noQuests:SetText(d.quests and "No quests here for your faction." or "This dungeon's quests aren't in the journal yet."); ui.noQuests:Show()
		y = y + 22
	else
		if ui.noQuests then ui.noQuests:Hide() end
		y = y + Head(nh, y, width, "QUESTS   |cffb8b8c0" .. #quests .. "  ·  " .. done .. " done|r")
		for i, q in ipairs(quests) do
			local r = QuestRow(i)
			y = y + FillQuestRow(r, q, y, width)
		end
	end
	for i = #quests + 1, #qrows do qrows[i]:Hide() end
	-- the bosses, two cards across
	local bosses = d.bosses or {}
	y = y + 14
	nh = nh + 1
	y = y + Head(nh, y, width, "BOSSES   |cffb8b8c0" .. #bosses .. "|r")
	local gap = 10
	local cols = width < 640 and 1 or 2
	local cw = math.floor((width - gap * (cols - 1)) / cols)
	local k = 1
	while k <= #bosses do
		local rowH = 0
		for col = 0, cols - 1 do
			local b = bosses[k + col]
			if b then
				local c = BossCard(k + col)
				rowH = math.max(rowH, FillBossCard(c, b, k + col, col * (cw + gap), y, cw))
			end
		end
		-- (cards in a row are the same height)
		for col = 0, cols - 1 do local c = bcards[k + col]; if bosses[k + col] then c:SetHeight(rowH) end end
		y = y + rowH + gap
		k = k + cols
	end
	for i = #bosses + 1, #bcards do bcards[i]:Hide() end
	for i = nh + 1, #heads do heads[i]:Hide() end
	ui.body:SetHeight(math.max(1, y))
end

-- The right side: Map ----------------------------------------------------------------------------------------------------------
local pins = {}
local function Pin(i)
	local p = pins[i]
	if p then return p end
	p = CreateFrame("Button", nil, ui.art)
	p:SetSize(34, 34); p:SetFrameLevel(ui.art:GetFrameLevel() + 5)
	local back = p:CreateTexture(nil, "BACKGROUND"); back:SetAllPoints(); back:SetTexture(ROUND); back:SetVertexColor(0.05, 0.03, 0.02, 0.9)
	p.face = p:CreateTexture(nil, "ARTWORK"); p.face:SetPoint("TOPLEFT", 3, -3); p.face:SetPoint("BOTTOMRIGHT", -3, 3)
	local m = p:CreateMaskTexture(); m:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(p.face); p.face:AddMaskTexture(m)
	p.ring = p:CreateTexture(nil, "OVERLAY"); p.ring:SetAllPoints(); p.ring:SetTexture(MEDIA .. "Ring"); p.ring:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	p:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.boss.name, 1, 0.9, 0.7)
		GameTooltip:AddLine("Click for its gear", 0.62, 0.64, 0.68); GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function() GameTooltip:Hide() end)
	p:SetScript("OnClick", function() J.SetTab("overview") end)
	pins[i] = p
	return p
end
function J.FitMap()
	local d = sel and Atlas().DungeonMapData[sel]
	if not (d and ui.mapFrame and ui.mapFrame:IsShown()) then return end
	local w, h = ui.mapFrame:GetWidth(), ui.mapFrame:GetHeight()
	if not w or not h or w <= 0 or h <= 0 then return end
	local mw, mh = d.w or 1002, d.h or 668
	local unit = math.min(w / mw, h / mh)
	ui.art:SetSize(mw * unit, mh * unit)
	ui.art:ClearAllPoints(); ui.art:SetPoint("CENTER", ui.mapFrame, "CENTER")
	if d.tiles then
		for i, t in ipairs(ui.tiles) do
			local col, row = (i - 1) % ACROSS, math.floor((i - 1) / ACROSS)
			t:SetSize(TILE * unit, TILE * unit); t:ClearAllPoints(); t:SetPoint("TOPLEFT", ui.art, "TOPLEFT", col * TILE * unit, -row * TILE * unit)
		end
	end
	for _, p in ipairs(pins) do
		if p:IsShown() then p:ClearAllPoints(); p:SetPoint("CENTER", ui.art, "TOPLEFT", p.boss.x * mw * unit, -p.boss.y * mh * unit) end
	end
end
function J.FillMap()
	local d = sel and Atlas().DungeonMapData[sel]
	if not d then return end
	for i, t in ipairs(ui.tiles) do
		if d.tiles then t:SetTexture(d.tiles[i]); t:Show() else t:Hide() end
	end
	if d.art then ui.picture:SetTexture(d.art); ui.picture:SetTexCoord(0, 1, 0, (d.h or 1) / (d.texH or d.h or 1)); ui.picture:Show() else ui.picture:Hide() end
	ui.noMap:SetShown(not (d.art or d.tiles))
	ui.credit:SetText(d.credit or ""); ui.credit:SetShown(d.credit ~= nil)
	local bosses = d.bosses or {}
	for i, b in ipairs(bosses) do
		local p = Pin(i); p.boss = b; Portrait(p.face, b.display)
		p:SetShown(b.x ~= nil and b.y ~= nil)
	end
	for i = #bosses + 1, #pins do pins[i]:Hide() end
	J.FitMap()
end

-- Tabs and the dungeon ---------------------------------------------------------------------------------------------------------
function J.SetTab(key)
	tab = key
	for k, t in pairs(ui.tabs) do
		local on = k == key
		t.text:SetTextColor(on and 0.98 or GREY[1], on and 0.95 or GREY[2], on and 0.92 or GREY[3])
		t.underline:SetShown(on)
	end
	ui.scroll:SetShown(key == "overview" and sel ~= nil)
	ui.mapFrame:SetShown(key == "map" and sel ~= nil)
	if key == "overview" then J.FillOverview() elseif key == "map" then J.FillMap() end
end

local rows = {}
function J.FillList()
	if not ui.listBody then return end
	list = Dungeons()
	local Atl = Atlas()
	for i, d in ipairs(list) do
		local r = rows[i]
		if not r then
			r = CreateFrame("Button", nil, ui.listBody); r:SetSize(LIST_W - 22, 36)
			r.back = r:CreateTexture(nil, "BACKGROUND"); r.back:SetAllPoints(); r.back:SetColorTexture(1, 1, 1, 0)
			r.mark = r:CreateTexture(nil, "BORDER"); r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:SetWidth(2); r.mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
			r.name = Text(r, "", 13); r.name:SetPoint("TOPLEFT", 12, -6); r.name:SetPoint("TOPRIGHT", -54, -6); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
			r.levels = Text(r, "", 11); r.levels:SetPoint("TOPRIGHT", -8, -7); r.levels:SetJustifyH("RIGHT")
			r.sub = Text(r, "", 10, GREY); r.sub:SetPoint("TOPLEFT", 12, -22); r.sub:SetJustifyH("LEFT")
			r:SetScript("OnEnter", function(self) if self.id ~= sel then self.back:SetColorTexture(1, 1, 1, 0.04) end end)
			r:SetScript("OnLeave", function(self) if self.id ~= sel then self.back:SetColorTexture(1, 1, 1, 0) end end)
			r:SetScript("OnClick", function(self) J.Select(self.id) end)
			rows[i] = r
		end
		r.id = d.id
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(i - 1) * 36); r:Show()
		local on = d.id == sel
		r.back:SetColorTexture(1, 1, 1, on and 0.07 or 0); r.mark:SetShown(on)
		r.name:SetText(d.name); r.name:SetTextColor(on and 1 or 0.86, on and 0.97 or 0.86, on and 0.94 or 0.88)
		r.levels:SetText(Levels(d.lo, d.hi)); r.levels:SetTextColor(Atl.LevelColour(d.lo))
		local done, total = QuestCount(d.data)
		r.sub:SetText((#(d.data.bosses or {}) .. " bosses") .. (done and ("  ·  " .. done .. " of " .. total .. " quests") or ""))
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	ui.listBody:SetHeight(math.max(1, #list * 36))
end

function J.Select(id)
	sel = id
	J.FillList()
	local d = id and Atlas().DungeonMapData[id]
	ui.empty:SetShown(d == nil)
	ui.tabs.overview:SetShown(d ~= nil); ui.tabs.map:SetShown(d ~= nil)
	ui.title:SetShown(d ~= nil); ui.sub:SetShown(d ~= nil)
	if d then
		local name, lo, hi = About(id)
		ui.title:SetText(name or "")
		local qn = #MyQuests(d)
		ui.sub:SetText((lo and lo > 0 and ("Levels " .. Levels(lo, hi) .. "  ·  ") or "") .. #(d.bosses or {}) .. " bosses  ·  " .. qn .. " quests")
		ui.scroll:SetVerticalScroll(0)
		for k in pairs(opened) do opened[k] = nil end
	end
	J.SetTab(d and tab or "overview")
end

-- Open the journal (on a dungeon, when given one).
function J.Show(id)
	J.want = id
	if Menu.Open then Menu:Open("journal") end
end
function J.Has(id) local A = Atlas(); return A and A.DungeonMapData and A.DungeonMapData[id] ~= nil end

-- The page ------------------------------------------------------------------------------------------------------------------------
local function Inside()
	if not (IsInInstance and IsInInstance()) then return end
	local id = select(8, GetInstanceInfo())
	return id and J.Has(id) and id or nil
end
function Menu:BuildJournalPage(page)
	ui.page = page
	-- the dungeons, down the left
	local left = CreateFrame("Frame", nil, page); left:SetPoint("TOPLEFT", 0, 0); left:SetPoint("BOTTOMLEFT", 0, 0); left:SetWidth(LIST_W)
	local lback = left:CreateTexture(nil, "BACKGROUND"); lback:SetAllPoints(); lback:SetColorTexture(1, 1, 1, 0.03)
	local lhead = Text(left, "DUNGEONS", 10, GREY); lhead:SetPoint("TOPLEFT", 12, -10)
	local lscroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
	lscroll:SetPoint("TOPLEFT", 0, -30); lscroll:SetPoint("BOTTOMRIGHT", -22, 4)
	ui.listBody = CreateFrame("Frame", nil, lscroll); ui.listBody:SetSize(LIST_W - 22, 1); lscroll:SetScrollChild(ui.listBody)
	-- the dungeon you picked, on the right
	local right = CreateFrame("Frame", nil, page); right:SetPoint("TOPLEFT", LIST_W + 14, 0); right:SetPoint("BOTTOMRIGHT", 0, 0)
	ui.right = right
	ui.title = Text(right, "", 20, { 0.97, 0.95, 0.92 }); ui.title:SetPoint("TOPLEFT", 2, -2); ui.title:SetJustifyH("LEFT")
	ui.sub = Text(right, "", 11, GREY); ui.sub:SetPoint("TOPLEFT", 2, -28)
	ui.empty = Text(right, "Pick a dungeon on the left for its quests, its bosses and the gear they drop.", 13, GREY)
	ui.empty:SetPoint("TOPLEFT", 4, -30); ui.empty:SetWidth(420); ui.empty:SetJustifyH("LEFT")
	ui.tabs = {}
	local x = 0
	for _, def in ipairs({ { "overview", "Quests and gear" }, { "map", "Map" } }) do
		local t = CreateFrame("Button", nil, right); t.text = Text(t, def[2], 13, GREY); t.text:SetPoint("LEFT")
		t:SetSize(t.text:GetStringWidth() + 4, 22); t:SetPoint("TOPLEFT", x, -50); x = x + t:GetWidth() + 22
		t.underline = t:CreateTexture(nil, "ARTWORK"); t.underline:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
		t.underline:SetPoint("BOTTOMLEFT", 0, -3); t.underline:SetPoint("BOTTOMRIGHT", 0, -3); t.underline:SetHeight(2)
		t:SetScript("OnClick", function() J.SetTab(def[1]) end)
		ui.tabs[def[1]] = t
	end
	local rule = right:CreateTexture(nil, "BORDER"); rule:SetColorTexture(1, 1, 1, 0.08); rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", 0, -76); rule:SetPoint("TOPRIGHT", 0, -76)
	ui.scroll = CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")
	ui.scroll:SetPoint("TOPLEFT", 0, -88); ui.scroll:SetPoint("BOTTOMRIGHT", -24, 2)
	ui.body = CreateFrame("Frame", nil, ui.scroll); ui.body:SetSize(600, 1); ui.scroll:SetScrollChild(ui.body)
	ui.scroll:SetScript("OnSizeChanged", function() if tab == "overview" and sel and page:IsShown() then J.FillOverview() end end)
	ui.mapFrame = CreateFrame("Frame", nil, right); ui.mapFrame:SetPoint("TOPLEFT", 0, -88); ui.mapFrame:SetPoint("BOTTOMRIGHT", 0, 2); ui.mapFrame:Hide()
	ui.mapFrame:SetScript("OnSizeChanged", function() J.FitMap() end)
	ui.art = CreateFrame("Frame", nil, ui.mapFrame); ui.art:SetClipsChildren(true)
	ui.tiles = {}
	for i = 1, ACROSS * DOWN do ui.tiles[i] = ui.art:CreateTexture(nil, "ARTWORK") end
	ui.picture = ui.art:CreateTexture(nil, "ARTWORK"); ui.picture:SetAllPoints()
	ui.noMap = Text(ui.mapFrame, "This dungeon has no map in the journal yet.", 12, GREY); ui.noMap:SetPoint("CENTER")
	ui.credit = Text(ui.mapFrame, "", 10, GREY); ui.credit:SetPoint("BOTTOMLEFT", ui.art, "BOTTOMLEFT", 6, 5)
	-- (item names and the quest log arrive after the page is up; one refill for a burst of them)
	local wait = false
	page:SetScript("OnEvent", function()
		if wait then return end
		wait = true
		C_Timer.After(0.2, function()
			wait = false
			if not page:IsShown() then return end
			J.FillList()
			if tab == "overview" and sel then J.FillOverview() end
		end)
	end)
	page:SetScript("OnShow", function(self)
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED"); self:RegisterEvent("QUEST_LOG_UPDATE")
		local want = J.want or sel or Inside()
		J.want = nil
		if not want then local first = Dungeons()[1]; want = first and first.id end
		C_Timer.After(0, function() if self:IsShown() then J.Select(want) end end)
	end)
	page:SetScript("OnHide", function(self) self:UnregisterEvent("GET_ITEM_INFO_RECEIVED"); self:UnregisterEvent("QUEST_LOG_UPDATE"); GameTooltip:Hide() end)
	ui.empty:Show(); ui.tabs.overview:Hide(); ui.tabs.map:Hide(); ui.title:Hide(); ui.sub:Hide()
end

SLASH_REDSQOLJOURNAL1="/rjournal"
SlashCmdList.REDSQOLJOURNAL=function() J.Show() end

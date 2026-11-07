-- The journal's data helpers only; no world-map replacement or edit-mode hooks.
local _,ns=...
local M=RedsQOL
local A={Caps={forever=M.IsForever()}}
ns.Atlas=A;M.JournalAtlas=A
function A.LevelColour(level)
 if GetQuestDifficultyColor and level then local c=GetQuestDifficultyColor(level);if c then return c.r,c.g,c.b end end
 return 1,.7,.3
end
A.PlaceData={dungeons={
 {1,0,0,false,43,"Wailing Caverns",17,24},
 {1,0,0,false,389,"Ragefire Chasm",13,18}},foreverDungeons={
 {1458,.725,.114,2999,"Ruins of Lordaeron",15,20},
 {1455,.277,.479,3065,"The Hall of Thanes",13,18}}}
function A.ShowOnMap(at,title,who)
 if not at then return end
 if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,"Blizzard_WorldMap") end
 if not WorldMapFrame then M:Say("The world map is unavailable.");return end
 if M.frame then M.frame:Hide() end
 if ShowUIPanel then ShowUIPanel(WorldMapFrame) else WorldMapFrame:Show() end
 if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(at[1]) end
 local api=_G.OpenMapAPI
 if api and api.IsStitched and api.IsStitched() and api.WorldFromMap and api.ShowWorld then
  local u,v=api.WorldFromMap(at[1],at[2],at[3])
  if u and v then api.ShowWorld(u,v) end
 end
 if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
  pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(at[1],at[2],at[3])) end)
 end
end
local function GuideText(s)
	if type(s) ~= "string" then return "" end
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", ""):gsub("%$bullet", ""):gsub("%$[%w_]+", ""):gsub("%s+", " ")
	s = s:match("^%s*(.-)%s*$") or ""
	if #s > 260 then s = s:sub(1, 257) .. "..." end
	return s
end
local function ReadGuide(encounterID)
	if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
	if not EJ_GetEncounterInfo then return nil end
	local ok, _, _, _, root = pcall(EJ_GetEncounterInfo, encounterID)
	if not ok or type(root) ~= "number" or root <= 0 then return nil end
	local get = (C_EncounterJournal and C_EncounterJournal.GetSectionInfo) or EJ_GetSectionInfo
	if not get then return nil end
	local out = {}
	local function Walk(id, depth)
		local guard = 0
		while id and id > 0 and guard < 60 and #out < 14 do
			guard = guard + 1
			local good, s = pcall(get, id)
			if not good or type(s) ~= "table" then return end
			local title = GuideText(s.title)
			if title ~= "" then out[#out + 1] = { title, (type(s.spellID) == "number" and s.spellID > 0) and s.spellID or nil, GuideText(s.description) } end
			if s.firstChildSectionID and depth < 4 then Walk(s.firstChildSectionID, depth + 1) end
			id = s.siblingSectionID
		end
	end
	Walk(root, 0)
	return #out > 0 and out or nil
end
function A.BossAbilities(b)
	if b.abilities then return b.abilities end
	if b.encounter and not b.guideTried then b.guideTried = true; b.abilities = ReadGuide(b.encounter) end
	return b.abilities or {}
end


-- QOL-owned pins on the existing Blizzard canvas. Native waypoint support is optional.
local _,ns=...
local A=ns.Atlas
local M=RedsQOL
local pins={};local watcher
local function Marker(parent)
 local b=CreateFrame("Button",nil,parent);b:SetSize(28,34);b:SetFrameLevel(parent:GetFrameLevel()+30)
 
 M.UI.StyleQuestPin(b)
 b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(self.title or "Quest pickup",1,.7,.3);GameTooltip:AddLine(self.who or "",1,1,1);GameTooltip:AddLine("Right-click to remove this pin",.7,.7,.7);GameTooltip:Show() end)
 b:SetScript("OnLeave",function() GameTooltip:Hide() end)
 b:RegisterForClicks("RightButtonUp");b:SetScript("OnClick",function(self) M.db.journalPins[self.key]=nil;self:Hide() end)
 return b
end
local function Update()
 if not WorldMapFrame then return end
 local canvas=WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() or WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
 if not canvas then return end
 local mapID=WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
 local api=_G.OpenMapAPI
 local stitched=api and api.IsStitched and api.IsStitched()
 local top=stitched and api.ArtTopLevel and api.ArtTopLevel() or 0
 local level=math.max(canvas:GetFrameLevel()+30,(tonumber(top) or 0)+10)
 local scroll=WorldMapFrame.ScrollContainer
 local scale=scroll and scroll.GetCanvasScale and scroll:GetCanvasScale() or 1
 if not scale or scale<=0 then scale=1 end
 for key,t in pairs(M.db.journalPins or {}) do
  local x,y=t.x,t.y
  local visible=t.map==mapID
  if stitched then
   visible=false
   if api.WorldFromMap and api.MapFromWorld then
    local u,v=api.WorldFromMap(t.map,t.x,t.y)
    if u and v then x,y=api.MapFromWorld(mapID,u,v);visible=x~=nil and y~=nil end
   end
  end
  local p=pins[key];if not p then p=Marker(canvas);pins[key]=p end
  if not p.mapAnchor then p.mapAnchor=CreateFrame("Frame",nil,canvas);p.mapAnchor:SetSize(1,1) end
  p.mapAnchor:SetParent(canvas);p:SetParent(p.mapAnchor)
  p.key,p.title,p.who=key,t.title,t.who
  if not InCombatLockdown() then p:SetFrameLevel(level) end
  p:SetScale(1/scale)
  if visible then
   p.mapAnchor:ClearAllPoints();p.mapAnchor:SetPoint("TOPLEFT",canvas,"TOPLEFT",x*canvas:GetWidth(),-y*canvas:GetHeight())
   p:ClearAllPoints();p:SetPoint("BOTTOM",p.mapAnchor,"TOPLEFT",0,0)
  end
  p:SetShown(visible)
 end
 for key,p in pairs(pins) do if not M.db.journalPins[key] then p:Hide() end end
end

local function EnsureWatcher()
 if WorldMapFrame and not watcher then watcher=CreateFrame("Frame","RedsQOLMapPinWatcher",WorldMapFrame);local elapsed=0;watcher:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt;if elapsed>.15 then elapsed=0;Update() end end) end
end
function A.ShowOnMap(at,title,who)
 if not at then M:Say("No pickup location has been mapped yet.");return end
 if at.dungeon then M:Initialize();M.db.journalPins={};Update();M.Journal.PinPickup(at,title,who);return end
 if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,"Blizzard_WorldMap") end
 if not WorldMapFrame then M:Say("The world map is unavailable.");return end
 M:Initialize();M.db.journalPins=M.db.journalPins or {}
 local key=at[1]..":"..string.format("%.4f:%.4f",at[2],at[3])..":"..(title or "")
 M.db.journalPins={[key]={map=at[1],x=at[2],y=at[3],title=title,who=who}}
 if M.frame then M.frame:Hide() end
 if ShowUIPanel then ShowUIPanel(WorldMapFrame) else WorldMapFrame:Show() end
 if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(at[1]) end
 local api=_G.OpenMapAPI
 if api and api.IsStitched and api.IsStitched() and api.WorldFromMap and api.ShowWorld then
  local u,v=api.WorldFromMap(at[1],at[2],at[3])
  if u and v then api.ShowWorld(u,v) end
 end
 EnsureWatcher()
 Update()
end
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN");login:RegisterEvent("ADDON_LOADED");login:SetScript("OnEvent",function(_,event,name)
 if event=="PLAYER_LOGIN" or name=="Blizzard_WorldMap" then M:Initialize();if not M.db.journalPinAnchorV2 then M.db.journalPins={};M.db.journalPinAnchorV2=true end;M.db.journalPins=M.db.journalPins or {};EnsureWatcher() end
end)

-- Top bar (Quality of life > Top bar): buttons on either side of a clock across the top of the screen, with FPS and latency under it.
-- Friends and Guild show how many are online (hover for the list); Hearthstone uses yours; Reds QOL, the dungeon journal, the trainer
-- list, the junk list, the map and your bags open those; the addon folder (your other addons' buttons) can be here too. Each button goes on the
-- left, the right, or off. Drag the bar in Red's edit mode. It follows the menu's look. Off, it costs nothing: no events, no timers.
local Menu=_G.RedsQOL
local UI=Menu.UI
local Text=UI.Text
local TB={};Menu.TopBar=TB

local HEARTH=6948
-- (the item cooldown call has moved between versions of the game)
local function HearthCooldown()
 local get=(C_Item and C_Item.GetItemCooldown) or (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
 if get then local s,d=get(HEARTH);return s or 0,d or 0 end
 return 0,0
end
local function HearthCount()
 if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(HEARTH) end
 return GetItemCount and GetItemCount(HEARTH) or 1
end
local ORDER={"friends","guild","hearth","reds","trainer","map","bags"}
local LABEL={friends="Friends",guild="Guild",hearth="Hearthstone",reds="Reds QOL",addons="Addon folder",journal="Dungeon journal",trainer="Trainer spells",junk="Junk list",map="World map",bags="Bags"}
-- the icons are flat white shapes (Media\TopBar, made by Tools\Make-TopBarIcons.ps1); they are tinted to match, lighter and red under the mouse
local MEDIA="Interface\\AddOns\\RedsQOL\\Media\\TopBar\\"
local ICON={}
for _,key in ipairs(ORDER) do ICON[key]=MEDIA..key end
local TINT,HOT={.82,.84,.88},{1,.42,.32}
TB.ORDER,TB.LABEL=ORDER,LABEL

local function Opt() return Menu:QoLSettings().topbar end
local function Look() return Menu.db and Menu.db.menuLook or "parchment" end

-- Where things show ----------------------------------------------------------------------------------------------------------------
-- Some things can be on the minimap's info bar, the top bar or chat's quick tabs. One grid on the options page: a row per thing, a
-- column per place. It reads the settings of those places (so it always says what is really on) and writes them back.
local GRID={
 {kind="clock",label="Clock",places={minimap=true,top=true}},
 {kind="system",label="FPS and latency",places={minimap=true,top=true}},
 {kind="social",label="Friends and Guild",places={top=true,chat=true}},
 {kind="addons",label="Addon folder",places={minimap=true,top=true,chat=true}},
}
local PLACES={{"minimap","Minimap"},{"top","Top bar"},{"chat","Chat"}}
function TB.PlaceGet(kind,place)
 local o=Opt();local m=Menu:MinimapSettings();local c=Menu:ChatSettings()
 local chat=c.enabled and c.quick
 local r
 if kind=="clock" then
  if place=="top" then r=o.enabled and o.showClock else r=m.enabled and m.info~="off" and m.showTime end
 elseif kind=="system" then
  if place=="top" then r=o.enabled and o.showSystem else r=m.enabled and m.info~="off" and (m.showFPS or m.showMS) end
 elseif kind=="social" then
  if place=="top" then r=o.enabled and (o.layout.friends~="off" or o.layout.guild~="off") else r=chat and (c.quickFriends or c.quickGuild) end
 elseif kind=="addons" then
  if place=="top" then r=o.enabled and o.layout.addons~="off"
  elseif place=="minimap" then r=Menu:QoLSettings().minimap.enabled
  else r=chat and c.quickAddons end
 end
 return r and true or false
end
-- (writes one place's setting, nothing else)
local function Raw(kind,place,on)
 local o=Opt();local m=Menu:MinimapSettings();local c=Menu:ChatSettings()
 on=on and true or false
 if on and place=="top" then o.enabled=true end
 local function MinimapInfo() if on then if m.info=="off" then m.info="bottom" end;m.enabled=true end end
 if kind=="clock" then
  if place=="top" then o.showClock=on else m.showTime=on;MinimapInfo() end
 elseif kind=="system" then
  if place=="top" then o.showSystem=on else m.showFPS=on;m.showMS=on;MinimapInfo() end
 elseif kind=="social" then
  if place=="top" then
   local lay=o.layout
   if on then if lay.friends=="off" then lay.friends="left" end;if lay.guild=="off" then lay.guild="left" end else lay.friends="off";lay.guild="off" end
  else c.quickFriends=on;c.quickGuild=on;if on then c.quick=true end end
 elseif kind=="addons" then
  if place=="top" then o.layout.addons=on and "right" or "off"
  elseif place=="minimap" then Menu:QoLSettings().minimap.enabled=on
  else c.quickAddons=on;if on then c.quick=true end end
 end
end
-- A thing shows in one place only: turning it on in one turns it off in the others.
function TB.PlaceSet(kind,place,on)
 on=on and true or false
 Raw(kind,place,on)
 if on then for _,g in ipairs(GRID) do if g.kind==kind then for p in pairs(g.places) do if p~=place then Raw(kind,p,false) end end end end end
 Menu:ApplyTopBar()
 if Menu.Minimap and Menu.Minimap.Changed then pcall(Menu.Minimap.Changed) end
 if Menu.Chat and Menu.Chat.Changed then pcall(Menu.Chat.Changed) end
end
-- the grid as one row of the options list (Modules\QoL.lua): headings for the places, a row of tick boxes per thing
function TB.BuildGrid(row,x,ctx)
 local W=row:GetWidth()
 local CELL=86;local first=W-3*CELL
 local center={}
 for i,p in ipairs(PLACES) do
  center[p[1]]=first+(i-1)*CELL+CELL/2
  local h=Text(row,p[2]:upper(),10,UI.MUTED);h:SetPoint("TOP",row,"TOPLEFT",center[p[1]],-8)
 end
 local boxes={}
 for r,item in ipairs(GRID) do
  local y=-30-(r-1)*30
  local label=Text(row,item.label,12);label:SetPoint("TOPLEFT",x,y-5)
  local line=row:CreateTexture(nil,"BACKGROUND");line:SetColorTexture(.5,.5,.5,.12);line:SetPoint("TOPLEFT",0,y-29);line:SetPoint("TOPRIGHT",-2,y-29);line:SetHeight(1)
  for _,p in ipairs(PLACES) do
   if item.places[p[1]] then
    local cb=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");cb:SetSize(24,24);cb:SetPoint("CENTER",row,"TOPLEFT",center[p[1]],y-14)
    cb:SetScript("OnClick",function(self) TB.PlaceSet(item.kind,p[1],self:GetChecked());ctx.Changed() end)
    boxes[#boxes+1]={cb=cb,kind=item.kind,place=p[1]}
   end
  end
 end
 return function() for _,b in ipairs(boxes) do b.cb:SetChecked(TB.PlaceGet(b.kind,b.place)) end end
end
-- numbers -------------------------------------------------------------------------------------------------------------------------
local function FriendsOnline()
 if C_FriendList and C_FriendList.GetNumOnlineFriends then return C_FriendList.GetNumOnlineFriends() or 0 end
 local n=0
 for i=1,(GetNumFriends and GetNumFriends() or 0) do local _,_,_,_,connected=GetFriendInfo(i);if connected then n=n+1 end end
 return n
end
local function GuildOnline()
 if not (IsInGuild and IsInGuild()) then return nil end
 local _,online=GetNumGuildMembers()
 return online or 0
end
local function Clock()
 local o=Opt()
 if Menu:MinimapSettings().time24 then return date("%H:%M") end   -- (one 24-hour setting for the minimap and the top bar)
 local t=date("%I:%M %p"):gsub("^0","")
 return t
end

-- the bar --------------------------------------------------------------------------------------------------------------------------
local bar
local pills,buttons={}, {}
local clockFs,sysFs
local hovered=false
local pending=false

local function Place()
 if not bar then return end
 local p=Menu.db and Menu.db.topBarPos
 bar:ClearAllPoints()
 if type(p)=="table" and p.x then bar:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y) else bar:SetPoint("TOP",UIParent,"TOP",0,-6) end
end

local function Tip(button,fn)
 button:SetScript("OnEnter",function(self)
  hovered=true
  if self.icon then self.icon:SetVertexColor(unpack(HOT)) end
  GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");fn(GameTooltip,self);GameTooltip:Show()
 end)
 button:SetScript("OnLeave",function(self) hovered=false;if self.icon then self.icon:SetVertexColor(unpack(TINT)) end;GameTooltip:Hide() end)
end

local function NewButton(key)
 local template=(key=="hearth") and "SecureActionButtonTemplate" or nil
 local b=CreateFrame("Button","RedsQOLTopBar_"..key,bar,template)
 b.key=key
 b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetAllPoints();b.icon:SetTexture(ICON[key]);b.icon:SetVertexColor(unpack(TINT))
 b.count=b:CreateFontString(nil,"OVERLAY");b.count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"");b.count:SetPoint("BOTTOMRIGHT",2,-2)
 b:RegisterForClicks("LeftButtonUp")
 if key=="hearth" then
  b:SetAttribute("type","item");b:SetAttribute("item","item:"..HEARTH)
  Tip(b,function(t) t:SetText("Hearthstone");local s,d=HearthCooldown();if s and s>0 and d>0 then t:AddLine("Ready in "..math.ceil(s+d-GetTime()).." seconds",1,.6,.3) else t:AddLine("Ready",.4,1,.4) end end)
 elseif key=="friends" then
  b:SetScript("OnClick",function() if ToggleFriendsFrame then ToggleFriendsFrame(1) end end)
  Tip(b,function(t)
   t:SetText("Friends");t:AddLine(FriendsOnline().." online",.4,1,.4)
   local shown=0
   for i=1,(C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or 0) do
    local info=C_FriendList.GetFriendInfoByIndex(i)
    if info and info.connected and shown<25 then shown=shown+1;t:AddDoubleLine(info.name..(info.level and ("  "..info.level) or ""),info.area or "",1,1,1,.7,.7,.7) end
   end
  end)
 elseif key=="guild" then
  b:SetScript("OnClick",function() if ToggleGuildFrame then ToggleGuildFrame() elseif ToggleFriendsFrame then ToggleFriendsFrame(3) end end)
  Tip(b,function(t)
   local online=GuildOnline()
   if not online then t:SetText("Guild");t:AddLine("You are not in a guild.",.7,.7,.7);return end
   t:SetText((GetGuildInfo("player") or "Guild"));t:AddLine(online.." online",.4,1,.4)
   local shown=0
   local okGuild,memberCount=pcall(GetNumGuildMembers)
   for i=1,(okGuild and memberCount or 0) do
    local name,_,_,level,_,zone,_,_,isOnline=GetGuildRosterInfo(i)
    if isOnline and shown<25 then shown=shown+1;t:AddDoubleLine((name or "?"):gsub("%-.*","").."  "..(level or ""),zone or "",1,1,1,.7,.7,.7) end
   end
  end)
 elseif key=="reds" then
  b:SetScript("OnClick",function() Menu:ToggleOptions() end);Tip(b,function(t) t:SetText("Reds QOL") end)
 elseif key=="addons" then
  b:SetScript("OnClick",function(self) if Menu.QoL and Menu.QoL.ToggleFolder then Menu.QoL.ToggleFolder(self) end end)
  Tip(b,function(t) t:SetText("Addon folder");t:AddLine("Your other addons' buttons",.8,.8,.8) end)
 elseif key=="journal" then
  b:SetScript("OnClick",function() if SlashCmdList.REDSATLAS then SlashCmdList.REDSATLAS("journal") end end);Tip(b,function(t) t:SetText("Dungeon journal") end)
 elseif key=="trainer" then
  b:SetScript("OnClick",function() if Menu.TrainerSpells then Menu.TrainerSpells.Toggle() end end);Tip(b,function(t) t:SetText("Trainer spells") end)
 elseif key=="junk" then
  b:SetScript("OnClick",function() if SlashCmdList.REDSJUNK then SlashCmdList.REDSJUNK("") end end);Tip(b,function(t) t:SetText("Junk list") end)
 elseif key=="map" then
  b:SetScript("OnClick",function() if ToggleWorldMap then ToggleWorldMap() end end);Tip(b,function(t) t:SetText("World map") end)
 elseif key=="bags" then
  b:SetScript("OnClick",function() if ToggleAllBags then ToggleAllBags() end end);Tip(b,function(t) t:SetText("Bags") end)
 end
 return b
end

local function Pill(side)
 local p=pills[side]
 if p then return p end
 p=CreateFrame("Frame",nil,bar,"BackdropTemplate");p.redsLook=Look;p:SetFrameLevel(bar:GetFrameLevel())
 UI.Box(p);pills[side]=p
 p.line=p:CreateTexture(nil,"OVERLAY");p.line:SetPoint("BOTTOMLEFT",1,1);p.line:SetPoint("BOTTOMRIGHT",-1,1);p.line:SetHeight(2)
 return p
end

local function Font(fs,size)
 fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size,Opt().outline and "OUTLINE" or "")
end

-- the panels follow the menu's look, each with a thin line of Red's red (gold-brown on parchment) along the bottom
function TB.Skin()
 for _,p in pairs(pills) do
  UI.Paper(p,Look(),Opt().bgAlpha);UI.RedrawButtons(p)
  if Look()=="parchment" then p.line:SetColorTexture(.62,.42,.2,1) else p.line:SetColorTexture(.78,.18,.12,1) end
  -- Forever Bronze: Paper dresses the panel in the bronze frame, so the red line goes
  p.line:SetShown(Look()~="bronze")
 end
end
-- lays the whole bar out again (out of combat: it holds a secure button)
local function Layout()
 if not bar then return end
 if InCombatLockdown() then pending=true;return end
 pending=false
 local o=Opt()
 local size=o.iconSize
 local gap,pad=4,6
 -- the buttons that are on, by side
 local sides={left={},right={}}
 for _,key in ipairs(ORDER) do
  local s=o.layout[key]
  -- (the addon folder holds a Reds QOL button of its own: not a second one beside it)
  if key=="reds" and o.layout.addons~="off" then s="off" end
  if s=="left" or s=="right" then
   buttons[key]=buttons[key] or NewButton(key)
   table.insert(sides[s],buttons[key])
  elseif buttons[key] then buttons[key]:Hide() end
 end
 -- clock and readout
 clockFs:SetShown(o.showClock);Font(clockFs,o.clockSize)
 sysFs:SetShown(o.showSystem);Font(sysFs,o.sysSize)
 local height=size+2*pad
 local clockW=o.showClock and math.max(60,math.ceil(clockFs:GetStringWidth()+20)) or 0
 clockFs:ClearAllPoints();clockFs:SetPoint("TOP",bar,"TOP",0,-(pad+(size-o.clockSize)/2))
 sysFs:ClearAllPoints();sysFs:SetPoint("TOP",bar,"TOP",0,-(height+2))
 local function Group(side,list)
  local p=Pill(side)
  if #list==0 then p:Hide();return 0 end
  local w=#list*size+(#list-1)*gap+2*pad
  p:SetSize(w,height);p:ClearAllPoints()
  local anchorTo=(o.showClock and clockW>0) and (side=="left" and "RIGHT" or "LEFT") or nil
  if o.showClock then
   if side=="left" then p:SetPoint("TOPRIGHT",bar,"TOP",-clockW/2-6,0) else p:SetPoint("TOPLEFT",bar,"TOP",clockW/2+6,0) end
  else
   if side=="left" then p:SetPoint("TOPRIGHT",bar,"TOP",-3,0) else p:SetPoint("TOPLEFT",bar,"TOP",3,0) end
  end
  p:Show()
  local x=pad
  for _,b in ipairs(list) do
   b:SetParent(p);b:SetSize(size,size);b:ClearAllPoints();b:SetPoint("LEFT",p,"LEFT",x,0);b:Show();x=x+size+gap
   Font(b.count,math.max(8,math.floor(size/2.4)))
  end
  return w
 end
 local lw=Group("left",sides.left)
 local rw=Group("right",sides.right)
 local total=lw+rw+(o.showClock and clockW+12 or 6)
 bar:SetSize(math.max(60,total),height+(o.showSystem and 16 or 0))
 -- (the pills follow the menu's look)
 TB.Skin()
end
TB.Layout=Layout

-- what changes every second -------------------------------------------------------------------------------------------------------
local since=0
local function Refresh()
 local o=Opt()
 if o.showClock then clockFs:SetText(Clock()) end
 if o.showSystem then
  local _,_,home,world=GetNetStats()
  sysFs:SetText(string.format("|cff9fe89f%d|r fps   |cff9fc7e8%d|r ms",math.floor(GetFramerate()+.5),world or home or 0))
 end
 local f=buttons.friends
 if f and f:IsShown() then local n=FriendsOnline();f.count:SetText(n>0 and n or "");f.count:SetTextColor(.4,1,.4) end
 local g=buttons.guild
 if g and g:IsShown() then local n=GuildOnline();g.count:SetText(n and n>0 and n or "");g.count:SetTextColor(.4,1,.4) end
 local h=buttons.hearth
 if h and h:IsShown() then
  local s,d=HearthCooldown()
  local left=(s and s>0 and d>0) and (s+d-GetTime()) or 0
  h.count:SetText(left>0 and (left>=60 and (math.ceil(left/60).."m") or math.ceil(left)) or "");h.count:SetTextColor(1,.6,.3)
  h.icon:SetAlpha(((HearthCount()==0) or left>0) and .4 or 1)
 end
 -- visibility: hidden in combat, or faded until the mouse is over it
 local alpha=1
 if o.hideInCombat and InCombatLockdown() then alpha=0
 elseif o.mouseover and not (bar:IsMouseOver() or hovered) then alpha=o.fadedAlpha end
 bar:SetAlpha(alpha)
end

local function Tick(_,elapsed)
 since=since+elapsed
 -- its drag box shows while Edit mode is open
 if bar.mover then bar.mover:SetShown(Menu.editModeActive and true or false) end
 if since<.5 then return end
 since=0
 Refresh()
end

-- building / turning on and off ---------------------------------------------------------------------------------------------------
local ev
local function Build()
 if bar then return end
 bar=CreateFrame("Frame","RedsQOLTopBar",UIParent);bar:SetFrameStrata("MEDIUM");bar:SetSize(100,40)
 clockFs=bar:CreateFontString(nil,"OVERLAY");clockFs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"");clockFs:SetTextColor(.95,.93,.88)
 sysFs=bar:CreateFontString(nil,"OVERLAY");sysFs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"");sysFs:SetTextColor(.8,.8,.8)
 -- the clock's tooltip: the date and the realm's time
 local hit=CreateFrame("Frame",nil,bar);hit:SetPoint("TOPLEFT",clockFs,-6,4);hit:SetPoint("BOTTOMRIGHT",clockFs,6,-4);hit:EnableMouse(true)
 hit:SetScript("OnEnter",function(self)
  hovered=true;GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:SetText(date("%A, %B %d"))
  local h,m=GetGameTime();GameTooltip:AddLine(string.format("Realm time: %02d:%02d",h,m),.8,.8,.8);GameTooltip:Show()
 end)
 hit:SetScript("OnLeave",function() hovered=false;GameTooltip:Hide() end)
 -- the readout's tooltip: latency
 local sysHit=CreateFrame("Frame",nil,bar);sysHit:SetPoint("TOPLEFT",sysFs,-6,3);sysHit:SetPoint("BOTTOMRIGHT",sysFs,6,-3);sysHit:EnableMouse(true)
 sysHit:SetScript("OnEnter",function(self)
  if not Opt().systemTooltip then return end
  hovered=true;GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:SetText("Connection")
  local _,_,home,world=GetNetStats();GameTooltip:AddDoubleLine("Home",(home or 0).." ms",1,1,1,.8,.8,.8);GameTooltip:AddDoubleLine("World",(world or 0).." ms",1,1,1,.8,.8,.8)
  GameTooltip:AddDoubleLine("Frame rate",math.floor(GetFramerate()+.5).." fps",1,1,1,.8,.8,.8);GameTooltip:Show()
 end)
 sysHit:SetScript("OnLeave",function() hovered=false;GameTooltip:Hide() end)
 -- its box in Red's edit mode
 local mv=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");mv:SetAllPoints(bar);mv:SetFrameStrata("DIALOG");mv:EnableMouse(true)
 UI.Box(mv,true);mv:SetBackdropColor(.24,.12,.025,.6);mv:SetBackdropBorderColor(1,.6,.15,1);mv:Hide();bar.mover=mv
 local label=Text(mv,"Top bar",11);label:SetPoint("CENTER")
 mv:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then UI.BeginDrag("topBar") end end)
 mv:SetScript("OnMouseUp",function(_,button) if button=="LeftButton" then UI.EndDrag() end end)
 Place()
 bar:SetScript("OnUpdate",Tick)
end

-- Where a thing already shows in more than one place (older settings), it stays in the first of: top bar, minimap, chat.
function TB.Exclusive()
 local changed=false
 for _,g in ipairs(GRID) do
  local kept
  for _,p in ipairs({"top","minimap","chat"}) do
   if g.places[p] and TB.PlaceGet(g.kind,p) then
    if kept then Raw(g.kind,p,false);changed=true else kept=p end
   end
  end
 end
 return changed
end
function Menu:ApplyTopBar()
 if not Menu.db then return end
 local o=Opt()
 if o.enabled and TB.Exclusive() then
  if Menu.Minimap and Menu.Minimap.Changed then pcall(Menu.Minimap.Changed) end
  if Menu.Chat and Menu.Chat.Changed then pcall(Menu.Chat.Changed) end
 end
 -- WoW Forever: the trainer list is a top bar button instead of a spellbook tab (once, the button is put on for those who had it off)
 if (select(4,GetBuildInfo()) or 0)>=16000 and not Menu.db.topbarTrainerMoved then
  Menu.db.topbarTrainerMoved=true
  if o.layout and (o.layout.trainer==nil or o.layout.trainer=="off") then o.layout.trainer="right" end
 end
 if Menu.UpdateMinimapButton then Menu:UpdateMinimapButton() end
 if not o.enabled then
  if bar then bar:Hide();bar:SetScript("OnUpdate",nil);if ev then ev:UnregisterAllEvents() end;if bar.mover then bar.mover:Hide() end end
  return
 end
 Build()
 bar:Show();bar:SetScript("OnUpdate",Tick)
 if not ev then
  ev=CreateFrame("Frame")
  ev:SetScript("OnEvent",function(_,event)
   if event=="PLAYER_REGEN_ENABLED" then if pending then Layout() end;Refresh()
   elseif event=="PLAYER_ENTERING_WORLD" then Layout();Refresh()
   else Refresh() end
  end)
 end
 for _,e in ipairs({"PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","FRIENDLIST_UPDATE","GUILD_ROSTER_UPDATE","PLAYER_ENTERING_WORLD","BAG_UPDATE_COOLDOWN"}) do pcall(ev.RegisterEvent,ev,e) end
 Layout();Refresh()
 if IsInGuild and IsInGuild() then if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end end
 if C_FriendList and C_FriendList.ShowFriends then C_FriendList.ShowFriends() end
end

-- the look follows the menu's
local prevLook=Menu.OnLookChanged
Menu.OnLookChanged=function(...)
 if prevLook then prevLook(...) end
 if bar and bar:IsShown() then TB.Skin() end
end

-- placing it in Red's edit mode
Menu.extraMovables=Menu.extraMovables or {}
Menu.extraMovables.topBar={
 frame=function() return bar and bar:IsShown() and bar or nil end,
 save=function(x,y) Menu.db.topBarPos={x=x,y=y};C_Timer.After(0,Place) end}

local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() Menu:Initialize();C_Timer.After(1,function() Menu:ApplyTopBar() end) end)

-- the options' extra controls
local build=Menu.BuildQoLPage
if build then
 function Menu:BuildQoLPage(page)
  build(self,page)
  local section=Menu.QoL and Menu.QoL.sections and Menu.QoL.sections.topbar
  if not section then return end
  local b=UI.Button(section.options,"Reset buttons",140,function()
   local o=Opt();o.layout={friends="left",guild="left",hearth="right",reds="right",addons="off",journal="off",trainer="off",junk="off",map="off",bags="off"}
   Menu:ApplyTopBar();if Menu.RefreshQoLPage then Menu:RefreshQoLPage() end
  end);b:SetHeight(24);b:SetPoint("TOPRIGHT",-42,-6)
 end
end

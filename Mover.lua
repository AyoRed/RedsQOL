-- Only Reds QOL's own displays participate. No Blizzard/Ellesmere frames or edit-mode hooks.
local M=RedsQOL
local V={unlocked=false};M.Mover=V
local displays={{key="reload",option="reload",name="Reload UI"},{key="rangeWarning",option="range",name="Attack range warning"},{key="campfire",option="campfire",name="Campfire buffs"},{key="topBar",option="topbar",name="Top bar"}}
local active={}
local function Refresh()
 M:ApplyQoL();M:ApplyTopBar();M:ApplyCampfire();M:ApplyReloadButton()
end
function V.SelectRed(key)
 for _,d in ipairs(displays) do if d.key==key and V.banner then V.banner.label:SetText("Moving: "..d.name);return end end
end
function V.Place(on)
 on=on and true or false
 if on and InCombatLockdown() then M:Say("Leave combat to move QOL displays.");return end
 M:EndBarDrag();M:Initialize();V.unlocked=on;M.editModeActive=on
 if on then
  if M.frame then M.frame:Hide() end
  Refresh();active={}
  local settings=M:QoLSettings()
  for _,d in ipairs(displays) do
   if settings[d.option].enabled then
    local f=M:MovableFrame(d.key)
    if f then active[#active+1]=f;if f.mover then f.mover:Show() end end
   end
  end
  if not V.banner then
   local b=CreateFrame("Frame","RedsQOLPlacementControls",UIParent,"BackdropTemplate");V.banner=b;b:SetSize(470,96);b:SetPoint("BOTTOM",0,140);b:SetFrameStrata("FULLSCREEN_DIALOG");M.UI.Box(b)
   local title=M.UI.Text(b,"Move Reds QOL displays",16,M.UI.GOLD);title:SetPoint("TOPLEFT",16,-12)
   b.label=M.UI.Text(b,"Drag a highlighted QOL display to place it.",12);b.label:SetPoint("TOPLEFT",16,-39)
   local done=M.UI.Button(b,"Lock position",150,function() V.Place(false) end);done:SetPoint("BOTTOMRIGHT",-14,12)
   local hint=M.UI.Text(b,"Campfire  |  Top bar  |  Range  |  Reload",11,M.UI.MUTED);hint:SetPoint("BOTTOMLEFT",16,18)
  end
  V.banner.label:SetText(#active>0 and "Drag a highlighted QOL display to place it." or "Enable a QOL display in settings to move it.");V.banner:Show()
 else
  for _,f in ipairs(active) do if f.mover then f.mover:Hide() end end;active={}
  if V.banner then V.banner:Hide() end
  M:ClosePositionPanel()
  if M.Campfire.SetPreview then M.Campfire.SetPreview(false) end
  Refresh()
 end
end
function V.Changed() if M.WindowMover then M.WindowMover.Changed() end end
function V.ResetElements()
 M:EndBarDrag();M:Initialize();M.db.reloadPos=nil;M.db.campfirePos=nil;M.db.topBarPos=nil;M:QoLSettings().range.position=nil
 Refresh();if V.unlocked then V.Place(true) end
end
function V.Spec()
 return {title="Move QOL displays",
  {type="subheader",label="Place Campfire buffs, Top Bar, Reload UI and the Attack Range warning. Enable each display in its section first.",height=52},
  {type="custom",height=44,build=function(row,x) local b=M.UI.Button(row,"Unlock & move QOL displays",280,function() M:ToggleMove() end);b:SetPoint("TOPLEFT",x,-6) end},
  {type="custom",height=44,build=function(row,x) local b=M.UI.Button(row,"Reset QOL display positions",280,V.ResetElements);b:SetPoint("TOPLEFT",x,-6) end},
  {type="subheader",label="Movers appear only while unlocked. Click Lock position when finished.",height=45},
  {type="header",label="Reload button"},{type="check",path="reload.enabled",label="Show the clickable Reload UI button"},{type="header",label="Blizzard windows (normal play)"},
  {type="check",path="mover.windows",label="Drag open windows such as spellbook and talents"},
  {type="check",path="mover.shift",label="Only drag windows while holding Shift"},
  {type="check",path="mover.wheel",label="Ctrl + mouse wheel resizes windows"},
  {type="custom",height=44,build=function(row,x) local b=M.UI.Button(row,"Reset Blizzard window positions",280,function() M.WindowMover.ResetWindows() end);b:SetPoint("TOPLEFT",x,-6) end}}
end
local ev=CreateFrame("Frame");ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent",function() if V.unlocked then V.Place(false) end end)


do
-- Move frames: drag Blizzard's own windows (character, spell book, quest log, merchant...) and place its on-screen
-- pieces (buffs, quest tracker, durability, unit frames...) where you want them. Spots are kept per profile
-- (Menu.db.qol.mover). Nothing runs on a timer or an update loop: a window gets its drag scripts once, a frame with a
-- saved spot gets one SetPoint hook that puts it back when Blizzard re-anchors it, and the blue boxes only exist while
-- the elements are unlocked. Frames are only touched out of combat (a frame other frames hang on can't move in combat).
local Menu=_G.RedsQOL
local UI=Menu.UI
local Text,Button,Box=UI.Text,UI.Button,UI.Box
local GOLD,MUTED=UI.GOLD,UI.MUTED
local Mv={tracked={},pending={},overlays={}}
Menu.WindowMover=Mv

-- Windows that open in the middle of the screen: dragged by any bare part of the window. Names this client doesn't have
-- are skipped; windows that load on demand are set up when their addon loads.
local WINDOWS={"CharacterFrame","SpellBookFrame","FriendsFrame","QuestLogFrame","TradeSkillFrame","CraftFrame","PlayerTalentFrame","TalentFrame",
 "InspectFrame","MerchantFrame","GossipFrame","QuestFrame","TradeFrame","MailFrame","BankFrame","AuctionFrame","TaxiFrame","ClassTrainerFrame",
 "PetStableFrame","TabardFrame","HelpFrame","MacroFrame","DressUpFrame","ItemTextFrame","GameMenuFrame","AddonList","KeyBindingFrame",
 "RaidParentFrame","LFGParentFrame","BattlefieldFrame","WorldStateScoreFrame","ItemSocketingFrame","TimeManagerFrame","CalendarFrame","ChannelFrame",
 -- WoW Forever's windows
 "PlayerSpellsFrame","ProfessionsFrame","ProfessionsBookFrame","AuctionHouseFrame","CommunitiesFrame","PVEFrame","CollectionsJournal","EncounterJournal","ClassTalentFrame","ChatConfigFrame","ArtifactFrame"}
-- On-screen pieces: {frame name, what it's called on the blue box}. Only the ones this client has get a box.
local MIN_SCALE,MAX_SCALE=.5,2

local function Cfg()
 local q=Menu.db and Menu.db.qol;local c=q and q.mover
 if c and c.win and c.hud then return c end
 return Menu:QoLSettings().mover  -- (a profile that predates Move frames: its defaults are filled in)
end
local function Ratio(frame) return frame:GetEffectiveScale()/UIParent:GetEffectiveScale() end

-- Where a frame sat before it was first moved, so a reset can put it back.
local function Snap(t)
 if t.orig then return end
 local f=t.frame;local n=f:GetNumPoints()
 if n==0 then return end
 local orig={scale=f:GetScale(),points={}}
 for i=1,n do orig.points[i]={f:GetPoint(i)} end
 t.orig=orig
end

-- Puts a tracked frame on its saved spot (top left corner, in screen units, so scale changes keep it in place).
local applying=false
local function Apply(name)
 local t=Mv.tracked[name];local c=Cfg();if not t or not c then return end
 local spot=c[t.store][name];if not spot then return end
 if t.store=="win" and not c.windows then return end
 -- (only a frame the game protects is held back until combat ends. The cooldown manager, buffs, quest tracker and the like are not protected:
 -- when the game moves one of them as a fight starts, its spot goes straight back instead of staying wrong until the fight is over)
 if InCombatLockdown() then
  local locked=true
  local ok,protected=pcall(function() return t.frame.IsProtected and t.frame:IsProtected() end)
  if ok and not protected then locked=false end
  if locked then Mv.pending[name]=true;return end
 end
 applying=true
 if spot.s then t.frame:SetScale(spot.s) end
 local r=Ratio(t.frame)
 -- (a frame the game's Edit Mode owns has its plain C methods kept as ClearAllPointsBase / SetPointBase: the ones the game itself marks as "moved"
 -- would set off its layout passes again and again; the plain ones just move it)
 local clear=t.frame.ClearAllPointsBase or t.frame.ClearAllPoints
 local setp=t.frame.SetPointBase or t.frame.SetPoint
 clear(t.frame)
 -- Held by the corner Blizzard anchors it from (Save): a frame that grows from that corner, like the buffs from their right edge,
 -- keeps that edge where it was put however many buffs come and go. Spots saved before this are held by their top left.
 if spot.p and spot.px then setp(t.frame,spot.p,UIParent,"BOTTOMLEFT",spot.px/r,spot.py/r)
 else setp(t.frame,"TOPLEFT",UIParent,"BOTTOMLEFT",spot.x/r,spot.y/r) end
 applying=false
end
-- Blizzard re-anchors some frames whenever the screen layout changes: put a moved frame back right after.
local function Hook(name)
 local t=Mv.tracked[name];if t.hooked then return end
 t.hooked=true
 -- (the game also places some frames without a SetPoint an addon can see: its own layout pass when the screen layout changes, a frame shown
 -- again, the Edit Mode anchor call. Straight after any of those the spot goes back on, once, a moment later when the game has finished)
 local pendingFix=false
 local function Later()
  if pendingFix then return end;pendingFix=true
  C_Timer.After(0,function() pendingFix=false;if applying then return end;local c=Cfg();if c and c[t.store][name] and not (Menu.editModeActive and not Menu.placing) then Apply(name) end end)
 end
 if t.frame.HookScript then pcall(t.frame.HookScript,t.frame,"OnShow",Later) end
 if t.frame.ApplySystemAnchor then pcall(hooksecurefunc,t.frame,"ApplySystemAnchor",Later) end
 if t.frame.UpdateSystemSettingsFrame then pcall(hooksecurefunc,t.frame,"UpdateSystemSettingsFrame",Later) end
 if t.frame.BreakFrameSnap then pcall(hooksecurefunc,t.frame,"BreakFrameSnap",Later) end
 if _G.UIParent_ManageFramePositions and not Mv.manageHooked then
  Mv.manageHooked=true;Mv.laters={}
  hooksecurefunc("UIParent_ManageFramePositions",function() for _,fn in pairs(Mv.laters) do fn() end end)
 end
 if Mv.laters then Mv.laters[name]=Later end
 hooksecurefunc(t.frame,"SetPoint",function()
  if applying then return end
  -- Blizzard's own Edit Mode is open: it places things itself, and Red's spots go back on when it closes (Mv.ReapplyAll).
  if Menu.editModeActive and not Menu.placing then return end
  -- Put back a moment later, never inside the game's own call: addon code running in the middle of the game's layout pass is what the game blocks.
  Later()
 end)
end
local function Save(name,x,y,s)
 local c=Cfg();local t=Mv.tracked[name]
 local spot=c[t.store][name];if not spot then spot={};c[t.store][name]=spot end
 spot.x,spot.y=x,y
 -- The corner it is held by: the one Blizzard anchors it from (its first point before it was moved), at the frame's size now.
 local f=t.frame;local p=t.orig and t.orig.points[1] and t.orig.points[1][1] or "TOPLEFT"
 local k=(s and f:GetScale()>0) and s/f:GetScale() or 1
 local r=Ratio(f);local w,h=(f:GetWidth() or 0)*r*k,(f:GetHeight() or 0)*r*k
 local fx=p:find("RIGHT") and 1 or p:find("LEFT") and 0 or .5
 local fy=p:find("TOP") and 0 or p:find("BOTTOM") and 1 or .5
 spot.p,spot.px,spot.py=p,x+fx*w,y-fy*h
 if s then spot.s=s end
end
-- The frame's current top left corner in screen units, saved as its spot (and its scale, when given).
local function SaveCurrent(name,scale)
 local t=Mv.tracked[name];local f=t.frame;local l,top=f:GetLeft(),f:GetTop()
 if not l or not top then return false end
 local r=Ratio(f);Save(name,l*r,top*r,scale);Hook(name);Apply(name)
 return true
end

-- Windows ------------------------------------------------------------------------------------------------------
local function SetupWindow(name)
 local frame=_G[name]
 if Mv.tracked[name] or type(frame)~="table" or not frame.RegisterForDrag or not frame.HookScript then return end
 if InCombatLockdown() then Mv.needSetup=true;return end
 local t={frame=frame,store="win"};Mv.tracked[name]=t
 frame:SetMovable(true);frame:SetClampedToScreen(true)
 if not frame:IsMouseEnabled() then frame:EnableMouse(true) end
 frame:RegisterForDrag("LeftButton")
 frame:HookScript("OnDragStart",function()
  local c=Cfg()
  if not c or not c.windows or Menu.editModeActive or InCombatLockdown() or (c.shift and not IsShiftKeyDown()) then return end
  Snap(t);frame:StartMoving();t.moving=true
 end)
 frame:HookScript("OnDragStop",function()
  if not t.moving then return end
  t.moving=false
  frame:StopMovingOrSizing()
  -- Moving marks a frame as the player's own placement, which the client would save and restore itself.
  pcall(frame.SetUserPlaced,frame,false)
  SaveCurrent(name)
 end)
 -- WoW Forever's windows are covered by their own title bar and frame art, which take the mouse before the window itself does: those
 -- parts pass the drag on to the window.
 -- (only the title bar: the frame art and the inner panel sit over the window's own buttons on some windows, and taking the mouse there stopped the clicks)
 for _,key in ipairs({"TitleContainer","TitleBar"}) do
  local part=frame[key]
  if type(part)=="table" and part~=frame and part.RegisterForDrag and part.HookScript then
   pcall(function()
    part:EnableMouse(true);part:RegisterForDrag("LeftButton")
    part:HookScript("OnDragStart",function()
     local c=Cfg()
     if not c or not c.windows or Menu.editModeActive or InCombatLockdown() or (c.shift and not IsShiftKeyDown()) then return end
     Snap(t);frame:StartMoving();t.moving=true
    end)
    part:HookScript("OnDragStop",function()
     if not t.moving then return end
     t.moving=false
     frame:StopMovingOrSizing()
     pcall(frame.SetUserPlaced,frame,false)
     SaveCurrent(name)
    end)
   end)
  end
 end
 frame:EnableMouseWheel(true)
 frame:HookScript("OnMouseWheel",function(_,delta)
  local c=Cfg()
  if not c or not c.windows or not c.wheel or not IsControlKeyDown() or InCombatLockdown() then return end
  Snap(t)
  SaveCurrent(name,math.max(.6,math.min(1.6,math.floor((frame:GetScale()+delta*.05)*20+.5)/20)))
 end)
 local c=Cfg()
 if c and c.win[name] then Snap(t);Hook(name);Apply(name) end
end


function Mv.ResetWindows()
 if InCombatLockdown() then Menu:Say("Leave combat to reset windows.");return end
 local c=Cfg()
 for name,t in pairs(Mv.tracked) do
  c.win[name]=nil
  if t.orig then applying=true;t.frame:ClearAllPoints();for _,p in ipairs(t.orig.points) do t.frame:SetPoint(unpack(p)) end;t.frame:SetScale(t.orig.scale);applying=false end
 end
end
function Mv.Changed()
 local c=Cfg();if InCombatLockdown() then return end
 for name,t in pairs(Mv.tracked) do
  if c.windows then Apply(name)
  elseif t.orig then applying=true;t.frame:ClearAllPoints();for _,p in ipairs(t.orig.points) do t.frame:SetPoint(unpack(p)) end;t.frame:SetScale(t.orig.scale);applying=false end
 end
end
local function SetupAll()
 if InCombatLockdown() then Mv.needSetup=true;return end
 Mv.needSetup=false
 for _,name in ipairs(WINDOWS) do SetupWindow(name) end
end
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","ADDON_LOADED","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,event)
 if event=="PLAYER_LOGIN" then Menu:Initialize();Menu:QoLSettings();Mv.ready=true end
 if Mv.ready then SetupAll() end
 if event=="PLAYER_REGEN_ENABLED" then for name in pairs(Mv.pending) do Mv.pending[name]=nil;Apply(name) end end
end)
end
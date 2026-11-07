-- Quality of life page. First feature: an attack range warning in the middle of the screen.
-- WoW gives addons no "can I hit this" answer, so range comes from the abilities on your action bars
-- (IsActionInRange). Facing and line of sight can only be known once you try, from the game's own error messages.
local Menu=_G.RedsQOL
local UI=Menu.UI
local Text,Box=UI.Text,UI.Box
local GOLD,MUTED=UI.GOLD,UI.MUTED
local FONT=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local QoL={};Menu.QoL=QoL

-- range.mode: "auto" (melee for melee classes and Druid cat/bear, otherwise any attack), "melee" or "any".
local DEFAULTS={reload={enabled=true},
 -- Move frames (Modules\Mover.lua): windows = Blizzard's windows can be dragged (shift = only with Shift held, wheel =
 -- Ctrl + wheel resizes); win / hud = the saved spots {x,y,s} by frame name.
 mover={windows=true,shift=false,wheel=true,win={},hud={},grid=true,gridSize=40,snap=false},
 range={enabled=false,onlyCombat=false,mode="auto",size=26,color={1,.25,.2},errors=true,unlocked=false},
 -- A colored ring that follows the mouse cursor.
 -- thickness 1-6 picks Media\CursorRing1..6 (thin to bold).
 cursor={enabled=false,size=56,thickness=3,color={1,.82,.2},alpha=.85,onlyCombat=false,classColor=false},
 -- A trail behind the cursor (Modules\Cursor.lua). style: sparkle/fairy/ribbon/neon/comet/stars/hearts/embers;
 -- colorMode: custom/two (color to color2 as it fades)/rainbow/class; length in seconds; density and spread scale
 -- how many particles and how far they scatter; glow draws them additive (bright).
 trail={enabled=false,style="sparkle",colorMode="rainbow",color={1,.82,.2},color2={.55,.3,1},size=14,alpha=.9,length=.6,
  density=1,spread=1,glow=true,onlyCombat=false},
 -- One folder button on the minimap holding other addons' minimap buttons. keep: names left on the minimap.
 -- style "button" (round button on the minimap's edge) or "tab" (the Addons tab: Red's crest in a square button
 -- beside the map at tabSpot, a corner, or "custom" where it was dragged: tabPos {x,y} from the minimap's center).
 -- tabUnlocked lets the tab be dragged.
 minimap={enabled=false,angle=225,columns=4,closeOnClick=true,includeReds=false,keep={},tabShape="square",tabSpot="topleft",tabUnlocked=false},
 -- Loot sparkles (Modules\LootSparkles.lua, WoW Forever): quest items, herbs, ore veins, corpses that still hold loot.
 sparkles={quest=true,herbs=true,ore=true,corpse=true,questObjects=true},
 -- Trainer spells (Modules\TrainerSpells.lua): remember what class trainers teach; notify = a chat note after a level up.
 trainer={tab=true,notify=true},
 -- Flight timer (Modules\FlightTimer.lua): a route bar with the time left while you ride a flight path.
 flight={enabled=true,showStops=true,showTotal=false,earlyExit=true},
 -- Spell ranks (Modules\Uprank.lua), Quest helper (Modules\QuestHelper.lua), Junk & bags (Modules\Junk.lua)
 uprank={enabled=true,announce=true},
 -- Campfire reminder (Modules\Campfire.lua, WoW Forever): a camp nearby, your camp bonuses and when one runs out.
 gear={ilvlBags=true,ilvlChar=true,durability=true,durabilityAt=25,upgrade=true},
 totemBar={enabled=true,size=38,space=4,vertical=false,showCall=true,showRecall=true,colorBorders=true,borderSize=2,timer=true,timerSize=12,choice={}},
 campfire={enabled=true,alertNearby=true,warnEnding=true,warnAt=60,sound=false,timer=true,iconSize=90,textSize=16,onlyLow=false,lowMinutes=5,soundKey="warn",ringColor={.2,.62,.38}},
 -- Top bar (Modules\TopBar.lua): each button goes "left", "right" or "off".
 topbar={enabled=false,showClock=true,use24h=false,showSystem=true,systemTooltip=true,iconSize=22,clockSize=16,sysSize=10,bgAlpha=.85,outline=false,
  hideInCombat=false,mouseover=false,fadedAlpha=.2,
  layout={friends="left",guild="left",hearth="right",reds="right",addons="off",journal="off",trainer="right",junk="off",map="off",bags="off"}},
 quests={rewardMarker=true,automation=true,stepAside=true,pauseShift=true,skipTrivial=true,lootChat=true,lootParty=true,doneSound=true,doneChat=true,doneSoundKey="ding"},
 junk={autoSell=true,warnBags=true,warnAt=4,marked={},sound=false,soundKey="warn"},
}
local DEFAULT_POSITION={0,120}
local ERROR_SECONDS=2
local THROTTLE=.15

local function Merge(target,defaults)
 for k,v in pairs(defaults) do
  if type(v)=="table" and v[1]==nil then
   if type(target[k])~="table" then target[k]={} end;Merge(target[k],v)
  elseif target[k]==nil or type(target[k])~=type(v) then target[k]=type(v)=="table" and {unpack(v)} or v end
 end
end
function Menu:QoLSettings()
 self:Initialize()
 if type(self.db.qol)~="table" then self.db.qol={} end
 local s=self.db.qol;Merge(s,DEFAULTS)
 -- Settings left over from the removed Not attacking warning.
 local r=s.range;r.idle,r.idleColor,r.idleEdges,r.idleSound=nil,nil,nil,nil
 -- Settings left over from the removed cursor look (custom shapes, outline, glow).
 s.pointer=nil
 -- The worded Addons tab and the "Red's logo" button became one Addons tab: the logo button, movable.
 local m=s.minimap
 if m.style=="logo" then m.style="tab" end
 if m.logoCorner then
  if ({topleft=1,topright=1,bottomleft=1,bottomright=1})[m.logoCorner] then m.tabSpot=m.logoCorner end
  m.logoCorner=nil
 elseif m.tabSide=="left" or m.tabSide=="right" then m.tabSpot="top"..m.tabSide end
 m.tabSide=nil
 if not ({topleft=1,topright=1,bottomleft=1,bottomright=1,custom=1})[m.tabSpot] then m.tabSpot="topleft" end
 if m.tabSpot=="custom" and not (type(m.tabPos)=="table" and type(m.tabPos[1])=="number" and type(m.tabPos[2])=="number") then m.tabSpot="topleft" end
 -- The round folder button is gone: the Addons tab is the folder now, in a square or round shape.
 m.style=nil;if m.tabShape~="round" then m.tabShape="square" end
 return s
end

-- Range ----------------------------------------------------------------------------------------------------
local MELEE_CLASSES={WARRIOR=true,ROGUE=true,PALADIN=true}
local function WantMelee(mode)
 if mode=="melee" then return true elseif mode=="any" then return false end
 local _,class=UnitClass("player")
 if MELEE_CLASSES[class] then return true end
 -- Druids in Cat (energy) or Bear (rage) Form fight in melee.
 return class=="DRUID" and UnitPowerType("player")~=0
end
-- Melee abilities have no range of their own (max range 0), Attack included.
local function SpellMaxRange(id)
 if C_Spell and C_Spell.GetSpellInfo then local info=C_Spell.GetSpellInfo(id);return info and info.maxRange end
 if GetSpellInfo then local _,_,_,_,_,maxRange=GetSpellInfo(id);return maxRange end
end
local function IsMeleeSlot(slot)
 local kind,id=GetActionInfo(slot)
 if kind~="spell" or not id then return false end
 local maxRange=SpellMaxRange(id)
 return maxRange~=nil and maxRange<=0
end
-- true: something on your bars reaches the target; false: nothing does; nil: no bar ability can tell.
local function InRange(melee)
 local checked=false
 for slot=1,120 do
  if HasAction(slot) and (not melee or IsMeleeSlot(slot)) then
   local result=IsActionInRange(slot)
   if result~=nil then
    checked=true
    if result==true or result==1 then return true end
   end
  end
 end
 if checked then return false end
 -- Nothing on the bars to ask: melee falls back to the close interact distance.
 if melee and CheckInteractDistance then return CheckInteractDistance("target",3) and true or false end
 return nil
end

-- Game errors that mean the target can't be hit right now; shown briefly after they happen.
local ERRORS={}
local function MapError(key,text) if _G[key] then ERRORS[_G[key]]=text end end
MapError("ERR_BADATTACKFACING","Facing the wrong way")
MapError("SPELL_FAILED_UNIT_NOT_INFRONT","Facing the wrong way")
MapError("ERR_BADATTACKPOS","Out of range")
MapError("ERR_OUT_OF_RANGE","Out of range")
MapError("SPELL_FAILED_OUT_OF_RANGE","Out of range")
MapError("SPELL_FAILED_TOO_CLOSE","Too close")
MapError("SPELL_FAILED_LINE_OF_SIGHT","Not in line of sight")
MapError("SPELL_FAILED_NOT_BEHIND","Get behind the target")
MapError("ERR_INVALID_ATTACK_TARGET","Can't attack target")
MapError("SPELL_FAILED_BAD_TARGETS","Can't attack target")

-- The message for right now, or nil for none.
local errorText,errorUntil
local function Evaluate(r)
 if errorText and GetTime()<errorUntil then return errorText end
 errorText=nil
 if not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsDeadOrGhost("player") then return end
 if r.onlyCombat and not UnitAffectingCombat("player") then return end
 if not UnitCanAttack("player","target") then
  -- Friendly targets are fine (healing, talking); only an enemy you can't attack gets a warning.
  if UnitIsEnemy("player","target") then return "Can't attack target" end
  return
 end
 if InRange(WantMelee(r.mode))==false then return "Out of range" end
end

-- Warning frame --------------------------------------------------------------------------------------------
local function Sampling(r) return Menu.editModeActive or r.unlocked end
local function StyleWarning(frame,r)
 frame.text:SetFont(FONT,r.size,"OUTLINE");frame.text:SetTextColor(unpack(r.color))
 frame:SetSize(math.max(120,r.size*12),r.size+12)
end
local elapsedSince=0
local function OnUpdate(frame,elapsed)
 elapsedSince=elapsedSince+elapsed
 if elapsedSince<THROTTLE then return end
 elapsedSince=0
 local r=Menu.db.qol.range
 local message=Evaluate(r)
 if message then frame.text:SetText(message);frame.text:SetAlpha(1)
 elseif Sampling(r) then frame.text:SetText("Out of range");frame.text:SetAlpha(.6)
 else frame.text:SetText("") end
end
local function Place(frame,position)
 frame:ClearAllPoints()
 local x,y=DEFAULT_POSITION[1],DEFAULT_POSITION[2]
 if type(position)=="table" and type(position.x)=="number" and type(position.y)=="number" then x,y=position.x,position.y end
 frame:SetPoint("CENTER",UIParent,"CENTER",x,y)
end
function QoL.PositionTarget()
 return {key="rangeWarning",title="Red's range warning",
  get=function() local frame=Menu:MovableFrame("rangeWarning");if frame then return UI.CenterOffset(frame) end;return 0,0 end,
  set=function(x,y) Menu:SaveBarPosition("rangeWarning",x,y) end,
  reset=function() Menu:QoLSettings().range.position=nil;Menu:ApplyQoL();Menu:RefreshPositionPanel() end}
end
Menu.extraMovables.rangeWarning={
 frame=function() local f=QoL.warning;return f and f.active and f or nil end,
 save=function(x,y) Menu:QoLSettings().range.position={x=x,y=y} end}
local function CreateWarning()
 local f=CreateFrame("Frame",nil,UIParent);f:SetFrameStrata("HIGH");f:SetClampedToScreen(true)
 f.text=f:CreateFontString(nil,"OVERLAY");f.text:SetFont(FONT,26,"OUTLINE");f.text:SetPoint("CENTER")
 f:SetScript("OnUpdate",OnUpdate)
 local mover=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");f.mover=mover
 mover:SetFrameStrata("DIALOG");mover:EnableMouse(true);mover:SetAllPoints(f);Box(mover,true);mover:Hide()
 mover.label=Text(mover,"",10);mover.label:SetPoint("BOTTOM",mover,"TOP",0,2)
 mover:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then UI.BeginDrag("rangeWarning") end end)
 mover:SetScript("OnMouseUp",function(_,button)
  if button=="LeftButton" then UI.EndDrag()
  elseif button=="RightButton" then Menu:OpenPositionPanel(QoL.PositionTarget()) end
 end)
 return f
end
local function UpdateMover(f,r)
 if InCombatLockdown() then return end
 local mover=f.mover
 if Menu.editModeActive then mover:SetBackdropColor(.24,.12,.025,.6);mover:SetBackdropBorderColor(1,.6,.15,1);mover.label:SetText("Red's range warning")
 else Box(mover,true);mover:SetBackdropColor(.16,.035,.025,.4);mover.label:SetText("Range warning") end
 if f.active and Sampling(r) then RegisterStateDriver(mover,"visibility","[combat] hide; show")
 else
  UnregisterStateDriver(mover,"visibility");mover:Hide()
  if Menu.drag and Menu.drag.index=="rangeWarning" then Menu:EndBarDrag(true) end
  Menu:ClosePositionPanel("rangeWarning")
 end
end
function Menu:ApplyQoL()
 local r=self:QoLSettings().range;local f=QoL.warning
 if r.enabled then
  if not f then f=CreateWarning();QoL.warning=f end
  f.active=true;StyleWarning(f,r);Place(f,r.position);f:Show();UpdateMover(f,r)
 elseif f and f.active then f.active=false;f:Hide();UpdateMover(f,r) end
end

-- Cursor ring ------------------------------------------------------------------------------------------------
-- Follows the mouse every frame. While the mouse steers the camera the cursor stays put (just hidden), so the
-- ring stays where it is and shows where the cursor will come back.
local function RingTexture(thickness)
 return "Interface\\AddOns\\RedsQOL\\Media\\CursorRing"..math.max(1,math.min(6,math.floor((thickness or 3)+.5)))
end
QoL.RingTexture=RingTexture
local function CursorOnUpdate(ring)
 local c=Menu.db.qol.cursor
 local hidden=c.onlyCombat and not UnitAffectingCombat("player")
 ring.texture:SetShown(not hidden)
 if hidden then return end
 local scale=ring:GetEffectiveScale();local x,y=GetCursorPosition()
 ring:ClearAllPoints();ring:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale,y/scale)
end
function Menu:ApplyCursorRing()
 local c=self:QoLSettings().cursor;local ring=QoL.cursorRing
 if c.enabled then
  if not ring then
   ring=CreateFrame("Frame",nil,UIParent);ring:SetFrameStrata("TOOLTIP");ring:EnableMouse(false);QoL.cursorRing=ring
   -- (it follows the cursor, so anything that lets it take the mouse stops every click under it: mouse off every way the game has, and no area to hit at all)
   if ring.SetMouseClickEnabled then pcall(ring.SetMouseClickEnabled,ring,false) end
   if ring.SetMouseMotionEnabled then pcall(ring.SetMouseMotionEnabled,ring,false) end
   pcall(ring.SetHitRectInsets,ring,10000,10000,10000,10000)
   ring.texture=ring:CreateTexture(nil,"OVERLAY");ring.texture:SetAllPoints()
   -- (it sits under the cursor: where textures can take the mouse, it never does)
   local t=ring.texture
   if t.EnableMouse then t:EnableMouse(false) end
   if t.SetMouseClickEnabled then t:SetMouseClickEnabled(false) end
   if t.SetMouseMotionEnabled then t:SetMouseMotionEnabled(false) end
   ring:SetScript("OnUpdate",CursorOnUpdate)
  end
  -- (Use my class color: the class's own color, as on the class's name everywhere)
  local r,g,b=c.color[1],c.color[2],c.color[3]
  if c.classColor then
   local _,class=UnitClass("player");local cc=class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
   if cc then r,g,b=cc.r,cc.g,cc.b end
  end
  ring.texture:SetTexture(RingTexture(c.thickness));ring:SetSize(c.size,c.size);ring.texture:SetVertexColor(r,g,b,c.alpha);ring:Show()
 elseif ring then ring:Hide() end
end


local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","UI_ERROR_MESSAGE","PLAYER_TARGET_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,messageType,message)
 if event=="PLAYER_LOGIN" then Menu:ApplyQoL();Menu:ApplyCursorRing()
 elseif event=="PLAYER_TARGET_CHANGED" then errorText=nil
 else local text=ERRORS[message] or ERRORS[messageType];local r=Menu.db and Menu.db.qol and Menu.db.qol.range
  if text and r and r.enabled and r.errors then errorText,errorUntil=text,GetTime()+ERROR_SECONDS end
 end
end)
function QoL.Changed()
 Menu:ApplyReloadButton();Menu:ApplyQoL();Menu:ApplyCursorRing();Menu:ApplyCursorFX();Menu:ApplySparkles();Menu:ApplyTopBar();Menu:ApplyCampfire()
 if Menu.Mover then Menu.Mover.Changed() end
end
-- Loot sparkles (WoW Forever): quest items sparkle again, and herbs, ore veins and corpses that still hold loot glint as you
-- walk up to them. Quality of life > Loot sparkles. Written for Reds QOL from how the game itself works:
--  * the quest item sparkle is the game's own, shown when its outline mode is off and outlineModeShowLootEffectWhenDisabled is on
--  * the rest hangs on Blizzard's soft targeting: the nearest thing you could interact with is the "softinteract" unit, and the game
--    can give it a nameplate, which the glints are drawn on. Nothing runs unless a switch is on, and nothing on Classic Era.
local Menu=_G.RedsQOL
local LS={};Menu.LootSparkles=LS

local SOFT="softinteract"
-- the game's own container/loot sparkle picture (file 219371, world\skillactivated\containers\sparkle), /rsparkle shows it on screen
local function Picture() return Menu.db and Menu.db.sparkleTexture or 219371 end
local GOLD,GREY={1,.88,.52},{.62,.62,.62}
local GLINTS,SPREAD,SIZE,DROP=7,44,30,-45
local POLL=.12

-- the game's quest item sparkle
local WANTED={outlineModeShowLootEffectWhenDisabled="1",graphicsOutlineMode="0",OutlineEngineMode="0",raidGraphicsOutlineMode="0",RAIDOutlineEngineMode="0"}
local UNWANTED={outlineModeShowLootEffectWhenDisabled="0",graphicsOutlineMode="2",OutlineEngineMode="2",raidGraphicsOutlineMode="2",RAIDOutlineEngineMode="2"}
-- soft targeting; the values it had are kept and put back when every switch is off
local SOFT_CVARS={SoftTargetInteract=3,SoftTargetInteractRange=60,SoftTargetInteractArc=2,SoftTargetInteractOnlyInRange=0,
 SoftTargetIconInteract=1,SoftTargetIconGameObject=1,SoftTargetLowPriorityIcons=1}

local function S() return Menu:QoLSettings().sparkles end
local function Secret(v) return issecretvalue~=nil and issecretvalue(v) end
local function Call(f,...)
 if not f then return nil end
 local ok,r=pcall(f,...)
 if not ok or Secret(r) then return nil end
 return r
end
local function SetCVar(name,value)
 local ok,cur=pcall(C_CVar.GetCVar,name)
 value=tostring(value)
 if ok and cur~=nil and cur~=value then pcall(C_CVar.SetCVar,name,value) end
end
-- (same test as Atlas\Core.lua: Classic Era is build 11509, Forever is 16000 and up. Era gives no nameplate to world objects,
-- so there is nothing to hang the glints on there.)
local FOREVER=(select(4,GetBuildInfo()) or 0)>=16000
local function Supported()
 if not (FOREVER and C_CVar and UnitIsGameObject) then return false end
 local ok,v=pcall(C_CVar.GetCVar,"SoftTargetInteract")
 return ok and v~=nil
end
local function AnyTarget() local s=S();return s.ore or s.herbs or s.corpse or s.questObjects end

-- Quest item sparkle -----------------------------------------------------------------------------------------------------
local applying,pending=false,false
local function SetMany(list)
 applying=true
 for name,value in pairs(list) do SetCVar(name,value) end
 applying=false
end
local function ApplyQuestItems()
 if not Supported() then return end
 if InCombatLockdown() then pending=true;return end
 if S().quest then SetMany(WANTED) elseif LS.questWasOn then SetMany(UNWANTED) end
 LS.questWasOn=S().quest
end

-- Soft targeting ---------------------------------------------------------------------------------------------------------
local gate,saved
local function SetGate(open)
 if gate==open or InCombatLockdown() then return end
 gate=open;SetCVar("SoftTargetNameplateInteract",open and 1 or 0)
end
local function ApplySoft()
 if not Supported() or InCombatLockdown() then if Supported() then pending=true end;return end
 local s=Menu.db.sparkleSaved
 if AnyTarget() then
  if not s then
   s={};Menu.db.sparkleSaved=s
   for name in pairs(SOFT_CVARS) do s[name]=C_CVar.GetCVar(name) or false end
   s.SoftTargetNameplateInteract=C_CVar.GetCVar("SoftTargetNameplateInteract") or false
  end
  for name,value in pairs(SOFT_CVARS) do SetCVar(name,value) end
  gate=nil
 elseif s then
  for name,value in pairs(s) do if value~=false then SetCVar(name,value) end end
  Menu.db.sparkleSaved=nil;gate=nil
 end
end

-- what is it? the cursor the game would show over it says: mining, herbs, or something else
local probe=UIParent:CreateTexture(nil,"BACKGROUND");probe:Hide()
local function Kind(unit)
 if not Call(SetUnitCursorTexture,probe,unit,nil,true) then return nil end
 local tex=probe:GetTexture();local atlas=probe.GetAtlas and probe:GetAtlas()
 local name=(type(tex)=="string" and not Secret(tex) and tex or type(atlas)=="string" and not Secret(atlas) and atlas or ""):lower()
 local blocked=name:find("unable",1,true)~=nil
 if name:find("gather",1,true) then return "herbs",blocked end
 if name:find("mine",1,true) then return "ore",blocked end
 return nil,blocked
end
-- Whether you have learned the gathering profession for what is there (every rank's spell counts). A herb or an ore vein only sparkles for someone who can
-- gather it; one whose level is above your skill is greyed (the cursor says so, "blocked"), as before.
local GATHER_SPELLS={herbs={2366,2368,3570,11993},ore={2575,2576,3564,10248}}
local function Knows(kind)
 local list=GATHER_SPELLS[kind];if not list then return true end
 local known=false;local usable=false
 for _,id in ipairs(list) do
  if IsPlayerSpell then usable=true;if Call(IsPlayerSpell,id)==true then known=true;break end
  elseif IsSpellKnown then usable=true;if Call(IsSpellKnown,id)==true then known=true;break end end
 end
 return known,usable
end
-- Quest objects (a Cactus Apple for "Cactus Apple Surprise"): the object's name is part of an unfinished objective in your log
local questTexts,questDirty={},true
local function Normal(t) return (t:lower():gsub("\194\160"," "):gsub("%d+%s*/%s*%d+",""):gsub("^[%s:%-]+",""):gsub("[%s:%-]+$","")) end
local function RebuildQuests()
 questDirty=false;wipe(questTexts)
 local function Add(text,finished)
  if type(text)=="string" and not Secret(text) and not finished then
   text=Normal(text);if #text>=4 then questTexts[#questTexts+1]=text end
  end
 end
 if GetNumQuestLogEntries and GetQuestLogTitle and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
  for i=1,GetNumQuestLogEntries() do
   local _,_,_,isHeader=GetQuestLogTitle(i)
   if not isHeader then
    for j=1,GetNumQuestLeaderBoards(i) or 0 do
     local text,_,finished=GetQuestLogLeaderBoard(j,i);Add(text,finished)
    end
   end
  end
 elseif C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
  for i=1,C_QuestLog.GetNumQuestLogEntries() do
   local id=C_QuestLog.GetQuestIDForLogIndex(i)
   local objectives=id and id>0 and C_QuestLog.GetQuestObjectives(id)
   if objectives then for _,o in ipairs(objectives) do Add(o.text,o.finished) end end
  end
 end
end
local function IsQuestObject(name)
 if type(name)~="string" or Secret(name) or #name<4 then return false end
 if questDirty then pcall(RebuildQuests) end
 name=Normal(name)
 for _,text in ipairs(questTexts) do
  if text:find(name,1,true) or (#text>=5 and name:find(text,1,true)) then return true end
 end
 return false
end

local function CorpseWithLoot(unit)
 if Call(UnitIsDead,unit)~=true then return false end
 local guid=Call(UnitGUID,unit)
 if not (guid and CanLootUnit) then return false end
 local ok,has,can=pcall(CanLootUnit,guid)
 return ok and not Secret(has) and not Secret(can) and has==true and can~=false
end

-- the glints
local sp={}
local function Respawn(g,now)
 local a,r=math.random()*2*math.pi,math.sqrt(math.random())
 g.x,g.y=math.cos(a)*r*SPREAD,math.sin(a)*r*SPREAD*.75
 g.life=.6+.8*math.random();g.scale=.5+.7*math.random();g.angle=math.random()*6.28;g.turn=math.random()-.5
 g.age=now and 0 or -.6*math.random()
end
local function Toward(v,target,step) if v<target then return math.min(v+step,target) end;return math.max(v-step,target) end
local function Animate(self,elapsed)
 if elapsed>.1 then elapsed=.1 end
 sp.appear=Toward(sp.appear,1,elapsed/.35)
 sp.near=Toward(sp.near,sp.state=="near" and 1 or 0,elapsed/.3)
 sp.grey=Toward(sp.grey,sp.state=="grey" and 1 or 0,elapsed/.3)
 local alpha=sp.appear*(.55+.45*sp.near)*(1-.55*sp.grey)
 local speed=(.8+.4*sp.near)*(1-.5*sp.grey)
 local r,g,b=GOLD[1]+(GREY[1]-GOLD[1])*sp.grey,GOLD[2]+(GREY[2]-GOLD[2])*sp.grey,GOLD[3]+(GREY[3]-GOLD[3])*sp.grey
 for _,gl in ipairs(sp.glints) do
  gl.age=gl.age+elapsed*speed
  if gl.age>=gl.life then Respawn(gl) end
  local shine=gl.age>0 and math.sin(math.pi*gl.age/gl.life) or 0
  local t=gl.tex
  t:SetPoint("CENTER",self,"CENTER",gl.x,gl.y+10*math.max(gl.age,0))
  local size=math.max(SIZE*gl.scale*(.35+.65*shine),.01)
  t:SetSize(size,size);t:SetRotation(gl.angle+gl.turn*math.max(gl.age,0));t:SetVertexColor(r,g,b,math.min(alpha*shine,1))
 end
end
local function Create()
 local f=CreateFrame("Frame");f:SetSize(1,1);f:Hide();sp.glints={}
 for i=1,GLINTS do
  local t=f:CreateTexture(nil,"OVERLAY");t:SetTexture(Picture());t:SetBlendMode("ADD");t:SetVertexColor(1,1,1,0)
  sp.glints[i]={tex=t}
 end
 f:SetScript("OnUpdate",Animate);sp.frame=f
 return f
end
local function Release()
 if not sp.anchor then return end
 sp.frame:Hide();sp.frame:ClearAllPoints();sp.frame:SetParent(nil);sp.anchor=nil
end
local function Attach(plate,state)
 local f=sp.frame or Create()
 f:SetParent(plate)
 local ok,level=pcall(plate.GetFrameLevel,plate)
 if ok and level and not Secret(level) then f:SetFrameLevel(math.max(level-1,0)) end
 f:ClearAllPoints();f:SetPoint("CENTER",plate,"CENTER",0,DROP);f:SetIgnoreParentAlpha(true)
 sp.anchor,sp.state=plate,state;sp.appear=0;sp.near=state=="near" and 1 or 0;sp.grey=state=="grey" and 1 or 0
 for _,gl in ipairs(sp.glints) do Respawn(gl) end
 f:Show()
end

local plates={}
function LS.Evaluate()
 if not AnyTarget() or InCombatLockdown() then Release();return end
 local exists=Call(UnitExists,SOFT)==true or Call(UnitIsGameObject,SOFT)==true
 if not exists then SetGate(false);Release();return end
 local s=S();local want,blocked=false
 if Call(UnitIsGameObject,SOFT)==true then
  local kind;kind,blocked=Kind(SOFT)
  if not kind and IsQuestObject(Call(UnitName,SOFT)) then kind="questObjects" end
  want=kind~=nil and s[kind]==true
  -- (a herb or ore vein for a profession you have not learned does not sparkle at all)
  if want and (kind=="herbs" or kind=="ore") then
   local known,usable=Knows(kind)
   if usable then if not known then want=false end
   elseif blocked then want=false end
  end
 elseif s.corpse and CorpseWithLoot(SOFT) then want=true end
 SetGate(want)
 local plate=want and Call(C_NamePlate.GetNamePlateForUnit,SOFT)
 if want and not plate then
  -- the game doesn't always answer for "softinteract" itself: take the nameplate of the world object being shown instead
  for unit in pairs(plates) do
   if Call(UnitIsGameObject,unit)==true or Call(UnitIsUnit,unit,SOFT)==true then
    plate=Call(C_NamePlate.GetNamePlateForUnit,unit);if plate then break end
   end
  end
 end
 if not plate then Release();return end
 local range=UnitIsInInteractRange and Call(UnitIsInInteractRange,SOFT)
 local state=range==false and "far" or blocked and "grey" or "near"
 if sp.anchor~=plate then Release();Attach(plate,state) else sp.state=state end
end

-- /rsparkle: the glints for 8 seconds in the middle of the screen (works on any version, to see the look).
-- /rsparkle star goes back to the plain star picture if the game's one looks wrong.
SLASH_REDSSPARKLE1="/rsparkle"
SlashCmdList.REDSSPARKLE=function(msg)
 if msg=="debug" then
  local function P(...) Menu.Print("|cffd8b878sparkle:|r",...) end
  local ok,v=pcall(C_CVar.GetCVar,"SoftTargetInteract")
  P("soft target setting:",ok and tostring(v) or "not in this game version","| UnitIsGameObject:",UnitIsGameObject and "yes" or "no")
  for _,n in ipairs({"SoftTargetInteractRange","SoftTargetNameplateInteract","SoftTargetIconGameObject","outlineModeShowLootEffectWhenDisabled","graphicsOutlineMode"}) do
   local o,x=pcall(C_CVar.GetCVar,n);P(n,"=",o and tostring(x) or "n/a")
  end
  P("supported:",tostring(Supported()),"any switch on:",tostring(AnyTarget()))
  P("softinteract exists:",tostring(Call(UnitExists,SOFT)),"game object:",tostring(UnitIsGameObject and Call(UnitIsGameObject,SOFT)),"name:",tostring(Call(UnitName,SOFT)))
  local kind,blocked=Kind(SOFT);P("kind:",tostring(kind),"blocked:",tostring(blocked))
  P("nameplate:",tostring(C_NamePlate and Call(C_NamePlate.GetNamePlateForUnit,SOFT)~=nil))
  local n,objs=0,0
  for unit in pairs(plates) do n=n+1;if Call(UnitIsGameObject,unit)==true then objs=objs+1 end end
  P("visible nameplates:",n,"of them world objects:",objs,"glints shown:",tostring(sp.anchor~=nil),"quest objectives known:",#questTexts)
  return
 end
 if msg=="star" or msg=="game" then
  Menu:Initialize();Menu.db.sparkleTexture=msg=="star" and "Interface\\Cooldown\\star4" or nil
  Menu.Print("Reds QOL: sparkle picture set to "..(msg=="star" and "the plain star" or "the game's sparkle")..". /reload to apply.")
  return
 end
 Release();Attach(UIParent,"near");sp.frame:ClearAllPoints();sp.frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
 C_Timer.After(8,function() if sp.anchor==UIParent then Release() end end)
end

local poller=CreateFrame("Frame");poller:Hide()
local since=0
poller:SetScript("OnUpdate",function(_,elapsed)
 since=since+elapsed
 if since>=POLL then since=0;LS.Evaluate() end
end)

function Menu:ApplySparkles()
 if not Supported() then
  -- not Forever: put back any soft targeting settings an earlier test version of this changed
  local s=Menu.db and Menu.db.sparkleSaved
  if s and not InCombatLockdown() then
   for name,value in pairs(s) do if value~=false then SetCVar(name,value) end end
   Menu.db.sparkleSaved=nil
  end
  return
 end
 ApplyQuestItems();ApplySoft()
 poller:SetShown(AnyTarget())
 if not AnyTarget() then Release() end
end

local ev=CreateFrame("Frame")
for _,e in ipairs({"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","QUEST_LOG_UPDATE","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","CVAR_UPDATE"}) do pcall(ev.RegisterEvent,ev,e) end
local timer
ev:SetScript("OnEvent",function(_,event,arg)
 if event=="QUEST_LOG_UPDATE" then questDirty=true;return end
 if event=="NAME_PLATE_UNIT_ADDED" then plates[arg]=true;return end
 if event=="NAME_PLATE_UNIT_REMOVED" then
  plates[arg]=nil
  local p=Call(C_NamePlate.GetNamePlateForUnit,arg);if p and p==sp.anchor then Release() end
  return
 end
 if event=="PLAYER_REGEN_DISABLED" then if AnyTarget() then SetGate(false);Release() end;return end
 if event=="PLAYER_REGEN_ENABLED" then if pending then pending=false;Menu:ApplySparkles() end;return end
 if event=="CVAR_UPDATE" then
  -- a graphics preset resets the outline mode: put the sparkle back a moment later
  if applying or type(arg)~="string" or not arg:lower():find("graphics",1,true) then return end
  if timer then return end
  timer=C_Timer.NewTimer(1,function() timer=nil;if Menu.db then ApplyQuestItems() end end)
  return
 end
 Menu:Initialize()
 Menu:ApplySparkles()
 if event=="PLAYER_LOGIN" then C_Timer.After(5,function() Menu:ApplySparkles() end) end
end)

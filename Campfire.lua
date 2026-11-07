-- Campfire reminder (WoW Forever only; Quality of life > Campfire). Forever has camps: standing near a campfire gives "Campfire Nearby", and
-- sitting at it gives "Camp Benefits" plus a bonus aura for each camp feature (a tent, a chair, a lute...). This shows:
--   * "Campfire nearby" while a camp is close and you have no bonuses yet, so you remember to sit by it
--   * your camp bonuses as small icons with the time left, and a warning when one is about to run out
-- The spell ids are the game's; on Classic Era nothing here exists and nothing runs. Drag it in Edit mode (it shows a sample there).
local Menu=_G.RedsQOL
local UI=Menu.UI
local Text=UI.Text
local CF={};Menu.Campfire=CF

local FOREVER=(select(4,GetBuildInfo()) or 0)>=16000
local NEARBY,BENEFITS=1283391,1229741
-- the bonus auras of the camp features (tent, sharpening wheel, first aid kit, incense, banner, fish bowl, lute, lodestone, spell, chair, mana well, salvager)
local BONUS={1229451,1230172,1230124,1229513,1229718,1230098,1230653,1230164,1230552,1229519,1230587,1283701}

local function Opt() return Menu:QoLSettings().campfire end
local function Look() return Menu.db and Menu.db.menuLook or "parchment" end
local function Secret(v) return issecretvalue~=nil and issecretvalue(v) end
local function Aura(id)
 local get=C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
 if not get then return nil end
 local ok,a=pcall(get,id)
 -- (the aura is there whenever a table comes back: its name and times can be hidden from an addon, which does not make the aura absent, so only
 -- those fields are checked, where they are used)
 if ok and type(a)=="table" then return a end
end
local function Clock(sec)
 sec=math.max(0,math.floor(sec+.5))
 if sec>=3600 then return string.format("%dh",math.floor(sec/3600)) end
 return string.format("%d:%02d",math.floor(sec/60),sec%60)
end

local f,icons
local demo=false
function CF.SetPreview(on) demo=on and true or false;if CF.Refresh then CF.Refresh() end end
local warned={}
local function Place()
 if not f then return end
 local p=Menu.db and Menu.db.campfirePos
 f:ClearAllPoints()
 if type(p)=="table" and p.x then f:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y) else f:SetPoint("TOP",UIParent,"TOP",0,-120) end
end
local ART="Interface\\AddOns\\RedsQOL\\Media\\CampFire"
local RING="Interface\\AddOns\\RedsQOL\\Media\\CampRing"
local FONTF=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local function Build()
 if f then return f end
 f=CreateFrame("Frame","RedsQOLCampfire",UIParent)
 f:SetSize(300,100);f:SetFrameStrata("MEDIUM");f:Hide()
 -- the campfire picture with a green ring that drains as the camp time runs down, and the bonuses beside it ("+Crit", "+Rested"); no box
 local r=CreateFrame("Frame",nil,f);r:SetSize(90,90);r:SetPoint("LEFT",0,0);f.round=r
 r.track=r:CreateTexture(nil,"BACKGROUND");r.track:SetAllPoints();r.track:SetTexture(RING);r.track:SetVertexColor(.08,.09,.1,.9)
 r.tex=r:CreateTexture(nil,"ARTWORK");r.tex:SetTexture(ART);r.tex:SetPoint("TOPLEFT",r,"TOPLEFT",10,-10);r.tex:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",-10,10)
 r.cd=CreateFrame("Cooldown",nil,r,"CooldownFrameTemplate");r.cd:SetAllPoints()
 r.cd:SetSwipeTexture(RING);r.cd:SetSwipeColor(.2,.62,.38,1);r.cd:SetReverse(true);r.cd:SetDrawEdge(false);r.cd:SetDrawBling(false)
 if r.cd.SetHideCountdownNumbers then r.cd:SetHideCountdownNumbers(true) end
 local over=CreateFrame("Frame",nil,r);over:SetAllPoints();over:SetFrameLevel(r.cd:GetFrameLevel()+2)
 r.time=over:CreateFontString(nil,"OVERLAY");r.time:SetFont(FONTF,15,"OUTLINE");r.time:SetPoint("CENTER")
 f.label=over:CreateFontString(nil,"OVERLAY");f.label:SetFont(FONTF,12,"OUTLINE");f.label:SetPoint("TOP",r,"BOTTOM",0,-2)
 f.bonus=f:CreateFontString(nil,"OVERLAY");f.bonus:SetFont(FONTF,16,"OUTLINE");f.bonus:SetJustifyH("LEFT");f.bonus:SetSpacing(2);f.bonus:SetTextColor(.82,.82,.82)
 -- near a camp (no bonuses yet): a small fire and "Camp Nearby · click to sit"; a click sits you down (no /sit to type)
 f.small=f:CreateTexture(nil,"ARTWORK");f.small:SetTexture(ART);f.small:SetSize(30,30);f.small:SetPoint("LEFT",0,0);f.small:Hide()
 f.nearText=f:CreateFontString(nil,"OVERLAY");f.nearText:SetFont(FONTF,20,"OUTLINE");f.nearText:SetPoint("LEFT",f.small,"RIGHT",8,0);f.nearText:Hide()
 f:SetScript("OnMouseUp",function(self,button)
  if button=="LeftButton" and self.nearNow and not InCombatLockdown() then
   if C_ChatInfo and C_ChatInfo.PerformEmote then pcall(C_ChatInfo.PerformEmote,"SIT") elseif DoEmote then pcall(DoEmote,"SIT") end
  end
 end)
 -- its box in Red's edit mode
 local mv=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");mv:SetAllPoints(f);mv:SetFrameStrata("DIALOG");mv:EnableMouse(true)
 UI.Box(mv,true);mv:SetBackdropColor(.24,.12,.025,.6);mv:SetBackdropBorderColor(1,.6,.15,1);mv:Hide();f.mover=mv
 local label=Text(mv,"Drag to move",13);label:SetPoint("CENTER")
 mv:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then UI.BeginDrag("campfire") end end)
 mv:SetScript("OnMouseUp",function(_,button) if button=="LeftButton" then UI.EndDrag() end end)
 Place()
 return f
end
-- short tags for what a bonus gives (the words of a line, or the bonus aura), in the order shown
local TAGS={{"rest","+Rested"},{"disenchant","+Disenchant"},{"critical","+Crit"},{"spell","+SP"},{"healing","+SP"},{"armor","+Armor"},{"attack power","+AP"},
 {"all stats","+Stats"},{"strength","+Str"},{"stamina","+Sta"},{"intellect","+Int"},{"spirit","+Spi"},{"mana","+MP5"}}
local AURA_TAG={[1229451]="+Rested",[1230172]="+Str",[1230124]="+Sta",[1229513]="+Int",[1229718]="+Spi",[1230098]="+Stats",[1230653]="+Armor",[1230164]="+AP",[1230552]="+SP",[1229519]="+Crit",[1230587]="+MP5",[1283701]="+Disenchant"}
local function TagOf(line)
 local low=line:lower()
 for _,t in ipairs(TAGS) do if low:find(t[1],1,true) then return t[2] end end
end
local function Short(sec)
 if sec>=3600 then return string.format("%dh",math.floor(sec/3600)) end
 if sec>=60 then return string.format("%dm",math.floor(sec/60)) end
 return string.format("%ds",math.max(0,math.floor(sec)))
end

-- The warning sound: the one chosen on the Campfire page (Red's own, the game's, or any BigWigs / SharedMedia sound), the raid warning by default
local function Chime()
 local o=Opt()
 local CDm=Menu.Cooldowns
 if CDm and CDm.PlaySound and o.soundKey then CDm.PlaySound(o.soundKey);return end
 if SOUNDKIT then pcall(PlaySound,SOUNDKIT.RAID_WARNING or 8959) end
end

-- The words of the camp benefits (each bonus and what it gives), read from the Camp Benefits aura's tooltip; read again only when the aura changes
local tipCache={lines={},next=0}
local function Lines()
 local a=Aura(BENEFITS)
 if not a then tipCache.id=nil;return tipCache.lines end
 local inst=a.auraInstanceID
 if not inst or Secret(inst) or not (C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID) then return {} end
 local now=GetTime()
 if tipCache.id==inst and (#tipCache.lines>0 or now<tipCache.next) then return tipCache.lines end
 tipCache.id=inst;tipCache.next=now+5;tipCache.lines={}
 local ok,data=pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID,"player",inst)
 local src=ok and data and data.lines
 if type(src)=="table" then
  for i=2,#src do
   local txt=src[i] and src[i].leftText
   if type(txt)=="string" and not Secret(txt) then
    txt=(txt:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""))
    for row in txt:gmatch("[^\n]+") do if row:match("^[^:]+:%s*%S") then tipCache.lines[#tipCache.lines+1]=row end end
   end
  end
 end
 return tipCache.lines
end

-- what to show now: {text,color,list of {icon,id,left}} or nil for nothing
local function Gather()
 local o=Opt()
 local list={}
 for _,id in ipairs(BONUS) do
  local a=Aura(id)
  if a then
   local exp=a.expirationTime
   local left=(type(exp)=="number" and not Secret(exp) and exp>0) and (exp-GetTime()) or nil
   list[#list+1]={icon=(not Secret(a.icon)) and a.icon or nil,id=id,left=left,name=(type(a.name)=="string" and not Secret(a.name)) and a.name or nil}
  end
 end
 if #list>0 or Aura(BENEFITS) then
  local soon
  if o.warnEnding then for _,e in ipairs(list) do if e.left and e.left>0 and e.left<=o.warnAt then soon=e;break end end end
  if soon then
   if o.sound and not warned[soon.id] then warned[soon.id]=true;pcall(Chime) end
   return {text="Camp bonus ending: "..(soon.name or "a bonus"),warn=true,list=list,lines=Lines()}
  end
  for id in pairs(warned) do local alive=false;for _,e in ipairs(list) do if e.id==id then alive=true end end;if not alive then warned[id]=nil end end
  return {text="Camp bonuses",list=list,lines=Lines()}
 end
 if o.alertNearby and Aura(NEARBY) then
  if o.sound and not warned.near then warned.near=true;pcall(Chime) end
  return {text="Campfire nearby: sit by it for camp bonuses",near=true,list={}}
 end
 warned.near=nil
end
local function Sample()
 return {text="Camp bonuses",list={},lines={"Lodestone: Melee Attack Power increased by 12.","Camp Chair: Critical Strike increased by 2%."}}
end

function CF.Refresh()
 if not f then return end
 local info=demo and Sample() or Gather()
 if not info then f:Hide();return end
 local o=Opt()
 local r=f.round
 f.nearNow=info.near and not demo or false
 f:EnableMouse(f.nearNow)
 if info.near then
  r:Hide();f.label:SetText("");f.bonus:SetText("");f.small:Show();f.nearText:Show()
  f.nearText:SetText("|cff2f9bff"..(o.nearbyWords or "Camp Nearby").."|r |cffaaaaaa· click to sit|r")
  f:SetSize(38+f.nearText:GetStringWidth(),32);f:Show()
  return
 end
 r:Show();f.small:Hide();f.nearText:Hide()
 local size=tonumber(o.iconSize) or 90
 if f.sized~=size then f.sized=size;r:SetSize(size,size);local inset=math.floor(size*.11+.5);r.tex:SetPoint("TOPLEFT",r,"TOPLEFT",inset,-inset);r.tex:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",-inset,inset) end
 local c=info.warn and {1,.55,.25} or info.near and {.6,.9,.6} or UI.GOLD
 r.tex:SetDesaturated(info.near and true or false)
 -- the camp's time: the Camp Benefits aura's own (a sample in Edit mode)
 local left,dur
 if demo then left,dur=2400,3600
 elseif not info.near then
  local a=Aura(BENEFITS)
  local exp,d=a and a.expirationTime,a and a.duration
  if type(exp)=="number" and type(d)=="number" and not Secret(exp) and not Secret(d) and exp>0 and d>0 then left,dur=exp-GetTime(),d end
 end
 if o.onlyLow and not demo and not info.near and not info.warn and left and left>(tonumber(o.lowMinutes) or 5)*60 then f:Hide();return end
 if left and o.timer~=false then
  local key=math.floor(left/5)
  if f.cdFor~=key or not f.cdSet then r.cd:SetCooldown(GetTime()-(dur-left),dur);f.cdSet=true;f.cdFor=key end
  local rc=o.ringColor or {.2,.62,.38};r.cd:SetSwipeColor(rc[1],rc[2],rc[3],1)
  r.cd:Show();r.time:SetText(Short(left));r.time:SetTextColor(unpack((left<=o.warnAt) and {1,.55,.25} or {1,1,1}))
 else r.cd:Clear();r.cd:Hide();f.cdSet=nil;r.time:SetText("") end
 r.time:SetFont(FONTF,math.max(10,math.floor(size*.17)),"OUTLINE")
 f.label:SetText(info.near and "Sit by the fire" or (info.warn and "Bonus ending" or ""));f.label:SetTextColor(c[1],c[2],c[3])
 -- the bonuses, short, one to a line: from the tooltip's lines and the bonus auras
 local tags,seen={},{}
 local function Add(tag) if tag and not seen[tag] then seen[tag]=true;tags[#tags+1]=tag end end
 for _,l in ipairs(info.lines or {}) do Add(TagOf(l)) end
 for _,e in ipairs(info.list) do Add(AURA_TAG[e.id] or (e.name and TagOf(e.name))) end
 if demo then Add("+Rested");Add("+Crit") end
 if info.near then tags={} end
 local ts=tonumber(o.textSize) or 16
 f.bonus:SetFont(FONTF,ts,"OUTLINE")
 f.bonus:ClearAllPoints();f.bonus:SetPoint("LEFT",r,"RIGHT",12,0);f.bonus:SetText(table.concat(tags,"\n"))
 if info.warn then f.bonus:SetTextColor(1,.55,.25) else f.bonus:SetTextColor(.82,.82,.82) end
 local bw=math.max(60,f.bonus:GetStringWidth())
 f:SetSize(size+12+bw,size+(f.label:GetText()~="" and 16 or 0));f:Show()
end
local since=0
local ticker=CreateFrame("Frame");ticker:Hide()
ticker:SetScript("OnUpdate",function(_,elapsed)
 since=since+elapsed
 if f and f.mover then f.mover:SetShown(Menu.editModeActive and true or false) end
 if demo and not Menu.editModeActive then demo=false;CF.Refresh() end
 if since<.5 then return end
 since=0;CF.Refresh()
end)

local ev=CreateFrame("Frame")
ev:SetScript("OnEvent",function(_,event,unit) if event~="UNIT_AURA" or unit=="player" then CF.Refresh() end end)

function Menu:ApplyCampfire()
 if not Menu.db or not FOREVER then return end
 local o=Opt()
 if not o.enabled then
  ev:UnregisterAllEvents();ticker:Hide();if f then f:Hide() end
  return
 end
 Build()
 pcall(ev.RegisterEvent,ev,"UNIT_AURA");pcall(ev.RegisterEvent,ev,"PLAYER_ENTERING_WORLD")
 ticker:Show();CF.Refresh()
end

-- Edit mode: a sample, so there is something to place
Menu.extraMovables=Menu.extraMovables or {}
Menu.extraMovables.campfire={
 frame=function()
  if not FOREVER then return nil end
  Build();demo=true;ticker:Show();CF.Refresh()
  if Menu.editModeActive and f.mover then f.mover:Show() end
  return f
 end,
 save=function(x,y) Menu.db.campfirePos={x=x,y=y};C_Timer.After(0,Place) end}
if Menu.Mover and Menu.Mover.Place then
 hooksecurefunc(Menu.Mover,"Place",function(on)
  if not on or not FOREVER then return end
  C_Timer.After(0,function() if Menu.editModeActive then Build();demo=true;ticker:Show();CF.Refresh();if f.mover then f.mover:Show() end end end)
 end)
end

local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() Menu:Initialize();C_Timer.After(2,function() Menu:ApplyCampfire() end) end)

-- the page's note
local build=Menu.BuildQoLPage
if build then
 function Menu:BuildQoLPage(page)
  build(self,page)
  local section=Menu.QoL and Menu.QoL.sections and Menu.QoL.sections.campfire
  if not section then return end
  local note=Text(section.options,FOREVER and "Shown near a camp and while you have camp bonuses. Move it in Edit mode." or "WoW Forever only: this game version has no camps.",11,UI.MUTED)
  note:SetPoint("BOTTOMLEFT",16,12);note:SetWidth(330);note:SetJustifyH("LEFT")
 end
end
-- /rcamp: what the game says about the camp auras right now (for when the reminder does not show)
SLASH_REDSQOLCAMPDEBUG1="/rcampdebug"
SlashCmdList.REDSQOLCAMPDEBUG=function()
 Menu:Initialize()
 local o=Opt()
 Menu:Say("Campfire: forever="..tostring(FOREVER)..", on="..tostring(o.enabled)..", frame="..tostring(f~=nil)..", shown="..tostring(f and f:IsShown()))
 Menu:Say("Camp nearby aura: "..tostring(Aura(NEARBY)~=nil)..", Camp Benefits aura: "..tostring(Aura(BENEFITS)~=nil)..", in instance: "..tostring((IsInInstance())))
 local n=0;for _,id in ipairs(BONUS) do if Aura(id) then n=n+1 end end
 Menu:Say("Camp bonus auras on you: "..n..". Auras secret now: "..tostring(C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()))
 -- every aura on you, by id (the game may use a different id than the one expected)
 local list={}
 for i=1,60 do
  local ok,a=pcall(C_UnitAuras.GetAuraDataByIndex,"player",i,"HELPFUL")
  if not ok or type(a)~="table" then break end
  local id=a.spellId
  list[#list+1]=(id and not Secret(id)) and tostring(id) or "?"
 end
 Menu:Say("Buff ids on you ("..#list.."): "..table.concat(list,", "))
 local ok2,sp=pcall(function() return C_UnitAuras.GetUnitAuraBySpellID and C_UnitAuras.GetUnitAuraBySpellID("player",NEARBY) end)
 Menu:Say("By unit lookup, nearby: "..tostring(ok2 and sp~=nil))
 Menu:ApplyCampfire()
end

-- The Campfire page's sound row: the chosen sound's name, a button to play it, and a list to pick another from (Red's own sounds, the game's,
-- and any other addon's shared sounds such as BigWigs')
local picker
local function ShowPicker(anchor,after,get,set)
 local CDm=Menu.Cooldowns
 if not (CDm and CDm.AllSounds) then return end
 if not picker then
  picker=CreateFrame("Frame","RedsQOLCampSounds",UIParent,"BackdropTemplate");picker:SetSize(270,300);picker:SetFrameStrata("FULLSCREEN_DIALOG");picker:Hide()
  UI.Box(picker);UI.RedEdge(picker,2)
  local scroll=CreateFrame("ScrollFrame","RedsQOLCampSoundScroll",picker,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",6,-6);scroll:SetPoint("BOTTOMRIGHT",-28,6)
  picker.child=CreateFrame("Frame",nil,scroll);picker.child:SetSize(230,10);scroll:SetScrollChild(picker.child);picker.rows={}
  pcall(picker.RegisterEvent,picker,"GLOBAL_MOUSE_DOWN")
  picker:SetScript("OnEvent",function(self) if self:IsShown() and not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then self:Hide() end end)
 end
 picker.anchor=anchor
 local list=CDm.AllSounds()
 local now=get()
 picker.set=set
 for i,o in ipairs(list) do
  local r=picker.rows[i]
  if not r then
   r=CreateFrame("Button",nil,picker.child);r:SetSize(230,22);r:SetPoint("TOPLEFT",0,-(i-1)*22)
   r.text=Text(r,"",12);r.text:SetPoint("LEFT",4,0);r.text:SetWidth(200);r.text:SetJustifyH("LEFT");r.text:SetWordWrap(false)
   local hl=r:CreateTexture(nil,"HIGHLIGHT");hl:SetAllPoints();hl:SetColorTexture(1,.82,.4,.15)
   r:SetScript("OnClick",function(self)
    picker.set(self.value);Menu.Cooldowns.PlaySound(self.value);picker:Hide()
    if picker.after then picker.after() end
   end)
   picker.rows[i]=r
  end
  r.value=o[1];r.text:SetText(o[2]);r.text:SetTextColor(unpack(o[1]==now and {1,.85,.53} or (o.shared and {.75,.8,.9}) or {1,1,1}));r:Show()
 end
 for i=#list+1,#picker.rows do picker.rows[i]:Hide() end
 picker.child:SetHeight(#list*22);picker.after=after
 picker:ClearAllPoints();picker:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-2);picker:Show()
end
local function SoundLabel(key)
 key=key or "warn"
 if key:sub(1,4)=="lsm:" then return key:sub(5) end
 local CDm=Menu.Cooldowns
 if CDm and CDm.AllSounds then for _,o in ipairs(CDm.AllSounds()) do if o[1]==key then return o[2] end end end
 return "Raid warning"
end
-- A sound row for any page: its label, the chosen sound (click for the list), and a button to play it. get() gives the saved key, set(key) saves one.
function Menu.BuildSoundPicker(row,x,text,get,set)
 local label=Text(row,text or "Warning sound",12);label:SetPoint("TOPLEFT",x,-8)
 local pick=UI.Button(row,"",170,function(b) if picker and picker:IsShown() then picker:Hide() else ShowPicker(b,function() b.label:SetText(SoundLabel(get())) end,get,set) end end)
 pick:SetHeight(22);pick:SetPoint("TOPRIGHT",-30,-4)
 local play=UI.Button(row,">",24,function() if Menu.Cooldowns and Menu.Cooldowns.PlaySound then Menu.Cooldowns.PlaySound(get() or "warn") end end)
 play:SetHeight(22);play:SetPoint("LEFT",pick,"RIGHT",4,0)
 return function() pick.label:SetText(SoundLabel(get())) end
end
-- Plays a chosen reminder sound (the raid warning when none is chosen or the list is not loaded)
function Menu.PlayReminderSound(key)
 local CDm=Menu.Cooldowns
 if CDm and CDm.PlaySound and key then CDm.PlaySound(key);return end
 if SOUNDKIT then pcall(PlaySound,SOUNDKIT.RAID_WARNING or 8959) end
end
function CF.BuildSoundRow(row,x,ctx)
 return Menu.BuildSoundPicker(row,x,"Warning sound",function() return Opt().soundKey end,function(k) Opt().soundKey=k end)
end

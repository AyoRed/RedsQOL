-- Trainer spells: what your class learns at each level, all the way up, without visiting a trainer first (the lists are in
-- Modules\TrainerSpellData.lua, made from the game's public data tables for Classic Era and WoW Forever). Shows as a tab on the game's
-- spellbook, and as its own window: /rtrainer. Each spell is learned (grey), ready at your level (green), or coming later (red level).
-- The cost is filled in once you've opened a class trainer (the game only tells us then). A chat note after a level up says which
-- spells are new. Nothing runs except while the list is open, at a trainer window and at a level up.
local Menu=_G.RedsQOL
local UI=Menu.UI
local Text,Button=UI.Text,UI.Button
local TS={};Menu.TrainerSpells=TS
local panel,tab   -- the spellbook tab and its panel (declared early: /rtrainer debug reads them)

local FOREVER=(select(4,GetBuildInfo()) or 0)>=16000
local function Look() return Menu.db and Menu.db.menuLook or "parchment" end
local function Class() return select(2,UnitClass("player")) end
local sidePanel,sideButton   -- (the Forever spellbook's button and panel, made further down)
local function Opt() return Menu:QoLSettings().trainer end

local function Data()
 local all=Menu.TrainerData
 local set=all and (FOREVER and all.Forever or all.Era)
 return set and set[Class()]
end

-- costs seen at trainers: "name|rank" -> copper (per class)
local function Costs(create)
 Menu:Initialize()
 local c=Menu.db.trainerCosts
 if not c then if not create then return {} end;c={};Menu.db.trainerCosts=c end
 local k=Class()
 if not c[k] then if not create then return {} end;c[k]={} end
 return c[k]
end
local function Capture()
 if not (GetNumTrainerServices and GetTrainerServiceInfo) then return end
 if IsTradeskillTrainer and IsTradeskillTrainer() then return end
 local costs=Costs(true)
 for i=1,GetNumTrainerServices() do
  local name,rank,category=GetTrainerServiceInfo(i)
  if type(name)=="string" and category and category~="header" then
   local cost=GetTrainerServiceCost and GetTrainerServiceCost(i)
   if tonumber(cost) and cost>0 then costs[name.."|"..(type(rank)=="string" and rank or "")]=cost end
  end
 end
end

local function Known(id)
 if IsPlayerSpell and IsPlayerSpell(id) then return true end
 return IsSpellKnown and IsSpellKnown(id) or false
end
local function Icon(id)
 local tex=C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or GetSpellTexture and GetSpellTexture(id)
 return tex or 134400
end

local function List()
 local data=Data()
 if not data then return {} end
 local level=UnitLevel("player")
 local costs=Costs(false)
 local out={}
 for _,d in ipairs(data) do
  local id,lv,name,rank,price=d[1],d[2],d[3],d[4],d[5]
  local rankText=rank>0 and ("Rank "..rank) or ""
  out[#out+1]={id=id,level=lv,name=name,rank=rankText,cost=costs[name.."|"..rankText] or ((price or 0)>0 and price or nil),
   state=Known(id) and "learned" or (lv<=level and "ready" or "later")}
 end
 return out
end

-- The list, built into any parent ---------------------------------------------------------------------------------------------
local ROW=24
local function Coin(copper)
 if not copper then return "" end
 if copper<=0 then return "free" end
 -- (written out here: 100 copper is 1 silver, and the game's own coin text is not there on every client)
 return Menu.Coin(copper)
end
-- two looks: on Red's own window, and on the book's parchment page (dark brown ink, like the game's own spell names)
local PAL_WINDOW={ready={.3,1,.3},later={1,.35,.3},learned={.5,.5,.5},nameReady={1,.85,.53},nameLater={.85,.85,.85},nameLearned={.55,.55,.55},
 costReady={1,1,1},costLater={.8,.8,.8},costLearned={.5,.5,.5},rank="9a9a9a",muted=UI.MUTED,
 stripe={1,1,1,.035},hover={1,1,1,.09},head={.85,.7,.45},rule={.3,.3,.33,1},accent={.78,.18,.12}}
local PAL_BOOK={ready={.08,.45,.08},later={.62,.12,.06},learned={.45,.38,.28},nameReady={.22,.11,.02},nameLater={.30,.17,.06},nameLearned={.5,.42,.3},
 costReady={.22,.11,.02},costLater={.35,.2,.08},costLearned={.5,.42,.3},rank="7a5a30",muted={.32,.2,.08},
 stripe={.3,.15,.02,.07},hover={1,.95,.8,.3},head={.36,.2,.07},rule={.5,.33,.16,.75},accent={.62,.12,.06}}
local HEAD=26
local function MakeList(parent,top,bottom,pal)
 pal=pal or PAL_WINDOW
 local L={rows={},heads={}}
 local base=top-34
 -- how many are ready, still ahead and learned, as big numbers
 L.stats={}
 for i,def in ipairs({{"ready","READY NOW",pal.ready},{"later","LATER",pal.later},{"learned","LEARNED",pal.learned}}) do
  local n=Text(parent,"0",20,def[3]);n:SetPoint("TOPLEFT",16+(i-1)*92,-base)
  local l=Text(parent,def[2],9,pal.muted);l:SetPoint("TOPLEFT",n,"BOTTOMLEFT",1,-1)
  L.stats[def[1]]=n
 end
 -- Show learned / Show not learned
 local function Show() Menu:Initialize();local s=Menu.db.trainerShow;if not s then s={learned=true,notLearned=true};Menu.db.trainerShow=s end;return s end
 L.checks={}
 for i,def in ipairs({{"learned","Learned"},{"notLearned","Not learned"}}) do
  local cb=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");cb:SetSize(20,20);cb:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-12-(2-i)*104-(i==1 and 0 or 0),-(base+2)-(i-1)*0)
  cb:ClearAllPoints();cb:SetPoint("TOPLEFT",parent,"TOPLEFT",16+(i-1)*104,-(base+44))
  local label=Text(cb,def[2],11,pal.muted);label:SetPoint("LEFT",cb,"RIGHT",1,0)
  cb:SetScript("OnShow",function(self) self:SetChecked(Show()[def[1]]~=false) end)
  cb:SetScript("OnClick",function(self) Show()[def[1]]=not not self:GetChecked();L.Refresh();L.scroll:SetVerticalScroll(0) end)
  L.checks[i]=cb
 end
 local scroll=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",8,-(base+68));scroll:SetPoint("BOTTOMRIGHT",-28,bottom)
 local content=CreateFrame("Frame",nil,scroll);content:SetSize(10,10);scroll:SetScrollChild(content)
 scroll:SetScript("OnSizeChanged",function(_,w) content:SetWidth(math.max(10,w)) end)
 L.scroll,L.content=scroll,content
 function L.Row(i)
  local r=L.rows[i]
  if r then return r end
  r=CreateFrame("Frame",nil,content);r:SetHeight(ROW)
  r.stripe=r:CreateTexture(nil,"BACKGROUND");r.stripe:SetAllPoints();r.stripe:SetColorTexture(unpack(pal.stripe))
  r.hover=r:CreateTexture(nil,"BACKGROUND",nil,1);r.hover:SetAllPoints();r.hover:SetColorTexture(unpack(pal.hover));r.hover:Hide()
  r.bar=r:CreateTexture(nil,"ARTWORK");r.bar:SetPoint("TOPLEFT",0,-3);r.bar:SetPoint("BOTTOMLEFT",0,3);r.bar:SetWidth(3)
  r.edge=r:CreateTexture(nil,"BORDER");r.edge:SetColorTexture(0,0,0,.6);r.edge:SetSize(22,22);r.edge:SetPoint("LEFT",10,0)
  r.icon=r:CreateTexture(nil,"ARTWORK");r.icon:SetPoint("TOPLEFT",r.edge,1,-1);r.icon:SetPoint("BOTTOMRIGHT",r.edge,-1,1);r.icon:SetTexCoord(.08,.92,.08,.92)
  r.cost=Text(r,"",11);r.cost:SetPoint("RIGHT",-6,0);r.cost:SetWidth(78);r.cost:SetJustifyH("RIGHT")
  r.lv=Text(r,"",10);r.lv:SetPoint("RIGHT",r.cost,"LEFT",-8,0);r.lv:SetWidth(34);r.lv:SetJustifyH("RIGHT")
  r.name=Text(r,"",12);r.name:SetPoint("LEFT",40,0);r.name:SetPoint("RIGHT",r.lv,"LEFT",-4,0);r.name:SetJustifyH("LEFT");r.name:SetWordWrap(false)
  r:EnableMouse(true)
  r:SetScript("OnEnter",function(self)
   self.hover:Show()
   if not self.id then return end
   GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
   if not pcall(GameTooltip.SetSpellByID,GameTooltip,self.id) then GameTooltip:SetText(self.spell or "") end
   GameTooltip:Show()
  end)
  r:SetScript("OnLeave",function(self) self.hover:Hide();GameTooltip:Hide() end)
  L.rows[i]=r
  return r
 end
 -- a section title: its name, how many spells, and what they cost together
 function L.Head(i)
  local h=L.heads[i]
  if h then return h end
  h=CreateFrame("Frame",nil,content);h:SetHeight(HEAD)
  h.bar=h:CreateTexture(nil,"ARTWORK");h.bar:SetSize(3,14);h.bar:SetPoint("LEFT",0,-2)
  h.title=Text(h,"",11);h.title:SetPoint("LEFT",10,-2)
  h.info=Text(h,"",10,pal.muted);h.info:SetPoint("RIGHT",-6,-2);h.info:SetJustifyH("RIGHT")
  h.rule=h:CreateTexture(nil,"ARTWORK");h.rule:SetColorTexture(unpack(pal.rule));h.rule:SetPoint("BOTTOMLEFT",0,0);h.rule:SetPoint("BOTTOMRIGHT",0,0);h.rule:SetHeight(1)
  L.heads[i]=h
  return h
 end
 function L.Refresh()
  local t0=debugprofilestop()
  local full=List()
  L.listMs=debugprofilestop()-t0
  content:SetWidth(math.max(10,scroll:GetWidth()>10 and scroll:GetWidth() or 300))
  local ready,later,learned=0,0,0
  for _,e in ipairs(full) do if e.state=="learned" then learned=learned+1 elseif e.state=="ready" then ready=ready+1 else later=later+1 end end
  L.stats.ready:SetText(ready);L.stats.later:SetText(later);L.stats.learned:SetText(learned)
  local show=Menu.db and Menu.db.trainerShow or {}
  -- sections: ready now, then each level still ahead, then what you have learned
  local sections,byLevel={}, {}
  local R,Lr={}, {}
  if show.notLearned~=false then
   for _,e in ipairs(full) do
    if e.state=="ready" then R[#R+1]=e
    elseif e.state=="later" then
     local g=byLevel[e.level]
     if not g then g={title="LEVEL "..e.level,state="later",items={},level=e.level};byLevel[e.level]=g;sections[#sections+1]=g end
     g.items[#g.items+1]=e
    end
   end
  end
  table.sort(sections,function(a,b) return a.level<b.level end)
  if #R>0 then table.insert(sections,1,{title="READY NOW",state="ready",items=R,showLevel=true}) end
  if show.learned~=false then
   for _,e in ipairs(full) do if e.state=="learned" then Lr[#Lr+1]=e end end
   if #Lr>0 then sections[#sections+1]={title="LEARNED",state="learned",items=Lr,showLevel=true} end
  end
  local y,ri,hi=0,0,0
  for _,sec in ipairs(sections) do
   hi=hi+1
   local h=L.Head(hi);h:Show();h:ClearAllPoints();h:SetPoint("TOPLEFT",0,-y);h:SetPoint("TOPRIGHT",0,-y)
   local total,priced=0,0
   for _,e in ipairs(sec.items) do if e.cost then total=total+e.cost;priced=priced+1 end end
   local col=sec.state=="ready" and pal.ready or sec.state=="learned" and pal.learned or pal.head
   h.title:SetText(sec.title);h.title:SetTextColor(unpack(col))
   h.bar:SetColorTexture(unpack(sec.state=="ready" and pal.ready or sec.state=="learned" and pal.learned or pal.accent))
   local n=#sec.items
   h.info:SetText(n.." spell"..(n==1 and "" or "s")..((sec.state~="learned" and priced>0) and ("   "..Coin(total)) or ""))
   y=y+HEAD
   for k,e in ipairs(sec.items) do
    ri=ri+1
    local r=L.Row(ri);r:Show();r:ClearAllPoints();r:SetPoint("TOPLEFT",0,-y);r:SetPoint("TOPRIGHT",0,-y)
    r.id,r.spell=e.id,e.name
    r.stripe:SetShown(k%2==0)
    r.icon:SetTexture(Icon(e.id))
    r.name:SetText(e.name..(e.rank~="" and ("  |cff"..pal.rank..e.rank.."|r") or ""))
    r.lv:SetText(sec.showLevel and ("Lv "..e.level) or "")
    local st=e.state
    r.bar:SetShown(st=="ready");if st=="ready" then r.bar:SetColorTexture(unpack(pal.ready)) end
    if st=="learned" then
     r.name:SetTextColor(unpack(pal.nameLearned));r.cost:SetTextColor(unpack(pal.costLearned));r.lv:SetTextColor(unpack(pal.learned));r.cost:SetText("learned");r.icon:SetDesaturated(true)
    elseif st=="ready" then
     r.name:SetTextColor(unpack(pal.nameReady));r.cost:SetTextColor(unpack(pal.costReady));r.lv:SetTextColor(unpack(pal.ready));r.cost:SetText(Coin(e.cost));r.icon:SetDesaturated(false)
    else
     r.name:SetTextColor(unpack(pal.nameLater));r.cost:SetTextColor(unpack(pal.costLater));r.lv:SetTextColor(unpack(pal.later));r.cost:SetText(Coin(e.cost));r.icon:SetDesaturated(false)
    end
    -- the price column is only as wide as what it says, so names get the room
    r.cost:SetWidth(200);local t=r.cost:GetText();r.cost:SetWidth((t and t~="") and math.ceil(r.cost:GetStringWidth())+4 or 1)
    y=y+ROW
   end
   y=y+6
  end
  for i=ri+1,#L.rows do L.rows[i]:Hide() end
  for i=hi+1,#L.heads do L.heads[i]:Hide() end
  content:SetHeight(math.max(10,y))
  if #full==0 then
   L.empty=L.empty or Text(parent,"No spell list for this class on this version of the game.",11,pal.muted)
   L.empty:ClearAllPoints();L.empty:SetPoint("TOPLEFT",16,-(base+76));L.empty:Show()
  elseif L.empty then L.empty:Hide() end
  L.totalMs=debugprofilestop()-t0
 end
 function L.ScrollToNext() scroll:SetVerticalScroll(0) end
 return L
end
-- Its own window (/rtrainer, Quality of life > Trainer spells) ----------------------------------------------------------------
local win
local function BuildWindow()
 if win then return win end
 local f=CreateFrame("Frame","RedsQOLTrainerSpells",UIParent,"BackdropTemplate")
 f.redsLook=Look;f:SetSize(420,520);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetToplevel(true)
 f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true)
 UI.Box(f);UI.TitleBar(f,30);UI.RedEdge(f,2)
 f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
 f.title=Text(f,"Trainer spells",15,UI.RED_TEXT);f.title:SetPoint("TOPLEFT",14,-8)
 local close=Button(f,"X",22,function() f:Hide() end);close:SetHeight(20);close:SetPoint("TOPRIGHT",-6,-5)
 f.list=MakeList(f,80,14)
 tinsert(UISpecialFrames,"RedsQOLTrainerSpells")
 f:Hide();win=f
 return f
end
function TS.Open()
 Menu:Initialize()
 local f=BuildWindow()
 f.title:SetText("Trainer spells - "..(UnitClass("player") or ""))
 UI.Paper(f,Look(),1);UI.RedrawButtons(f)
 if UI.SkinTree then UI.SkinTree(f,Look()) end
 f.list.Refresh();f:Show();f:Raise()
 C_Timer.After(.05,function() if f:IsShown() then f.list.Refresh();f.list.ScrollToNext() end end)
end
function TS.Toggle() if win and win:IsShown() then win:Hide() else TS.Open() end end
SLASH_REDSTRAINER1="/rtrainer"
SlashCmdList.REDSTRAINER=function(msg)
 if msg=="debug" then
  Menu.Print("|cffd8b878trainer:|r SpellBookFrame",tostring(SpellBookFrame~=nil),"tab built",tostring(_G.RedsQOLTrainerTab~=nil),"class",Class(),"spells",#List(),"forever",tostring(FOREVER))
  Menu.Print("|cffd8b878trainer:|r data",tostring(Menu.TrainerData~=nil),"panel",tostring(panel~=nil),panel and (panel:IsShown() and "shown " or "hidden ")..math.floor(panel:GetWidth()).."x"..math.floor(panel:GetHeight()) or "",
   "rows",panel and #panel.list.rows or 0,"scroll",panel and math.floor(panel.list.scroll:GetWidth()).."x"..math.floor(panel.list.scroll:GetHeight()) or "","content",panel and math.floor(panel.list.content:GetWidth()).."x"..math.floor(panel.list.content:GetHeight()) or "")
  if panel then Menu.Print("|cffd8b878trainer:|r last refresh",string.format("%.0f ms (building the list %.0f ms)",panel.list.totalMs or 0,panel.list.listMs or 0)) end
  if TS.TabInfo then for _,line in ipairs({TS.TabInfo()}) do Menu.Print("|cffd8b878trainer tab:|r",line) end end
  Menu.Print("|cffd8b878trainer:|r PlayerSpellsFrame",tostring(_G.PlayerSpellsFrame~=nil),"its SpellBookFrame",tostring(_G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame~=nil),"side button",tostring(sideButton~=nil),"tab option",tostring(Opt().tab))
  if SpellBookFrame then
   local shown,names=0,{}
   for i=1,12 do local b=_G["SpellBookSkillLineTab"..i];if b then names[#names+1]=i..(b:IsShown() and "+" or "-") end end
   Menu.Print("|cffd8b878trainer:|r skill tabs",table.concat(names," "),"| our tab",_G.RedsQOLTrainerTab and (_G.RedsQOLTrainerTab:IsShown() and "shown" or "hidden") or "none")
  end
  return
 end
 TS.Toggle()
end

-- A tab on the game's spellbook ------------------------------------------------------------------------------------------------
local function HidePanel() if panel then panel:Hide() end end
local function ShowPanel()
 if not panel then
  panel=CreateFrame("Frame","RedsQOLTrainerBook",SpellBookFrame,"BackdropTemplate")
  -- on the book's page: from the first spell slot to the page arrows, over the page's own parchment
  local first,nextPage=_G.SpellButton1,_G.SpellBookNextPageButton
  if first and nextPage then
   panel:SetPoint("TOPLEFT",first,"TOPLEFT",-14,10);panel:SetPoint("BOTTOMRIGHT",nextPage,"BOTTOMRIGHT",12,-8)
  else
   panel:SetPoint("TOPLEFT",SpellBookFrame,"TOPLEFT",12,-58);panel:SetPoint("BOTTOMRIGHT",SpellBookFrame,"BOTTOMRIGHT",-30,76)
  end
  panel:SetFrameLevel(SpellBookFrame:GetFrameLevel()+20);panel:EnableMouse(true)
  panel.bg=panel:CreateTexture(nil,"BACKGROUND");panel.bg:SetAllPoints();panel.bg:SetColorTexture(.85,.69,.44,1)
  panel:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});panel:SetBackdropBorderColor(.5,.34,.17,1)
  panel.list=MakeList(panel,40,10,PAL_BOOK)
  -- (the first time, the book hasn't laid the panel out yet: fill it again a moment later)
  panel:SetScript("OnShow",function()
   local ok,err=pcall(panel.list.Refresh)
   if not ok then Menu.Print("|cffd8b878trainer:|r list error:",err) end
   C_Timer.After(.05,function() if panel:IsShown() then panel.list.Refresh();panel.list.ScrollToNext() end end)
  end)
  -- (a new frame starts out shown, which wouldn't run the OnShow above: hide it, ShowPanel shows it)
  panel:Hide()
 end
 panel:Show()
end
-- (the book's tabs are a column of icons on its right edge: ours goes under the last one)
local function PlaceTab()
 if not tab then return end
 local last
 for i=1,12 do
  local b=_G["SpellBookSkillLineTab"..i]
  if b and b:IsShown() then last=b end
 end
 tab:ClearAllPoints()
 if last then tab:SetPoint("TOPLEFT",last,"BOTTOMLEFT",0,-17)
 else tab:SetPoint("TOPLEFT",SpellBookFrame,"TOPRIGHT",-4,-60) end
end
local function BuildTab()
 if tab or not SpellBookFrame then return end
 tab=CreateFrame("Button","RedsQOLTrainerTab",SpellBookFrame,"BackdropTemplate")
 tab:SetSize(36,36);tab:SetFrameLevel(SpellBookFrame:GetFrameLevel()+25)
 tab.redsLook=Look;UI.Box(tab);UI.RedEdge(tab,1)
 tab.icon=tab:CreateTexture(nil,"ARTWORK");tab.icon:SetPoint("TOPLEFT",4,-4);tab.icon:SetPoint("BOTTOMRIGHT",-4,4)
 tab.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09");tab.icon:SetTexCoord(.08,.92,.08,.92)
 tab.glow=tab:CreateTexture(nil,"HIGHLIGHT");tab.glow:SetAllPoints(tab.icon);tab.glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square");tab.glow:SetBlendMode("ADD")
 tab:SetScript("OnClick",function()
  if panel and panel:IsShown() then HidePanel();return end
  local ok,err=pcall(ShowPanel)
  if not ok then Menu.Print("|cffd8b878trainer:|r tab error:",err) end
 end)
 tab:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Trainer spells");GameTooltip:AddLine("What your class learns, by level.",1,1,1);GameTooltip:Show() end)
 tab:SetScript("OnLeave",function() GameTooltip:Hide() end)
 -- the game's own tabs bring its pages back
 for i=1,12 do
  local b=_G["SpellBookSkillLineTab"..i]
  if b then b:HookScript("OnClick",HidePanel) end
 end
 for i=1,8 do
  local b=_G["SpellBookFrameTabButton"..i]
  if b then b:HookScript("OnClick",HidePanel) end
 end
 SpellBookFrame:HookScript("OnHide",HidePanel)
 SpellBookFrame:HookScript("OnShow",function() C_Timer.After(0,PlaceTab) end)
 PlaceTab();C_Timer.After(0,PlaceTab)
end
-- Forever's spellbook is a different window (PlayerSpellsFrame, loaded when first opened): a "Trainer spells" button under it and the list in a
-- panel beside it, in Red's look. (Era's has the tab above.)
sidePanel,sideButton=nil,nil
local function BuildModern()
 local frame=_G.PlayerSpellsFrame
 local book=frame and (frame.SpellBookFrame or frame)
 if sidePanel or not book then return end
 sidePanel=CreateFrame("Frame","RedsQOLTrainerSide",UIParent,"BackdropTemplate")
 sidePanel.redsLook=Look;sidePanel:SetSize(390,math.max(460,frame:GetHeight() or 460));sidePanel:SetFrameStrata("DIALOG");sidePanel:SetToplevel(true)
 sidePanel:SetPoint("TOPLEFT",frame,"TOPRIGHT",8,0);sidePanel:EnableMouse(true)
 UI.Box(sidePanel);UI.TitleBar(sidePanel,30);UI.RedEdge(sidePanel,2)
 sidePanel.title=Text(sidePanel,"Trainer spells",15,UI.RED_TEXT);sidePanel.title:SetPoint("TOPLEFT",14,-8)
 local close=Button(sidePanel,"X",22,function() sidePanel:Hide() end);close:SetHeight(20);close:SetPoint("TOPRIGHT",-6,-5)
 sidePanel.list=MakeList(sidePanel,80,14)
 sidePanel:SetScript("OnShow",function(self)
  UI.Paper(self,Look(),1);UI.RedrawButtons(self);if UI.SkinTree then UI.SkinTree(self,Look()) end
  self.list.Refresh();C_Timer.After(.05,function() if self:IsShown() then self.list.Refresh() end end)
 end)
 sidePanel:Hide()
 local function Toggle() if sidePanel:IsShown() then sidePanel:Hide() else sidePanel:Show() end end
 -- A tab in the row of the game's own tabs across the top of the window (made from the game's tab template so it looks the same); if the
 -- window has no such row, a button under it instead.
 local tab
 -- An icon tab like the game's own spell tabs (the little square icons along the top left of the book), after the last of them, the same size.
 -- Those are found by what they are: square buttons of tab size sitting in the top strip of the window; the rightmost is the one to follow.
 -- It is placed again each time the book opens (the game makes its tabs late).
 local function LastIconTab()
  -- every small, roughly square, mouse-taking frame under the window's top strip, grouped by how high it sits: the game's spell tabs are the
  -- group of several the same size in one line (nothing else up there is), and the last of them is the one to follow
  local top=frame:GetTop()
  if not top then return end
  local groups={}
  local seen=0
  local function Scan(parent,depth)
   for _,c in ipairs({parent:GetChildren()}) do
    if c~=tab and c~=sidePanel and c.IsShown and c:IsShown() then
     local w,h,ct,l=c:GetWidth(),c:GetHeight(),c:GetTop(),c:GetLeft()
     if w and h and ct and l and w>=22 and w<=90 and math.abs(w-h)<=10 and top-ct>=26 and top-ct<=190 and c.IsMouseEnabled and c:IsMouseEnabled() then
      -- (26 down from the top or more: the title bar's own buttons, the arrow and the close X, are a pair of the same size too, and are not the tabs;
      -- the lit tab sits a little off the others, so heights are grouped loosely)
      seen=seen+1
      local key=math.floor(ct/16+.5)
      groups[key]=groups[key] or {}
      table.insert(groups[key],c)
     end
    end
    if depth<5 and c.GetChildren then Scan(c,depth+1) end
   end
  end
  Scan(frame,1)
  local best,bestCount,bestTop
  TS.scanInfo={candidates=seen,groups={}}
  for key,list in pairs(groups) do
   TS.scanInfo.groups[#TS.scanInfo.groups+1]=#list
   if #list>=3 then
    local ct=list[1]:GetTop()
    if not best or #list>bestCount or (#list==bestCount and ct>bestTop) then best,bestCount,bestTop=list,#list,ct end
   end
  end
  if not best then return end
  table.sort(best,function(a,b) return (a:GetLeft() or 0)<(b:GetLeft() or 0) end)
  return best[#best],best[#best-1]
 end local function PlaceTab()
  if not tab then return end
  local last,prev=LastIconTab()
  tab:ClearAllPoints()
  if last then
   tab:SetSize(last:GetWidth(),last:GetHeight())
   local gap=6
   if prev and prev:GetRight() and last:GetLeft() then gap=math.max(2,math.min(16,last:GetLeft()-prev:GetRight())) end
   tab:SetPoint("TOPLEFT",last,"TOPRIGHT",gap,0)
  else
   local down=44
   local sb
   local function FindBox(parent,depth)
    for _,c in ipairs({parent:GetChildren()}) do
     if not sb and c.IsShown and c:IsShown() and c.GetObjectType and c:GetObjectType()=="EditBox" and c:GetTop() then sb=c;return end
     if depth<5 and c.GetChildren then FindBox(c,depth+1) end
    end
   end
   pcall(FindBox,frame,1)
   if sb and frame:GetTop() then down=math.max(20,math.min(90,frame:GetTop()-sb:GetTop())) end
   tab:SetSize(37,37)
   tab:SetPoint("TOPLEFT",frame,"TOPLEFT",207,-down)
  end
 end do
  local ok,made=pcall(CreateFrame,"Button","RedsQOLTrainerSpellsTab",frame,"BackdropTemplate")
  if ok and made then
   tab=made;tab:SetSize(42,42);tab:SetFrameStrata("HIGH")
   tab.redsLook=Look;UI.Box(tab);UI.RedEdge(tab,1)
   tab.icon=tab:CreateTexture(nil,"ARTWORK");tab.icon:SetPoint("TOPLEFT",3,-3);tab.icon:SetPoint("BOTTOMRIGHT",-3,3)
   tab.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09");tab.icon:SetTexCoord(.08,.92,.08,.92)
   -- the game's tab is lit with a yellow frame while it is the one showing: this one is while the trainer list is open
   tab.on=tab:CreateTexture(nil,"OVERLAY");tab.on:SetAllPoints();tab.on:SetColorTexture(1,.82,0,0);tab.on:Hide()
   tab.sel=CreateFrame("Frame",nil,tab,"BackdropTemplate");tab.sel:SetAllPoints()
   tab.sel:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2});tab.sel:SetBackdropBorderColor(1,.82,0,1);tab.sel:Hide()
   tab.glow=tab:CreateTexture(nil,"HIGHLIGHT");tab.glow:SetAllPoints(tab.icon);tab.glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square");tab.glow:SetBlendMode("ADD")
   tab:SetScript("OnClick",Toggle)
   tab:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Trainer spells");GameTooltip:AddLine("What your class learns, by level.",1,1,1);GameTooltip:Show() end)
   tab:SetScript("OnLeave",function() GameTooltip:Hide() end)
   sidePanel:HookScript("OnShow",function() tab.sel:Show() end)
   sidePanel:HookScript("OnHide",function() tab.sel:Hide() end)
   PlaceTab()
   frame:HookScript("OnShow",function() C_Timer.After(0,PlaceTab);C_Timer.After(.3,PlaceTab);C_Timer.After(1,PlaceTab) end)
   book:HookScript("OnShow",function() C_Timer.After(0,PlaceTab) end)
   -- (once a session, a moment after the book first opens: what the search for the game's tabs saw, in the chat, for when the tab is not where it should be)
   C_Timer.After(2,PlaceTab)
   TS.PlaceModernTab=PlaceTab
   TS.LastIconTab=LastIconTab
   TS.TabInfo=function()
    local last,prev=LastIconTab()
    local fl,ft=frame:GetLeft(),frame:GetTop()
    local function Describe(b)
     if not b then return "none" end
     return string.format("%s  %dx%d at %d right, %d down",(b.GetDebugName and b:GetDebugName()) or (b.GetName and b:GetName()) or "?",b:GetWidth() or 0,b:GetHeight() or 0,(b:GetLeft() or 0)-(fl or 0),(ft or 0)-(b:GetTop() or 0))
    end
    local si=TS.scanInfo
    -- the window's named parts (how the game built it), for finding the tabs by name
    local function Keys(owner,label)
     if type(owner)~="table" then return end
     local names={}
     for k,v in pairs(owner) do
      if type(k)=="string" and type(v)=="table" and v.GetObjectType and v.GetWidth then
       local ok,w,h,shown=pcall(function() return math.floor(v:GetWidth() or 0),math.floor(v:GetHeight() or 0),v:IsShown() end)
       if ok and (k:lower():find("tab") or k:lower():find("categor") or k:lower():find("spec")) then
        local extra=""
        if type(v.tabs)=="table" then local n=0;for _ in pairs(v.tabs) do n=n+1 end;extra=" tabs="..n end
        names[#names+1]=string.format("%s=%s %dx%d %s%s",k,v:GetObjectType(),w,h,shown and "shown" or "hidden",extra)
       end
      end
     end
     table.sort(names)
     Menu.Print("|cffd8b878trainer tab:|r",label,#names>0 and table.concat(names,"; ") or "(no tab-like parts)")
    end
    Keys(frame,"window parts:");Keys(book,"book parts:")
    local seenText="scan: "..(si and (si.candidates.." candidates in groups of "..table.concat(si.groups,",")) or "not run")
    return "follows: "..Describe(last),"before it: "..Describe(prev),"our tab: "..Describe(tab),seenText
   end
  end
 end if tab then sideButton=tab
 else
  sideButton=Button(UIParent,"Trainer spells",150,Toggle)
  sideButton:SetHeight(26);sideButton:SetFrameStrata("DIALOG");sideButton:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",22,2)
 end
 -- only while the spellbook itself is showing
 local function Sync() sideButton:SetShown(book:IsVisible());if not book:IsVisible() then sidePanel:Hide() end end
 book:HookScript("OnShow",Sync);book:HookScript("OnHide",Sync);frame:HookScript("OnHide",Sync)
 Sync()
end
local modernHooked
local function TryModern()
 -- (no tab on WoW Forever's spellbook for now: the list opens from Red's menu, Quality of life > Trainer spells, and with /rtrainer)
 if true then return end
 if not (Menu.db and Opt().tab and _G.PlayerSpellsFrame) then return end
 pcall(BuildModern)
 -- (the book's own page may be made when the window first opens: try again then)
 if not sidePanel and not modernHooked then modernHooked=true;_G.PlayerSpellsFrame:HookScript("OnShow",function() pcall(BuildModern) end) end
end
-- Events -----------------------------------------------------------------------------------------------------------------------
local ev=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","TRAINER_SHOW","TRAINER_UPDATE","PLAYER_LEVEL_UP"}) do pcall(ev.RegisterEvent,ev,e) end
local timer
ev:SetScript("OnEvent",function(_,event,level)
 Menu:Initialize()
 if event=="PLAYER_LOGIN" then
  if Opt().tab then
   -- (Forever's own spellbook window is preferred whenever the client has one, even if an old-style SpellBookFrame name also exists)
   if _G.PlayerSpellsFrame or FOREVER then TryModern() elseif SpellBookFrame then BuildTab() end
   -- (the window is made when first opened on Forever: look again a few times in case nothing else tells us)
   for _,delay in ipairs({2,6,15}) do C_Timer.After(delay,function() if Menu.db and Opt().tab and _G.PlayerSpellsFrame and not sidePanel then pcall(TryModern) end end) end
   -- (if the book isn't there yet, the first time it's opened)
   for _,fn in ipairs({"ToggleSpellBook","ShowUIPanel"}) do
    if _G[fn] then pcall(hooksecurefunc,fn,function() if Opt().tab and SpellBookFrame and not tab then BuildTab() end end) end
   end
  end
 elseif event=="PLAYER_LEVEL_UP" then
  if not Opt().notify then return end
  level=tonumber(level)
  local names={}
  for _,e in ipairs(List()) do
   if e.state~="learned" and e.level==level then names[#names+1]=e.name..(e.rank~="" and (" "..e.rank) or "") end
  end
  if #names>0 then Menu:Say("New spells at level "..level..": "..table.concat(names,", ")..". /rtrainer lists them all.") end
 else
  if timer then return end
  timer=C_Timer.NewTimer(.4,function() timer=nil;pcall(Capture);if win and win:IsShown() then win.list.Refresh() end;if panel and panel:IsShown() then panel.list.Refresh() end end)
 end
end)
-- (on versions where the spellbook is loaded on demand)
local late=CreateFrame("Frame");late:RegisterEvent("ADDON_LOADED")
late:SetScript("OnEvent",function(_,_,name)
 if name=="Blizzard_SpellBook" or name=="Blizzard_Spellbook" or name=="Blizzard_SpellBookUI" or name=="Blizzard_PlayerSpells" then
  if Menu.db and Opt().tab then if _G.PlayerSpellsFrame or FOREVER then TryModern() elseif SpellBookFrame then BuildTab() end end
 end
end)

-- The Quality of life section's button
local build=Menu.BuildQoLPage
if build then
 function Menu:BuildQoLPage(page)
  build(self,page)
  local QoL=Menu.QoL
  local section=QoL and QoL.sections and QoL.sections.trainer
  if not section then return end
  local b=Button(section.options,"Open the spell list",180,function() TS.Open() end);b:SetHeight(26);b:SetPoint("TOPLEFT",16,-150)
  local note=Text(section.options,"Shows what your class learns at each level. It also sits as a Trainer tab on the spellbook (a /reload applies that switch). Type /rtrainer any time. Costs fill in as you visit trainers.",11,UI.MUTED)
  note:SetPoint("TOPLEFT",16,-190);note:SetWidth(330);note:SetJustifyH("LEFT")
 end
end

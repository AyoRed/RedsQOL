local M={extraMovables={}};RedsQOL=M
local function Copy(v) if type(v)~="table" then return v end;local t={};for k,x in pairs(v) do t[k]=Copy(x) end;return t end
function M:Initialize()
 if self.db then return end
 RedsQOLDB=type(RedsQOLDB)=="table" and RedsQOLDB or {};self.db=RedsQOLDB
 self.db.qol=type(self.db.qol)=="table" and self.db.qol or {}
 if not self.db.campfireImported then
  local old=_G.RedsCampfireBuffsDB
  if type(old)=="table" then self.db.qol.campfire=Copy(old.campfire);self.db.campfirePos=Copy(old.campfirePos);self.db.minimapAngle=old.minimapAngle end
  self.db.campfireImported=true
 end
 self.db.menuLook="bronze"
end
function M:Say(t) print("|cffffad45Reds QOL:|r "..t) end
M.Print=print
function M.IsForever() return (select(4,GetBuildInfo()) or 0)>=16000 end
function M.Coin(n) return string.format("%dg %ds %dc",math.floor(n/10000),math.floor(n/100)%100,n%100) end
function M:MinimapSettings() self:Initialize();self.db.map=self.db.map or {enabled=false,time24=false};return self.db.map end
function M:ChatSettings() return {enabled=false,quick=false} end
local UI={GOLD={1,.7,.3},RED_TEXT={1,.65,.25},MUTED={.72,.67,.6},WHITE={1,1,1},WHITE_TEXTURE="Interface\\Buttons\\WHITE8X8"};M.UI=UI
function UI.Text(parent,text,size,color)
 local t=parent:CreateFontString(nil,"OVERLAY");t:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size or 12);t:SetText(text)
 t:SetTextColor(unpack(color or UI.WHITE));return t
end
function UI.Box(f) f:SetBackdrop({bgFile=UI.WHITE_TEXTURE,edgeFile=UI.WHITE_TEXTURE,edgeSize=2});f:SetBackdropColor(.055,.038,.028,.97);f:SetBackdropBorderColor(.65,.34,.12,1) end
function UI.RedEdge() end
function UI.TitleBar(f,height)
 local t=f:CreateTexture(nil,"BACKGROUND");t:SetPoint("TOPLEFT",2,-2);t:SetPoint("TOPRIGHT",-2,-2);t:SetHeight(height);t:SetColorTexture(.2,.09,.025,.65)
end
function UI.Paper(f,look,alpha) if f.SetBackdropColor then f:SetBackdropColor(.055,.038,.028,alpha or .97) end end
function UI.RedrawButtons() end
function UI.Button(parent,text,width,click)
 local b=CreateFrame("Button",nil,parent,"BackdropTemplate");b:SetSize(width,26);UI.Box(b);b:SetBackdropColor(.18,.085,.035,1)
 b.label=UI.Text(b,text,12,UI.GOLD);b.label:SetPoint("CENTER")
 b:SetScript("OnEnter",function(self) self:SetBackdropColor(.32,.14,.045,1) end)
 b:SetScript("OnLeave",function(self) self:SetBackdropColor(.18,.085,.035,1) end)
 b:SetScript("OnClick",click);return b
end
function UI.CenterOffset(f)
 local x,y=f:GetCenter();local px,py=UIParent:GetCenter();local r=f:GetEffectiveScale()/UIParent:GetEffectiveScale();return x*r-px,y*r-py
end
function M:MovableFrame(key) local d=self.extraMovables[key];return d and d.frame() end
function M:SaveBarPosition(key,x,y)
 local d=self.extraMovables[key];if not d then return end;d.save(x,y)
 local f=d.frame();if f then f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"CENTER",x,y) end
end
function M:BeginBarDrag(key)
 if not self.editModeActive or InCombatLockdown() then return end
 local f=self:MovableFrame(key);if not f then return end
 f:SetMovable(true);f:SetClampedToScreen(true);f:StartMoving();self.drag={index=key,frame=f}
 if self.Mover then self.Mover.SelectRed(key) end
end
function M:EndBarDrag()
 local d=self.drag;if not d then return end;d.frame:StopMovingOrSizing();local x,y=UI.CenterOffset(d.frame);self.drag=nil;self:SaveBarPosition(d.index,x,y)
end
function UI.BeginDrag(key) M:BeginBarDrag(key) end
function UI.EndDrag() M:EndBarDrag() end
function M:ToggleMove() self:EndBarDrag();self.Mover.Place(not self.editModeActive) end
function M:ToggleOptions() if self.OpenOptions then self.OpenOptions() end end
function M:ClosePositionPanel() if self.positionPanel then self.positionPanel:Hide() end end
function M:RefreshPositionPanel()
 local p=self.positionPanel;if not p or not p.target then return end
 local x,y=p.target.get();p.x:SetText(string.format("%.0f",x));p.y:SetText(string.format("%.0f",y))
end
function M:OpenPositionPanel(target)
 if not self.positionPanel then
  local p=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");self.positionPanel=p;p:SetSize(320,145);p:SetPoint("CENTER",0,-180);p:SetFrameStrata("FULLSCREEN_DIALOG");UI.Box(p)
  p.title=UI.Text(p,"Position",14,UI.GOLD);p.title:SetPoint("TOPLEFT",14,-12)
  for i,key in ipairs({"x","y"}) do local e=CreateFrame("EditBox",nil,p,"InputBoxTemplate");p[key]=e;e:SetSize(100,24);e:SetPoint("TOPLEFT",22+(i-1)*145,-48);e:SetAutoFocus(false);local l=UI.Text(p,key:upper(),11);l:SetPoint("BOTTOMLEFT",e,"TOPLEFT",0,3) end
  local apply=UI.Button(p,"Apply",85,function() local x,y=tonumber(p.x:GetText()),tonumber(p.y:GetText());if x and y then p.target.set(x,y) end end);apply:SetPoint("BOTTOMLEFT",12,12)
  local reset=UI.Button(p,"Reset",85,function() if p.target.reset then p.target.reset() else p.target.set(0,0) end;M:RefreshPositionPanel() end);reset:SetPoint("LEFT",apply,"RIGHT",8,0)
  local close=UI.Button(p,"Close",85,function() p:Hide() end);close:SetPoint("LEFT",reset,"RIGHT",8,0)
 end
 self.positionPanel.target=target;self.positionPanel.title:SetText(target.title or "Position");self:RefreshPositionPanel();self.positionPanel:Show()
end
-- The separate campfire addon is superseded only while Reds QOL is enabled.
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function()
 M:Initialize()
 local old=_G.RedsCampfireBuffs
 if old and old.db then
  old:QoLSettings().campfire.enabled=false;old.editModeActive=false
  if old.ApplyCampfire then old:ApplyCampfire() end
  for _,f in ipairs({old.minimapButton,old.options,old.moveBar,_G.RedsCampfireBuffsCampfire and _G.RedsCampfireBuffsCampfire.mover}) do if f then f:Hide() end end
 end
end)

-- A persistent one-click reload button, positioned only through Reds QOL's mover.
do
local M=RedsQOL
local button
local function Place()
 if not button then return end
 button:ClearAllPoints()
 local p=M.db.reloadPos
 if type(p)=="table" and type(p.x)=="number" and type(p.y)=="number" then button:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y)
 else button:SetPoint("BOTTOM",UIParent,"BOTTOM",0,110) end
end
function M:ApplyReloadButton()
 if InCombatLockdown() then return end
 local o=self:QoLSettings().reload
 if not o.enabled then if button then UnregisterStateDriver(button,"visibility");button:Hide();button.mover:Hide() end;return end
 if not button then
  button=CreateFrame("Button","RedsQOLQuickReload",UIParent,"SecureActionButtonTemplate,BackdropTemplate")
  button:SetSize(112,30);M.UI.Box(button);button:SetBackdropColor(.18,.085,.035,1)
  button.label=M.UI.Text(button,"Reload UI",12,M.UI.GOLD);button.label:SetPoint("CENTER")
  button:RegisterForClicks("AnyUp","AnyDown");button:SetAttribute("type","macro");button:SetAttribute("macrotext","/reload")
  M.reloadButton=button;button:SetHeight(30);button:SetFrameStrata("MEDIUM");button:SetClampedToScreen(true)
  local enter=button:GetScript("OnEnter");local leave=button:GetScript("OnLeave")
  button:SetScript("OnEnter",function(self) if enter then enter(self) end;GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Reload UI",1,.65,.25);GameTooltip:AddLine("Click to reload the game interface.",1,1,1);GameTooltip:AddLine("Reposition with Reds QOL's unlock button.",.7,.7,.7);GameTooltip:Show() end)
  button:SetScript("OnLeave",function(self) if leave then leave(self) end;GameTooltip:Hide() end)
  local mover=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");button.mover=mover;mover:SetAllPoints(button);mover:SetFrameStrata("DIALOG");mover:EnableMouse(true);M.UI.Box(mover)
  mover:SetBackdropColor(.24,.12,.025,.6);mover:SetBackdropBorderColor(1,.6,.15,1)
  local label=M.UI.Text(mover,"Drag to move",12);label:SetPoint("CENTER")
  mover:SetScript("OnMouseDown",function(_,key) if key=="LeftButton" then M.UI.BeginDrag("reload") end end)
  mover:SetScript("OnMouseUp",function(_,key) if key=="LeftButton" then M.UI.EndDrag() end end)
  mover:Hide()
 end
 Place();RegisterStateDriver(button,"visibility","[combat] hide; show");button:Show();button.mover:SetShown(self.editModeActive and true or false)
end
M.extraMovables.reload={frame=function() return button and button:IsShown() and button end,save=function(x,y) M.db.reloadPos={x=x,y=y};Place() end}
local ev=CreateFrame("Frame");ev:RegisterEvent("PLAYER_LOGIN");ev:RegisterEvent("PLAYER_REGEN_ENABLED");ev:SetScript("OnEvent",function() M:ApplyReloadButton() end)
end

-- Only the amber halo fades; the quest icon remains readable throughout the pulse.
function RedsQOL.UI.AddPinPulse(pin)
 local halo=pin:CreateTexture(nil,"BACKGROUND")
 halo:SetTexture("Interface\\AddOns\\RedsQOL\\Media\\Ring");halo:SetSize(38,38);halo:SetPoint("CENTER",0,-2);halo:SetVertexColor(1,.6,.15);halo:SetAlpha(.2)
 local pulse=halo:CreateAnimationGroup();pulse:SetLooping("BOUNCE")
 local fade=pulse:CreateAnimation("Alpha");fade:SetFromAlpha(.2);fade:SetToAlpha(.65);fade:SetDuration(.85);fade:SetSmoothing("IN_OUT")
 pin:HookScript("OnShow",function() pulse:Play() end)
 pin:HookScript("OnHide",function() pulse:Stop() end)
 pulse:Play()
end
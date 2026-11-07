local M=RedsQOL
local function Build()
 M:Initialize()
 local b=CreateFrame("Button","RedsQOLMinimapButton",Minimap);M.minimapButton=b
 b:SetSize(34,34);b:SetFrameStrata("MEDIUM");b:SetFrameLevel(Minimap:GetFrameLevel()+8)
 b:RegisterForClicks("LeftButtonUp","RightButtonUp");b:RegisterForDrag("LeftButton")
 local bg=b:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.055,.035,.02,1)
 local icon=b:CreateTexture(nil,"ARTWORK");icon:SetTexture("Interface\\AddOns\\RedsQOL\\Media\\CampFire");icon:SetPoint("TOPLEFT",4,-4);icon:SetPoint("BOTTOMRIGHT",-4,4)
 local border=b:CreateTexture(nil,"OVERLAY");border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");border:SetSize(56,56);border:SetPoint("TOPLEFT")
 local highlight=b:CreateTexture(nil,"HIGHLIGHT");highlight:SetAllPoints();highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");highlight:SetBlendMode("ADD")
 local dragging=false
 local function Place()
  local angle=math.rad(tonumber(M.db.minimapAngle) or 225)
  local x,y=math.cos(angle),math.sin(angle)
  local shape=GetMinimapShape and GetMinimapShape() or "ROUND"
  local round={ROUND={true,true,true,true},SQUARE={false,false,false,false},["CORNER-TOPLEFT"]={false,false,false,true},["CORNER-TOPRIGHT"]={false,false,true,false},["CORNER-BOTTOMLEFT"]={false,true,false,false},["CORNER-BOTTOMRIGHT"]={true,false,false,false},["SIDE-LEFT"]={false,true,false,true},["SIDE-RIGHT"]={true,false,true,false},["SIDE-TOP"]={false,false,true,true},["SIDE-BOTTOM"]={true,true,false,false}}
  local q=(x<0 and 1 or 0)+(y>0 and 2 or 0)+1
  if round[shape] and not round[shape][q] then local scale=math.max(math.abs(x),math.abs(y));x=x/scale;y=y/scale end
  b:ClearAllPoints();b:SetPoint("CENTER",Minimap,"CENTER",x*(Minimap:GetWidth()/2+8),y*(Minimap:GetHeight()/2+8))
 end
 b:SetScript("OnDragStart",function() dragging=true;GameTooltip:Hide() end)
 b:SetScript("OnDragStop",function() dragging=false end)
 b:SetScript("OnUpdate",function() if dragging then
  local x,y=GetCursorPosition();local scale=Minimap:GetEffectiveScale();local mx,my=Minimap:GetCenter()
  M.db.minimapAngle=math.deg(math.atan2(y/scale-my,x/scale-mx));Place()
 end end)
 b:SetScript("OnClick",function(_,button) if button=="RightButton" then M:ToggleMove() else M.OpenOptions() end end)
 b:SetScript("OnEnter",function() if dragging then return end;GameTooltip:SetOwner(b,"ANCHOR_LEFT");GameTooltip:AddLine("Reds QOL",1,.65,.25);GameTooltip:AddLine("Left-click: settings",1,1,1);GameTooltip:AddLine("Right-click: unlock / lock QOL displays",1,1,1);GameTooltip:AddLine("Drag: move minimap button",.7,.7,.7);GameTooltip:Show() end)
 b:SetScript("OnLeave",function() GameTooltip:Hide() end)
 Place()
end
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN");login:SetScript("OnEvent",Build)

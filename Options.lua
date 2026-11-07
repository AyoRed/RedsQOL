local M=RedsQOL
local sections={{"range","Attack range"},{"cursor","Mouse cursor"},{"sparkles","Loot sparkles"},{"trainer","Trainer spells"},{"campfire","Campfire"},{"topbar","Top bar"},{"mover","Move frames"}}
local panel,scroll,content,current,rows
local function Get(path)
 local value=M:QoLSettings();for key in path:gmatch("[^.]+") do value=value[key] end;return value
end
local function Set(path,value)
 local t=M:QoLSettings();local keys={};for k in path:gmatch("[^.]+") do keys[#keys+1]=k end
 for i=1,#keys-1 do t=t[keys[i]] end;t[keys[#keys]]=value
end
local Draw
local function Changed(rebuild)
 M.QoL.Changed();if rebuild then Draw(current) end
end
Draw=function(key)
 current=key
 for _,f in ipairs(rows or {}) do f:Hide();f:SetParent(nil) end;rows={}
 local spec=key=="mover" and M.Mover.Spec() or M.QOLSpecs[key]
 panel.sectionTitle:SetText(spec.title);scroll:SetVerticalScroll(0)
 for k,b in pairs(panel.tabs) do b:SetBackdropBorderColor(unpack(k==key and {1,.65,.25,1} or {.4,.24,.12,1})) end
 local y=0
 local ctx={Settings=function() return M:QoLSettings() end,Changed=function() Changed(false) end}
 for _,item in ipairs(spec) do
  local option=item
  if not option.when or option.when(M:QoLSettings()) then
   local row=CreateFrame("Frame",nil,content);rows[#rows+1]=row;row:SetPoint("TOPLEFT",0,-y);row:SetSize(540,option.height or 38)
   local function read() return option.get and option.get(M:QoLSettings()) or (option.path and Get(option.path)) end
   local function write(v) if option.set then option.set(M:QoLSettings(),v) else Set(option.path,v) end end
   local kind=option.type
   if kind=="header" or kind=="subheader" then
    local label=M.UI.Text(row,option.label,kind=="header" and 14 or 11,M.UI.GOLD);label:SetPoint("TOPLEFT",4,-9);label:SetWidth(510);label:SetJustifyH("LEFT")
   elseif kind=="check" then
    local b=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");b:SetPoint("LEFT",0,0);b:SetChecked(read());local label=M.UI.Text(b,option.label,12);label:SetPoint("LEFT",b,"RIGHT",2,0);label:SetWidth(490);label:SetJustifyH("LEFT")
    b:SetScript("OnClick",function(self) write(self:GetChecked() and true or false);Changed(true) end)
   elseif kind=="slider" then
    local label=M.UI.Text(row,"",12);label:SetPoint("TOPLEFT",4,-6)
    local s=CreateFrame("Slider",nil,row,"OptionsSliderTemplate");s:SetPoint("TOPRIGHT",-12,-5);s:SetSize(245,16);s:SetMinMaxValues(option.min,option.max);s:SetValueStep(option.step);s:SetObeyStepOnDrag(true);s:SetValue(read())
    local function format(v) return option.percent and string.format("%d%%",v*100+.5) or string.format("%.2f",v):gsub("0+$",""):gsub("%.$","") end
    label:SetText(option.label..": "..format(read()));label:SetWidth(260);label:SetJustifyH("LEFT")
    s:SetScript("OnValueChanged",function(_,v) v=math.floor(v/option.step+.5)*option.step;write(v);label:SetText(option.label..": "..format(v));Changed(false) end)
   elseif kind=="choice" or kind=="cycle" then
    local label=M.UI.Text(row,option.label,12);label:SetPoint("LEFT",4,0)
    local function entry(pair) if kind=="cycle" then return pair[1],pair[2] else return pair[2],pair[1] end end
    local text="";for _,pair in ipairs(option.options) do local value,name=entry(pair);if value==read() then text=name end end
    local b=M.UI.Button(row,text.."  >",240,function()
     local at=0;for i,pair in ipairs(option.options) do local v=entry(pair);if v==read() then at=i end end
     local value=entry(option.options[at%#option.options+1]);write(value);Changed(true)
    end);b:SetPoint("RIGHT",-12,0)
   elseif kind=="color" then
    local b=M.UI.Button(row,option.label,250,function()
     local c=read();local old={unpack(c)}
     ColorPickerFrame:SetupColorPickerAndShow({r=c[1],g=c[2],b=c[3],hasOpacity=false,swatchFunc=function() local r,g,b=ColorPickerFrame:GetColorRGB();write({r,g,b});Changed(false) end,cancelFunc=function() write(old);Changed(false) end})
    end);b:SetPoint("LEFT",4,0)
   elseif kind=="custom" then local refresh=option.build(row,4,ctx);if refresh then refresh() end end
   y=y+(option.height or 38)
  end
 end
 content:SetHeight(math.max(y,20))
end
local function Open(key)
 M:Initialize()
 if panel then
  if key then panel:Show();Draw(key) else panel:SetShown(not panel:IsShown());if panel:IsShown() then Draw(current) end end
  return
 end
 panel=CreateFrame("Frame","RedsQOLOptions",UIParent,"BackdropTemplate");M.frame=panel;panel:SetSize(780,710);panel:SetPoint("CENTER");panel:SetFrameStrata("DIALOG");M.UI.Box(panel);panel:EnableMouse(true);panel:SetMovable(true);panel:SetClampedToScreen(true)
 panel:RegisterForDrag("LeftButton");panel:SetScript("OnDragStart",panel.StartMoving);panel:SetScript("OnDragStop",panel.StopMovingOrSizing);tinsert(UISpecialFrames,"RedsQOLOptions")
 local art=panel:CreateTexture(nil,"ARTWORK");art:SetTexture("Interface\\AddOns\\RedsQOL\\Media\\CampFire");art:SetSize(48,48);art:SetPoint("TOPLEFT",18,-14)
 local title=M.UI.Text(panel,"Reds QOL",24,M.UI.RED_TEXT);title:SetPoint("TOPLEFT",78,-18)
 local subtitle=M.UI.Text(panel,"Quality of life. Your way.",12);subtitle:SetPoint("TOPLEFT",78,-48)
 local close=M.UI.Button(panel,"X",26,function() panel:Hide() end);close:SetPoint("TOPRIGHT",-10,-10)
 local move=M.UI.Button(panel,"Unlock & move QOL displays",220,function() M:ToggleMove() end);move:SetPoint("TOPRIGHT",-30,-48)
 panel.tabs={}
 for i,def in ipairs(sections) do local k=def[1];local b=M.UI.Button(panel,def[2],166,function() Draw(k) end);panel.tabs[k]=b;b:SetHeight(36);b:SetPoint("TOPLEFT",18,-96-(i-1)*44) end
 local line=panel:CreateTexture(nil,"BACKGROUND");line:SetColorTexture(.65,.34,.12,.45);line:SetWidth(1);line:SetPoint("TOPLEFT",198,-86);line:SetPoint("BOTTOMLEFT",198,22)
 panel.sectionTitle=M.UI.Text(panel,"",18,M.UI.GOLD);panel.sectionTitle:SetPoint("TOPLEFT",218,-92)
 scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",212,-130);scroll:SetPoint("BOTTOMRIGHT",-32,44)
 content=CreateFrame("Frame",nil,scroll);content:SetSize(540,20);scroll:SetScrollChild(content)
 local hint=M.UI.Text(panel,"Minimap: left-click settings | right-click unlock / lock QOL displays",11,M.UI.MUTED);hint:SetPoint("BOTTOMLEFT",218,18)
 Draw(key or "campfire")
end
M.OpenOptions=Open
function M:RefreshQoLPage() end
SLASH_REDSQOL1="/rqol";SLASH_REDSQOL2="/redsqol"
SlashCmdList.REDSQOL=function(msg) if (msg or ""):lower()=="move" then M:ToggleMove() else Open() end end
SLASH_REDSCAMPFIRE1="/rcamp";SLASH_REDSCAMPFIRE2="/redscampfire"
SlashCmdList.REDSCAMPFIRE=function(msg) if (msg or ""):lower()=="move" then M:ToggleMove() else Open("campfire") end end

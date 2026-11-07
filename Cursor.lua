-- Red's cursor trail: effects left behind the mouse cursor.
-- Settings live with the cursor ring on Quality of life > Mouse cursor (db.qol.trail).
-- Trails are particles (sparkles, fairy dust, comet, stars, hearts, embers) or line segments (ribbon, neon).
local Menu=_G.RedsQOL
local MEDIA="Interface\\AddOns\\RedsQOL\\Media\\"
local FX={};Menu.CursorFX=FX

-- Trail styles: texture and motion. size is a share of the Thickness setting; life a share of Length.
local STYLES={
 sparkle={texture="TrailSparkle",size=1.1,life=1,drift=18,twinkle=true,shrink=.25},
 fairy={texture="TrailSparkle",size=.55,life=1.3,drift=45,lift=35,gravity=-140,twinkle=true,shrink=.4},
 comet={texture="TrailSoft",size=1.2,life=1,shrink=0},
 stars={texture="TrailStar",size=.9,life=1,drift=14,spin=3,shrink=.2},
 hearts={texture="TrailHeart",size=.9,life=1.2,drift=8,lift=28,sway=true,shrink=.3},
 embers={texture="TrailSoft",size=.5,life=1.2,drift=12,lift=55,sway=true,flicker=true,shrink=.2},
 ribbon={line=true},
 neon={line=true,neon=true},
}
FX.STYLES={{"sparkle","Sparkles"},{"fairy","Fairy dust"},{"ribbon","Ribbon"},{"neon","Neon"},{"comet","Comet"},
 {"stars","Stars"},{"hearts","Hearts"},{"embers","Embers"}}

local function Settings() return Menu:QoLSettings() end
local function HSV(h)
 local i=math.floor(h*6)%6;local f=h*6-math.floor(h*6);local q,t=1-f,f
 if i==0 then return 1,t,0 elseif i==1 then return q,1,0 elseif i==2 then return 0,1,t
 elseif i==3 then return 0,q,1 elseif i==4 then return t,0,1 end
 return 1,0,q
end
local function ClassColor()
 local _,class=UnitClass("player");local c=class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
 if c then return c.r,c.g,c.b end
 return 1,.82,.2
end
-- Cursor position in UIParent's units.
local function CursorXY()
 local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
 return x/scale,y/scale
end
-- The trail's pieces sit right under the cursor; on clients where textures and lines can take the mouse, that would catch every hover
-- and click (the map's markers, buttons) before it reached them. They never take it.
local function NoMouse(r)
 if r.EnableMouse then r:EnableMouse(false) end
 if r.SetMouseClickEnabled then r:SetMouseClickEnabled(false) end
 if r.SetMouseMotionEnabled then r:SetMouseMotionEnabled(false) end
 return r
end

-- Hidden (no per-frame work) until something is switched on; shown at login by Menu:ApplyCursorFX.
local fx=CreateFrame("Frame",nil,UIParent);fx:SetFrameStrata("TOOLTIP");fx:SetFrameLevel(9000);fx:SetAllPoints();NoMouse(fx);fx:Hide()
FX.frame=fx

-- Trail ---------------------------------------------------------------------------------------------------------
local MAX_PARTICLES,MAX_POINTS=200,120
-- Slow movement still leaves a steady trail: while the mouse moves, something is added at least this often.
local MIN_INTERVAL=.03
local particles,free={},{}
local points={} -- ribbon and neon: {x,y,born,hue}
local lines={}
local lastX,lastY,carry,hueStep=nil,nil,0,0
local lastEmit=0
local headX,headY -- the cursor, where the line's newest segment ends
local canLine=fx.CreateLine~=nil

local function TrailColor(t,age,life,hue)
 if t.colorMode=="rainbow" then return HSV(((GetTime()*.25)+hue)%1) end
 if t.colorMode=="class" then return ClassColor() end
 if t.colorMode=="two" then
  local k=math.min(1,age/math.max(life,.01));local a,b=t.color,t.color2
  return a[1]+(b[1]-a[1])*k,a[2]+(b[2]-a[2])*k,a[3]+(b[3]-a[3])*k
 end
 return t.color[1],t.color[2],t.color[3]
end
local function Particle(t,style,x,y)
 if #particles>=MAX_PARTICLES then return end
 local p=table.remove(free)
 if not p then p={tex=NoMouse(fx:CreateTexture(nil,"ARTWORK"))} end
 local tex=p.tex
 tex:SetTexture(MEDIA..style.texture);tex:SetBlendMode(t.glow and "ADD" or "BLEND");tex:Show()
 local drift=(style.drift or 0)*t.spread
 p.x,p.y=x,y
 p.vx=(math.random()*2-1)*drift
 p.vy=(math.random()*2-1)*drift+(style.lift or 0)*(.6+math.random()*.6)
 p.gravity=style.gravity or 0
 p.age=0;p.life=t.length*style.life*(.75+math.random()*.5)
 p.size=t.size*style.size*(.7+math.random()*.6)
 p.rot=style.spin and math.random()*6.28 or (style.texture=="TrailSparkle" and (math.random()<.5 and 0 or .785) or 0)
 p.spin=style.spin and (math.random()*2-1)*style.spin or 0
 p.phase=math.random()*6.28;p.hue=hueStep;p.style=style
 hueStep=(hueStep+.015)%1
 particles[#particles+1]=p
end
local function UpdateParticles(t,dt)
 local now=GetTime()
 for i=#particles,1,-1 do
  local p=particles[i];p.age=p.age+dt
  if p.age>=p.life then
   p.tex:Hide();free[#free+1]=p;table.remove(particles,i)
  else
   local s=p.style;local k=p.age/p.life
   p.vy=p.vy+p.gravity*dt
   p.x=p.x+p.vx*dt+(s.sway and math.sin(now*3+p.phase)*12*dt or 0);p.y=p.y+p.vy*dt
   p.rot=p.rot+p.spin*dt
   local size=p.size*(1-k*(1-(s.shrink or 0)))
   local alpha=t.alpha*(1-k)
   if s.twinkle then alpha=alpha*(.75+.25*math.sin(p.age*18+p.phase)) end
   if s.flicker then alpha=alpha*(.7+.3*math.random()) end
   local tex=p.tex
   tex:ClearAllPoints();tex:SetPoint("CENTER",UIParent,"BOTTOMLEFT",p.x,p.y);tex:SetSize(size,size)
   if tex.SetRotation then tex:SetRotation(p.rot) end
   local r,g,b=TrailColor(t,p.age,p.life,p.hue);tex:SetVertexColor(r,g,b,math.max(0,alpha))
  end
 end
end
local function Line(i)
 local l=lines[i]
 if not l then l=NoMouse(fx:CreateLine(nil,"ARTWORK"));l:SetTexture(MEDIA.."TrailLine");lines[i]=l end
 return l
end
local function DrawLines(t,style)
 local now=GetTime();local life=t.length
 while points[1] and now-points[1].born>life do table.remove(points,1) end
 local used=0
 local passes=style.neon and 2 or 1
 -- The newest segment runs on to the cursor itself, so the line never lags behind or gaps at the front.
 local last=points[#points];local head=last and headX and (headX~=last.x or headY~=last.y) and {x=headX,y=headY,born=now,hue=hueStep}
 local count=#points+(head and 1 or 0)
 for pass=1,passes do
  for i=2,count do
   local a,b=points[i-1],points[i] or head;local k=1-(now-b.born)/life
   if k>0 then
    used=used+1;local l=Line(used)
    local width,alpha=t.size*(.25+.75*k),t.alpha*k
    local r,g,bl=TrailColor(t,now-b.born,life,b.hue)
    if style.neon then
     if pass==1 then width,alpha=width*2.2,alpha*.35
     else width=math.max(1.5,width*.45);r,g,bl=r+(1-r)*.65,g+(1-g)*.65,bl+(1-bl)*.65 end
    end
    l:SetStartPoint("BOTTOMLEFT",UIParent,a.x,a.y);l:SetEndPoint("BOTTOMLEFT",UIParent,b.x,b.y)
    l:SetThickness(width);l:SetVertexColor(r,g,bl,alpha);l:SetBlendMode(t.glow and "ADD" or "BLEND");l:Show()
   end
  end
 end
 for i=used+1,#lines do lines[i]:Hide() end
end
local function ClearTrail()
 for i=#particles,1,-1 do local p=particles[i];p.tex:Hide();free[#free+1]=p;particles[i]=nil end
 for _,l in ipairs(lines) do l:Hide() end
 wipe(points);lastX,lastY,carry,headX,headY=nil,nil,0,nil,nil
end
FX.ClearTrail=ClearTrail
local function UpdateTrail(t,dt,x,y,hidden)
 local style=STYLES[t.style] or STYLES.sparkle
 if style.line and not canLine then style=STYLES.comet end
 local now=GetTime()
 if hidden then lastX,lastY,headX,headY=nil,nil,nil,nil
 elseif lastX then
  local dx,dy=x-lastX,y-lastY;local dist=math.sqrt(dx*dx+dy*dy)
  -- The cursor jumps back after turning the camera; no streak across the screen.
  if dist>400 then lastX,lastY=x,y;dist=0;wipe(points) end
  if style.line then
   -- A new point once the cursor is 3 pixels from the last one, or (moving slowly) every MIN_INTERVAL.
   local last=points[#points]
   local d=last and math.sqrt((x-last.x)^2+(y-last.y)^2) or 0
   if not last or d>=3 or (d>.5 and now-last.born>=MIN_INTERVAL) then
    points[#points+1]={x=x,y=y,born=now,hue=hueStep};hueStep=(hueStep+.02)%1
    if #points>MAX_POINTS then table.remove(points,1) end
   end
   headX,headY=x,y
  elseif dist>0 then
   local spacing=math.max(2,t.size*.45/t.density)
   carry=carry+dist;local n=0
   while carry>=spacing and n<14 do
    carry=carry-spacing;n=n+1
    local k=1-carry/math.max(dist,.01);if k<0 then k=0 end
    Particle(t,style,lastX+dx*k,lastY+dy*k)
   end
   if n>=14 then carry=0 end
   -- Moving slower than the spacing per frame still leaves particles at a steady rate.
   if n>0 then lastEmit=now
   elseif now-lastEmit>=MIN_INTERVAL/math.max(.25,t.density) then Particle(t,style,x,y);carry=0;lastEmit=now end
  end
 end
 if not hidden then lastX,lastY=x,y end
 if style.line then
  for i=#particles,1,-1 do local p=particles[i];p.tex:Hide();free[#free+1]=p;particles[i]=nil end
  DrawLines(t,style)
 else
  for _,l in ipairs(lines) do l:Hide() end;wipe(points)
  UpdateParticles(t,dt)
 end
end

-- Every frame -----------------------------------------------------------------------------------------------------
-- Reads the saved table directly (Menu:ApplyCursorFX filled in its defaults before the frame was first shown).
fx:SetScript("OnUpdate",function(_,dt)
 local s=Menu.db and Menu.db.qol;local t=s and s.trail
 -- A profile switched in without it yet: fill it in once.
 if not t then t=Settings().trail end
 local x,y=CursorXY()
 -- While the mouse turns the camera the cursor is hidden: no trail.
 local looking=IsMouselooking and IsMouselooking()
 if t.enabled then UpdateTrail(t,dt,x,y,looking or (t.onlyCombat and not UnitAffectingCombat("player")))
 elseif #particles>0 or #points>0 then ClearTrail() end
end)

function Menu:ApplyCursorFX()
 local t=self:QoLSettings().trail
 fx:SetShown(t.enabled)
 if not t.enabled then ClearTrail() end
 -- Particle and line textures pick up a new style, glow or color on their next update.
 for _,q in ipairs(particles) do q.tex:SetBlendMode(t.glow and "ADD" or "BLEND") end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function() Menu:ApplyCursorFX() end)

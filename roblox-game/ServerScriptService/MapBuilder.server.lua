-- GunTycoon MapBuilder v4 - Iron Arsenal
-- Per-floor architecture: Armory (industrial) → Barracks (military) → War Room (high-tech) → Black Ops (experimental)
-- Multi-part themed machines with 3 visual upgrade tiers revealed by server on upgrade
-- F4 has animated radar dish, rooftop AA guns, dramatic beacon tower
-- Advanced players look dramatically more impressive than new players

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local WS           = game:GetService("Workspace")

-- ============================================================
-- Config (must match MainGameServer inline values)
-- ============================================================

local FACTIONS = {
    {name="Red Militia",       primary=Color3.fromRGB(185,35,35),   accent=Color3.fromRGB(255,80,80)  },
    {name="Blue Spec Ops",     primary=Color3.fromRGB(28,68,185),   accent=Color3.fromRGB(65,125,255) },
    {name="Green Rangers",     primary=Color3.fromRGB(38,145,45),   accent=Color3.fromRGB(75,210,90)  },
    {name="Gold Mercs",        primary=Color3.fromRGB(182,148,12),  accent=Color3.fromRGB(255,202,40) },
    {name="Purple Shadow Ops", primary=Color3.fromRGB(105,28,165),  accent=Color3.fromRGB(168,78,255) },
    {name="Orange Frontline",  primary=Color3.fromRGB(192,85,18),   accent=Color3.fromRGB(255,132,42) },
    {name="Cyan Navy SEALs",   primary=Color3.fromRGB(20,155,175),  accent=Color3.fromRGB(50,208,228) },
    {name="White Ghost Div",   primary=Color3.fromRGB(188,188,198), accent=Color3.fromRGB(228,228,242)},
}

local FLOOR_THEME = {
    [1]={name="Armory",    wall=Color3.fromRGB(58,58,68),   trim=Color3.fromRGB(82,82,96),   light=Color3.fromRGB(190,205,255)},
    [2]={name="Barracks",  wall=Color3.fromRGB(44,58,44),   trim=Color3.fromRGB(68,96,68),   light=Color3.fromRGB(120,255,120)},
    [3]={name="War Room",  wall=Color3.fromRGB(52,38,22),   trim=Color3.fromRGB(88,68,38),   light=Color3.fromRGB(255,140,60) },
    [4]={name="Black Ops", wall=Color3.fromRGB(12,12,18),   trim=Color3.fromRGB(52,36,82),   light=Color3.fromRGB(145,60,255) },
}
local FLOOR_H = {18, 20, 24, 28}
local PAD_H   = 2
local BW      = 80
local BD      = 62
local BASE_Y  = {PAD_H}
for f = 2, 4 do BASE_Y[f] = BASE_Y[f-1] + FLOOR_H[f-1] + 2 end

local BULLET_COLORS = {
    Color3.fromRGB(255,240,160), Color3.fromRGB(160,220,255),
    Color3.fromRGB(255,100,50),  Color3.fromRGB(200,80,255),
}
local AMBER   = Color3.fromRGB(255,162,0)
local PLT_COL = Color3.fromRGB(24,24,30)
local WLL_COL = Color3.fromRGB(18,18,24)

local GC_DROPPERS = {
    [1]={
        {id=101,name="Pistol Range",  baseCost=100,       costMult=1.9, maxLevel=8},
        {id=102,name="Rifle Station", baseCost=1500,      costMult=1.9, maxLevel=8},
        {id=103,name="Shotgun Rack",  baseCost=8500,      costMult=1.9, maxLevel=8},
        {id=104,name="Ammo Press",    baseCost=32000,     costMult=1.9, maxLevel=8},
    },
    [2]={
        {id=201,name="SMG Assembly",  baseCost=150000,    costMult=2.0, maxLevel=8},
        {id=202,name="AR Workshop",   baseCost=500000,    costMult=2.0, maxLevel=8},
        {id=203,name="Heavy Forge",   baseCost=1800000,   costMult=2.0, maxLevel=8},
    },
    [3]={
        {id=301,name="Sniper Lab",    baseCost=8000000,   costMult=2.1, maxLevel=8},
        {id=302,name="LMG Factory",   baseCost=32000000,  costMult=2.1, maxLevel=8},
        {id=303,name="Launcher Bay",  baseCost=130000000, costMult=2.1, maxLevel=8},
    },
    [4]={
        {id=401,name="Minigun Core",  baseCost=750000000,   costMult=2.2, maxLevel=8},
        {id=402,name="Rocket Depot",  baseCost=3500000000,  costMult=2.2, maxLevel=8},
        {id=403,name="Railgun Lab",   baseCost=16000000000, costMult=2.2, maxLevel=8},
    },
}
local GC_WEAPONS = {
    [1]={{id=1011,name="Pistol",cost=600},{id=1012,name="Revolver",cost=2500},{id=1013,name="Shotgun",cost=5000}},
    [2]={{id=1021,name="SMG",cost=15000},{id=1022,name="Assault Rifle",cost=35000},{id=1023,name="Combat Shotgun",cost=75000}},
    [3]={{id=1031,name="Sniper Rifle",cost=250000},{id=1032,name="LMG",cost=600000},{id=1033,name="Grenade Launcher",cost=1200000}},
    [4]={{id=1041,name="Minigun",cost=5000000},{id=1042,name="Rocket Launcher",cost=14000000},{id=1043,name="Railgun",cost=30000000}},
}
local GC_FLOOR_COSTS = {0, 60000, 4000000, 250000000}

-- ============================================================
-- Helpers
-- ============================================================

local function makeBox(size, cf, color, mat, parent, name)
    local p = Instance.new("Part")
    p.Size=size; p.CFrame=cf; p.Color=color; p.Material=mat or Enum.Material.SmoothPlastic
    p.Anchored=true; p.CastShadow=false; p.Name=name or "Part"; p.Parent=parent or WS
    return p
end

local function makeWedge(size, cf, color, mat, parent, name)
    local p = Instance.new("WedgePart")
    p.Size=size; p.CFrame=cf; p.Color=color; p.Material=mat or Enum.Material.SmoothPlastic
    p.Anchored=true; p.CastShadow=false; p.Name=name or "Wedge"; p.Parent=parent or WS
    return p
end

local function addLight(part, ltype, color, range, brightness)
    local l = Instance.new(ltype or "PointLight")
    l.Color=color or Color3.new(1,1,1); l.Range=range or 16; l.Brightness=brightness or 2
    if ltype=="SpotLight" then l.Angle=50; l.Face=Enum.NormalId.Top end
    l.Parent=part; return l
end

local function addBB(part, text, width, textCol, bgCol, maxDist)
    local bb = Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,width or 200,0,46); bb.StudsOffset=Vector3.new(0,3.2,0)
    bb.AlwaysOnTop=false; bb.MaxDistance=maxDist or 24
    bb.Adornee=part; bb.Parent=part
    local lbl=Instance.new("TextLabel",bb)
    lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundColor3=bgCol or Color3.fromRGB(8,8,12)
    lbl.BackgroundTransparency=0.1; lbl.TextColor3=textCol or Color3.new(1,1,1)
    lbl.Text=text; lbl.Font=Enum.Font.GothamBold; lbl.TextScaled=true
    lbl.Name="Label"; lbl.BorderSizePixel=0
    Instance.new("UICorner",lbl).CornerRadius=UDim.new(0.22,0)
    return lbl
end

local function pulse(part, c1, c2, dur)
    task.spawn(function()
        TweenService:Create(part, TweenInfo.new(dur or 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Color=c2}):Play()
    end)
end

local function numFmt(n)
    if n>=1e12 then return string.format("%.1fT",n/1e12)
    elseif n>=1e9 then return string.format("%.1fB",n/1e9)
    elseif n>=1e6 then return string.format("%.1fM",n/1e6)
    elseif n>=1e3 then return string.format("%.1fK",n/1e3)
    else return tostring(n) end
end

-- Tier parts: start hidden, revealed by server on upgrade
local function tierPart(p, tier)
    p:SetAttribute("UpgradeTier", tier)
    p.Transparency = 1
    p.CanCollide   = false
end

local function hideFolder(folder)
    for _, d in ipairs(folder:GetDescendants()) do
        if d:IsA("BasePart") then
            d:SetAttribute("OrigTrans",   d.Transparency)
            d:SetAttribute("OrigCollide", d.CanCollide)
            d.Transparency=1; d.CanCollide=false; d.CastShadow=false
        elseif d:IsA("ProximityPrompt") then
            d.Enabled=false
        end
    end
end

-- ============================================================
-- World folders
-- ============================================================

local mapF  = Instance.new("Folder"); mapF.Name="Map";      mapF.Parent=WS
local tycF  = Instance.new("Folder"); tycF.Name="Tycoons";  tycF.Parent=WS
local covF  = Instance.new("Folder"); covF.Name="Cover";    covF.Parent=WS
local vipF  = Instance.new("Folder"); vipF.Name="VIPZone";  vipF.Parent=WS
local ownF  = Instance.new("Folder"); ownF.Name="OwnerRoom"; ownF.Parent=WS

-- Spinner table: parts animated by the heartbeat loop
local spinners = {}

-- ============================================================
-- Platform
-- ============================================================

local PSIZE = Vector3.new(640,5,640)
local hx=PSIZE.X/2; local hz=PSIZE.Z/2
local wH=115; local wT=12

makeBox(PSIZE, CFrame.new(0,-PSIZE.Y/2,0), PLT_COL, Enum.Material.SmoothPlastic, mapF, "Platform")

for i=-4,4 do
    local gc = i==0 and Color3.fromRGB(52,52,64) or Color3.fromRGB(34,34,42)
    makeBox(Vector3.new(PSIZE.X,0.08,1.2), CFrame.new(0,0.04,i*80), gc, Enum.Material.SmoothPlastic, mapF, "GridH")
    makeBox(Vector3.new(1.2,0.08,PSIZE.Z), CFrame.new(i*80,0.04,0), gc, Enum.Material.SmoothPlastic, mapF, "GridV")
end

for _,sd in ipairs({
    {Vector3.new(PSIZE.X-4,0.4,1.5), CFrame.new(0,0.2,-(hz-1.5))},
    {Vector3.new(PSIZE.X-4,0.4,1.5), CFrame.new(0,0.2,  hz-1.5)},
    {Vector3.new(1.5,0.4,PSIZE.Z-4), CFrame.new(-(hx-1.5),0.2,0)},
    {Vector3.new(1.5,0.4,PSIZE.Z-4), CFrame.new(  hx-1.5, 0.2,0)},
}) do
    local s=makeBox(sd[1],sd[2],AMBER,Enum.Material.Neon,mapF,"Border")
    pulse(s,AMBER,Color3.fromRGB(255,200,80),2.2)
end

-- ============================================================
-- Perimeter walls
-- ============================================================

local DOOR_W=14
local sHalf=(PSIZE.X+wT*2-DOOR_W)/2

makeBox(Vector3.new(PSIZE.X+wT*2,wH,wT), CFrame.new(0,wH/2,-(hz+wT/2)),   WLL_COL,Enum.Material.SmoothPlastic,mapF,"WallN")
makeBox(Vector3.new(sHalf,wH,wT), CFrame.new(-(DOOR_W/2+sHalf/2),wH/2,hz+wT/2), WLL_COL,Enum.Material.SmoothPlastic,mapF,"WallS_L")
makeBox(Vector3.new(sHalf,wH,wT), CFrame.new(  DOOR_W/2+sHalf/2, wH/2,hz+wT/2), WLL_COL,Enum.Material.SmoothPlastic,mapF,"WallS_R")
makeBox(Vector3.new(DOOR_W+6,10,wT+2), CFrame.new(0,wH-5,hz+wT/2), Color3.fromRGB(22,22,28),Enum.Material.SmoothPlastic,ownF,"DoorLintel")
makeBox(Vector3.new(wT,wH,PSIZE.Z), CFrame.new(-(hx+wT/2),wH/2,0), WLL_COL,Enum.Material.SmoothPlastic,mapF,"WallW")
makeBox(Vector3.new(wT,wH,PSIZE.Z), CFrame.new(  hx+wT/2, wH/2,0), WLL_COL,Enum.Material.SmoothPlastic,mapF,"WallE")

for _,wx in ipairs({-80,0,80}) do
    for _,side in ipairs({-(hx+wT-2),(hx+wT-2)}) do
        local wlp=makeBox(Vector3.new(2.5,2.5,2.5),CFrame.new(side,20,wx),AMBER,Enum.Material.Neon,mapF,"WLight")
        addLight(wlp,"PointLight",Color3.fromRGB(255,175,70),55,1.8)
    end
end
for _,wz in ipairs({-80,0,80}) do
    for _,side in ipairs({-(hz+wT-2),(hz+wT-2)}) do
        local wlp=makeBox(Vector3.new(2.5,2.5,2.5),CFrame.new(wz,20,side),AMBER,Enum.Material.Neon,mapF,"WLight")
        addLight(wlp,"PointLight",Color3.fromRGB(255,175,70),55,1.8)
    end
end

local bS=18
for i=1,math.floor((PSIZE.X+wT*2)/bS) do
    local bx=-(hx+wT)+(i-0.5)*bS; local bc=Color3.fromRGB(14,14,18)
    makeBox(Vector3.new(bS*0.48,7,wT*0.8),CFrame.new(bx,wH+3.5,-(hz+wT/2)),bc,Enum.Material.SmoothPlastic,mapF,"Batt")
    makeBox(Vector3.new(bS*0.48,7,wT*0.8),CFrame.new(bx,wH+3.5,  hz+wT/2), bc,Enum.Material.SmoothPlastic,mapF,"Batt")
end
for i=1,math.floor(PSIZE.Z/bS) do
    local bz=-hz+(i-0.5)*bS; local bc=Color3.fromRGB(14,14,18)
    makeBox(Vector3.new(wT*0.8,7,bS*0.48),CFrame.new(-(hx+wT/2),wH+3.5,bz),bc,Enum.Material.SmoothPlastic,mapF,"Batt")
    makeBox(Vector3.new(wT*0.8,7,bS*0.48),CFrame.new(  hx+wT/2, wH+3.5,bz),bc,Enum.Material.SmoothPlastic,mapF,"Batt")
end

for _,cv in ipairs({Vector3.new(-(hx+wT/2),0,-(hz+wT/2)),Vector3.new(hx+wT/2,0,-(hz+wT/2)),Vector3.new(-(hx+wT/2),0,hz+wT/2),Vector3.new(hx+wT/2,0,hz+wT/2)}) do
    local tw=wT+14; local th=wH+30
    makeBox(Vector3.new(tw,th,tw),CFrame.new(cv.X,th/2,cv.Z),Color3.fromRGB(16,16,22),Enum.Material.SmoothPlastic,mapF,"Tower")
    local cap=makeBox(Vector3.new(tw+2,1.5,tw+2),CFrame.new(cv.X,th+0.75,cv.Z),AMBER,Enum.Material.Neon,mapF,"TowerCap")
    addLight(cap,"PointLight",Color3.fromRGB(255,175,60),35,3)
    addLight(makeBox(Vector3.new(tw,1,tw),CFrame.new(cv.X,th+0.5,cv.Z),WLL_COL,Enum.Material.SmoothPlastic,mapF,"TowerTop"),"SpotLight",Color3.fromRGB(240,215,155),115,6)
end

-- ============================================================
-- Tycoon slot positions
-- ============================================================

local SLOTS = {
    {pos=Vector3.new(-256,0,  0), look=Vector3.new( 1,0, 0)},
    {pos=Vector3.new( 256,0,  0), look=Vector3.new(-1,0, 0)},
    {pos=Vector3.new(  0,0,-256), look=Vector3.new( 0,0, 1)},
    {pos=Vector3.new(  0,0, 256), look=Vector3.new( 0,0,-1)},
    {pos=Vector3.new(-178,0,-178), look=Vector3.new( 1,0, 1).Unit},
    {pos=Vector3.new( 178,0,-178), look=Vector3.new(-1,0, 1).Unit},
    {pos=Vector3.new(-178,0, 178), look=Vector3.new( 1,0,-1).Unit},
    {pos=Vector3.new( 178,0, 178), look=Vector3.new(-1,0,-1).Unit},
}

-- ============================================================
-- Build one tycoon
-- ============================================================

local function buildTycoon(slotId, slotData, faction)
    local folder = Instance.new("Folder")
    folder.Name="Tycoon_"..slotId; folder.Parent=tycF

    local look   = slotData.look
    local origin = slotData.pos
    local rightV = Vector3.new(-look.Z,0,look.X)
    local baseCF = CFrame.fromMatrix(origin,rightV,Vector3.new(0,1,0),-look)
    local function lc(x,y,z) return baseCF*CFrame.new(x,y,z) end

    -- Foundation pad (always visible)
    local pad=makeBox(Vector3.new(BW+10,PAD_H,BD+10),lc(0,PAD_H/2,0),Color3.fromRGB(20,20,26),Enum.Material.Concrete,folder,"Pad")
    pad:SetAttribute("TycoonId",slotId); pad:SetAttribute("IsPad",true)
    -- Raised pad border detail
    makeBox(Vector3.new(BW+10,0.3,BD+10),lc(0,PAD_H+0.15,0),Color3.fromRGB(28,28,36),Enum.Material.SmoothPlastic,folder,"PadTop")
    -- Faction color edge strips on all 4 sides
    for _,ed in ipairs({
        {Vector3.new(BW+10,0.5,1.6), lc(0,PAD_H+0.25,  (BD+10)/2)},
        {Vector3.new(BW+10,0.5,1.6), lc(0,PAD_H+0.25, -(BD+10)/2)},
        {Vector3.new(1.6,0.5,BD+10), lc(  (BW+10)/2,  PAD_H+0.25,0)},
        {Vector3.new(1.6,0.5,BD+10), lc( -(BW+10)/2,  PAD_H+0.25,0)},
    }) do
        local s=makeBox(ed[1],ed[2],faction.accent,Enum.Material.Neon,folder,"PadEdge")
        pulse(s,faction.accent,Color3.fromRGB(255,255,210),1.9)
    end

    -- Claim button (front outer edge of pad)
    local claim=makeBox(Vector3.new(11,0.6,11),lc(0,PAD_H+0.3,(BD+10)/2-8),Color3.fromRGB(35,185,65),Enum.Material.Neon,folder,"ClaimButton")
    claim:SetAttribute("TycoonId",slotId); claim:SetAttribute("IsClaimBtn",true)
    addBB(claim,"CLAIM  "..faction.name,240,Color3.fromRGB(255,255,200),Color3.fromRGB(6,16,4),38)
    pulse(claim,Color3.fromRGB(35,185,65),Color3.fromRGB(90,255,110),0.9)
    addLight(claim,"PointLight",Color3.fromRGB(50,255,80),20,2.5)
    local clPP=Instance.new("ProximityPrompt")
    clPP.ActionText="Claim"; clPP.ObjectText=faction.name
    clPP.MaxActivationDistance=14; clPP.RequiresLineOfSight=false; clPP.Parent=claim

    -- ================================================================
    -- Floors
    -- ================================================================
    for floor=1,4 do
        local fth   = FLOOR_THEME[floor]
        local baseY = BASE_Y[floor]
        local fh    = FLOOR_H[floor]
        local flF   = Instance.new("Folder"); flF.Name="Floor_"..floor; flF.Parent=folder

        -- ---- Core structure ----
        makeBox(Vector3.new(BW,fh,2.5),     lc(0,baseY+fh/2,-BD/2+1.25),   fth.wall,Enum.Material.Concrete,flF,"BW_F"..floor)
        makeBox(Vector3.new(2.5,fh,BD),     lc(-BW/2+1.25,baseY+fh/2,0),   fth.wall,Enum.Material.Concrete,flF,"LW_F"..floor)
        makeBox(Vector3.new(2.5,fh,BD),     lc( BW/2-1.25,baseY+fh/2,0),   fth.wall,Enum.Material.Concrete,flF,"RW_F"..floor)
        if floor>1 then
            makeBox(Vector3.new(BW,2,BD),   lc(0,baseY+1,0),Color3.fromRGB(28,28,36),Enum.Material.SmoothPlastic,flF,"FLSlab_F"..floor)
        end
        makeBox(Vector3.new(BW+3,2,BD+3),   lc(0,baseY+fh+1,0),Color3.fromRGB(26,26,34),Enum.Material.SmoothPlastic,flF,"Ceiling_F"..floor)
        -- Corner pilasters
        for _,cx in ipairs({-BW/2+1.5,BW/2-1.5}) do
            for _,cz in ipairs({-BD/2+1.5,BD/2-1.5}) do
                makeBox(Vector3.new(3,fh,3),lc(cx,baseY+fh/2,cz),Color3.fromRGB(24,24,30),Enum.Material.SmoothPlastic,flF,"CP_F"..floor)
            end
        end

        -- ---- Entrance pillars (front open face) ----
        local pilCol = floor==4 and Color3.fromRGB(8,8,14) or Color3.fromRGB(28,28,36)
        makeBox(Vector3.new(4,fh,4),   lc(-BW/2+3.5,baseY+fh/2, BD/2-2), pilCol, Enum.Material.SmoothPlastic, flF,"PilL_F"..floor)
        makeBox(Vector3.new(4,fh,4),   lc( BW/2-3.5,baseY+fh/2, BD/2-2), pilCol, Enum.Material.SmoothPlastic, flF,"PilR_F"..floor)
        local pCapL=makeBox(Vector3.new(5,1.2,5),lc(-BW/2+3.5,baseY+fh+0.6,BD/2-2),faction.accent,Enum.Material.Neon,flF,"PCapL_F"..floor)
        local pCapR=makeBox(Vector3.new(5,1.2,5),lc( BW/2-3.5,baseY+fh+0.6,BD/2-2),faction.accent,Enum.Material.Neon,flF,"PCapR_F"..floor)
        addLight(pCapL,"PointLight",faction.accent,16,2)
        addLight(pCapR,"PointLight",faction.accent,16,2)
        -- Pillar vertical glow strips (F3/F4 only)
        if floor>=3 then
            makeBox(Vector3.new(0.4,fh,0.4),lc(-BW/2+1.5,baseY+fh/2,BD/2-0.5),faction.accent,Enum.Material.Neon,flF,"PilNeonL_F"..floor)
            makeBox(Vector3.new(0.4,fh,0.4),lc( BW/2-1.5,baseY+fh/2,BD/2-0.5),faction.accent,Enum.Material.Neon,flF,"PilNeonR_F"..floor)
        end
        -- Entrance header beam
        local hdrH = floor==4 and 5 or 3.5
        local hdr = makeBox(Vector3.new(BW-8,hdrH,4),lc(0,baseY+fh-hdrH/2+0.5,BD/2-2),faction.primary,Enum.Material.SmoothPlastic,flF,"Hdr_F"..floor)
        addBB(hdr, faction.name:upper().."   "..fth.name:upper(), 300, faction.accent, faction.primary, 55)
        local uNeon=makeBox(Vector3.new(BW-12,0.5,1.2),lc(0,baseY+fh-hdrH-0.2,BD/2-2),faction.accent,Enum.Material.Neon,flF,"HdrNeon_F"..floor)
        pulse(uNeon,faction.accent,Color3.fromRGB(255,255,255),1.5)
        addLight(uNeon,"PointLight",faction.accent,22,2)

        -- ---- Floor-specific decoration ----
        if floor==1 then
            -- Corrugated metal strips on back wall (industrial workshop feel)
            for i=1,6 do
                makeBox(Vector3.new(BW-2,0.35,0.7),lc(0,baseY+(fh/7)*i,-BD/2+1.8),Color3.fromRGB(52,52,62),Enum.Material.Metal,flF,"Corr_F1")
            end
            -- Overhead pendant lights (3 rows)
            for xi=-1,1 do
                local pLt=makeBox(Vector3.new(1.5,0.8,1.5),lc(xi*13,baseY+fh-2.5,-2),Color3.fromRGB(48,48,58),Enum.Material.Metal,flF,"PendHook_F1")
                local pLamp=makeBox(Vector3.new(3.5,0.6,3.5),lc(xi*13,baseY+fh-3.5,-2),fth.light,Enum.Material.Neon,flF,"PendLight_F1")
                addLight(pLamp,"PointLight",fth.light,26,1.8)
            end
            -- Side wall horizontal racks (holding tool/ammo boxes)
            for zr=-1,1 do
                makeBox(Vector3.new(0.5,0.4,12),lc(-BW/2+1.8,baseY+fh*0.5,zr*5),Color3.fromRGB(58,62,72),Enum.Material.Metal,flF,"Rack_F1")
            end

        elseif floor==2 then
            -- Reinforced bunker panel overlays on back wall
            for xi=-1,1 do
                makeBox(Vector3.new(13,fh-4,0.5),lc(xi*13.5,baseY+fh/2+1,-BD/2+2.3),Color3.fromRGB(38,50,38),Enum.Material.SmoothPlastic,flF,"BPanel_F2")
                makeBox(Vector3.new(12,0.5,0.3),lc(xi*13.5,baseY+fh*0.4,-BD/2+2.6),fth.trim,Enum.Material.SmoothPlastic,flF,"BDiag_F2")
                makeBox(Vector3.new(12,0.5,0.3),lc(xi*13.5,baseY+fh*0.65,-BD/2+2.6),fth.trim,Enum.Material.SmoothPlastic,flF,"BDiag_F2")
            end
            -- Narrow slit windows on sides (backlit bunker style)
            for _,zw in ipairs({-BD/2+9, 0, BD/2-9}) do
                local slL=makeBox(Vector3.new(0.5,3,4.5),lc(-BW/2+1.7,baseY+fh*0.62,zw),fth.light,Enum.Material.Neon,flF,"SlitL_F2")
                local slR=makeBox(Vector3.new(0.5,3,4.5),lc( BW/2-1.7,baseY+fh*0.62,zw),fth.light,Enum.Material.Neon,flF,"SlitR_F2")
                addLight(slL,"PointLight",fth.light,12,1.2)
                addLight(slR,"PointLight",fth.light,12,1.2)
            end
            -- Fluorescent ceiling strips
            for xi=-1,1 do
                local fs=makeBox(Vector3.new(1,0.5,20),lc(xi*10,baseY+fh-2,-1),fth.light,Enum.Material.Neon,flF,"Fluoro_F2")
                addLight(fs,"PointLight",fth.light,28,1.4)
            end
            -- Barbed wire accent at top of pillars
            makeBox(Vector3.new(BW,0.4,0.6),lc(0,baseY+fh-1,BD/2-2),Color3.fromRGB(88,88,92),Enum.Material.Metal,flF,"BarbWire_F2")

        elseif floor==3 then
            -- Circuit board pattern on back wall panels
            for xi=-1,1 do
                makeBox(Vector3.new(13,fh-3,0.45),lc(xi*13,baseY+fh/2,-BD/2+2.2),Color3.fromRGB(18,24,36),Enum.Material.SmoothPlastic,flF,"CircPanel_F3")
                -- Horizontal circuit traces
                for _,ht in ipairs({0.3,0.5,0.7}) do
                    local tr=makeBox(Vector3.new(12,0.35,0.25),lc(xi*13,baseY+fh*ht,-BD/2+2.5),fth.light,Enum.Material.Neon,flF,"Trace_F3")
                    tr.Transparency=0.3
                end
                -- Vertical trace
                makeBox(Vector3.new(0.3,fh-4,0.25),lc(xi*13+4,baseY+fh/2,-BD/2+2.5),fth.light,Enum.Material.Neon,flF,"TraceV_F3")
            end
            -- Large backlit window panels on sides
            for _,zw in ipairs({-BD/2+9, BD/2-9}) do
                makeBox(Vector3.new(0.5,fh*0.5,10),  lc(-BW/2+2,  baseY+fh*0.42,zw),fth.trim,Enum.Material.SmoothPlastic,flF,"WinFrame_F3")
                local wg=makeBox(Vector3.new(0.3,fh*0.48,9.5),lc(-BW/2+1.8,baseY+fh*0.42,zw),fth.light,Enum.Material.Neon,flF,"WinGlow_F3")
                wg.Transparency=0.35; addLight(wg,"PointLight",fth.light,22,1.2)
                makeBox(Vector3.new(0.5,fh*0.5,10),  lc( BW/2-2,  baseY+fh*0.42,zw),fth.trim,Enum.Material.SmoothPlastic,flF,"WinFrame_F3")
                local wg2=makeBox(Vector3.new(0.3,fh*0.48,9.5),lc(BW/2-1.8,baseY+fh*0.42,zw),fth.light,Enum.Material.Neon,flF,"WinGlow_F3")
                wg2.Transparency=0.35; addLight(wg2,"PointLight",fth.light,22,1.2)
            end
            -- Holographic ceiling projectors (downward spotlight cones)
            for xi=-1,1 do
                local proj=makeBox(Vector3.new(2.5,1.2,2.5),lc(xi*10,baseY+fh-2,-5),fth.trim,Enum.Material.SmoothPlastic,flF,"Proj_F3")
                local beam=makeBox(Vector3.new(1.5,9,1.5),  lc(xi*10,baseY+fh-7,-5),fth.light,Enum.Material.Neon,flF,"ProjBeam_F3")
                beam.Transparency=0.72; addLight(proj,"SpotLight",fth.light,32,3.5)
            end

        elseif floor==4 then
            -- Obsidian wall panels with neon frame edges
            for xi=-1,1 do
                makeBox(Vector3.new(13,fh-2,0.45),lc(xi*13,baseY+fh/2,-BD/2+2.2),Color3.fromRGB(6,6,10),Enum.Material.SmoothPlastic,flF,"ObsPanel_F4")
                -- Frame strips left and right of each panel
                for _,sx in ipairs({-7,7}) do
                    local fe=makeBox(Vector3.new(0.4,fh-2,0.5),lc(xi*13+sx,baseY+fh/2,-BD/2+2.4),faction.accent,Enum.Material.Neon,flF,"PanelFE_F4")
                    pulse(fe,faction.accent,Color3.fromRGB(255,255,255),1.1)
                end
                -- Top/bottom horizontal frame
                makeBox(Vector3.new(13,0.4,0.4),lc(xi*13,baseY+fh*0.1,-BD/2+2.4),faction.accent,Enum.Material.Neon,flF,"PanelFT_F4")
                makeBox(Vector3.new(13,0.4,0.4),lc(xi*13,baseY+fh*0.9,-BD/2+2.4),faction.accent,Enum.Material.Neon,flF,"PanelFB_F4")
            end
            -- Full vertical neon edge strips on building corners (visible from arena)
            local sideN1=makeBox(Vector3.new(0.5,fh,0.5),lc(-BW/2+0.8,baseY+fh/2,BD/2-0.8),faction.accent,Enum.Material.Neon,flF,"EdgeNL_F4")
            local sideN2=makeBox(Vector3.new(0.5,fh,0.5),lc( BW/2-0.8,baseY+fh/2,BD/2-0.8),faction.accent,Enum.Material.Neon,flF,"EdgeNR_F4")
            pulse(sideN1,faction.accent,Color3.fromRGB(255,255,255),0.95)
            pulse(sideN2,faction.accent,Color3.fromRGB(255,255,255),0.95)
            addLight(sideN1,"PointLight",faction.accent,24,2.8)
            addLight(sideN2,"PointLight",faction.accent,24,2.8)
            -- Dramatic overhead lighting (4 angled spot clusters)
            for _,xv in ipairs({-12,12}) do
                for _,zv in ipairs({-5,5}) do
                    local ds=makeBox(Vector3.new(2,0.6,2),lc(xv,baseY+fh-2,zv),faction.accent,Enum.Material.Neon,flF,"DramaSpot_F4")
                    addLight(ds,"SpotLight",faction.accent,45,4.5)
                    addLight(ds,"PointLight",faction.accent,14,2)
                end
            end
        end

        -- Faction fascia strip under ceiling
        makeBox(Vector3.new(BW,3.5,2.2),lc(0,baseY+fh-1.75,BD/2+0.8),faction.primary,Enum.Material.SmoothPlastic,flF,"Fascia_F"..floor)
        -- F4 top edge neons (exterior top rim, visible across map)
        if floor==4 then
            local topFN=makeBox(Vector3.new(BW+5,0.5,1.5),lc(0,baseY+fh+2.2,BD/2+1.2),faction.accent,Enum.Material.Neon,flF,"TopEdge_F4")
            local topBN=makeBox(Vector3.new(BW+5,0.5,1.5),lc(0,baseY+fh+2.2,-BD/2-1.2),faction.accent,Enum.Material.Neon,flF,"BackEdge_F4")
            pulse(topFN,faction.accent,Color3.fromRGB(255,255,255),1.0)
            pulse(topBN,faction.accent,Color3.fromRGB(255,255,255),1.0)
            addLight(topFN,"SpotLight",faction.accent,65,4.5)
        end

        -- ---- Dropper machines ----
        local dlist  = GC_DROPPERS[floor]
        local dCount = #dlist
        local dXmax  = BW/2-12   -- wider spread for bigger building
        local dXmin  = -BW/2+14  -- keep clear of left-wall weapon cases
        local floorSurfY = floor==1 and PAD_H or baseY+2

        for di, dd in ipairs(dlist) do
            local dx = dCount==1 and (dXmin+dXmax)/2 or dXmin+(di-1)*(dXmax-dXmin)/(dCount-1)
            local dz = -math.floor(BD*0.22)  -- ~1/4 depth from center toward back, clear of weapon cases
            local machF=Instance.new("Folder"); machF.Name="DMach_F"..floor.."_"..di; machF.Parent=flF
            machF:SetAttribute("TycoonId",slotId); machF:SetAttribute("FloorId",floor); machF:SetAttribute("DropperId",di)

            if floor==1 then
                -- ---- ARMORY: Industrial workbench / hydraulic press ----
                -- Main press body (heavy dark metal box)
                makeBox(Vector3.new(8,5,7.5),    lc(dx,floorSurfY+2.5,dz),       Color3.fromRGB(52,54,62),  Enum.Material.Metal,         machF,"MBody")
                -- Bench top plate
                makeBox(Vector3.new(8.5,0.5,8),  lc(dx,floorSurfY+5.25,dz),      Color3.fromRGB(66,70,80),  Enum.Material.SmoothPlastic, machF,"MBenchTop")
                -- Front control panel (juts out)
                makeBox(Vector3.new(4,3.5,0.7),  lc(dx,floorSurfY+3.8,dz+3.85),  Color3.fromRGB(22,26,34),  Enum.Material.SmoothPlastic, machF,"MPanel")
                -- Panel buttons (3 neon dots)
                for bi=-1,1 do
                    makeBox(Vector3.new(0.7,0.7,0.3),lc(dx+bi*1.2,floorSurfY+4.5,dz+4.2),fth.light,Enum.Material.Neon,machF,"MBtn")
                end
                -- Back wall tool rack
                makeBox(Vector3.new(0.5,5.5,7.5),lc(dx-3.8,floorSurfY+3,dz),     Color3.fromRGB(38,40,50),  Enum.Material.SmoothPlastic, machF,"MRack")
                -- Tool pegs on rack
                for pi=-1,1 do
                    makeBox(Vector3.new(0.9,0.9,1.8),lc(dx-3.5,floorSurfY+3+pi*1.6,dz),Color3.fromRGB(68,72,82),Enum.Material.SmoothPlastic,machF,"MPeg")
                end
                -- Main glow top indicator
                local gTop=makeBox(Vector3.new(7.5,0.5,7.5),lc(dx,floorSurfY+5.8,dz),fth.light,Enum.Material.Neon,machF,"DGlow_F"..floor.."_"..di)
                gTop:SetAttribute("IsGlow",true); addLight(gTop,"PointLight",fth.light,9,1.4)
                -- [Tier 2] Exhaust stack at back-right
                local p2=makeBox(Vector3.new(1.5,10,1.5),lc(dx+3,floorSurfY+5,dz-3.2),Color3.fromRGB(46,48,56),Enum.Material.Metal,machF,"T2Pipe")
                tierPart(p2,2)
                local p2h=makeBox(Vector3.new(2.8,1,2.8),lc(dx+3,floorSurfY+10.5,dz-3.2),Color3.fromRGB(58,60,68),Enum.Material.SmoothPlastic,machF,"T2PipeHead")
                tierPart(p2h,2)
                local p2g=makeBox(Vector3.new(2.6,0.4,2.6),lc(dx+3,floorSurfY+10.6,dz-3.2),fth.light,Enum.Material.Neon,machF,"T2PipeGlow")
                tierPart(p2g,2); addLight(p2g,"PointLight",fth.light,8,1.5)
                -- [Tier 3] Second stack + glow ring around bench
                local p3=makeBox(Vector3.new(1.2,8,1.2),lc(dx+1.4,floorSurfY+4,dz-3.6),Color3.fromRGB(46,48,56),Enum.Material.Metal,machF,"T3Pipe2")
                tierPart(p3,3)
                local ring=makeBox(Vector3.new(10.5,0.5,10.5),lc(dx,floorSurfY+6.1,dz),fth.light,Enum.Material.Neon,machF,"T3Ring")
                tierPart(ring,3); addLight(ring,"PointLight",fth.light,16,2.2)
                -- Animated spinning gear plate on bench top
                local gear=makeBox(Vector3.new(6,0.3,6),lc(dx,floorSurfY+5.5,dz),fth.light,Enum.Material.Neon,machF,"GearSpin")
                gear.Transparency=0.35
                table.insert(spinners,{part=gear, baseCF=lc(dx,floorSurfY+5.5,dz), speed=1.2+di*0.4})

            elseif floor==2 then
                -- ---- BARRACKS: Assembly station with mechanical robotic arm ----
                makeBox(Vector3.new(10.5,2.5,10),lc(dx,floorSurfY+1.25,dz),    Color3.fromRGB(38,50,38),  Enum.Material.Metal,         machF,"MBase")
                makeBox(Vector3.new(7.5,7.5,7.5),lc(dx,floorSurfY+2.5+3.75,dz),fth.trim,                  Enum.Material.SmoothPlastic, machF,"MBody")
                -- Front riveted panel
                makeBox(Vector3.new(6.5,4,0.5),  lc(dx,floorSurfY+4.8,dz+3.8), Color3.fromRGB(30,42,30),  Enum.Material.SmoothPlastic, machF,"MFrontPanel")
                makeBox(Vector3.new(5.5,0.4,0.3),lc(dx,floorSurfY+5.5,dz+4),   fth.light,                 Enum.Material.Neon,          machF,"MPanelBar")
                -- Arm tower (right side)
                makeBox(Vector3.new(2.2,9.5,2.2),lc(dx+3,floorSurfY+2.5+4.75,dz-2.8),Color3.fromRGB(32,44,32),Enum.Material.Metal,machF,"MArmTower")
                -- Arm horizontal extending toward front-left
                makeBox(Vector3.new(6.5,1.6,1.6),lc(dx-0.25,floorSurfY+12.5,dz-2.8),Color3.fromRGB(46,62,46),Enum.Material.Metal,machF,"MArmH")
                -- Gripper head
                makeBox(Vector3.new(2.6,2.6,2.6),lc(dx-3.75,floorSurfY+11,dz-2.8),Color3.fromRGB(58,76,58),Enum.Material.SmoothPlastic,machF,"MArmHead")
                makeBox(Vector3.new(2.8,0.4,2.8),lc(dx-3.75,floorSurfY+9.6,dz-2.8),fth.light,Enum.Material.Neon,machF,"MArmGrip")
                -- Status glow strip on front panel
                local gs=makeBox(Vector3.new(6,0.5,0.5),lc(dx,floorSurfY+4,dz+4.1),fth.light,Enum.Material.Neon,machF,"DGlow_F"..floor.."_"..di)
                gs:SetAttribute("IsGlow",true); addLight(gs,"PointLight",fth.light,11,1.6)
                -- [Tier 2] Second arm on left side
                local t2tow=makeBox(Vector3.new(2.2,8,2.2),lc(dx-3,floorSurfY+2.5+4,dz-2.8),Color3.fromRGB(32,44,32),Enum.Material.Metal,machF,"T2ArmTow")
                tierPart(t2tow,2)
                local t2arm=makeBox(Vector3.new(5.5,1.5,1.5),lc(dx+0.75,floorSurfY+11,dz-2.8),Color3.fromRGB(46,62,46),Enum.Material.Metal,machF,"T2ArmH")
                tierPart(t2arm,2)
                local t2head=makeBox(Vector3.new(2.4,2.4,2.4),lc(dx+3.75,floorSurfY+9.7,dz-2.8),Color3.fromRGB(58,76,58),Enum.Material.SmoothPlastic,machF,"T2ArmHead")
                tierPart(t2head,2)
                -- [Tier 3] Overhead crane rail spanning the machine
                local crane=makeBox(Vector3.new(11,1,1),lc(dx,floorSurfY+14,dz),Color3.fromRGB(38,54,38),Enum.Material.Metal,machF,"T3Crane")
                tierPart(crane,3)
                local craneg=makeBox(Vector3.new(10.5,0.4,0.8),lc(dx,floorSurfY+14.8,dz),fth.light,Enum.Material.Neon,machF,"T3CraneGlow")
                tierPart(craneg,3); addLight(craneg,"PointLight",fth.light,20,2.2)
                -- Animated spinning cog on arm tower
                local cog=makeBox(Vector3.new(3,0.35,3),lc(dx+3,floorSurfY+11.5,dz-2.8),fth.light,Enum.Material.Neon,machF,"CogSpin")
                cog.Transparency=0.3
                table.insert(spinners,{part=cog, baseCF=lc(dx+3,floorSurfY+11.5,dz-2.8), speed=-(1.8+di*0.5)})

            elseif floor==3 then
                -- ---- WAR ROOM: High-tech research pod with holographic display ----
                -- Wide hexagonal-ish base platform
                makeBox(Vector3.new(11,2.2,9.5),  lc(dx,floorSurfY+1.1,dz),   Color3.fromRGB(28,34,46), Enum.Material.SmoothPlastic,machF,"MBase")
                makeBox(Vector3.new(3,2.2,5),      lc(dx+6.5,floorSurfY+1.1,dz),Color3.fromRGB(24,30,40),Enum.Material.SmoothPlastic,machF,"MBaseAngR")
                makeBox(Vector3.new(3,2.2,5),      lc(dx-6.5,floorSurfY+1.1,dz),Color3.fromRGB(24,30,40),Enum.Material.SmoothPlastic,machF,"MBaseAngL")
                -- Main body (sleek tall unit)
                makeBox(Vector3.new(7.5,10.5,7.5), lc(dx,floorSurfY+2.2+5.25,dz),fth.trim,              Enum.Material.SmoothPlastic,machF,"MBody")
                -- Front holographic display screen
                local screen=makeBox(Vector3.new(5.5,5,0.3),lc(dx,floorSurfY+7.5,dz+3.85),Color3.fromRGB(30,50,70),Enum.Material.Neon,machF,"MScreen")
                screen.Transparency=0.42
                -- Screen data lines
                for sl=1,3 do
                    makeBox(Vector3.new(4.5,0.3,0.2),lc(dx,floorSurfY+6.2+sl*0.9,dz+3.95),fth.light,Enum.Material.Neon,machF,"MScreenLine")
                end
                -- Cooling tower (back-left)
                makeBox(Vector3.new(2.8,11.5,2.8),lc(dx-2.8,floorSurfY+5.75,dz-3.2),Color3.fromRGB(22,28,38),Enum.Material.SmoothPlastic,machF,"MCoolTower")
                makeBox(Vector3.new(2.6,0.5,2.6), lc(dx-2.8,floorSurfY+12,dz-3.2),  fth.light,Enum.Material.Neon,machF,"MCoolTop")
                -- Cooling fins on sides (3 per side)
                for _,xi in ipairs({-4.2,4.2}) do
                    for fi=0,2 do
                        makeBox(Vector3.new(0.4,4.5,2.5),lc(dx+xi,floorSurfY+6+fi*2.2,dz+fi*0.4-1),Color3.fromRGB(20,26,36),Enum.Material.SmoothPlastic,machF,"MFin")
                    end
                end
                -- Main glow core on top
                local core=makeBox(Vector3.new(5,0.5,5),lc(dx,floorSurfY+13.2,dz),fth.light,Enum.Material.Neon,machF,"DGlow_F"..floor.."_"..di)
                core:SetAttribute("IsGlow",true); addLight(core,"PointLight",fth.light,14,2)
                -- [Tier 2] Energy ring around body
                local ring=makeBox(Vector3.new(10,0.5,10),lc(dx,floorSurfY+7,dz),fth.light,Enum.Material.Neon,machF,"T2Ring")
                tierPart(ring,2); addLight(ring,"PointLight",fth.light,18,2.5)
                local ring2=makeBox(Vector3.new(11,0.4,11),lc(dx,floorSurfY+11,dz),fth.light,Enum.Material.Neon,machF,"T2Ring2")
                tierPart(ring2,2)
                -- [Tier 3] Secondary angled display + overhead energy emitter
                local d2=makeBox(Vector3.new(4.5,4,0.3),lc(dx+4,floorSurfY+9.5,dz+1.5),Color3.fromRGB(30,50,70),Enum.Material.Neon,machF,"T3Disp2")
                tierPart(d2,3); d2:SetAttribute("BaseTrans",0.42)
                local emit=makeBox(Vector3.new(2.5,2.5,2.5),lc(dx,floorSurfY+16.5,dz),fth.light,Enum.Material.Neon,machF,"T3Emitter")
                tierPart(emit,3); addLight(emit,"PointLight",fth.light,28,3.5)
                -- Animated orbit ring around core — always spinning
                local orbit=makeBox(Vector3.new(8,0.4,8),lc(dx,floorSurfY+9,dz),fth.light,Enum.Material.Neon,machF,"OrbitRing")
                orbit.Transparency=0.45
                table.insert(spinners,{part=orbit, baseCF=lc(dx,floorSurfY+9,dz), speed=2.2+di*0.6})

            elseif floor==4 then
                -- ---- BLACK OPS: Experimental energy weapon core ----
                -- Heavy obsidian base with faction glow edge
                makeBox(Vector3.new(11.5,3.5,11.5),lc(dx,floorSurfY+1.75,dz),  Color3.fromRGB(6,6,10),  Enum.Material.SmoothPlastic,machF,"MBase")
                local bEdge=makeBox(Vector3.new(12,0.5,12),lc(dx,floorSurfY+3.7,dz),faction.accent,Enum.Material.Neon,machF,"MBaseEdge")
                pulse(bEdge,faction.accent,Color3.fromRGB(255,255,255),1.6)
                -- Core housing (dark octagonal shape approximated)
                makeBox(Vector3.new(8.5,9.5,8.5),lc(dx,floorSurfY+3.5+4.75,dz),Color3.fromRGB(10,10,16),Enum.Material.SmoothPlastic,machF,"MCoreHouse")
                -- Angled corner cuts (chamfer look)
                for _,ci in ipairs({{1,1},{1,-1},{-1,1},{-1,-1}}) do
                    makeBox(Vector3.new(1.5,9.5,1.5),lc(dx+ci[1]*4.75,floorSurfY+3.5+4.75,dz+ci[2]*4.75),Color3.fromRGB(8,8,14),Enum.Material.SmoothPlastic,machF,"MChamfer")
                end
                -- 4 energy collector coil towers at corners
                for _,ci in ipairs({{1,1},{1,-1},{-1,1},{-1,-1}}) do
                    makeBox(Vector3.new(2,8,2),lc(dx+ci[1]*4.5,floorSurfY+3.5+4,dz+ci[2]*4.5),Color3.fromRGB(16,12,24),Enum.Material.SmoothPlastic,machF,"MCoil")
                    local coilTop=makeBox(Vector3.new(2.2,0.5,2.2),lc(dx+ci[1]*4.5,floorSurfY+11.5,dz+ci[2]*4.5),faction.accent,Enum.Material.Neon,machF,"MCoilTop")
                    coilTop:SetAttribute("UpgradeTier",2); coilTop.Transparency=1; coilTop.CanCollide=false
                    addLight(coilTop,"PointLight",faction.accent,12,2.2)
                end
                -- Central energy core pillar (always glowing)
                local core=makeBox(Vector3.new(3,9.5,3),lc(dx,floorSurfY+3.5+4.75,dz),fth.light,Enum.Material.Neon,machF,"DGlow_F"..floor.."_"..di)
                core:SetAttribute("IsGlow",true); core.Transparency=0.2
                addLight(core,"PointLight",fth.light,20,4)
                -- Top focusing lens
                local lens=makeBox(Vector3.new(5.5,1.8,5.5),lc(dx,floorSurfY+14.2,dz),faction.accent,Enum.Material.Neon,machF,"MLens")
                pulse(lens,faction.accent,Color3.fromRGB(255,255,255),1.9)
                addLight(lens,"SpotLight",faction.accent,38,4.5)
                -- Spinning energy rings (two counter-rotating for portal look)
                local spinRing=makeBox(Vector3.new(11,0.5,11),lc(dx,floorSurfY+12,dz),faction.accent,Enum.Material.Neon,machF,"MSpinRing")
                spinRing.Transparency=0.22; addLight(spinRing,"PointLight",faction.accent,16,2.5)
                table.insert(spinners,{part=spinRing, baseCF=lc(dx,floorSurfY+12,dz), speed=1.6+di*0.35})
                local spinRing2=makeBox(Vector3.new(14,0.35,14),lc(dx,floorSurfY+9.5,dz),faction.accent,Enum.Material.Neon,machF,"MSpinRing2")
                spinRing2.Transparency=0.55
                table.insert(spinners,{part=spinRing2, baseCF=lc(dx,floorSurfY+9.5,dz), speed=-(1.0+di*0.25)})
                -- [Tier 2] Coil tops reveal (handled via UpgradeTier=2 on coilTop above)
                -- [Tier 3] Outer energy containment field
                local field=makeBox(Vector3.new(14,12,14),lc(dx,floorSurfY+3.5+6,dz),faction.accent,Enum.Material.Neon,machF,"T3Field")
                tierPart(field,3); field:SetAttribute("BaseTrans",0.78)
                addLight(field,"PointLight",faction.accent,35,3.5)
            end

            -- ---- Upgrade button (above machine) ----
            local btnOffsets = {6.4, 13.2, 14.0, 15.5}
            local upBtn=makeBox(Vector3.new(8.5,0.6,6.5),lc(dx,floorSurfY+btnOffsets[floor],dz),Color3.fromRGB(25,140,55),Enum.Material.SmoothPlastic,machF,"UpBtn_F"..floor.."_"..di)
            upBtn:SetAttribute("TycoonId",slotId); upBtn:SetAttribute("FloorId",floor)
            upBtn:SetAttribute("DropperId",di); upBtn:SetAttribute("ItemId",dd.id); upBtn:SetAttribute("IsUpgradeBtn",true)
            addBB(upBtn, dd.name.."\nLv0  |  "..numFmt(dd.baseCost).." coins", 210, Color3.new(1,1,1), Color3.fromRGB(6,20,10), 20)
            local upPP=Instance.new("ProximityPrompt")
            upPP.ActionText="Upgrade"; upPP.ObjectText=dd.name
            upPP.MaxActivationDistance=7; upPP.RequiresLineOfSight=false; upPP.Parent=upBtn
        end

        -- ---- Weapon display cases (LEFT wall) ----
        local bulletCol = BULLET_COLORS[floor]
        local wZpos = {-BD/2+8, 0, BD/2-8}
        for wi, wd in ipairs(GC_WEAPONS[floor]) do
            local wz   = wZpos[wi] or 0
            local caseX = -BW/2+4

            -- Display case body (glass cabinet)
            local cBack=makeBox(Vector3.new(1,8,7),    lc(caseX-0.6,baseY+5.5,wz), fth.trim,                  Enum.Material.SmoothPlastic,flF,"WCBack_F"..floor.."_"..wi)
            local cBody=makeBox(Vector3.new(2.5,7.5,7),lc(caseX+0.7,baseY+5.5,wz), Color3.fromRGB(10,12,16),  Enum.Material.Glass,         flF,"WCBody_F"..floor.."_"..wi)
            cBody.Transparency=0.55
            -- Glass front (tinted neon)
            local glass=makeBox(Vector3.new(0.25,7.6,7.1),lc(caseX+2,baseY+5.5,wz),bulletCol,Enum.Material.Neon,flF,"WGlass_F"..floor.."_"..wi)
            glass.Transparency=0.72
            -- Interior weapon stand
            makeBox(Vector3.new(2,0.4,5),lc(caseX+0.7,baseY+2.3,wz),fth.trim,Enum.Material.SmoothPlastic,flF,"WStand_F"..floor.."_"..wi)
            -- Overhead spot inside case
            local cLight=makeBox(Vector3.new(1.5,0.4,1.5),lc(caseX+0.7,baseY+9.2,wz),bulletCol,Enum.Material.Neon,flF,"WCLight_F"..floor.."_"..wi)
            addLight(cLight,"SpotLight",bulletCol,18,3.5)
            -- Weapon silhouette model inside case (barrel + grip)
            local bLen = 2+floor*1.4; local bH=0.4+floor*0.12
            makeBox(Vector3.new(1.3,bH,bLen),      lc(caseX+0.7,baseY+4.2,wz),                  Color3.fromRGB(52,54,62),Enum.Material.Metal,flF,"WModel_F"..floor.."_"..wi)
            makeBox(Vector3.new(1.1,bH*2.8,bLen*0.3),lc(caseX+0.7,baseY+3.3,wz+bLen*0.28),     Color3.fromRGB(44,46,54),Enum.Material.Metal,flF,"WGrip_F"..floor.."_"..wi)
            -- Weapon label plate on case back
            cBack:SetAttribute("TycoonId",slotId); cBack:SetAttribute("FloorId",floor)
            cBack:SetAttribute("WeaponId",wi); cBack:SetAttribute("IsWeaponMount",true)

            -- Buy pedestal in front
            makeBox(Vector3.new(6.5,0.5,5),  lc(caseX+7,baseY+0.25,wz),fth.trim,Enum.Material.SmoothPlastic,flF,"WPedBase_F"..floor.."_"..wi)
            makeBox(Vector3.new(3.5,2.8,3),  lc(caseX+7,baseY+1.9, wz),fth.trim,Enum.Material.SmoothPlastic,flF,"WPedCol_F"..floor.."_"..wi)
            local wBtn=makeBox(Vector3.new(6.5,0.5,5),lc(caseX+7,baseY+3.3,wz),Color3.fromRGB(18,92,172),Enum.Material.Neon,flF,"WBtn_F"..floor.."_"..wi)
            wBtn:SetAttribute("TycoonId",slotId); wBtn:SetAttribute("FloorId",floor)
            wBtn:SetAttribute("WeaponId",wi); wBtn:SetAttribute("ItemId",wd.id); wBtn:SetAttribute("IsWeaponBtn",true)
            pulse(wBtn,Color3.fromRGB(18,92,172),Color3.fromRGB(55,145,255),1.3)
            addLight(wBtn,"PointLight",Color3.fromRGB(45,125,255),11,2.2)
            addBB(wBtn, wd.name.."\n"..numFmt(wd.cost).." coins", 195, Color3.new(1,1,1), Color3.fromRGB(5,12,24), 17)
            local wPP=Instance.new("ProximityPrompt")
            wPP.ActionText="Buy / Equip"; wPP.ObjectText=wd.name
            wPP.MaxActivationDistance=7; wPP.RequiresLineOfSight=false; wPP.Parent=wBtn
        end

        -- ---- Elevator pads (front-right corner) ----
        local elevSurfY = floor==1 and PAD_H+0.3 or floorSurfY+0.3
        if floor<4 then
            -- Elevator shaft housing
            makeBox(Vector3.new(8,fh*0.65,8),lc(BW/2-9,baseY+fh*0.325,BD/2-9),Color3.fromRGB(20,20,26),Enum.Material.SmoothPlastic,flF,"ElevHousing_F"..floor)
            local elevU=makeBox(Vector3.new(7.5,0.5,7.5),lc(BW/2-9,elevSurfY,BD/2-9),Color3.fromRGB(255,200,30),Enum.Material.Neon,flF,"ElevUp_F"..floor)
            elevU:SetAttribute("TycoonId",slotId); elevU:SetAttribute("FloorId",floor); elevU:SetAttribute("IsElevUp",true)
            pulse(elevU,Color3.fromRGB(255,200,30),Color3.fromRGB(255,255,120),1.0)
            addLight(elevU,"PointLight",Color3.fromRGB(255,210,60),18,2.8)
            makeBox(Vector3.new(8,0.5,8),lc(BW/2-9,baseY+fh*0.65+0.25,BD/2-9),Color3.fromRGB(255,200,30),Enum.Material.Neon,flF,"ElevRoof_F"..floor)
            addBB(elevU,"FLOOR "..(floor+1).."  ("..numFmt(GC_FLOOR_COSTS[floor+1])..")",215,Color3.fromRGB(28,18,0),Color3.fromRGB(255,200,30),20)
            local euPP=Instance.new("ProximityPrompt")
            euPP.ActionText="Go Up"; euPP.ObjectText="Floor "..(floor+1)
            euPP.MaxActivationDistance=8; euPP.RequiresLineOfSight=false; euPP.Parent=elevU
        end
        if floor>1 then
            local elevD=makeBox(Vector3.new(6.5,0.5,6.5),lc(BW/2-9,elevSurfY,BD/2-18),Color3.fromRGB(80,150,255),Enum.Material.Neon,flF,"ElevDn_F"..floor)
            elevD:SetAttribute("TycoonId",slotId); elevD:SetAttribute("FloorId",floor); elevD:SetAttribute("IsElevDn",true)
            pulse(elevD,Color3.fromRGB(80,150,255),Color3.fromRGB(155,205,255),1.2)
            addBB(elevD,"FLOOR "..(floor-1),165,Color3.new(1,1,1),Color3.fromRGB(6,12,26),15)
            local edPP=Instance.new("ProximityPrompt")
            edPP.ActionText="Go Down"; edPP.ObjectText="Floor "..(floor-1)
            edPP.MaxActivationDistance=7; edPP.RequiresLineOfSight=false; edPP.Parent=elevD
        end

        -- ---- F4 Rooftop: Dramatic beacon tower, spinning radar, AA guns ----
        if floor==4 then
            local roofY = baseY+fh+2
            makeBox(Vector3.new(BW+3,2,BD+3),lc(0,roofY+1,0),Color3.fromRGB(7,7,12),Enum.Material.SmoothPlastic,flF,"RoofDeck_F4")
            -- Roof faction sign (massive, visible across map)
            local roofSign=makeBox(Vector3.new(BW,7,2.5),lc(0,roofY+5.5,BD/2+1.5),faction.primary,Enum.Material.SmoothPlastic,flF,"RoofSign_F4")
            addBB(roofSign,faction.name:upper(),340,faction.accent,faction.primary,110)
            local rNeon=makeBox(Vector3.new(BW-5,0.5,1.8),lc(0,roofY+2.5,BD/2+2.5),faction.accent,Enum.Material.Neon,flF,"RoofNeon_F4")
            pulse(rNeon,faction.accent,Color3.fromRGB(255,255,255),1.7)
            addLight(rNeon,"SpotLight",faction.accent,75,5.5)
            -- Central beacon tower
            local twH=30
            makeBox(Vector3.new(8,twH,8),lc(0,roofY+2+twH/2,0),Color3.fromRGB(8,8,14),Enum.Material.SmoothPlastic,flF,"BcnTower_F4")
            -- Tower neon corner strips (4 edges)
            for _,tc in ipairs({{1,1},{1,-1},{-1,1},{-1,-1}}) do
                local te=makeBox(Vector3.new(0.5,twH,0.5),lc(tc[1]*4.2,roofY+2+twH/2,tc[2]*4.2),faction.accent,Enum.Material.Neon,flF,"TowerEdge_F4")
                pulse(te,faction.accent,Color3.fromRGB(255,255,255),0.85+tc[1]*tc[2]*0.1)
            end
            -- Tower top beacon cap
            local twTop = roofY+2+twH
            local cap=makeBox(Vector3.new(10.5,3,10.5),lc(0,twTop+1.5,0),faction.accent,Enum.Material.Neon,flF,"BcnCap_F4")
            pulse(cap,faction.accent,Color3.fromRGB(255,255,255),0.75)
            addLight(cap,"SpotLight",faction.accent,110,8)
            addLight(cap,"PointLight",faction.accent,45,6)
            -- Spinning radar arm + dish (animated)
            local radarY = twTop+4.5
            local radarArm=makeBox(Vector3.new(14,0.8,1.4),lc(0,radarY,0),faction.accent,Enum.Material.Neon,flF,"RadarArm_F4")
            local radarDish=makeBox(Vector3.new(5,2,5),     lc(6,radarY+1.2,0),Color3.fromRGB(24,24,32),Enum.Material.SmoothPlastic,flF,"RadarDish_F4")
            makeBox(Vector3.new(1.5,1.5,1.5),lc(0,radarY,0),faction.accent,Enum.Material.Neon,flF,"RadarPivot_F4")
            local pivotCF   = lc(0,radarY,0)
            local armLocal  = CFrame.new(0,0,0)
            local dishLocal = CFrame.new(6,1.2,0)
            table.insert(spinners,{type="pivot", arm=radarArm, dish=radarDish, pivotCF=pivotCF, armLocal=armLocal, dishLocal=dishLocal, speed=0.75})
            -- Rooftop corner floodlights
            for _,rc in ipairs({{BW/2-5,-(BD/2-5)},{-(BW/2-5),-(BD/2-5)},{BW/2-5,BD/2-5},{-(BW/2-5),BD/2-5}}) do
                local rl=makeBox(Vector3.new(3.5,0.5,3.5),lc(rc[1],roofY+2.6,rc[2]),faction.accent,Enum.Material.Neon,flF,"RoofFlood_F4")
                pulse(rl,faction.accent,Color3.fromRGB(255,255,255),1.0+math.abs(rc[1])*0.02)
                addLight(rl,"PointLight",faction.accent,18,3)
            end
            -- Anti-aircraft gun emplacements (front corners, visible silhouettes)
            for _,sx in ipairs({-BW/2+7, BW/2-7}) do
                makeBox(Vector3.new(2.5,5,2.5),    lc(sx,roofY+4.5,BD/2-5),   Color3.fromRGB(16,16,22),Enum.Material.Metal,flF,"AABase_F4")
                makeBox(Vector3.new(4,3,4),         lc(sx,roofY+7.5,BD/2-5),   Color3.fromRGB(20,20,28),Enum.Material.Metal,flF,"AATurret_F4")
                makeBox(Vector3.new(1.2,1.2,9),     lc(sx,roofY+9,BD/2-5),     Color3.fromRGB(24,24,32),Enum.Material.Metal,flF,"AABarrel_F4")
                local aaglow=makeBox(Vector3.new(1.5,0.4,1.5),lc(sx,roofY+7.8,BD/2-5),faction.accent,Enum.Material.Neon,flF,"AAGlow_F4")
                addLight(aaglow,"PointLight",faction.accent,9,1.8)
            end
        end

        hideFolder(flF)
    end
end

for i,slot in ipairs(SLOTS) do
    buildTycoon(i,slot,FACTIONS[i])
end

-- ============================================================
-- Spinner heartbeat (machine rings + radar dishes)
-- ============================================================

RunService.Heartbeat:Connect(function()
    local t = tick()
    for _, s in ipairs(spinners) do
        if s.type == "pivot" then
            local rot = CFrame.Angles(0, t*s.speed, 0)
            if s.arm.Parent  then s.arm.CFrame  = s.pivotCF * rot * s.armLocal  end
            if s.dish.Parent then s.dish.CFrame = s.pivotCF * rot * s.dishLocal end
        else
            if s.part.Parent then
                s.part.CFrame = s.baseCF * CFrame.Angles(0, t*s.speed, 0)
            end
        end
    end
end)

-- ============================================================
-- PvP Cover
-- ============================================================

math.randomseed(42)
local coverLayout = {
    {Vector3.new(-52,0, 0),   Vector3.new(14,4.5,3),  Color3.fromRGB(65,60,50),  "Barricade"},
    {Vector3.new( 52,0, 0),   Vector3.new(14,4.5,3),  Color3.fromRGB(65,60,50),  "Barricade"},
    {Vector3.new(0,0,-52),    Vector3.new(3,4.5,14),  Color3.fromRGB(65,60,50),  "Barricade"},
    {Vector3.new(0,0, 52),    Vector3.new(3,4.5,14),  Color3.fromRGB(65,60,50),  "Barricade"},
    {Vector3.new(-82,0,-82),  Vector3.new(14,5.5,14), Color3.fromRGB(58,55,45),  "Bunker"},
    {Vector3.new( 82,0,-82),  Vector3.new(14,5.5,14), Color3.fromRGB(58,55,45),  "Bunker"},
    {Vector3.new(-82,0, 82),  Vector3.new(14,5.5,14), Color3.fromRGB(58,55,45),  "Bunker"},
    {Vector3.new( 82,0, 82),  Vector3.new(14,5.5,14), Color3.fromRGB(58,55,45),  "Bunker"},
    {Vector3.new(-98,0, 0),   Vector3.new(3.5,4,16),  Color3.fromRGB(135,120,85),"Sandbag"},
    {Vector3.new( 98,0, 0),   Vector3.new(3.5,4,16),  Color3.fromRGB(135,120,85),"Sandbag"},
    {Vector3.new(0,0,-98),    Vector3.new(16,4,3.5),  Color3.fromRGB(135,120,85),"Sandbag"},
    {Vector3.new(0,0, 98),    Vector3.new(16,4,3.5),  Color3.fromRGB(135,120,85),"Sandbag"},
    {Vector3.new(-52,0, 32),  Vector3.new(5,7,5),     Color3.fromRGB(48,56,62),  "Crate"},
    {Vector3.new( 52,0,-32),  Vector3.new(5,7,5),     Color3.fromRGB(48,56,62),  "Crate"},
    {Vector3.new(-32,0,-68),  Vector3.new(5,7,5),     Color3.fromRGB(48,56,62),  "Crate"},
    {Vector3.new( 32,0, 68),  Vector3.new(5,7,5),     Color3.fromRGB(48,56,62),  "Crate"},
    {Vector3.new(-112,0, 42), Vector3.new(12,4,3),    Color3.fromRGB(65,60,50),  "Wall"},
    {Vector3.new( 112,0,-42), Vector3.new(12,4,3),    Color3.fromRGB(65,60,50),  "Wall"},
}
for _,cl in ipairs(coverLayout) do
    local pos=cl[1]; local sz=cl[2]; local col=cl[3]; local nm=cl[4]
    local yaw=math.random()*0.4-0.2
    makeBox(sz,CFrame.new(pos)*CFrame.Angles(0,yaw,0)*CFrame.new(0,sz.Y/2,0),col,Enum.Material.SmoothPlastic,covF,nm)
    if sz.Y>=4.5 then
        makeBox(Vector3.new(sz.X,0.3,0.35),CFrame.new(pos)*CFrame.Angles(0,yaw,0)*CFrame.new(0,sz.Y*0.62,sz.Z/2),AMBER,Enum.Material.SmoothPlastic,covF,"Stripe")
    end
end

-- ============================================================
-- VIP Zone: Center elevated platform
-- ============================================================

local VT_COL  = Color3.fromRGB(180,148,15)
local VT_TRIM = Color3.fromRGB(255,210,0)
local VT_PLT  = Color3.fromRGB(38,32,8)
local VIP_Y   = 16

local vipPlat=makeBox(Vector3.new(52,VIP_Y,52),CFrame.new(0,VIP_Y/2,0),VT_PLT,Enum.Material.SmoothPlastic,vipF,"VIPPlatform")
addLight(vipPlat,"SpotLight",Color3.fromRGB(255,238,100),100,4)
makeBox(Vector3.new(52,0.5,52),CFrame.new(0,VIP_Y+0.25,0),Color3.fromRGB(26,21,4),Enum.Material.SmoothPlastic,vipF,"VIPFloor")

for _,ed in ipairs({
    {Vector3.new(52,1,1.4),CFrame.new(0,VIP_Y+0.7,-26.7)},
    {Vector3.new(52,1,1.4),CFrame.new(0,VIP_Y+0.7, 26.7)},
    {Vector3.new(1.4,1,52),CFrame.new(-26.7,VIP_Y+0.7,0)},
    {Vector3.new(1.4,1,52),CFrame.new( 26.7,VIP_Y+0.7,0)},
}) do
    local tr=makeBox(ed[1],ed[2],VT_TRIM,Enum.Material.Neon,vipF,"VIPTrim")
    pulse(tr,VT_TRIM,Color3.fromRGB(255,255,140),1.7)
end

for _,sd in ipairs({
    {axis="Z", dir= 1, pos=Vector3.new(0,0, 26)},
    {axis="Z", dir=-1, pos=Vector3.new(0,0,-26)},
    {axis="X", dir= 1, pos=Vector3.new( 26,0,0)},
    {axis="X", dir=-1, pos=Vector3.new(-26,0,0)},
}) do
    local rampRise=VIP_Y; local rampRun=24
    local rampSz = sd.axis=="Z" and Vector3.new(10,rampRise,rampRun) or Vector3.new(rampRun,rampRise,10)
    local rampPos = sd.axis=="Z" and Vector3.new(0,rampRise/2,sd.pos.Z+sd.dir*rampRun/2) or Vector3.new(sd.pos.X+sd.dir*rampRun/2,rampRise/2,0)
    local angleY  = sd.axis=="Z" and 0 or math.pi/2
    local angleX  = math.atan2(rampRise,rampRun)*sd.dir*(sd.axis=="Z" and -1 or 1)
    makeWedge(rampSz,CFrame.new(rampPos)*CFrame.Angles(angleX*(sd.axis=="Z" and 1 or 0),angleY,angleX*(sd.axis=="X" and 1 or 0)),VT_COL,Enum.Material.SmoothPlastic,vipF,"VIPRamp")
end

local gate=makeBox(Vector3.new(10,10,1),CFrame.new(0,VIP_Y+5,27),VT_TRIM,Enum.Material.Neon,vipF,"VIPGate")
gate.Transparency=0.42; gate:SetAttribute("IsVIPGate",true)
addBB(gate,"VIP ONLY - Step up to buy",225,Color3.fromRGB(255,215,0),Color3.fromRGB(18,14,0),30)

local crownPed=makeBox(Vector3.new(7,2,7),CFrame.new(0,VIP_Y+1,0),VT_TRIM,Enum.Material.Neon,vipF,"CrownPedestal")
crownPed:SetAttribute("IsCrownPed",true)
addBB(crownPed,"CLAIM CROWN (VIP Only)",205,Color3.fromRGB(255,215,0),Color3.fromRGB(18,14,0),22)
addLight(crownPed,"PointLight",Color3.fromRGB(255,235,100),20,3)
local cp2=Instance.new("ProximityPrompt"); cp2.ActionText="Claim Crown"; cp2.ObjectText="VIP"; cp2.MaxActivationDistance=7; cp2.RequiresLineOfSight=false; cp2.Parent=crownPed

local vPad=makeBox(Vector3.new(16,1,16),CFrame.new(0,0.5,56),VT_TRIM,Enum.Material.Neon,vipF,"VIPPurchasePad")
vPad:SetAttribute("IsVIPPad",true)
addBB(vPad,"STEP HERE: BUY VIP\n499 Robux",255,Color3.fromRGB(255,215,0),Color3.fromRGB(20,16,0),28)
pulse(vPad,VT_TRIM,Color3.fromRGB(255,255,100),1.1)
addLight(vPad,"PointLight",Color3.fromRGB(255,225,80),20,2.5)
local pp_vip=Instance.new("ProximityPrompt"); pp_vip.ActionText="Buy VIP (499 R$)"; pp_vip.ObjectText="VIP Gamepass"; pp_vip.MaxActivationDistance=10; pp_vip.RequiresLineOfSight=false; pp_vip.Parent=vPad

for wi=-1,1 do
    local stand=makeBox(Vector3.new(4,11,2),CFrame.new(wi*16,VIP_Y+5.5,-18),VT_COL,Enum.Material.SmoothPlastic,vipF,"VIPDisplay")
    local dg=makeBox(Vector3.new(3.5,0.4,1.8),CFrame.new(wi*16,VIP_Y+11.2,-18),VT_TRIM,Enum.Material.Neon,vipF,"VIPDisplayGlow")
    addLight(dg,"PointLight",Color3.fromRGB(255,235,100),12,2)
end

-- ============================================================
-- Owner door
-- ============================================================

local ownerDoor=makeBox(Vector3.new(DOOR_W-2,18,2),CFrame.new(0,9,hz+wT/2),Color3.fromRGB(28,195,78),Enum.Material.Neon,ownF,"OwnerDoor")
ownerDoor.Transparency=0.35; ownerDoor:SetAttribute("IsOwnerDoor",true)
addLight(ownerDoor,"PointLight",Color3.fromRGB(60,255,110),18,2.5)
for _,fr in ipairs({
    {Vector3.new(2,22,wT+2),CFrame.new(-DOOR_W/2,11,hz+wT/2)},
    {Vector3.new(2,22,wT+2),CFrame.new( DOOR_W/2,11,hz+wT/2)},
    {Vector3.new(DOOR_W+4,3,wT+2),CFrame.new(0,21.5,hz+wT/2)},
}) do makeBox(fr[1],fr[2],Color3.fromRGB(18,18,24),Enum.Material.SmoothPlastic,ownF,"DFrame") end

local keypad=makeBox(Vector3.new(4,6,2.5),CFrame.new(-8,7,hz+wT/2-wT/2-1.5),Color3.fromRGB(16,16,24),Enum.Material.SmoothPlastic,ownF,"OwnerKeypad")
keypad:SetAttribute("IsOwnerKeypad",true)
addBB(keypad,"OWNER ACCESS",155,Color3.fromRGB(80,255,120),Color3.fromRGB(5,12,6),12)
addLight(keypad,"PointLight",Color3.fromRGB(55,255,100),7,1.8)
local kpp=Instance.new("ProximityPrompt"); kpp.ActionText="Access"; kpp.ObjectText="Staff Only"; kpp.MaxActivationDistance=8; kpp.RequiresLineOfSight=false; kpp.Parent=keypad

local rmPos=Vector3.new(0,10,hz+wT+20)
makeBox(Vector3.new(40,20,34),CFrame.new(rmPos.X,rmPos.Y,rmPos.Z),Color3.fromRGB(14,14,20),Enum.Material.SmoothPlastic,ownF,"OwnerRoomHull")
local rmL=makeBox(Vector3.new(7,0.4,7),CFrame.new(rmPos.X,rmPos.Y+9.8,rmPos.Z),Color3.fromRGB(120,255,160),Enum.Material.Neon,ownF,"RmLight")
addLight(rmL,"PointLight",Color3.fromRGB(100,255,140),28,2.5)
local exitPad=makeBox(Vector3.new(4,6,2.5),CFrame.new(rmPos.X+8,rmPos.Y-4,rmPos.Z-15.5),Color3.fromRGB(16,16,24),Enum.Material.SmoothPlastic,ownF,"OwnerExitPad")
exitPad:SetAttribute("IsOwnerExit",true)
addBB(exitPad,"EXIT",95,Color3.fromRGB(255,100,80),Color3.fromRGB(14,5,5),12)
local epp=Instance.new("ProximityPrompt"); epp.ActionText="Exit"; epp.ObjectText=""; epp.MaxActivationDistance=7; epp.RequiresLineOfSight=false; epp.Parent=exitPad

-- ============================================================
-- Leaderboard
-- ============================================================

local lbPart=makeBox(Vector3.new(68,52,3),CFrame.new(0,28,-(hz-8)),Color3.fromRGB(8,8,14),Enum.Material.SmoothPlastic,mapF,"LeaderboardBoard")
lbPart:SetAttribute("IsLeaderboard",true)
makeBox(Vector3.new(72,56,1),CFrame.new(0,28,-(hz-7.5)),AMBER,Enum.Material.Neon,mapF,"LBFrame").Transparency=0.52
addLight(lbPart,"SpotLight",Color3.fromRGB(255,200,45),38,2.5)
local sg=Instance.new("SurfaceGui"); sg.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize; sg.CanvasSize=Vector2.new(680,520); sg.Face=Enum.NormalId.Front; sg.Name="LBSurface"; sg.Parent=lbPart
local lbT=Instance.new("TextLabel",sg); lbT.Name="Title"; lbT.Size=UDim2.new(1,0,0.12,0); lbT.BackgroundTransparency=1; lbT.TextColor3=Color3.fromRGB(255,200,40); lbT.Font=Enum.Font.GothamBold; lbT.Text="TOP EARNERS"; lbT.TextScaled=true
local lbEnt=Instance.new("Frame",sg); lbEnt.Name="Entries"; lbEnt.Size=UDim2.new(1,-14,0.88,0); lbEnt.Position=UDim2.new(0,7,0.12,0); lbEnt.BackgroundTransparency=1
for r=1,10 do
    local e=Instance.new("TextLabel",lbEnt); e.Name="R"..r
    e.Size=UDim2.new(1,0,0.1,-3); e.Position=UDim2.new(0,0,(r-1)*0.1,0)
    e.BackgroundColor3=r<=3 and Color3.fromRGB(36,32,5) or Color3.fromRGB(12,12,18); e.BackgroundTransparency=0.2
    e.TextColor3=r==1 and Color3.fromRGB(255,215,0) or r==2 and Color3.fromRGB(198,198,198) or r==3 and Color3.fromRGB(172,100,38) or Color3.fromRGB(185,185,190)
    e.Font=Enum.Font.GothamBold; e.Text="#"..r.."  --"; e.TextScaled=true
    Instance.new("UICorner",e).CornerRadius=UDim.new(0.18,0)
end

-- ============================================================
-- Spawn pad
-- ============================================================

local spPlat=makeBox(Vector3.new(32,3,32),CFrame.new(0,1.5,0),Color3.fromRGB(38,38,46),Enum.Material.Concrete,mapF,"SpawnPad")
for _,sd in ipairs({
    {Vector3.new(32,0.4,1),CFrame.new(0,3.2,-15.5)},{Vector3.new(32,0.4,1),CFrame.new(0,3.2,15.5)},
    {Vector3.new(1,0.4,32),CFrame.new(-15.5,3.2,0)},{Vector3.new(1,0.4,32),CFrame.new(15.5,3.2,0)},
}) do
    local s=makeBox(sd[1],sd[2],AMBER,Enum.Material.Neon,mapF,"SpawnBorder"); pulse(s,AMBER,Color3.fromRGB(255,200,80),2.4)
end
local spg=makeBox(Vector3.new(3,0.4,3),CFrame.new(0,3.2,0),Color3.fromRGB(90,255,130),Enum.Material.Neon,mapF,"SpawnGlow")
addLight(spg,"PointLight",Color3.fromRGB(90,255,130),22,2.2)
addBB(spPlat,"SPAWN",150,Color3.fromRGB(180,255,190),Color3.fromRGB(10,14,12),28)

-- ============================================================
-- Atmosphere
-- ============================================================

local lighting=game:GetService("Lighting")
lighting.Brightness=1.55; lighting.ClockTime=15; lighting.FogEnd=850
lighting.FogColor=Color3.fromRGB(22,22,30); lighting.Ambient=Color3.fromRGB(80,80,96)
lighting.OutdoorAmbient=Color3.fromRGB(98,98,112); lighting.ShadowSoftness=0.22

local atmo=Instance.new("Atmosphere",lighting)
atmo.Density=0.2; atmo.Offset=0.12; atmo.Haze=0.32
atmo.Color=Color3.fromRGB(105,115,152); atmo.Glare=0.15; atmo.Decay=Color3.fromRGB(72,72,98)
local bloom=Instance.new("BloomEffect",lighting)
bloom.Intensity=0.48; bloom.Size=22; bloom.Threshold=0.92

print("[MapBuilder] Iron Arsenal v4 ready - "..#tycF:GetChildren().." tycoon slots, "..#spinners.." animated parts")

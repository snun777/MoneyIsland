-- GunTycoon MapBuilder v3 - Iron Arsenal
-- Progressive building: floors only appear when purchased
-- Center VIP platform, elevator navigation, clean weapon/dropper layout

local TweenService = game:GetService("TweenService")
local WS           = game:GetService("Workspace")

-- ============================================================
-- Inline config
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

-- Per-floor visual theme
local FLOOR_THEME = {
    [1]={name="Armory",    wall=Color3.fromRGB(62,62,72),  trim=Color3.fromRGB(88,88,102), light=Color3.fromRGB(200,210,255), neon=false},
    [2]={name="Barracks",  wall=Color3.fromRGB(48,62,48),  trim=Color3.fromRGB(72,100,72), light=Color3.fromRGB(130,255,130), neon=true },
    [3]={name="War Room",  wall=Color3.fromRGB(58,44,28),  trim=Color3.fromRGB(98,76,44),  light=Color3.fromRGB(255,145,65),  neon=true },
    [4]={name="Black Ops", wall=Color3.fromRGB(16,16,22),  trim=Color3.fromRGB(58,40,92),  light=Color3.fromRGB(148,65,255),  neon=true },
}
local FLOOR_H    = {14, 16, 20, 24}   -- height of each floor in studs
local PAD_H      = 2                   -- pad height off ground
local BW         = 50                  -- building width
local BD         = 38                  -- building depth
-- Computed floor base-Y (interior floor level for each floor)
local BASE_Y     = {PAD_H}
for f = 2, 4 do BASE_Y[f] = BASE_Y[f-1] + FLOOR_H[f-1] + 2 end
-- BASE_Y = {2, 18, 36, 58}

local BULLET_COLORS = {
    Color3.fromRGB(255,240,160), Color3.fromRGB(160,220,255),
    Color3.fromRGB(255,100,50),  Color3.fromRGB(200,80,255),
}
local AMBER   = Color3.fromRGB(255,162,0)
local PLT_COL = Color3.fromRGB(28,28,34)
local WLL_COL = Color3.fromRGB(20,20,26)

local GC_DROPPERS = {
    [1]={ {name="Pistol Range",baseCost=0,maxLevel=8,costMult=2.1},{name="Rifle Station",baseCost=200,maxLevel=8,costMult=2.1},{name="Shotgun Rack",baseCost=700,maxLevel=8,costMult=2.1},{name="Ammo Press",baseCost=2500,maxLevel=8,costMult=2.1} },
    [2]={ {name="SMG Assembly",baseCost=9000,maxLevel=8,costMult=2.15},{name="AR Workshop",baseCost=25000,maxLevel=8,costMult=2.15},{name="Heavy Forge",baseCost=65000,maxLevel=8,costMult=2.15} },
    [3]={ {name="Sniper Lab",baseCost=200000,maxLevel=8,costMult=2.2},{name="LMG Factory",baseCost=550000,maxLevel=8,costMult=2.2},{name="Launcher Bay",baseCost=1500000,maxLevel=8,costMult=2.2} },
    [4]={ {name="Minigun Core",baseCost=4000000,maxLevel=8,costMult=2.3},{name="Rocket Depot",baseCost=12000000,maxLevel=8,costMult=2.3},{name="Railgun Lab",baseCost=35000000,maxLevel=8,costMult=2.3} },
}
local GC_WEAPONS = {
    [1]={ {name="Pistol",cost=600},{name="Revolver",cost=2500},{name="Shotgun",cost=5000} },
    [2]={ {name="SMG",cost=15000},{name="Assault Rifle",cost=35000},{name="Combat Shotgun",cost=75000} },
    [3]={ {name="Sniper Rifle",cost=250000},{name="LMG",cost=600000},{name="Grenade Launcher",cost=1200000} },
    [4]={ {name="Minigun",cost=5000000},{name="Rocket Launcher",cost=14000000},{name="Railgun",cost=30000000} },
}
local GC_FLOOR_COSTS = {0, 5000, 120000, 2500000}

-- ============================================================
-- Helpers
-- ============================================================

local function makeBox(size, cf, color, mat, parent, name)
    local p = Instance.new("Part")
    p.Size        = size; p.CFrame    = cf
    p.Color       = color; p.Material = mat or Enum.Material.SmoothPlastic
    p.Anchored    = true; p.CastShadow = false
    p.Name        = name or "Part"; p.Parent = parent or WS
    return p
end

local function makeWedge(size, cf, color, mat, parent, name)
    local p = Instance.new("WedgePart")
    p.Size = size; p.CFrame = cf; p.Color = color
    p.Material = mat or Enum.Material.SmoothPlastic
    p.Anchored = true; p.CastShadow = false
    p.Name = name or "Wedge"; p.Parent = parent or WS
    return p
end

local function addLight(part, ltype, color, range, brightness)
    local l = Instance.new(ltype or "PointLight")
    l.Color = color or Color3.new(1,1,1); l.Range = range or 16
    l.Brightness = brightness or 2
    if ltype == "SpotLight" then l.Angle = 50; l.Face = Enum.NormalId.Top end
    l.Parent = part; return l
end

local function addBB(part, text, width, textCol, bgCol, maxDist)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, width or 200, 0, 46)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = maxDist or 24
    bb.Adornee = part; bb.Parent = part
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundColor3 = bgCol or Color3.fromRGB(8,8,12)
    lbl.BackgroundTransparency = 0.1
    lbl.TextColor3 = textCol or Color3.new(1,1,1)
    lbl.Text = text; lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true; lbl.Name = "Label"; lbl.BorderSizePixel = 0
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0.22, 0)
    return lbl
end

local function pulse(part, c1, c2, dur)
    task.spawn(function()
        TweenService:Create(part, TweenInfo.new(dur or 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Color=c2}):Play()
    end)
end

local function numFmt(n)
    if n>=1e9 then return string.format("%.1fB",n/1e9)
    elseif n>=1e6 then return string.format("%.1fM",n/1e6)
    elseif n>=1e3 then return string.format("%.1fK",n/1e3)
    else return tostring(n) end
end

-- Hide all BaseParts and disable all ProximityPrompts in a folder (for progressive reveal)
local function hideFolder(folder)
    for _, d in ipairs(folder:GetDescendants()) do
        if d:IsA("BasePart") then
            d:SetAttribute("OrigTrans", d.Transparency)
            d:SetAttribute("OrigCollide", d.CanCollide)
            d.Transparency = 1; d.CanCollide = false; d.CastShadow = false
        elseif d:IsA("ProximityPrompt") then
            d.Enabled = false
        end
    end
end

-- ============================================================
-- World folders
-- ============================================================

local mapF    = Instance.new("Folder"); mapF.Name="Map";      mapF.Parent=WS
local tycF    = Instance.new("Folder"); tycF.Name="Tycoons";  tycF.Parent=WS
local covF    = Instance.new("Folder"); covF.Name="Cover";    covF.Parent=WS
local vipF    = Instance.new("Folder"); vipF.Name="VIPZone";  vipF.Parent=WS
local ownF    = Instance.new("Folder"); ownF.Name="OwnerRoom"; ownF.Parent=WS

-- ============================================================
-- Platform
-- ============================================================

local PSIZE = Vector3.new(640, 5, 640)
local hx = PSIZE.X/2; local hz = PSIZE.Z/2
local wH = 82; local wT = 12

makeBox(PSIZE, CFrame.new(0,-PSIZE.Y/2,0), PLT_COL, Enum.Material.SmoothPlastic, mapF, "Platform")

-- Grid lines
for i = -4, 4 do
    local gc = i==0 and Color3.fromRGB(55,55,68) or Color3.fromRGB(36,36,44)
    makeBox(Vector3.new(PSIZE.X,0.08,1.2), CFrame.new(0,0.04,i*80), gc, Enum.Material.SmoothPlastic, mapF, "GridH")
    makeBox(Vector3.new(1.2,0.08,PSIZE.Z), CFrame.new(i*80,0.04,0), gc, Enum.Material.SmoothPlastic, mapF, "GridV")
end

-- Amber border neons inside platform edge
for _,sd in ipairs({
    {Vector3.new(PSIZE.X-4,0.4,1.5), CFrame.new(0,0.2,-(hz-1.5))},
    {Vector3.new(PSIZE.X-4,0.4,1.5), CFrame.new(0,0.2,  hz-1.5)},
    {Vector3.new(1.5,0.4,PSIZE.Z-4), CFrame.new(-(hx-1.5),0.2,0)},
    {Vector3.new(1.5,0.4,PSIZE.Z-4), CFrame.new(  hx-1.5, 0.2,0)},
}) do
    local s = makeBox(sd[1],sd[2],AMBER,Enum.Material.Neon,mapF,"Border")
    pulse(s,AMBER,Color3.fromRGB(255,200,80),2.2)
end

-- ============================================================
-- Perimeter walls (south wall split for owner door)
-- ============================================================

local DOOR_W = 14
local sHalf  = (PSIZE.X + wT*2 - DOOR_W)/2

makeBox(Vector3.new(PSIZE.X+wT*2,wH,wT), CFrame.new(0,wH/2,-(hz+wT/2)),   WLL_COL, Enum.Material.SmoothPlastic, mapF, "WallN")
makeBox(Vector3.new(sHalf,wH,wT),         CFrame.new(-(DOOR_W/2+sHalf/2),wH/2,hz+wT/2), WLL_COL, Enum.Material.SmoothPlastic, mapF, "WallS_L")
makeBox(Vector3.new(sHalf,wH,wT),         CFrame.new(  DOOR_W/2+sHalf/2, wH/2,hz+wT/2), WLL_COL, Enum.Material.SmoothPlastic, mapF, "WallS_R")
makeBox(Vector3.new(DOOR_W+6,10,wT+2),    CFrame.new(0,wH-5,hz+wT/2),     Color3.fromRGB(24,24,30), Enum.Material.SmoothPlastic, ownF, "DoorLintel")
makeBox(Vector3.new(wT,wH,PSIZE.Z),       CFrame.new(-(hx+wT/2),wH/2,0),  WLL_COL, Enum.Material.SmoothPlastic, mapF, "WallW")
makeBox(Vector3.new(wT,wH,PSIZE.Z),       CFrame.new(  hx+wT/2, wH/2,0),  WLL_COL, Enum.Material.SmoothPlastic, mapF, "WallE")

-- Wall amber floodlights
for _,wx in ipairs({-80,0,80}) do
    for _,side in ipairs({-(hx+wT-2),(hx+wT-2)}) do
        local wlp = makeBox(Vector3.new(2.5,2.5,2.5), CFrame.new(side,20,wx), AMBER, Enum.Material.Neon, mapF, "WLight")
        addLight(wlp,"PointLight",Color3.fromRGB(255,175,70),55,1.8)
    end
end
for _,wz in ipairs({-80,0,80}) do
    for _,side in ipairs({-(hz+wT-2),(hz+wT-2)}) do
        local wlp = makeBox(Vector3.new(2.5,2.5,2.5), CFrame.new(wz,20,side), AMBER, Enum.Material.Neon, mapF, "WLight")
        addLight(wlp,"PointLight",Color3.fromRGB(255,175,70),55,1.8)
    end
end

-- Battlements
local bS = 18
for i=1,math.floor((PSIZE.X+wT*2)/bS) do
    local bx = -(hx+wT)+(i-0.5)*bS
    local battC = Color3.fromRGB(16,16,20)
    makeBox(Vector3.new(bS*0.48,7,wT*0.8), CFrame.new(bx,wH+3.5,-(hz+wT/2)), battC, Enum.Material.SmoothPlastic, mapF, "Batt")
    makeBox(Vector3.new(bS*0.48,7,wT*0.8), CFrame.new(bx,wH+3.5,  hz+wT/2),  battC, Enum.Material.SmoothPlastic, mapF, "Batt")
end
for i=1,math.floor(PSIZE.Z/bS) do
    local bz = -hz+(i-0.5)*bS; local battC = Color3.fromRGB(16,16,20)
    makeBox(Vector3.new(wT*0.8,7,bS*0.48), CFrame.new(-(hx+wT/2),wH+3.5,bz), battC, Enum.Material.SmoothPlastic, mapF, "Batt")
    makeBox(Vector3.new(wT*0.8,7,bS*0.48), CFrame.new(  hx+wT/2, wH+3.5,bz), battC, Enum.Material.SmoothPlastic, mapF, "Batt")
end

-- Corner towers
for _,cv in ipairs({Vector3.new(-(hx+wT/2),0,-(hz+wT/2)),Vector3.new(hx+wT/2,0,-(hz+wT/2)),Vector3.new(-(hx+wT/2),0,hz+wT/2),Vector3.new(hx+wT/2,0,hz+wT/2)}) do
    local tw=wT+14; local th=wH+30
    makeBox(Vector3.new(tw,th,tw), CFrame.new(cv.X,th/2,cv.Z), Color3.fromRGB(18,18,24), Enum.Material.SmoothPlastic, mapF, "Tower")
    local cap=makeBox(Vector3.new(tw+2,1.5,tw+2), CFrame.new(cv.X,th+0.75,cv.Z), AMBER, Enum.Material.Neon, mapF, "TowerCap")
    addLight(cap,"PointLight",Color3.fromRGB(255,175,60),35,3)
    addLight(makeBox(Vector3.new(tw,1,tw),CFrame.new(cv.X,th+0.5,cv.Z),WLL_COL,Enum.Material.SmoothPlastic,mapF,"TowerTop"),"SpotLight",Color3.fromRGB(240,215,155),115,6)
end

-- ============================================================
-- Tycoon slot positions
-- ============================================================

local SLOTS = {
    {pos=Vector3.new(-238,0,  0), look=Vector3.new( 1,0, 0)},
    {pos=Vector3.new( 238,0,  0), look=Vector3.new(-1,0, 0)},
    {pos=Vector3.new(  0,0,-238), look=Vector3.new( 0,0, 1)},
    {pos=Vector3.new(  0,0, 238), look=Vector3.new( 0,0,-1)},
    {pos=Vector3.new(-168,0,-168), look=Vector3.new( 1,0, 1).Unit},
    {pos=Vector3.new( 168,0,-168), look=Vector3.new(-1,0, 1).Unit},
    {pos=Vector3.new(-168,0, 168), look=Vector3.new( 1,0,-1).Unit},
    {pos=Vector3.new( 168,0, 168), look=Vector3.new(-1,0,-1).Unit},
}

-- ============================================================
-- Build one tycoon
-- ============================================================

local function buildTycoon(slotId, slotData, faction)
    local folder = Instance.new("Folder")
    folder.Name = "Tycoon_"..slotId; folder.Parent = tycF

    local look   = slotData.look
    local origin = slotData.pos
    local rightV = Vector3.new(-look.Z, 0, look.X)
    local baseCF = CFrame.fromMatrix(origin, rightV, Vector3.new(0,1,0), -look)
    local function lc(x,y,z) return baseCF * CFrame.new(x,y,z) end

    -- Foundation pad (always visible)
    local pad = makeBox(Vector3.new(BW+10,PAD_H,BD+10), lc(0,PAD_H/2,0), Color3.fromRGB(28,28,34), Enum.Material.Concrete, folder, "Pad")
    pad:SetAttribute("TycoonId", slotId); pad:SetAttribute("IsPad", true)

    -- Faction-colored pad accent strip on front edge
    local padStr = makeBox(Vector3.new(BW+10,0.4,1.5), lc(0,PAD_H+0.2,(BD+10)/2), faction.accent, Enum.Material.Neon, folder, "PadStripe")
    pulse(padStr, faction.accent, Color3.fromRGB(255,255,200), 1.6)

    -- Claim button (always visible, front-center of pad)
    local claim = makeBox(Vector3.new(10,0.5,10), lc(0,PAD_H+0.25,(BD+8)/2-8), Color3.fromRGB(38,192,68), Enum.Material.Neon, folder, "ClaimButton")
    claim:SetAttribute("TycoonId", slotId); claim:SetAttribute("IsClaimBtn", true)
    addBB(claim, "CLAIM  "..faction.name, 220, Color3.fromRGB(255,255,200), Color3.fromRGB(8,18,6), 36)
    pulse(claim, Color3.fromRGB(38,192,68), Color3.fromRGB(92,255,112), 0.95)
    addLight(claim,"PointLight",Color3.fromRGB(55,255,85),18,2.5)
    local pp = Instance.new("ProximityPrompt"); pp.ActionText="Claim"; pp.ObjectText=faction.name
    pp.MaxActivationDistance=14; pp.RequiresLineOfSight=false; pp.Parent=claim

    -- ================================================================
    -- Build each floor (all content hidden initially)
    -- ================================================================

    for floor = 1, 4 do
        local fth  = FLOOR_THEME[floor]
        local fac  = faction
        local baseY = BASE_Y[floor]
        local fh    = FLOOR_H[floor]

        local floorFolder = Instance.new("Folder")
        floorFolder.Name = "Floor_"..floor; floorFolder.Parent = folder

        local function fl(x,y,z) return baseCF*CFrame.new(x,y,z) end

        -- ---- Structural walls ----
        -- Back wall
        makeBox(Vector3.new(BW,fh,2.5), fl(0,baseY+fh/2,-BD/2+1.25), fth.wall, Enum.Material.Concrete, floorFolder, "BW_F"..floor)
        -- Left wall
        makeBox(Vector3.new(2.5,fh,BD), fl(-BW/2+1.25,baseY+fh/2,0), fth.wall, Enum.Material.Concrete, floorFolder, "LW_F"..floor)
        -- Right wall
        makeBox(Vector3.new(2.5,fh,BD), fl( BW/2-1.25,baseY+fh/2,0), fth.wall, Enum.Material.Concrete, floorFolder, "RW_F"..floor)
        -- Floor slab (f>1 only, f==1 uses pad)
        if floor > 1 then
            makeBox(Vector3.new(BW,2,BD), fl(0,baseY+1,0), Color3.fromRGB(35,35,42), Enum.Material.SmoothPlastic, floorFolder, "FLSlab_F"..floor)
        end
        -- Ceiling slab
        makeBox(Vector3.new(BW+3,2,BD+3), fl(0,baseY+fh+1,0), Color3.fromRGB(34,34,42), Enum.Material.SmoothPlastic, floorFolder, "Slab_F"..floor)

        -- Corner pilasters
        for _,cx in ipairs({-BW/2+1.5,BW/2-1.5}) do
            for _,cz in ipairs({-BD/2+1.5,BD/2-1.5}) do
                makeBox(Vector3.new(3,fh,3), fl(cx,baseY+fh/2,cz), Color3.fromRGB(28,28,35), Enum.Material.SmoothPlastic, floorFolder, "Pillar_F"..floor)
            end
        end

        -- Faction fascia strip on front (top of each floor)
        makeBox(Vector3.new(BW,3.5,2), fl(0,baseY+fh-1.75,BD/2-1), fac.primary, Enum.Material.SmoothPlastic, floorFolder, "Fascia_F"..floor)
        -- Neon accent below fascia (only F2+)
        if floor >= 2 or true then
            local neon = makeBox(Vector3.new(BW-8,0.45,1), fl(0,baseY+fh-4,BD/2), fac.accent, Enum.Material.Neon, floorFolder, "Neon_F"..floor)
            pulse(neon, fac.accent, Color3.fromRGB(255,255,255), 1.5)
        end
        -- Side window neons (F2+)
        if floor >= 2 then
            for _,wnh in ipairs({0.3,0.65}) do
                makeBox(Vector3.new(0.5,1.2,BD-10), fl(-BW/2+1,baseY+fh*wnh,0), fth.light, Enum.Material.Neon, floorFolder, "WinL_F"..floor)
                makeBox(Vector3.new(0.5,1.2,BD-10), fl( BW/2-1,baseY+fh*wnh,0), fth.light, Enum.Material.Neon, floorFolder, "WinR_F"..floor)
            end
        end
        -- F4 special: extra neon edges around building exterior
        if floor == 4 then
            local edgN = makeBox(Vector3.new(BW+3,0.5,1), fl(0,baseY+fh+2.1,BD/2+1.5), fac.accent, Enum.Material.Neon, floorFolder, "EdgeN_F4")
            pulse(edgN, fac.accent, Color3.fromRGB(255,255,255), 1.2)
            local edgS = makeBox(Vector3.new(BW+3,0.5,1), fl(0,baseY+fh+2.1,-BD/2-1.5), fac.accent, Enum.Material.Neon, floorFolder, "EdgeS_F4")
            pulse(edgS, fac.accent, Color3.fromRGB(255,255,255), 1.2)
        end

        -- Ceiling light
        local cL = makeBox(Vector3.new(5,0.45,5), fl(0,baseY+fh-0.5,0), fth.light, Enum.Material.Neon, floorFolder, "CLight_F"..floor)
        addLight(cL, "PointLight", fth.light, 28, 2.2)

        -- Floor label (on fascia, right corner)
        local flLabel = makeBox(Vector3.new(7,3.5,0.4), fl(BW/2-5.5,baseY+fh-6.5,BD/2+0.25), fac.primary, Enum.Material.SmoothPlastic, floorFolder, "FLabel_F"..floor)
        addBB(flLabel, "F"..floor.."  "..fth.name, 165, fac.accent, fac.primary, 32)

        -- ---- Dropper machines (back half, left-to-center, avoiding right side) ----
        local dlist  = GC_DROPPERS[floor]
        local dCount = #dlist
        -- X positions: spread across left+center portion (avoid right ~10 studs for elevator)
        local dXmax  = BW/2 - 13  -- avoid right side
        local dXmin  = -BW/2 + 8
        for di, dd in ipairs(dlist) do
            local dx = dXmin + (di-1)*(dXmax-dXmin)/(math.max(dCount-1,1))
            if dCount == 1 then dx = (dXmin+dXmax)/2 end
            local dz = -BD/2 + 11  -- in back area

            local mach = makeBox(Vector3.new(8,7,8), fl(dx,baseY+PAD_H/2+3.5,dz), fth.trim, Enum.Material.SmoothPlastic, floorFolder, "Dropper_F"..floor.."_"..di)
            mach:SetAttribute("TycoonId",slotId); mach:SetAttribute("FloorId",floor)
            mach:SetAttribute("DropperId",di); mach:SetAttribute("IsDropper",true)
            -- Glow top
            local gTop = makeBox(Vector3.new(7.5,0.45,7.5), fl(dx,baseY+PAD_H/2+7.3,dz), fth.light, Enum.Material.Neon, floorFolder, "DGlow_F"..floor.."_"..di)
            addLight(gTop,"PointLight",fth.light,10,1.5)
            -- Conveyor strip
            makeBox(Vector3.new(7,0.4,10), fl(dx,baseY+PAD_H/2+3,dz+8), Color3.fromRGB(48,48,58), Enum.Material.SmoothPlastic, floorFolder, "Conv_F"..floor.."_"..di)
            -- Upgrade button on top of machine
            local upBtn = makeBox(Vector3.new(8,0.55,6), fl(dx,baseY+PAD_H/2+7.5,dz), Color3.fromRGB(28,145,58), Enum.Material.SmoothPlastic, floorFolder, "UpBtn_F"..floor.."_"..di)
            upBtn:SetAttribute("TycoonId",slotId); upBtn:SetAttribute("FloorId",floor)
            upBtn:SetAttribute("DropperId",di); upBtn:SetAttribute("IsUpgradeBtn",true)
            addBB(upBtn, dd.name.."\nLv0  "..numFmt(dd.baseCost).." coins", 200, Color3.new(1,1,1), Color3.fromRGB(8,22,12), 18)
            local up_pp = Instance.new("ProximityPrompt")
            up_pp.ActionText="Upgrade"; up_pp.ObjectText=dd.name
            up_pp.MaxActivationDistance=7; up_pp.RequiresLineOfSight=false; up_pp.Parent=upBtn
        end

        -- ---- Weapon displays (LEFT wall, evenly spaced along depth) ----
        local wlist  = GC_WEAPONS[floor]
        local wZ     = {-BD/2+8, 0, BD/2-8}  -- 3 fixed z positions on left wall
        for wi, wd in ipairs(wlist) do
            local wz = wZ[wi] or 0
            -- Wall mount
            local wmount = makeBox(Vector3.new(2.5,5.5,7), fl(-BW/2+2.8,baseY+5,wz), fth.trim, Enum.Material.SmoothPlastic, floorFolder, "WMount_F"..floor.."_"..wi)
            wmount:SetAttribute("TycoonId",slotId); wmount:SetAttribute("FloorId",floor)
            wmount:SetAttribute("WeaponId",wi); wmount:SetAttribute("IsWeaponMount",true)
            -- Glow understrip
            local wglow = makeBox(Vector3.new(2,0.3,6), fl(-BW/2+2.8,baseY+2.5,wz), BULLET_COLORS[floor], Enum.Material.Neon, floorFolder, "WGlow_F"..floor.."_"..wi)
            addLight(wglow,"PointLight",BULLET_COLORS[floor],7,1.5)
            -- Buy button (on floor in front of mount)
            local wBtn = makeBox(Vector3.new(7,0.45,5), fl(-BW/2+9,baseY+PAD_H/2+0.23,wz), Color3.fromRGB(20,95,175), Enum.Material.SmoothPlastic, floorFolder, "WBtn_F"..floor.."_"..wi)
            wBtn:SetAttribute("TycoonId",slotId); wBtn:SetAttribute("FloorId",floor)
            wBtn:SetAttribute("WeaponId",wi); wBtn:SetAttribute("IsWeaponBtn",true)
            addBB(wBtn, wd.name.."\n"..numFmt(wd.cost).." coins", 185, Color3.new(1,1,1), Color3.fromRGB(6,14,26), 16)
            local w_pp = Instance.new("ProximityPrompt")
            w_pp.ActionText="Buy / Equip"; w_pp.ObjectText=wd.name
            w_pp.MaxActivationDistance=6; w_pp.RequiresLineOfSight=false; w_pp.Parent=wBtn
        end

        -- ---- Elevator pads (front-right area of each floor) ----
        if floor < 4 then
            local elevU = makeBox(Vector3.new(6,0.45,6), fl(BW/2-8,baseY+PAD_H/2+0.23,BD/2-8), Color3.fromRGB(255,200,30), Enum.Material.Neon, floorFolder, "ElevUp_F"..floor)
            elevU:SetAttribute("TycoonId",slotId); elevU:SetAttribute("FloorId",floor); elevU:SetAttribute("IsElevUp",true)
            pulse(elevU, Color3.fromRGB(255,200,30), Color3.fromRGB(255,255,120), 1.0)
            addLight(elevU,"PointLight",Color3.fromRGB(255,210,60),14,2)
            addBB(elevU, "GO UP  F"..(floor+1).." ("..numFmt(GC_FLOOR_COSTS[floor+1])..")", 200, Color3.fromRGB(30,20,0), Color3.fromRGB(255,200,30), 16)
            local eu_pp = Instance.new("ProximityPrompt")
            eu_pp.ActionText="Go Up"; eu_pp.ObjectText="Floor "..(floor+1)
            eu_pp.MaxActivationDistance=7; eu_pp.RequiresLineOfSight=false; eu_pp.Parent=elevU
        end
        if floor > 1 then
            local elevD = makeBox(Vector3.new(5,0.45,5), fl(BW/2-8,baseY+PAD_H/2+0.23,BD/2-15), Color3.fromRGB(80,150,255), Enum.Material.Neon, floorFolder, "ElevDn_F"..floor)
            elevD:SetAttribute("TycoonId",slotId); elevD:SetAttribute("FloorId",floor); elevD:SetAttribute("IsElevDn",true)
            pulse(elevD, Color3.fromRGB(80,150,255), Color3.fromRGB(160,210,255), 1.2)
            addBB(elevD, "GO DOWN  F"..(floor-1), 175, Color3.new(1,1,1), Color3.fromRGB(8,14,28), 14)
            local ed_pp = Instance.new("ProximityPrompt")
            ed_pp.ActionText="Go Down"; ed_pp.ObjectText="Floor "..(floor-1)
            ed_pp.MaxActivationDistance=7; ed_pp.RequiresLineOfSight=false; ed_pp.Parent=elevD
        end

        -- F4 rooftop tower + faction sign (impressive cap for full build)
        if floor == 4 then
            local towerH = 22
            local twrBase = makeBox(Vector3.new(10,towerH,10), fl(0,baseY+fh+towerH/2,0), fac.primary, Enum.Material.SmoothPlastic, floorFolder, "Tower_F4")
            local twrCap = makeBox(Vector3.new(12,2,12), fl(0,baseY+fh+towerH+1,0), fac.accent, Enum.Material.Neon, floorFolder, "TowerCap_F4")
            pulse(twrCap, fac.accent, Color3.fromRGB(255,255,255), 1.1)
            addLight(twrCap,"SpotLight",fac.accent,80,5)

            -- Rooftop faction sign (MaxDistance 90 so visible from far)
            local roofSign = makeBox(Vector3.new(BW,5,2), fl(0,baseY+fh+4,BD/2+2), fac.primary, Enum.Material.SmoothPlastic, floorFolder, "RoofSign")
            addBB(roofSign, faction.name:upper(), 300, fac.accent, fac.primary, 90)
            local rn = makeBox(Vector3.new(BW-6,0.45,1.2), fl(0,baseY+fh+4,BD/2+3.5), fac.accent, Enum.Material.Neon, floorFolder, "RoofNeon")
            pulse(rn, fac.accent, Color3.fromRGB(255,255,255), 1.8)
            addLight(rn,"SpotLight",fac.accent,65,4)
        end

        -- Hide entire floor folder until revealed by server
        hideFolder(floorFolder)
    end
end

for i, slot in ipairs(SLOTS) do
    buildTycoon(i, slot, FACTIONS[i])
end

-- ============================================================
-- PvP Cover (tactical)
-- ============================================================

math.randomseed(42)
local coverLayout = {
    {Vector3.new(-52,0, 0),  Vector3.new(14,4.5,3),  Color3.fromRGB(65,60,50),  "Barricade"},
    {Vector3.new( 52,0, 0),  Vector3.new(14,4.5,3),  Color3.fromRGB(65,60,50),  "Barricade"},
    {Vector3.new(0,0,-52),   Vector3.new(3,4.5,14),  Color3.fromRGB(65,60,50),  "Barricade"},
    {Vector3.new(0,0, 52),   Vector3.new(3,4.5,14),  Color3.fromRGB(65,60,50),  "Barricade"},
    {Vector3.new(-82,0,-82), Vector3.new(14,5.5,14), Color3.fromRGB(58,55,45),  "Bunker"},
    {Vector3.new( 82,0,-82), Vector3.new(14,5.5,14), Color3.fromRGB(58,55,45),  "Bunker"},
    {Vector3.new(-82,0, 82), Vector3.new(14,5.5,14), Color3.fromRGB(58,55,45),  "Bunker"},
    {Vector3.new( 82,0, 82), Vector3.new(14,5.5,14), Color3.fromRGB(58,55,45),  "Bunker"},
    {Vector3.new(-98,0, 0),  Vector3.new(3.5,4,16),  Color3.fromRGB(135,120,85),"Sandbag"},
    {Vector3.new( 98,0, 0),  Vector3.new(3.5,4,16),  Color3.fromRGB(135,120,85),"Sandbag"},
    {Vector3.new(0,0,-98),   Vector3.new(16,4,3.5),  Color3.fromRGB(135,120,85),"Sandbag"},
    {Vector3.new(0,0, 98),   Vector3.new(16,4,3.5),  Color3.fromRGB(135,120,85),"Sandbag"},
    {Vector3.new(-52,0, 32), Vector3.new(5,7,5),     Color3.fromRGB(48,56,62),  "Crate"},
    {Vector3.new( 52,0,-32), Vector3.new(5,7,5),     Color3.fromRGB(48,56,62),  "Crate"},
    {Vector3.new(-32,0,-68), Vector3.new(5,7,5),     Color3.fromRGB(48,56,62),  "Crate"},
    {Vector3.new( 32,0, 68), Vector3.new(5,7,5),     Color3.fromRGB(48,56,62),  "Crate"},
    {Vector3.new(-112,0,42), Vector3.new(12,4,3),    Color3.fromRGB(65,60,50),  "Wall"},
    {Vector3.new( 112,0,-42),Vector3.new(12,4,3),    Color3.fromRGB(65,60,50),  "Wall"},
}
for _,cl in ipairs(coverLayout) do
    local pos=cl[1]; local sz=cl[2]; local col=cl[3]; local nm=cl[4]
    local yaw = math.random()*0.4-0.2
    makeBox(sz, CFrame.new(pos)*CFrame.Angles(0,yaw,0)*CFrame.new(0,sz.Y/2,0), col, Enum.Material.SmoothPlastic, covF, nm)
    -- Amber hazard stripe on tall cover
    if sz.Y >= 4.5 then
        makeBox(Vector3.new(sz.X,0.3,0.35), CFrame.new(pos)*CFrame.Angles(0,yaw,0)*CFrame.new(0,sz.Y*0.62,sz.Z/2), AMBER, Enum.Material.SmoothPlastic, covF, "Stripe")
    end
end

-- ============================================================
-- VIP Zone: Center elevated platform
-- ============================================================

local VT_COL = Color3.fromRGB(180,148,15)
local VT_TRIM = Color3.fromRGB(255,210,0)
local VT_PLT  = Color3.fromRGB(38,32,8)
local VIP_Y = 16  -- height of VIP platform surface

-- Platform
local vipPlat = makeBox(Vector3.new(52,VIP_Y,52), CFrame.new(0,VIP_Y/2,0), VT_PLT, Enum.Material.SmoothPlastic, vipF, "VIPPlatform")
addLight(vipPlat,"SpotLight",Color3.fromRGB(255,238,100),100,4)
-- Polished top
makeBox(Vector3.new(52,0.5,52), CFrame.new(0,VIP_Y+0.25,0), Color3.fromRGB(28,23,5), Enum.Material.SmoothPlastic, vipF, "VIPFloor")

-- Gold trim neons on all 4 edges
for _,ed in ipairs({
    {Vector3.new(52,1,1.4), CFrame.new(0,VIP_Y+0.7,-26.7)},
    {Vector3.new(52,1,1.4), CFrame.new(0,VIP_Y+0.7, 26.7)},
    {Vector3.new(1.4,1,52), CFrame.new(-26.7,VIP_Y+0.7,0)},
    {Vector3.new(1.4,1,52), CFrame.new( 26.7,VIP_Y+0.7,0)},
}) do
    local tr = makeBox(ed[1],ed[2],VT_TRIM,Enum.Material.Neon,vipF,"VIPTrim")
    pulse(tr,VT_TRIM,Color3.fromRGB(255,255,140),1.7)
end

-- 4 access staircases (N/S/E/W) - each is a wedge ramp
for _,sd in ipairs({
    {axis="Z", dir= 1, pos=Vector3.new(0,0, 26)},   -- South
    {axis="Z", dir=-1, pos=Vector3.new(0,0,-26)},   -- North
    {axis="X", dir= 1, pos=Vector3.new( 26,0,0)},   -- East
    {axis="X", dir=-1, pos=Vector3.new(-26,0,0)},   -- West
}) do
    -- Ramp: rises VIP_Y over 24 studs depth
    local rampRise = VIP_Y; local rampRun = 24
    local rampSz = sd.axis=="Z" and Vector3.new(10, rampRise, rampRun) or Vector3.new(rampRun, rampRise, 10)
    local rampPos = sd.axis=="Z" and Vector3.new(0,rampRise/2,sd.pos.Z+sd.dir*rampRun/2) or Vector3.new(sd.pos.X+sd.dir*rampRun/2,rampRise/2,0)
    local angleY  = sd.axis=="Z" and 0 or math.pi/2
    local angleX  = math.atan2(rampRise, rampRun) * sd.dir * (sd.axis=="Z" and -1 or 1)
    local wedge = makeWedge(rampSz, CFrame.new(rampPos)*CFrame.Angles(angleX*(sd.axis=="Z" and 1 or 0),angleY,angleX*(sd.axis=="X" and 1 or 0)), VT_COL, Enum.Material.SmoothPlastic, vipF, "VIPRamp")
end

-- VIP gate: blocks non-VIPs at top of south ramp
local gate = makeBox(Vector3.new(10,10,1), CFrame.new(0,VIP_Y+5,27), VT_TRIM, Enum.Material.Neon, vipF, "VIPGate")
gate.Transparency = 0.42; gate:SetAttribute("IsVIPGate",true)
addBB(gate, "VIP ONLY - Step up to buy", 220, Color3.fromRGB(255,215,0), Color3.fromRGB(18,14,0), 30)

-- Crown pedestal (center of platform)
local crownPed = makeBox(Vector3.new(7,2,7), CFrame.new(0,VIP_Y+1,0), VT_TRIM, Enum.Material.Neon, vipF, "CrownPedestal")
crownPed:SetAttribute("IsCrownPed",true)
addBB(crownPed,"CLAIM CROWN (VIP Only)",200,Color3.fromRGB(255,215,0),Color3.fromRGB(18,14,0),22)
addLight(crownPed,"PointLight",Color3.fromRGB(255,235,100),20,3)
local cp2=Instance.new("ProximityPrompt"); cp2.ActionText="Claim Crown"; cp2.ObjectText="VIP"; cp2.MaxActivationDistance=7; cp2.RequiresLineOfSight=false; cp2.Parent=crownPed

-- VIP purchase pad (at base of south ramp, on ground)
local vPad = makeBox(Vector3.new(16,1,16), CFrame.new(0,0.5,56), VT_TRIM, Enum.Material.Neon, vipF, "VIPPurchasePad")
vPad:SetAttribute("IsVIPPad",true)
addBB(vPad,"STEP HERE: BUY VIP\n499 Robux",250,Color3.fromRGB(255,215,0),Color3.fromRGB(20,16,0),28)
pulse(vPad, VT_TRIM, Color3.fromRGB(255,255,100),1.1)
addLight(vPad,"PointLight",Color3.fromRGB(255,225,80),20,2.5)
local pp_vip=Instance.new("ProximityPrompt"); pp_vip.ActionText="Buy VIP (499 R$)"; pp_vip.ObjectText="VIP Gamepass"; pp_vip.MaxActivationDistance=10; pp_vip.RequiresLineOfSight=false; pp_vip.Parent=vPad

-- VIP display stands (on platform)
for wi=-1,1 do
    local stand=makeBox(Vector3.new(4,11,2),CFrame.new(wi*16,VIP_Y+5.5,-18),VT_COL,Enum.Material.SmoothPlastic,vipF,"VIPDisplay")
    local dg=makeBox(Vector3.new(3.5,0.4,1.8),CFrame.new(wi*16,VIP_Y+11.2,-18),VT_TRIM,Enum.Material.Neon,vipF,"VIPDisplayGlow")
    addLight(dg,"PointLight",Color3.fromRGB(255,235,100),12,2)
end

-- ============================================================
-- Owner door (south wall area)
-- ============================================================

local ownerDoor = makeBox(Vector3.new(DOOR_W-2,18,2), CFrame.new(0,9,hz+wT/2), Color3.fromRGB(28,195,78), Enum.Material.Neon, ownF, "OwnerDoor")
ownerDoor.Transparency=0.35; ownerDoor:SetAttribute("IsOwnerDoor",true)
addLight(ownerDoor,"PointLight",Color3.fromRGB(60,255,110),18,2.5)
for _,fr in ipairs({
    {Vector3.new(2,22,wT+2), CFrame.new(-DOOR_W/2,11,hz+wT/2)},
    {Vector3.new(2,22,wT+2), CFrame.new( DOOR_W/2,11,hz+wT/2)},
    {Vector3.new(DOOR_W+4,3,wT+2), CFrame.new(0,21.5,hz+wT/2)},
}) do makeBox(fr[1],fr[2],Color3.fromRGB(20,20,26),Enum.Material.SmoothPlastic,ownF,"DFrame") end

local keypad=makeBox(Vector3.new(4,6,2.5),CFrame.new(-8,7,hz+wT/2-wT/2-1.5),Color3.fromRGB(18,18,26),Enum.Material.SmoothPlastic,ownF,"OwnerKeypad")
keypad:SetAttribute("IsOwnerKeypad",true)
addBB(keypad,"OWNER ACCESS",155,Color3.fromRGB(80,255,120),Color3.fromRGB(5,12,6),12)
addLight(keypad,"PointLight",Color3.fromRGB(55,255,100),7,1.8)
local kpp=Instance.new("ProximityPrompt"); kpp.ActionText="Access"; kpp.ObjectText="Staff Only"; kpp.MaxActivationDistance=8; kpp.RequiresLineOfSight=false; kpp.Parent=keypad

local rmPos=Vector3.new(0,10,hz+wT+20)
makeBox(Vector3.new(40,20,34),CFrame.new(rmPos.X,rmPos.Y,rmPos.Z),Color3.fromRGB(16,16,22),Enum.Material.SmoothPlastic,ownF,"OwnerRoomHull")
local rmL=makeBox(Vector3.new(7,0.4,7),CFrame.new(rmPos.X,rmPos.Y+9.8,rmPos.Z),Color3.fromRGB(120,255,160),Enum.Material.Neon,ownF,"RmLight")
addLight(rmL,"PointLight",Color3.fromRGB(100,255,140),28,2.5)
local exitPad=makeBox(Vector3.new(4,6,2.5),CFrame.new(rmPos.X+8,rmPos.Y-4,rmPos.Z-15.5),Color3.fromRGB(18,18,26),Enum.Material.SmoothPlastic,ownF,"OwnerExitPad")
exitPad:SetAttribute("IsOwnerExit",true)
addBB(exitPad,"EXIT",95,Color3.fromRGB(255,100,80),Color3.fromRGB(14,5,5),12)
local epp=Instance.new("ProximityPrompt"); epp.ActionText="Exit"; epp.ObjectText=""; epp.MaxActivationDistance=7; epp.RequiresLineOfSight=false; epp.Parent=exitPad

-- ============================================================
-- Leaderboard (south wall interior face)
-- ============================================================

local lbPart=makeBox(Vector3.new(68,52,3),CFrame.new(0,28,-(hz-8)),Color3.fromRGB(10,10,16),Enum.Material.SmoothPlastic,mapF,"LeaderboardBoard")
lbPart:SetAttribute("IsLeaderboard",true)
makeBox(Vector3.new(72,56,1),CFrame.new(0,28,-(hz-7.5)),AMBER,Enum.Material.Neon,mapF,"LBFrame").Transparency=0.52
addLight(lbPart,"SpotLight",Color3.fromRGB(255,200,45),38,2.5)
local sg=Instance.new("SurfaceGui"); sg.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize; sg.CanvasSize=Vector2.new(680,520); sg.Face=Enum.NormalId.Front; sg.Name="LBSurface"; sg.Parent=lbPart
local lbT=Instance.new("TextLabel",sg); lbT.Name="Title"; lbT.Size=UDim2.new(1,0,0.12,0); lbT.BackgroundTransparency=1; lbT.TextColor3=Color3.fromRGB(255,200,40); lbT.Font=Enum.Font.GothamBold; lbT.Text="TOP EARNERS"; lbT.TextScaled=true
local lbEnt=Instance.new("Frame",sg); lbEnt.Name="Entries"; lbEnt.Size=UDim2.new(1,-14,0.88,0); lbEnt.Position=UDim2.new(0,7,0.12,0); lbEnt.BackgroundTransparency=1
for r=1,10 do
    local e=Instance.new("TextLabel",lbEnt); e.Name="R"..r
    e.Size=UDim2.new(1,0,0.1,-3); e.Position=UDim2.new(0,0,(r-1)*0.1,0)
    e.BackgroundColor3=r<=3 and Color3.fromRGB(36,32,5) or Color3.fromRGB(14,14,20); e.BackgroundTransparency=0.2
    e.TextColor3=r==1 and Color3.fromRGB(255,215,0) or r==2 and Color3.fromRGB(198,198,198) or r==3 and Color3.fromRGB(172,100,38) or Color3.fromRGB(188,188,192)
    e.Font=Enum.Font.GothamBold; e.Text="#"..r.."  --"; e.TextScaled=true
    Instance.new("UICorner",e).CornerRadius=UDim.new(0.18,0)
end

-- ============================================================
-- Spawn (center ground, under VIP platform)
-- ============================================================

local spPlat=makeBox(Vector3.new(32,3,32),CFrame.new(0,1.5,0),Color3.fromRGB(40,40,48),Enum.Material.Concrete,mapF,"SpawnPad")
for _,sd in ipairs({ {Vector3.new(32,0.4,1),CFrame.new(0,3.2,-15.5)},{Vector3.new(32,0.4,1),CFrame.new(0,3.2,15.5)},{Vector3.new(1,0.4,32),CFrame.new(-15.5,3.2,0)},{Vector3.new(1,0.4,32),CFrame.new(15.5,3.2,0)} }) do
    local s=makeBox(sd[1],sd[2],AMBER,Enum.Material.Neon,mapF,"SpawnBorder"); pulse(s,AMBER,Color3.fromRGB(255,200,80),2.4)
end
local spg=makeBox(Vector3.new(3,0.4,3),CFrame.new(0,3.2,0),Color3.fromRGB(90,255,130),Enum.Material.Neon,mapF,"SpawnGlow")
addLight(spg,"PointLight",Color3.fromRGB(90,255,130),22,2.2)
addBB(spPlat,"SPAWN",150,Color3.fromRGB(180,255,190),Color3.fromRGB(12,16,14),28)

-- ============================================================
-- Atmosphere
-- ============================================================

local lighting=game:GetService("Lighting")
lighting.Brightness=1.55; lighting.ClockTime=15; lighting.FogEnd=850
lighting.FogColor=Color3.fromRGB(24,24,32); lighting.Ambient=Color3.fromRGB(82,82,98); lighting.OutdoorAmbient=Color3.fromRGB(102,100,115); lighting.ShadowSoftness=0.22

local atmo=Instance.new("Atmosphere",lighting); atmo.Density=0.2; atmo.Offset=0.12; atmo.Haze=0.32; atmo.Color=Color3.fromRGB(105,115,152); atmo.Glare=0.15; atmo.Decay=Color3.fromRGB(75,75,102)
local bloom=Instance.new("BloomEffect",lighting); bloom.Intensity=0.42; bloom.Size=22; bloom.Threshold=0.94

print("[MapBuilder] Iron Arsenal v3 ready - "..#tycF:GetChildren().." tycoon slots")

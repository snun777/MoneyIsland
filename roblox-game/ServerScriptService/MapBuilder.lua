-- ============================================================
-- MONEY ISLAND TYCOON — MapBuilder.lua (v7 - CONNECTED LAYOUT)
-- Place in: ServerScriptService
-- ============================================================

local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local coinBE = ReplicatedStorage:WaitForChild("CoinCollected_BE", 15)

-- ============================================================
-- REMOVE DEFAULT BASEPLATE & SPAWN (prevents underground respawn)
-- ============================================================
for _, obj in ipairs(Workspace:GetChildren()) do
    if obj.Name == "Baseplate" or obj.Name == "SpawnLocation" then
        obj:Destroy()
    end
end

-- ============================================================
-- TERRAIN
-- Keep it simple: flat island at Y=0, ocean below Y=-6
-- FillBlock for the main landmass so top is EXACTLY Y=0
-- ============================================================
local terrain = Workspace.Terrain
terrain:Clear()

local G = 0  -- ground surface Y. Everything built relative to this.

-- Ocean
terrain:FillBlock(CFrame.new(0,-16,0), Vector3.new(900,20,900), Enum.Material.Water)

-- Main island: flat slab, top face at Y=0
terrain:FillBlock(CFrame.new(0,-8,0), Vector3.new(220,16,220), Enum.Material.Grass)

-- Dirt underneath
terrain:FillBlock(CFrame.new(0,-18,0), Vector3.new(218,14,218), Enum.Material.Ground)

-- Carve ocean around island edges so it looks like an island, not a square
for i=0,15 do
    local a = math.rad(i*24)
    local r = 95 + math.sin(i*1.3)*12  -- irregular coastline
    terrain:FillBall(Vector3.new(math.cos(a)*r, -6, math.sin(a)*r), 22, Enum.Material.Water)
end

-- Sand beaches where ocean meets land
for i=0,23 do
    local a = math.rad(i*15)
    local r = 78 + math.sin(i*0.9)*8
    terrain:FillBall(Vector3.new(math.cos(a)*r, -1, math.sin(a)*r), 12, Enum.Material.Sand)
end

-- Some gentle hills for visual interest (don't block paths)
terrain:FillBall(Vector3.new(60,  4, 55),  16, Enum.Material.Grass)
terrain:FillBall(Vector3.new(-60, 4, 50),  14, Enum.Material.Grass)
terrain:FillBall(Vector3.new(55, 4, -60),  12, Enum.Material.Grass)

-- Volcano (west) — builds up FROM ground
terrain:FillBall(Vector3.new(-72, 0,  0), 22, Enum.Material.Basalt)
terrain:FillBall(Vector3.new(-72, 14, 0), 16, Enum.Material.Basalt)
terrain:FillBall(Vector3.new(-72, 24, 0), 11, Enum.Material.Basalt)
terrain:FillBall(Vector3.new(-72, 32, 0),  7, Enum.Material.CrackedLava)

-- Secret cave (south underground)
terrain:FillBall(Vector3.new(0, -10, 75), 15, Enum.Material.Air)
terrain:FillBall(Vector3.new(0,  -5, 66),  5, Enum.Material.Air)  -- entrance shaft

-- Wide cobblestone paths connecting all zones
-- Center to Farm (east)
terrain:FillBlock(CFrame.new(36, 0, 0),  Vector3.new(50,1,12), Enum.Material.Cobblestone)
-- Center to Shop (north)
terrain:FillBlock(CFrame.new(0, 0, -38), Vector3.new(12,1,50), Enum.Material.Cobblestone)
-- Center to Boss (west)
terrain:FillBlock(CFrame.new(-36,0, 0),  Vector3.new(50,1,12), Enum.Material.Cobblestone)
-- Center to Secret (south)
terrain:FillBlock(CFrame.new(0, 0, 38),  Vector3.new(12,1,50), Enum.Material.Cobblestone)

-- ============================================================
-- HELPERS
-- ============================================================
local MAP = Instance.new("Folder", Workspace); MAP.Name = "MoneyIslandMap"

local function P(props)
    local p = Instance.new("Part")
    p.Anchored      = true
    p.CanCollide    = props.cc ~= false
    p.Size          = props.sz or Vector3.new(4,1,4)
    p.CFrame        = props.cf or CFrame.new(props.pos or Vector3.new())
    p.Color         = props.col or Color3.fromRGB(163,162,165)
    p.Material      = props.mat or Enum.Material.SmoothPlastic
    p.Name          = props.name or "Part"
    p.Transparency  = props.tr or 0
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = props.par or MAP
    return p
end

local function CYL(props)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Cylinder
    p.Anchored = true; p.CanCollide = props.cc ~= false
    p.Size = props.sz or Vector3.new(1,4,4)
    p.CFrame = props.cf or CFrame.new(props.pos or Vector3.new())
    p.Color = props.col or Color3.fromRGB(200,200,200)
    p.Material = props.mat or Enum.Material.SmoothPlastic
    p.Name = props.name or "Cyl"
    p.Transparency = props.tr or 0
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = props.par or MAP
    return p
end

local function light(parent, b, r, col)
    local l = Instance.new("PointLight", parent)
    l.Brightness = b; l.Range = r; l.Color = col
end

local function sign(parent, text, col, dy)
    local bb = Instance.new("BillboardGui", parent)
    bb.Size = UDim2.new(0,220,0,54)
    bb.StudsOffset = Vector3.new(0, dy or 3, 0)
    bb.MaxDistance = 70
    local tl = Instance.new("TextLabel", bb)
    tl.Size = UDim2.new(1,0,1,0)
    tl.BackgroundTransparency = 1
    tl.Text = text
    tl.TextColor3 = col or Color3.new(1,1,1)
    tl.Font = Enum.Font.GothamBold
    tl.TextScaled = true
    tl.TextStrokeTransparency = 0.3
    tl.TextStrokeColor3 = Color3.new(0,0,0)
end

-- shorthand: Y for a part of height h sitting on ground G
local function onG(h) return G + h/2 end

-- ============================================================
-- SPAWN ZONE — center of island
-- ============================================================
local spawnF = Instance.new("Folder",MAP); spawnF.Name="SpawnZone"

-- Single SpawnLocation flush with ground — this is the ONLY one
local sp = Instance.new("SpawnLocation")
sp.Size     = Vector3.new(14, 1, 14)
sp.CFrame   = CFrame.new(0, G + 0.5, 0)
sp.Neutral  = true
sp.Duration = 0
sp.Anchored = true
sp.BrickColor = BrickColor.new("Cyan")
sp.Material = Enum.Material.Neon
sp.TopSurface = Enum.SurfaceType.Smooth
sp.Parent = spawnF

-- Arch (north side, facing shop)
for _,x in ipairs({-10,10}) do
    P({name="ArchPillar",par=spawnF,sz=Vector3.new(2,14,2),
        pos=Vector3.new(x, G+7, -14),
        col=Color3.fromRGB(200,160,0),mat=Enum.Material.SmoothPlastic})
end
local archBar = P({name="ArchBar",par=spawnF,sz=Vector3.new(22,2,2),
    pos=Vector3.new(0, G+15, -14),
    col=Color3.fromRGB(255,200,0),mat=Enum.Material.Neon})
light(archBar, 2, 14, Color3.fromRGB(255,200,0))
sign(archBar, "💰 MONEY ISLAND", Color3.fromRGB(255,215,0), 3)

-- Direction signs at spawn (tells players where to go)
local dirSigns = {
    {pos=Vector3.new(0, G+4, -13),  text="🛒 SHOP →", col=Color3.fromRGB(255,200,0)},
    {pos=Vector3.new(13, G+4, 0),   text="⚡ FARM →", col=Color3.fromRGB(0,255,80)},
    {pos=Vector3.new(-13, G+4, 0),  text="← 👹 BOSS", col=Color3.fromRGB(255,60,60)},
    {pos=Vector3.new(0, G+4, 13),   text="🕳️ SECRET ↓", col=Color3.fromRGB(180,100,255)},
}
for _, d in ipairs(dirSigns) do
    local post = P({name="DirPost",par=spawnF,sz=Vector3.new(0.8,5,0.8),
        pos=d.pos, col=Color3.fromRGB(80,60,30),mat=Enum.Material.Wood})
    sign(post, d.text, d.col, 4)
end

-- 4 palm trees around spawn
local function palm(f,x,z)
    for i=0,3 do
        CYL({par=f,name="Trunk",sz=Vector3.new(1.1,4,1.1),
            cf=CFrame.new(x,G+2+i*3.5,z)*CFrame.Angles(0,0,math.rad(math.random(-5,5))),
            col=Color3.fromRGB(110,72,22),mat=Enum.Material.Wood})
    end
    for i=0,4 do
        local a=math.rad(i*72)
        local lp=P({par=f,name="Leaf",sz=Vector3.new(6,0.4,1.6),
            col=Color3.fromRGB(35,135,35),mat=Enum.Material.Grass})
        lp.CFrame=CFrame.new(x+math.cos(a)*3,G+14,z+math.sin(a)*3)*CFrame.Angles(math.rad(-22),a,0)
    end
end
palm(spawnF,-18,-18); palm(spawnF,18,-18)
palm(spawnF,-18, 18); palm(spawnF,18, 18)

-- ============================================================
-- FARM ZONE — east, flat on ground, accessible from cobble path
-- ============================================================
local farmF = Instance.new("Folder",MAP); farmF.Name="FarmZone"

-- Farm sits ON the ground, raised by just 1 stud so it's clearly defined
local farmX = 68
local FARM_H = 1  -- just 1 stud tall so it's basically flush
local FARM_TOP = G + FARM_H

P({name="FarmDeck",par=farmF,sz=Vector3.new(50,FARM_H,50),
    pos=Vector3.new(farmX, G+FARM_H/2, 0),
    col=Color3.fromRGB(105,72,38),mat=Enum.Material.Wood})

-- Ramp from cobble path onto farm deck (west side of farm)
P({name="FarmRamp",par=farmF,sz=Vector3.new(8, FARM_H, 4),
    cf=CFrame.new(farmX-26, G+FARM_H/2, 0)*CFrame.Angles(math.rad(-8),0,0),
    col=Color3.fromRGB(90,65,30),mat=Enum.Material.Wood})

-- Low fence around edge
for i=0,4 do
    local o = i*10-20
    for _,side in ipairs({{-25,o},{25,o},{o,-25},{o,25}}) do
        P({name="Fence",par=farmF,sz=Vector3.new(1,3,1),
            pos=Vector3.new(farmX+side[1], FARM_TOP+1.5, side[2]),
            col=Color3.fromRGB(80,55,22),mat=Enum.Material.Wood})
    end
end
-- Fence rails
for _,side in ipairs({-25,25}) do
    P({name="FenceRail",par=farmF,sz=Vector3.new(1,0.5,50),
        pos=Vector3.new(farmX+side, FARM_TOP+2.5, 0),
        col=Color3.fromRGB(80,55,22),mat=Enum.Material.Wood})
    P({name="FenceRail",par=farmF,sz=Vector3.new(50,0.5,1),
        pos=Vector3.new(farmX, FARM_TOP+2.5, side),
        col=Color3.fromRGB(80,55,22),mat=Enum.Material.Wood})
end

-- Sign post at entrance
P({name="FarmSignPost",par=farmF,sz=Vector3.new(1,6,1),
    pos=Vector3.new(farmX-22,G+3,-22),col=Color3.fromRGB(80,55,22),mat=Enum.Material.Wood})
local fsign=P({name="FarmSign",par=farmF,sz=Vector3.new(12,4,1),
    pos=Vector3.new(farmX-22,G+8,-22),
    col=Color3.fromRGB(35,90,25),mat=Enum.Material.SmoothPlastic})
sign(fsign,"⚡ FARM ZONE\nClick the coins!",Color3.fromRGB(60,255,80),2)

-- COINS: 5x5 grid ON the farm deck, sitting just above it
local coinsF = Instance.new("Folder",farmF); coinsF.Name="CoinModels"
local coinY = FARM_TOP + 3  -- coins float 3 studs above deck

for row=0,4 do
    for col=0,4 do
        local cx = farmX-18 + col*9
        local cz = -18 + row*9

        -- dirt plot
        P({name="Plot",par=farmF,sz=Vector3.new(7,0.4,7),
            pos=Vector3.new(cx, FARM_TOP+0.25, cz),
            col=Color3.fromRGB(65,44,18),mat=Enum.Material.Ground})

        -- coin — solid, clickable
        local coin=CYL({par=coinsF,name="Coin",
            sz=Vector3.new(0.5,3,3),
            cf=CFrame.new(cx,coinY,cz)*CFrame.Angles(0,0,math.rad(90)),
            col=Color3.fromRGB(255,205,0),mat=Enum.Material.Neon,cc=false})
        coin:SetAttribute("IsCoin",true)
        light(coin, 1, 8, Color3.fromRGB(255,210,0))

        local cd=Instance.new("ClickDetector",coin)
        cd.MaxActivationDistance=20
        cd.MouseClick:Connect(function(player)
            print("[MoneyIsland] ClickDetector fired for", player.Name, "coinBE=", coinBE ~= nil)
            if coinBE then
                coinBE:Fire(player)
            else
                warn("[MoneyIsland] coinBE is nil! MainGameServer may not have run yet.")
            end
        end)
    end
end

-- ============================================================
-- SHOP ZONE — north, built on ground
-- ============================================================
local shopF=Instance.new("Folder",MAP); shopF.Name="ShopZone"
local shopZ = -75

-- Stone foundation flush with ground
P({name="Foundation",par=shopF,sz=Vector3.new(46,2,38),
    pos=Vector3.new(0,G+1,shopZ),
    col=Color3.fromRGB(115,100,80),mat=Enum.Material.Cobblestone})

local wY = G+2  -- wall base Y
local wc = Color3.fromRGB(200,185,150)
for _,w in ipairs({
    {Vector3.new(46,16,1.5), Vector3.new(0,wY+8,shopZ-18)},
    {Vector3.new(46,16,1.5), Vector3.new(0,wY+8,shopZ+18)},
    {Vector3.new(1.5,16,38), Vector3.new(-23,wY+8,shopZ)},
    {Vector3.new(1.5,16,38), Vector3.new(23, wY+8,shopZ)},
}) do
    P({name="Wall",par=shopF,sz=w[1],pos=w[2],col=wc,mat=Enum.Material.SmoothPlastic})
end

P({name="Roof",par=shopF,sz=Vector3.new(50,2,42),
    pos=Vector3.new(0,wY+17,shopZ),col=Color3.fromRGB(145,38,28),mat=Enum.Material.SmoothPlastic})

-- Door opening (south wall gap)
P({name="Door",par=shopF,sz=Vector3.new(8,11,0.5),
    pos=Vector3.new(0,wY+6.5,shopZ+17.6),col=Color3.fromRGB(70,42,16),mat=Enum.Material.Wood})

-- Shop sign
local shopSign=P({name="ShopSign",par=shopF,sz=Vector3.new(18,4,1),
    pos=Vector3.new(0,wY+18,shopZ+18),col=Color3.fromRGB(255,195,0),mat=Enum.Material.Neon})
sign(shopSign,"🛒 UPGRADE SHOP",Color3.fromRGB(10,10,10),2)
light(shopSign,2,16,Color3.fromRGB(255,195,0))

-- Counter + shopkeeper NPC
P({name="Counter",par=shopF,sz=Vector3.new(28,4,4),
    pos=Vector3.new(0,wY+4,shopZ-8),col=Color3.fromRGB(88,58,24),mat=Enum.Material.Wood})

local npc=P({name="NPC",par=shopF,sz=Vector3.new(2.5,5,1.5),
    pos=Vector3.new(0,wY+9,shopZ-6),col=Color3.fromRGB(240,170,55),mat=Enum.Material.SmoothPlastic})
P({name="NPCHead",par=shopF,sz=Vector3.new(2.5,2.5,2.5),
    pos=Vector3.new(0,wY+13,shopZ-6),col=Color3.fromRGB(255,205,95),mat=Enum.Material.SmoothPlastic})
sign(npc,"🛒 CLICK TO SHOP!",Color3.fromRGB(255,215,0),7)

local shopCD=Instance.new("ClickDetector",npc); shopCD.MaxActivationDistance=18
shopCD.MouseClick:Connect(function(player)
    local s=ReplicatedStorage:FindFirstChild("ShowShop")
    if s then s:FireClient(player) end
end)

-- Torches
for _,x in ipairs({-18,18}) do
    P({name="TorchPost",par=shopF,sz=Vector3.new(1,7,1),
        pos=Vector3.new(x,G+3.5,shopZ+18),col=Color3.fromRGB(70,42,16),mat=Enum.Material.Wood})
    local fl=P({name="Flame",par=shopF,sz=Vector3.new(1.5,1.5,1.5),
        pos=Vector3.new(x,G+8.5,shopZ+18),col=Color3.fromRGB(255,80,0),
        mat=Enum.Material.Neon,cc=false})
    light(fl,3,12,Color3.fromRGB(255,110,0))
end

-- ============================================================
-- BOSS ZONE — volcano west, arena on top with spiral steps
-- ============================================================
local bossF=Instance.new("Folder",MAP); bossF.Name="BossZone"
local VOL_TOP = G + 38  -- top of volcano terrain

-- Arena platform on volcano peak
P({name="Arena",par=bossF,sz=Vector3.new(28,2,28),
    pos=Vector3.new(-72,VOL_TOP,0),col=Color3.fromRGB(30,4,4),mat=Enum.Material.Basalt})

-- Lava puddles on arena
for i=0,5 do
    local a=math.rad(i*60)
    P({name="Lava",par=bossF,sz=Vector3.new(4,0.5,4),
        pos=Vector3.new(-72+math.cos(a)*11,VOL_TOP+1.3,math.sin(a)*11),
        col=Color3.fromRGB(255,50,0),mat=Enum.Material.Neon,cc=false})
end
light(P({name="ArenaGlow",par=bossF,sz=Vector3.new(1,1,1),
    pos=Vector3.new(-72,VOL_TOP+2,0),tr=1,cc=false}),5,24,Color3.fromRGB(255,30,0))

-- Boss body on arena
local bt=VOL_TOP+2
P({name="BossLegs",par=bossF,sz=Vector3.new(5,6,3),pos=Vector3.new(-72,bt+3,0),col=Color3.fromRGB(45,0,0),mat=Enum.Material.Basalt})
P({name="BossTorso",par=bossF,sz=Vector3.new(6,8,3),pos=Vector3.new(-72,bt+10,0),col=Color3.fromRGB(65,0,0),mat=Enum.Material.Basalt})
local bh=P({name="BossHead",par=bossF,sz=Vector3.new(5,5,5),pos=Vector3.new(-72,bt+16.5,0),col=Color3.fromRGB(100,0,0),mat=Enum.Material.Neon})
light(bh,4,20,Color3.fromRGB(255,0,0))
sign(bh,"👹 MEGA BOSS\n[Coming Soon]",Color3.fromRGB(255,70,70),5)

local bossSign=P({name="BossSign",par=bossF,sz=Vector3.new(16,4,1),
    pos=Vector3.new(-72,VOL_TOP+14,12),col=Color3.fromRGB(150,8,8),mat=Enum.Material.Neon})
sign(bossSign,"👹 BOSS ARENA",Color3.fromRGB(255,60,60),2)
light(bossSign,2,14,Color3.fromRGB(255,0,0))

-- Spiral steps: start from cobble path at G, spiral up to VOL_TOP
for i=0,13 do
    local a=math.rad(i*26)
    local r=28-i*0.5
    P({name="Step",par=bossF,sz=Vector3.new(7,1.5,4),
        cf=CFrame.new(-72+math.cos(a)*r, G+i*3, math.sin(a)*r)*CFrame.Angles(0,a,0),
        col=Color3.fromRGB(70,52,32),mat=Enum.Material.Cobblestone})
end

-- ============================================================
-- SECRET VAULT — underground south
-- ============================================================
local secretF=Instance.new("Folder",MAP); secretF.Name="SecretZone"
local caveY=G-12

P({name="Floor",par=secretF,sz=Vector3.new(34,1,34),
    pos=Vector3.new(0,caveY,75),col=Color3.fromRGB(18,65,40),mat=Enum.Material.Grass})
P({name="Ceiling",par=secretF,sz=Vector3.new(36,1,36),
    pos=Vector3.new(0,caveY+11,75),col=Color3.fromRGB(18,16,25),mat=Enum.Material.SmoothPlastic})
for _,w in ipairs({
    {Vector3.new(36,12,1),Vector3.new(0,caveY+6,58)},
    {Vector3.new(36,12,1),Vector3.new(0,caveY+6,92)},
    {Vector3.new(1,12,36),Vector3.new(-18,caveY+6,75)},
    {Vector3.new(1,12,36),Vector3.new(18, caveY+6,75)},
}) do
    P({name="Wall",par=secretF,sz=w[1],pos=w[2],col=Color3.fromRGB(12,12,20),mat=Enum.Material.SmoothPlastic})
end

local chest=P({name="Chest",par=secretF,sz=Vector3.new(5,4,4),
    pos=Vector3.new(0,caveY+3,75),col=Color3.fromRGB(105,70,16),mat=Enum.Material.Wood})
P({name="ChestLid",par=secretF,sz=Vector3.new(5,1.5,4),
    pos=Vector3.new(0,caveY+5.3,75),col=Color3.fromRGB(125,90,25),mat=Enum.Material.Wood})
light(chest,5,18,Color3.fromRGB(255,200,0))
sign(chest,"🏴‍☠️ SECRET VAULT!\n+2000 COINS",Color3.fromRGB(255,215,0),6)

local chestCD=Instance.new("ClickDetector",chest); chestCD.MaxActivationDistance=10
chestCD.MouseClick:Connect(function(player)
    for i=1,20 do if coinBE then coinBE:Fire(player) end end
    local n=ReplicatedStorage:FindFirstChild("NotifyPlayer")
    if n then n:FireClient(player,"🏴‍☠️ SECRET FOUND!","+2000 bonus coins!","gold") end
end)

for i=0,5 do
    local a=math.rad(i*60)
    local mp=P({name="Mushroom",par=secretF,sz=Vector3.new(1.4,2,1.4),
        pos=Vector3.new(math.cos(a)*9,caveY+1.5,75+math.sin(a)*9),
        col=Color3.fromRGB(85,0,120),mat=Enum.Material.Neon,cc=false})
    light(mp,1,6,Color3.fromRGB(120,0,160))
end

-- Entrance hole at surface
local hole=P({name="Hole",par=secretF,sz=Vector3.new(7,0.2,7),
    pos=Vector3.new(0,G+0.1,68),col=Color3.fromRGB(4,4,4),mat=Enum.Material.Neon,cc=false})
sign(hole,"🕳️ Drop in...?",Color3.fromRGB(130,130,180),3)

-- ============================================================
-- VIP LOUNGE — floating island northeast
-- ============================================================
local vipF=Instance.new("Folder",MAP); vipF.Name="VIPLounge"
local VIP_Y=G+55

-- Floating terrain
terrain:FillBall(Vector3.new(80,VIP_Y-5,-80), 20, Enum.Material.Grass)
terrain:FillBall(Vector3.new(80,VIP_Y-11,-80),18, Enum.Material.Ground)

P({name="VIPFloor",par=vipF,sz=Vector3.new(38,2,38),
    pos=Vector3.new(80,VIP_Y,-80),col=Color3.fromRGB(65,12,120),mat=Enum.Material.Neon})

for _,pos in ipairs({{69,-69},{91,-69},{69,-91},{91,-91}}) do
    P({name="Pillar",par=vipF,sz=Vector3.new(2.5,16,2.5),
        pos=Vector3.new(pos[1],VIP_Y-7,pos[2]),
        col=Color3.fromRGB(110,35,185),mat=Enum.Material.Neon})
end

local vipBarrier=P({name="VIPBarrier",par=vipF,sz=Vector3.new(40,6,1),
    pos=Vector3.new(80,VIP_Y+4,-62),col=Color3.fromRGB(100,12,180),mat=Enum.Material.Neon})
sign(vipBarrier,"⭐ VIP ONLY — R$499",Color3.fromRGB(220,150,255),3)
light(vipBarrier,2,12,Color3.fromRGB(150,0,220))

vipBarrier.Touched:Connect(function(hit)
    local char=hit.Parent
    local plr=Players:GetPlayerFromCharacter(char)
    if not plr then return end
    local ok,owns=pcall(function()
        return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(plr.UserId,1821720069)
    end)
    if ok and owns then return end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame=hrp.CFrame+Vector3.new(0,0,10) end
    local n=ReplicatedStorage:FindFirstChild("NotifyPlayer")
    if n then n:FireClient(plr,"⭐ VIP Only!","Get the VIP Gamepass!","gold") end
end)

-- Cloud stepping stones up to VIP (northeast direction)
for i=0,11 do
    local t=i/11
    P({name="CloudStep",par=vipF,sz=Vector3.new(7,1.5,6),
        pos=Vector3.new(18+t*62, G+t*VIP_Y, -18-t*62),
        col=Color3.fromRGB(225,225,240),mat=Enum.Material.SmoothPlastic})
end

-- Fountain
P({name="FountainBase",par=vipF,sz=Vector3.new(9,2,9),
    pos=Vector3.new(80,VIP_Y+1.5,-80),col=Color3.fromRGB(140,50,220),mat=Enum.Material.Neon})
light(P({name="FountainGlow",par=vipF,sz=Vector3.new(1,1,1),
    pos=Vector3.new(80,VIP_Y+7,-80),tr=1,cc=false}),4,18,Color3.fromRGB(100,160,255))

-- ============================================================
-- LIGHTING
-- ============================================================
Lighting.Brightness=1.6; Lighting.ClockTime=14
Lighting.Ambient=Color3.fromRGB(80,95,110)
Lighting.OutdoorAmbient=Color3.fromRGB(115,132,148)
Lighting.GlobalShadows=true; Lighting.ShadowSoftness=0.3

local atmo=Instance.new("Atmosphere",Lighting)
atmo.Density=0.2; atmo.Offset=0.06
atmo.Color=Color3.fromRGB(185,205,235)
atmo.Decay=Color3.fromRGB(85,105,125)
atmo.Glare=0.08; atmo.Haze=0.4

local bloom=Instance.new("BloomEffect",Lighting)
bloom.Intensity=0.35; bloom.Size=22; bloom.Threshold=0.95

local sr=Instance.new("SunRaysEffect",Lighting); sr.Intensity=0.07; sr.Spread=0.5
local cc=Instance.new("ColorCorrectionEffect",Lighting)
cc.Saturation=0.12; cc.Brightness=0.02; cc.Contrast=0.04

print("[MoneyIsland] ✅ Map v7 built! Ground=Y:"..G)

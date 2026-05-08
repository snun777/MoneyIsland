-- MapBuilder.server.lua (v26 - 20 unique machines + night skybox + CoinRain/GeyserSurge events)

local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

-- MainGameServer creates these first; we wait for them
local coinBE       = ReplicatedStorage:WaitForChild("CoinCollected_BE", 15)
local CoinRainBE   = ReplicatedStorage:WaitForChild("CoinRain_BE",      30)
local GeyserSurgeBE= ReplicatedStorage:WaitForChild("GeyserSurge_BE",   30)

-- We create these; MainGameServer waits for them
local CoinDestroyBE    = Instance.new("BindableEvent", ReplicatedStorage); CoinDestroyBE.Name    = "CoinDestroy_BE"
local GeyserActivateBE = Instance.new("BindableEvent", ReplicatedStorage); GeyserActivateBE.Name = "GeyserActivate_BE"
local PlotRelockBE     = Instance.new("BindableEvent", ReplicatedStorage); PlotRelockBE.Name     = "PlotRelock_BE"
local MegaBurstBE      = Instance.new("BindableEvent", ReplicatedStorage); MegaBurstBE.Name      = "MegaBurst_BE"
-- RemoteEvent: broadcasts geyser on/off state + mega burst alerts to all clients
local GeyserStateRE    = Instance.new("RemoteEvent",   ReplicatedStorage); GeyserStateRE.Name    = "GeyserState"
local PlotPurchaseBE   = Instance.new("BindableEvent", ReplicatedStorage); PlotPurchaseBE.Name   = "PlotPurchase"
local plotUnlockedBE   = Instance.new("BindableEvent", ReplicatedStorage); plotUnlockedBE.Name   = "PlotUnlocked"
local PrestigeResetBE  = Instance.new("BindableEvent", ReplicatedStorage); PrestigeResetBE.Name  = "PrestigeReset_BE"
local PlotTransferBE   = Instance.new("BindableEvent", ReplicatedStorage); PlotTransferBE.Name   = "PlotTransfer_BE"
local PlotRaidAlertBE  = Instance.new("BindableEvent", ReplicatedStorage); PlotRaidAlertBE.Name  = "PlotRaidAlert_BE"

for _, obj in ipairs(Workspace:GetChildren()) do
	if obj.Name == "Baseplate" or obj.Name == "SpawnLocation" then obj:Destroy() end
end

local terrain = Workspace.Terrain; terrain:Clear()
terrain:FillBlock(CFrame.new(0, -8,  0), Vector3.new(600, 16,  600),  Enum.Material.Pavement)
terrain:FillBlock(CFrame.new(0, -18, 0), Vector3.new(598, 14,  598),  Enum.Material.Ground)
terrain:FillBlock(CFrame.new(0, -20, 0), Vector3.new(1200, 18, 1200), Enum.Material.Water)

local G   = 0
local MAP = Instance.new("Folder", Workspace); MAP.Name = "MoneyIslandMap"

-- ── PART HELPERS ─────────────────────────────────────────────
local function P(t)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = t.cc ~= false
	p.Size   = t.sz  or Vector3.new(4,1,4)
	p.CFrame = t.cf  or CFrame.new(t.pos or Vector3.new())
	p.Color  = t.col or Color3.fromRGB(163,162,165)
	p.Material = t.mat or Enum.Material.SmoothPlastic
	p.Name = t.name or "Part"; p.Transparency = t.tr or 0
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = t.shadow ~= false
	p.Parent = t.par or MAP; return p
end

local function CYL(t)
	local p = Instance.new("Part"); p.Shape = Enum.PartType.Cylinder
	p.Anchored = true; p.CanCollide = t.cc ~= false
	p.Size   = t.sz  or Vector3.new(1,4,4)
	p.CFrame = t.cf  or CFrame.new(t.pos or Vector3.new())
	p.Color  = t.col or Color3.fromRGB(200,200,200)
	p.Material = t.mat or Enum.Material.SmoothPlastic
	p.Name = t.name or "Cyl"; p.Transparency = t.tr or 0
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = t.par or MAP; return p
end

local function addLight(par, brightness, range, col)
	local l = Instance.new("PointLight", par)
	l.Brightness = brightness; l.Range = range; l.Color = col
	return l
end

local function makeBillboard(par, txt, col, dy, w, h, maxDist)
	local bb = Instance.new("BillboardGui", par)
	bb.Size = UDim2.new(0, w or 200, 0, h or 50)
	bb.StudsOffset = Vector3.new(0, dy or 3, 0); bb.MaxDistance = maxDist or 80
	bb.AlwaysOnTop = false; bb.LightInfluence = 0
	local tl = Instance.new("TextLabel", bb); tl.Size = UDim2.new(1,0,1,0)
	tl.BackgroundTransparency = 1; tl.Text = txt; tl.TextColor3 = col or Color3.new(1,1,1)
	tl.Font = Enum.Font.GothamBold; tl.TextScaled = true
	tl.TextStrokeTransparency = 0.3; tl.TextStrokeColor3 = Color3.new(0,0,0)
	return bb
end

-- ── SPAWN PLATFORM ────────────────────────────────────────────
local sp = Instance.new("SpawnLocation")
sp.Size = Vector3.new(10,0.5,10); sp.CFrame = CFrame.new(0, G+0.25, 0)
sp.Neutral = true; sp.Duration = 0; sp.Anchored = true
sp.BrickColor = BrickColor.new("Cyan"); sp.Material = Enum.Material.Neon
sp.TopSurface = Enum.SurfaceType.Smooth; sp.Parent = MAP

local SPAWN_RING_N = 20
for i = 0, SPAWN_RING_N-1 do
	local a = i * (2*math.pi / SPAWN_RING_N)
	P({name="SpawnRing", par=MAP, sz=Vector3.new(1.2,0.4,1.2),
		pos=Vector3.new(math.cos(a)*7.5, G+0.5, math.sin(a)*7.5),
		col=Color3.fromRGB(0,220,255), mat=Enum.Material.Neon, cc=false, shadow=false})
end

-- ── LAYOUT CONSTANTS ──────────────────────────────────────────
local DECK_TOP     = G + 0.6
local PLOT_W       = 50
local PLOT_D       = 50
local COLS = {-2*PLOT_W, -PLOT_W, 0, PLOT_W, 2*PLOT_W}
local ROWS = {-2*PLOT_D, -PLOT_D, 0, PLOT_D, 2*PLOT_D}
local PC = Color3.fromRGB(188,140,80)
local RC = Color3.fromRGB(160,110,55)
local PM = Enum.Material.WoodPlanks

local farmF  = Instance.new("Folder", MAP); farmF.Name  = "FarmZone"
local coinsF = Instance.new("Folder", farmF); coinsF.Name = "CoinModels"
local totalW = PLOT_W*5 + 10
local totalD = PLOT_D*5 + 10

P({name="Deck", par=farmF, sz=Vector3.new(totalW,0.6,totalD),
	pos=Vector3.new(0,G+0.3,0), col=Color3.fromRGB(120,82,42), mat=PM})

-- ── FENCE BUILDERS ────────────────────────────────────────────
local function fenceSection(f, x, z1, z2, vertical)
	local len = math.abs(z2-z1); if len < 1 then return end
	local cz  = (z1+z2)/2
	if vertical then
		P({par=f,name="Rail",sz=Vector3.new(0.5,0.8,len),pos=Vector3.new(x,DECK_TOP+1.5,cz),col=RC,mat=PM})
		P({par=f,name="Rail",sz=Vector3.new(0.5,0.8,len),pos=Vector3.new(x,DECK_TOP+4.0,cz),col=RC,mat=PM})
		local steps = math.max(1, math.floor(len/2.5))
		for i = 0, steps do
			P({par=f,name="Picket",sz=Vector3.new(0.4,6,0.8),
				pos=Vector3.new(x,DECK_TOP+3.0,z1+i*(len/steps)),col=PC,mat=PM})
		end
	else
		P({par=f,name="Rail",sz=Vector3.new(len,0.8,0.5),pos=Vector3.new(cz,DECK_TOP+1.5,x),col=RC,mat=PM})
		P({par=f,name="Rail",sz=Vector3.new(len,0.8,0.5),pos=Vector3.new(cz,DECK_TOP+4.0,x),col=RC,mat=PM})
		local steps = math.max(1, math.floor(len/2.5))
		for i = 0, steps do
			P({par=f,name="Picket",sz=Vector3.new(0.8,6,0.4),
				pos=Vector3.new(z1+i*(len/steps),DECK_TOP+3.0,x),col=PC,mat=PM})
		end
	end
end

local function fencePost(f, x, z, h)
	h = h or 7
	P({par=f,name="Post",   sz=Vector3.new(1.4,h,1.4),  pos=Vector3.new(x,DECK_TOP+h/2,z),   col=Color3.fromRGB(140,90,40),mat=PM})
	P({par=f,name="PostCap",sz=Vector3.new(1.6,0.6,1.6),pos=Vector3.new(x,DECK_TOP+h+0.3,z), col=Color3.fromRGB(120,75,30),mat=PM})
end

-- Grid dividers
for _, zd in ipairs({ROWS[1]+PLOT_D/2, ROWS[2]+PLOT_D/2, ROWS[3]+PLOT_D/2, ROWS[4]+PLOT_D/2}) do
	P({name="DivZ",par=farmF,sz=Vector3.new(totalW,0.3,0.6),pos=Vector3.new(0,DECK_TOP+0.2,zd),col=Color3.fromRGB(60,40,14),mat=PM})
end
for _, xd in ipairs({COLS[1]+PLOT_W/2, COLS[2]+PLOT_W/2, COLS[3]+PLOT_W/2, COLS[4]+PLOT_W/2}) do
	P({name="DivX",par=farmF,sz=Vector3.new(0.6,0.3,totalD),pos=Vector3.new(xd,DECK_TOP+0.2,0),col=Color3.fromRGB(60,40,14),mat=PM})
end

local BX = COLS[#COLS] + PLOT_W/2 - 1
local BZ = ROWS[#ROWS] + PLOT_D/2 - 1
fenceSection(farmF,-BX,-BZ,BZ,true);  fenceSection(farmF,BX,-BZ,BZ,true)
fenceSection(farmF,-BZ,-BX,BX,false); fenceSection(farmF,BZ,-BX,BX,false)
fencePost(farmF,-BX,-BZ); fencePost(farmF,-BX,BZ)
fencePost(farmF, BX,-BZ); fencePost(farmF, BX,BZ)

-- ── LAMP POSTS ────────────────────────────────────────────────
local lampF = Instance.new("Folder", MAP); lampF.Name = "Lamps"
local function lampPost(cx, cz)
	P({par=lampF,name="LampPost",sz=Vector3.new(0.9,11,0.9),
		pos=Vector3.new(cx,G+5.5,cz),col=Color3.fromRGB(70,50,20),mat=PM,shadow=false})
	P({par=lampF,name="LampArm",sz=Vector3.new(4,0.5,0.5),
		pos=Vector3.new(cx+2,G+11.2,cz),col=Color3.fromRGB(60,40,15),mat=PM,shadow=false})
	local globe = P({par=lampF,name="LampGlobe",sz=Vector3.new(2.4,2.4,2.4),
		pos=Vector3.new(cx+2,G+10.2,cz),col=Color3.fromRGB(255,238,160),mat=Enum.Material.Neon,cc=false,shadow=false})
	addLight(globe, 4, 35, Color3.fromRGB(255,230,140))
end
local lp = BX+10
lampPost(lp,lp); lampPost(-lp,lp); lampPost(lp,-lp); lampPost(-lp,-lp)
lampPost(lp,0);  lampPost(-lp,0);  lampPost(0,lp);   lampPost(0,-lp)

-- ── TREES ─────────────────────────────────────────────────────
local treeF = Instance.new("Folder", MAP); treeF.Name = "Trees"
local TREE_POSITIONS = {
	{165,165},{-165,165},{165,-165},{-165,-165},
	{-170,0},{0,170},{0,-170},
	{210,100},{-210,100},{210,-100},{-210,-100},
	{100,210},{-100,210},{100,-210},{-100,-210},
}
local function addTree(cx, cz, h)
	h = h or 8
	P({par=treeF,name="TreeTrunk",sz=Vector3.new(2.5,h,2.5),
		pos=Vector3.new(cx,G+h/2-2,cz),col=Color3.fromRGB(85,52,18),mat=PM})
	P({par=treeF,name="TreeCanopy",sz=Vector3.new(13,7,13),
		pos=Vector3.new(cx,G+h+2,cz),col=Color3.fromRGB(30,148,52),mat=Enum.Material.SmoothPlastic,cc=false})
	P({par=treeF,name="TreeTop",sz=Vector3.new(9,5,9),
		pos=Vector3.new(cx,G+h+6.5,cz),col=Color3.fromRGB(20,128,42),mat=Enum.Material.SmoothPlastic,cc=false})
end
for i, tp in ipairs(TREE_POSITIONS) do addTree(tp[1], tp[2], 7+(i%3)) end

-- ── DECORATIVE ROCKS ──────────────────────────────────────────
local rockF = Instance.new("Folder", MAP); rockF.Name = "Rocks"
local ROCKS = {
	{190,35,5,13,7},{-175,-30,4,11,6},{28,188,6,9,14},{-38,-172,3,12,8},
	{162,160,7,8,8},{-163,145,4,10,7},{154,-160,5,7,10},{-158,-148,4,12,9},
	{240,50,5,10,8},{-240,-60,4,9,7},{60,242,6,11,9},{-70,-238,3,8,6},
}
for _, r in ipairs(ROCKS) do
	local rx,rz,rh,rw,rd = r[1],r[2],r[3],r[4],r[5]
	P({par=rockF,name="Rock",sz=Vector3.new(rw,rh,rd),
		pos=Vector3.new(rx,-11+rh/2-1,rz),col=Color3.fromRGB(88,83,78),mat=Enum.Material.SmoothPlastic})
	if rh >= 5 then
		P({par=rockF,name="RockCap",sz=Vector3.new(rw-3,1.5,rd-3),
			pos=Vector3.new(rx,-11+rh-0.5,rz),col=Color3.fromRGB(72,68,64),mat=Enum.Material.SmoothPlastic})
	end
end

-- ── LEADERBOARD PLATFORM (right side of island, out of gameplay area) ────
local lbF = Instance.new("Folder", MAP); lbF.Name = "LeaderboardArea"
-- Board faces left (toward spawn) from the right side
local LB_X = 175; local LB_Z = 0
local boardCF = CFrame.lookAt(Vector3.new(LB_X, G+14, LB_Z), Vector3.new(0, G+14, LB_Z))
-- Support pillars (tall so board is visible above fence)
for _, dz in ipairs({-12, 12}) do
	P({name="LBPillar",par=lbF,sz=Vector3.new(1.2,26,1.2),
		pos=Vector3.new(LB_X, G+13, LB_Z+dz),col=Color3.fromRGB(70,50,20),mat=PM,shadow=false})
end
-- Base platform
P({name="LBPedestal",par=lbF,sz=Vector3.new(4,1,30),
	pos=Vector3.new(LB_X, G+0.5, LB_Z),col=Color3.fromRGB(50,35,12),mat=PM})
-- Board face
local lbBoard = P({name="LeaderboardBoard",par=lbF,sz=Vector3.new(22,14,0.8),
	cf=boardCF,col=Color3.fromRGB(8,8,20),mat=Enum.Material.SmoothPlastic,shadow=false})
addLight(lbBoard, 3, 28, Color3.fromRGB(255,215,0))
-- Neon frame edges
local halfW, halfH = 11.3, 7.3
for _, edge in ipairs({
	{sz=Vector3.new(23.5,0.5,0.5), off=Vector3.new(0, halfH, 0)},
	{sz=Vector3.new(23.5,0.5,0.5), off=Vector3.new(0,-halfH, 0)},
	{sz=Vector3.new(0.5,15.5,0.5), off=Vector3.new( halfW,0,0)},
	{sz=Vector3.new(0.5,15.5,0.5), off=Vector3.new(-halfW,0,0)},
}) do
	P({name="LBEdge",par=lbF,sz=edge.sz,cf=boardCF*CFrame.new(edge.off),
		col=Color3.fromRGB(255,200,0),mat=Enum.Material.Neon,cc=false,shadow=false})
end

-- ── PLOT DEFINITIONS ──────────────────────────────────────────
-- contested=true: always open geyser zone, no ownership, no purchase
-- All other plots are owned per-player via auto-tick income
local PLOT_DEFS = {
	-- ── CONTESTED GEYSER ZONE (center cross, 5 plots) ──
	{id="C_M",  cx=COLS[3], cz=ROWS[3], contested=true},
	{id="L_M",  cx=COLS[2], cz=ROWS[3], contested=true},
	{id="R_M",  cx=COLS[4], cz=ROWS[3], contested=true},
	{id="C_N",  cx=COLS[3], cz=ROWS[4], contested=true},
	{id="C_S",  cx=COLS[3], cz=ROWS[2], contested=true},
	-- ── OWNED PLOTS ring 1 (adjacent to contested, cost 4,000) ──
	{id="L_N",  cx=COLS[2], cz=ROWS[4], cost=4000,   color=Color3.fromRGB(80,255,120), label="4,000 Coins"},
	{id="R_N",  cx=COLS[4], cz=ROWS[4], cost=4000,   color=Color3.fromRGB(80,255,120), label="4,000 Coins"},
	{id="L_S",  cx=COLS[2], cz=ROWS[2], cost=4000,   color=Color3.fromRGB(80,255,120), label="4,000 Coins"},
	{id="R_S",  cx=COLS[4], cz=ROWS[2], cost=4000,   color=Color3.fromRGB(80,255,120), label="4,000 Coins"},
	-- ── OWNED PLOTS ring 2 (cost 25,000) ──
	{id="LL_M", cx=COLS[1], cz=ROWS[3], cost=25000,  color=Color3.fromRGB(255,160,0),  label="25,000 Coins"},
	{id="RR_M", cx=COLS[5], cz=ROWS[3], cost=25000,  color=Color3.fromRGB(255,160,0),  label="25,000 Coins"},
	{id="C_NN", cx=COLS[3], cz=ROWS[5], cost=25000,  color=Color3.fromRGB(255,160,0),  label="25,000 Coins"},
	{id="C_SS", cx=COLS[3], cz=ROWS[1], cost=25000,  color=Color3.fromRGB(255,160,0),  label="25,000 Coins"},
	-- ── OWNED PLOTS ring 3 (cost 75,000) ──
	{id="LL_N", cx=COLS[1], cz=ROWS[4], cost=75000,  color=Color3.fromRGB(255,200,0),  label="75,000 Coins"},
	{id="LL_S", cx=COLS[1], cz=ROWS[2], cost=75000,  color=Color3.fromRGB(255,200,0),  label="75,000 Coins"},
	{id="RR_N", cx=COLS[5], cz=ROWS[4], cost=75000,  color=Color3.fromRGB(255,200,0),  label="75,000 Coins"},
	{id="RR_S", cx=COLS[5], cz=ROWS[2], cost=75000,  color=Color3.fromRGB(255,200,0),  label="75,000 Coins"},
	{id="L_NN", cx=COLS[2], cz=ROWS[5], cost=75000,  color=Color3.fromRGB(255,200,0),  label="75,000 Coins"},
	{id="R_NN", cx=COLS[4], cz=ROWS[5], cost=75000,  color=Color3.fromRGB(255,200,0),  label="75,000 Coins"},
	{id="L_SS", cx=COLS[2], cz=ROWS[1], cost=75000,  color=Color3.fromRGB(255,200,0),  label="75,000 Coins"},
	{id="R_SS", cx=COLS[4], cz=ROWS[1], cost=75000,  color=Color3.fromRGB(255,200,0),  label="75,000 Coins"},
	-- ── OWNED PLOTS ring 4 corners (cost 200,000) ──
	{id="LL_NN",cx=COLS[1], cz=ROWS[5], cost=200000, color=Color3.fromRGB(220,80,255), label="200,000 Coins"},
	{id="RR_NN",cx=COLS[5], cz=ROWS[5], cost=200000, color=Color3.fromRGB(220,80,255), label="200,000 Coins"},
	{id="LL_SS",cx=COLS[1], cz=ROWS[1], cost=200000, color=Color3.fromRGB(220,80,255), label="200,000 Coins"},
	{id="RR_SS",cx=COLS[5], cz=ROWS[1], cost=200000, color=Color3.fromRGB(220,80,255), label="200,000 Coins"},
}

-- Floor color tiers for owned plots
local TIER_FLOORS = {
	[2000]  = Color3.fromRGB(108,75,38),
	[10000] = Color3.fromRGB(90,62,28),
	[25000] = Color3.fromRGB(72,50,22),
	[50000] = Color3.fromRGB(55,35,80),
}
local function getFloorCol(cost) return TIER_FLOORS[cost] or Color3.fromRGB(120,84,44) end

local plotState  = {}  -- plotState[plotId] = {unlocked, ownerUserId, folder, def, signBB}
local plotByPos  = {}  -- plotByPos["cx_cz"] = state

-- ── NEIGHBOR HELPERS ──────────────────────────────────────────
local function getNeighborKeys(def)
	return {
		(def.cx-PLOT_W).."_"..def.cz,
		(def.cx+PLOT_W).."_"..def.cz,
		def.cx.."_"..(def.cz-PLOT_D),
		def.cx.."_"..(def.cz+PLOT_D),
	}
end

local function hasUnlockedNeighbor(def)
	for _, key in ipairs(getNeighborKeys(def)) do
		local ns = plotByPos[key]
		if ns and (ns.unlocked or ns.def.contested) then return true end
	end
	return false
end

local function revealNeighborSigns(def)
	for _, key in ipairs(getNeighborKeys(def)) do
		local ns = plotByPos[key]
		if ns and not ns.unlocked and not ns.def.contested and ns.signBB then
			ns.signBB.Enabled = true
		end
	end
end

-- ── BUILD LOCKED OWNED PLOT ───────────────────────────────────
local function buildLockedPlot(state)
	local def    = state.def
	local folder = state.folder
	state.signBB = nil

	local x1 = def.cx - PLOT_W/2 + 1; local x2 = def.cx + PLOT_W/2 - 1
	local z1 = def.cz - PLOT_D/2 + 1; local z2 = def.cz + PLOT_D/2 - 1
	local isOuterX1 = (def.cx == COLS[1]); local isOuterX2 = (def.cx == COLS[#COLS])
	local isOuterZ1 = (def.cz == ROWS[1]); local isOuterZ2 = (def.cz == ROWS[#ROWS])

	P({name="Overlay",par=folder,sz=Vector3.new(PLOT_W-1,0.15,PLOT_D-1),
		pos=Vector3.new(def.cx,DECK_TOP+0.1,def.cz),
		col=Color3.fromRGB(35,35,35),mat=Enum.Material.SmoothPlastic,tr=0.25,cc=false})

	if not isOuterX1 then fenceSection(folder,x1,z1,z2,true) end
	if not isOuterX2 then fenceSection(folder,x2,z1,z2,true) end
	if not isOuterZ1 then fenceSection(folder,z1,x1,x2,false) end
	if not isOuterZ2 then fenceSection(folder,z2,x1,x2,false) end
	if not isOuterX1 and not isOuterZ1 then fencePost(folder,x1,z1) end
	if not isOuterX1 and not isOuterZ2 then fencePost(folder,x1,z2) end
	if not isOuterX2 and not isOuterZ1 then fencePost(folder,x2,z1) end
	if not isOuterX2 and not isOuterZ2 then fencePost(folder,x2,z2) end

	local signAnchor = Instance.new("Part")
	signAnchor.Name = "SignAnchor"; signAnchor.Anchored = true; signAnchor.CanCollide = false
	signAnchor.Size = Vector3.new(1,1,1); signAnchor.CFrame = CFrame.new(def.cx,DECK_TOP+5,def.cz)
	signAnchor.Transparency = 1; signAnchor.Parent = folder

	local scaledLabel = def.label or (def.cost.." Coins")
	local signBB = makeBillboard(signAnchor, "🔒 "..scaledLabel.."\nClick to buy!", def.color, 5, 280, 80, 80)
	signBB.Enabled = true  -- all plots visible from start; reach-based access only
	state.signBB = signBB

	local function addFaceAnchor(sz, cf)
		local a = Instance.new("Part")
		a.Name = "Anchor"; a.Anchored = true; a.CanCollide = true
		a.Size = sz; a.CFrame = cf; a.Transparency = 1; a.Parent = folder
		local cd = Instance.new("ClickDetector", a); cd.MaxActivationDistance = 60
		cd.MouseClick:Connect(function(player)
			if state.unlocked then return end
			local rebirths = 0
			local ls = player:FindFirstChild("leaderstats")
			if ls then local rv = ls:FindFirstChild("Rebirths"); if rv then rebirths = rv.Value end end
			local scaledCost = math.floor(def.cost * (1.5 ^ rebirths))
			PlotPurchaseBE:Fire(player, def.id, scaledCost)
		end)
	end

	if not isOuterX2 then addFaceAnchor(Vector3.new(1,10,PLOT_D-2), CFrame.new(x2,DECK_TOP+5,def.cz)) end
	if not isOuterX1 then addFaceAnchor(Vector3.new(1,10,PLOT_D-2), CFrame.new(x1,DECK_TOP+5,def.cz)) end
	if not isOuterZ2 then addFaceAnchor(Vector3.new(PLOT_W-2,10,1), CFrame.new(def.cx,DECK_TOP+5,z2)) end
	if not isOuterZ1 then addFaceAnchor(Vector3.new(PLOT_W-2,10,1), CFrame.new(def.cx,DECK_TOP+5,z1)) end
end

-- ── UNLOCK / RELOCK OWNED PLOTS ───────────────────────────────

-- ── COIN MACHINES ─────────────────────────────────────────────
local function spinX(part, dps)
	task.spawn(function()
		while part and part.Parent do
			part.CFrame = part.CFrame * CFrame.Angles(math.rad(dps), 0, 0)
			task.wait(0.05)
		end
	end)
end

local function spinWorldY(part, cx, cy, cz, dps, extraAngles)
	task.spawn(function()
		local a = 0
		while part and part.Parent do
			a = a + dps
			part.CFrame = CFrame.new(cx, cy, cz) * CFrame.Angles(0, math.rad(a), 0) * (extraAngles or CFrame.new())
			task.wait(0.05)
		end
	end)
end

local function bob(part, cx, cy, cz, amp, sp, extraAngles)
	task.spawn(function()
		local t = 0
		while part and part.Parent do
			t = t + sp
			part.CFrame = CFrame.new(cx, cy + math.sin(t)*amp, cz) * (extraAngles or CFrame.new())
			task.wait(0.05)
		end
	end)
end

-- Tier 2,000: 🖨️ Coin Printer
local function buildPrinter(cx, cz, f)
	local Y = DECK_TOP
	local body = P({name="M",par=f,sz=Vector3.new(14,5,8),
		pos=Vector3.new(cx,Y+2.7,cz),col=Color3.fromRGB(52,52,62),mat=PM})
	P({name="M",par=f,sz=Vector3.new(14,5,0.4),
		pos=Vector3.new(cx,Y+2.7,cz-4.2),col=Color3.fromRGB(72,72,86),mat=PM,cc=false,shadow=false})
	local roller = CYL({name="M",par=f,sz=Vector3.new(13,1.4,1.4),
		cf=CFrame.new(cx,Y+4.8,cz-4.0),col=Color3.fromRGB(28,28,32),mat=PM})
	spinX(roller, 5)
	P({name="M",par=f,sz=Vector3.new(9,0.3,0.5),
		pos=Vector3.new(cx,Y+0.9,cz-4.6),col=Color3.fromRGB(255,215,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	P({name="M",par=f,sz=Vector3.new(8,0.25,2.5),
		pos=Vector3.new(cx,Y+0.3,cz-5.8),col=Color3.fromRGB(155,130,22),mat=PM,cc=false,shadow=false})
	for i=0,2 do
		CYL({name="M",par=f,sz=Vector3.new(0.35,2.2,2.2),
			cf=CFrame.new(cx-2+i*2, Y+0.55, cz-5.8)*CFrame.Angles(0,0,math.rad(90)),
			col=Color3.fromRGB(255,215,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	end
	P({name="M",par=f,sz=Vector3.new(5,3,0.3),
		pos=Vector3.new(cx,Y+3.5,cz+4.2),col=Color3.fromRGB(30,160,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	P({name="M",par=f,sz=Vector3.new(0.9,0.9,0.9),
		pos=Vector3.new(cx+5.5,Y+5.5,cz),col=Color3.fromRGB(0,255,100),mat=Enum.Material.Neon,cc=false,shadow=false})
	addLight(body, 3, 22, Color3.fromRGB(255,215,0))
	makeBillboard(body,"🖨️ COIN PRINTER",Color3.fromRGB(255,215,0),8,210,46,85)
end

-- Tier 10,000: 🤖 Coin Roomba
local function buildRoomba(cx, cz, f)
	local Y = DECK_TOP
	local discY = Y + 1.6
	local discAngles = CFrame.Angles(0, 0, math.rad(90))
	local body = CYL({name="M",par=f,sz=Vector3.new(3,16,16),
		cf=CFrame.new(cx,discY,cz)*discAngles,
		col=Color3.fromRGB(28,28,34),mat=PM})
	CYL({name="M",par=f,sz=Vector3.new(3.1,17.4,17.4),
		cf=CFrame.new(cx,discY,cz)*discAngles,
		col=Color3.fromRGB(255,85,0),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.15})
	P({name="M",par=f,sz=Vector3.new(5.5,2,5.5),
		pos=Vector3.new(cx,discY+2.2,cz),col=Color3.fromRGB(44,44,56),mat=PM,cc=false,shadow=false})
	for _, ex in ipairs({-2, 2}) do
		P({name="M",par=f,sz=Vector3.new(1.2,1.2,0.6),
			pos=Vector3.new(cx+ex, discY+1.5, cz-8.3),
			col=Color3.fromRGB(255,220,50),mat=Enum.Material.Neon,cc=false,shadow=false})
	end
	CYL({name="M",par=f,sz=Vector3.new(0.6,3,3),
		cf=CFrame.new(cx,discY+3.2,cz)*discAngles,
		col=Color3.fromRGB(0,220,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	P({name="M",par=f,sz=Vector3.new(0.5,4.5,0.5),
		pos=Vector3.new(cx,discY+4.5,cz),col=Color3.fromRGB(80,80,95),mat=PM,cc=false,shadow=false})
	P({name="M",par=f,sz=Vector3.new(1.4,1.4,1.4),
		pos=Vector3.new(cx,discY+7.0,cz),col=Color3.fromRGB(255,85,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	spinWorldY(body, cx, discY, cz, 1.0, discAngles)
	addLight(body, 3.5, 26, Color3.fromRGB(255,120,0))
	makeBillboard(body,"🤖 COIN ROOMBA",Color3.fromRGB(255,120,0),10,210,46,85)
end

-- Tier 25,000: 🏭 Coin Factory
local function buildFactory(cx, cz, f)
	local Y = DECK_TOP
	local body = P({name="M",par=f,sz=Vector3.new(16,9,13),
		pos=Vector3.new(cx,Y+4.7,cz),col=Color3.fromRGB(55,53,65),mat=PM})
	P({name="M",par=f,sz=Vector3.new(17.5,0.7,14.5),
		pos=Vector3.new(cx,Y+9.4,cz),col=Color3.fromRGB(42,40,52),mat=PM,cc=false})
	local upAngles = CFrame.Angles(0,0,math.rad(90))
	CYL({name="M",par=f,sz=Vector3.new(11,3.5,3.5),
		cf=CFrame.new(cx-4.5,Y+14.5,cz+2.5)*upAngles,col=Color3.fromRGB(62,60,72),mat=PM,cc=false})
	CYL({name="M",par=f,sz=Vector3.new(8,2.8,2.8),
		cf=CFrame.new(cx+4.0,Y+12.5,cz-2)*upAngles,col=Color3.fromRGB(62,60,72),mat=PM,cc=false})
	CYL({name="M",par=f,sz=Vector3.new(0.8,3.7,3.7),
		cf=CFrame.new(cx-4.5,Y+9.5,cz+2.5)*upAngles,
		col=Color3.fromRGB(255,80,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	CYL({name="M",par=f,sz=Vector3.new(0.8,3.0,3.0),
		cf=CFrame.new(cx+4.0,Y+9.0,cz-2)*upAngles,
		col=Color3.fromRGB(255,80,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	local smoke1 = CYL({name="M",par=f,sz=Vector3.new(0.6,4.5,4.5),
		cf=CFrame.new(cx-4.5,Y+20,cz+2.5)*upAngles,
		col=Color3.fromRGB(200,200,210),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.4})
	local smoke2 = CYL({name="M",par=f,sz=Vector3.new(0.6,3.5,3.5),
		cf=CFrame.new(cx+4.0,Y+18,cz-2)*upAngles,
		col=Color3.fromRGB(200,200,210),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.4})
	bob(smoke1, cx-4.5, Y+20, cz+2.5, 1.5, 0.08, upAngles)
	bob(smoke2, cx+4.0, Y+18, cz-2,   1.2, 0.12, upAngles)
	for _, wpos in ipairs({{-5,7},{1,7},{-5,4},{1,4}}) do
		P({name="M",par=f,sz=Vector3.new(3,2.5,0.3),
			pos=Vector3.new(cx+wpos[1],Y+wpos[2],cz-6.6),
			col=Color3.fromRGB(255,220,100),mat=Enum.Material.Neon,cc=false,shadow=false})
	end
	P({name="M",par=f,sz=Vector3.new(4,5,0.3),
		pos=Vector3.new(cx+5,Y+2.6,cz-6.6),col=Color3.fromRGB(38,36,48),mat=PM,cc=false,shadow=false})
	for i=0,3 do
		P({name="M",par=f,sz=Vector3.new(7,0.2,0.5),
			pos=Vector3.new(cx,Y+0.25,cz-7.5+i*0.6),
			col=Color3.fromRGB(28,28,28),mat=PM,cc=false,shadow=false})
	end
	P({name="M",par=f,sz=Vector3.new(0.3,3,8),
		pos=Vector3.new(cx+8.2,Y+7.5,cz),
		col=Color3.fromRGB(255,200,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	addLight(body, 4, 34, Color3.fromRGB(255,190,60))
	makeBillboard(body,"🏭 COIN FACTORY",Color3.fromRGB(255,190,60),26,220,46,90)
end

-- Tier 50,000: 🏛️ Coin Vault
local function buildVault(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(18,1.2,18),
		pos=Vector3.new(cx,Y+0.7,cz),col=Color3.fromRGB(44,38,54),mat=PM,cc=false})
	local faceAngles = CFrame.Angles(0, math.rad(90), 0)
	P({name="M",par=f,sz=Vector3.new(5,20,20),
		pos=Vector3.new(cx,Y+11,cz-3),col=Color3.fromRGB(38,32,48),mat=PM})
	local door = CYL({name="M",par=f,sz=Vector3.new(3.5,17,17),
		cf=CFrame.new(cx,Y+11,cz-3)*faceAngles,
		col=Color3.fromRGB(66,58,82),mat=PM})
	CYL({name="M",par=f,sz=Vector3.new(0.8,19,19),
		cf=CFrame.new(cx,Y+11,cz-3)*faceAngles,
		col=Color3.fromRGB(200,60,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	local lock = CYL({name="M",par=f,sz=Vector3.new(2,6,6),
		cf=CFrame.new(cx,Y+11,cz-5)*faceAngles,
		col=Color3.fromRGB(200,180,30),mat=PM})
	spinWorldY(lock, cx, Y+11, cz-5, 0.6, faceAngles)
	P({name="M",par=f,sz=Vector3.new(0.5,0.5,4),
		pos=Vector3.new(cx,Y+11,cz-5.5),col=Color3.fromRGB(40,40,50),mat=PM,cc=false,shadow=false})
	P({name="M",par=f,sz=Vector3.new(4,0.5,0.5),
		pos=Vector3.new(cx,Y+8.5,cz-4.5),col=Color3.fromRGB(200,180,30),mat=PM,cc=false,shadow=false})
	for i=0,2 do
		for j=0,1 do
			P({name="M",par=f,sz=Vector3.new(3.5,1.2,5.5),
				pos=Vector3.new(cx+5.5+j*0.2, Y+0.8+i*1.3, cz+(j-0.5)*2),
				col=Color3.fromRGB(255,200,20),mat=PM,cc=false,shadow=false})
		end
	end
	for i=0,3 do
		local a = math.rad(i*90 + 45)
		local orb = P({name="M",par=f,sz=Vector3.new(1.2,1.2,1.2),
			pos=Vector3.new(cx+math.cos(a)*9, Y+11, cz+math.sin(a)*9),
			col=Color3.fromRGB(200,60,255),mat=Enum.Material.Neon,cc=false,shadow=false})
		bob(orb, cx+math.cos(a)*9, Y+11, cz+math.sin(a)*9, 2.5, 0.06+i*0.015)
	end
	addLight(door, 5, 42, Color3.fromRGB(220,80,255))
	makeBillboard(door,"🏛️ COIN VAULT",Color3.fromRGB(220,80,255),16,220,46,100)
end

-- ── NEW UNIQUE MACHINE BUILDERS ──────────────────────────────

-- L_N: 🧲 Coin Magnet
local function buildMagnet(cx, cz, f)
	local Y = DECK_TOP
	local base = P({name="M",par=f,sz=Vector3.new(13,2,7),pos=Vector3.new(cx,Y+1.2,cz),col=Color3.fromRGB(38,38,50),mat=PM})
	P({name="M",par=f,sz=Vector3.new(4,11,5),pos=Vector3.new(cx-4,Y+7.5,cz),col=Color3.fromRGB(190,36,36),mat=PM})
	P({name="M",par=f,sz=Vector3.new(14,4,5),pos=Vector3.new(cx,Y+13.8,cz),col=Color3.fromRGB(30,30,42),mat=PM})
	P({name="M",par=f,sz=Vector3.new(4,11,5),pos=Vector3.new(cx+4,Y+7.5,cz),col=Color3.fromRGB(38,38,200),mat=PM})
	P({name="M",par=f,sz=Vector3.new(4,2.5,5.5),pos=Vector3.new(cx-4,Y+12.3,cz),col=Color3.fromRGB(255,60,60),mat=Enum.Material.Neon,cc=false,shadow=false})
	P({name="M",par=f,sz=Vector3.new(4,2.5,5.5),pos=Vector3.new(cx+4,Y+12.3,cz),col=Color3.fromRGB(60,80,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	local orbCoin = CYL({name="M",par=f,sz=Vector3.new(0.5,3.5,3.5),cf=CFrame.new(cx+10,Y+7,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,215,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	spinWorldY(orbCoin, cx, Y+7, cz, 3.5)
	addLight(base, 3.5, 28, Color3.fromRGB(255,120,120))
	makeBillboard(base,"🧲 COIN MAGNET",Color3.fromRGB(255,120,120),20,220,46,85)
end

-- R_N: ⚗️ Alchemy Cauldron
local function buildAlchemyCauldron(cx, cz, f)
	local Y = DECK_TOP
	for _, ox in ipairs({-4.5,0,4.5}) do
		P({name="M",par=f,sz=Vector3.new(1.2,5,1.2),pos=Vector3.new(cx+ox,Y+2.5,cz),col=Color3.fromRGB(65,40,15),mat=PM})
	end
	local body = CYL({name="M",par=f,sz=Vector3.new(7,13,13),cf=CFrame.new(cx,Y+7.5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(40,32,22),mat=PM})
	CYL({name="M",par=f,sz=Vector3.new(7.2,14.5,14.5),cf=CFrame.new(cx,Y+7.5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(90,62,24),mat=PM,cc=false,shadow=false,tr=0.6})
	CYL({name="M",par=f,sz=Vector3.new(1.5,11,11),cf=CFrame.new(cx,Y+11.5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(0,200,80),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.3})
	for i=0,2 do
		local a = math.rad(i*120)
		local orb = P({name="M",par=f,sz=Vector3.new(1.8,1.8,1.8),pos=Vector3.new(cx+math.cos(a)*7,Y+13,cz+math.sin(a)*7),col=Color3.fromRGB(160,0,255),mat=Enum.Material.Neon,cc=false,shadow=false})
		bob(orb,cx+math.cos(a)*7,Y+13,cz+math.sin(a)*7,1.8,0.07+i*0.03)
	end
	addLight(body,4,32,Color3.fromRGB(0,220,100))
	makeBillboard(body,"⚗️ ALCHEMY CAULDRON",Color3.fromRGB(60,255,140),10,240,46,85)
end

-- L_S: 🎰 Slot Machine
local function buildSlotMachine(cx, cz, f)
	local Y = DECK_TOP
	local cab = P({name="M",par=f,sz=Vector3.new(14,16,9),pos=Vector3.new(cx,Y+8.2,cz),col=Color3.fromRGB(160,20,20),mat=PM})
	P({name="M",par=f,sz=Vector3.new(13.5,0.8,9.5),pos=Vector3.new(cx,Y+16.7,cz),col=Color3.fromRGB(200,30,30),mat=PM,cc=false})
	P({name="M",par=f,sz=Vector3.new(10,7,1),pos=Vector3.new(cx,Y+9,cz-4.6),col=Color3.fromRGB(255,255,200),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.15})
	for i=0,2 do
		local drum = CYL({name="M",par=f,sz=Vector3.new(5.5,2.5,2.5),cf=CFrame.new(cx-3+i*3,Y+9,cz-5)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,215,0),mat=Enum.Material.Neon,cc=false,shadow=false})
		spinX(drum, 8+i*2)
	end
	P({name="M",par=f,sz=Vector3.new(10,2,8),pos=Vector3.new(cx,Y+1,cz),col=Color3.fromRGB(120,15,15),mat=PM})
	local arm = P({name="M",par=f,sz=Vector3.new(1,9,1),pos=Vector3.new(cx+8,Y+12,cz),col=Color3.fromRGB(200,200,200),mat=PM,cc=false})
	P({name="M",par=f,sz=Vector3.new(2.5,2.5,2.5),pos=Vector3.new(cx+8,Y+17,cz),col=Color3.fromRGB(255,80,80),mat=Enum.Material.Neon,cc=false,shadow=false})
	for _, col in ipairs({Color3.fromRGB(255,50,50),Color3.fromRGB(50,255,50),Color3.fromRGB(255,255,50)}) do
		bob(arm,cx+8,Y+12,cz,0.8,0.15)
	end
	addLight(cab,3.5,26,Color3.fromRGB(255,180,0))
	makeBillboard(cab,"🎰 SLOT MACHINE",Color3.fromRGB(255,200,50),14,220,46,85)
end

-- RR_M: ⚡ Tesla Coil
local function buildTeslaCoil(cx, cz, f)
	local Y = DECK_TOP
	local base = P({name="M",par=f,sz=Vector3.new(10,4,10),pos=Vector3.new(cx,Y+2.2,cz),col=Color3.fromRGB(30,30,42),mat=PM})
	CYL({name="M",par=f,sz=Vector3.new(16,4.5,4.5),cf=CFrame.new(cx,Y+12,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(50,50,60),mat=PM,cc=false})
	for i=0,5 do
		CYL({name="M",par=f,sz=Vector3.new(0.8,3.8-i*0.3,3.8-i*0.3),cf=CFrame.new(cx,Y+6+i*2.4,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(200,220,255),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.2})
	end
	local top = P({name="M",par=f,sz=Vector3.new(2,2,2),pos=Vector3.new(cx,Y+20,cz),col=Color3.fromRGB(180,220,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	for i=0,3 do
		local a=math.rad(i*90); local r=6
		local arc=P({name="M",par=f,sz=Vector3.new(0.3,6,0.3),
			cf=CFrame.new(cx+math.cos(a)*r,Y+17,cz+math.sin(a)*r)*CFrame.Angles(0,0,math.rad(30+i*5)),
			col=Color3.fromRGB(150,200,255),mat=Enum.Material.Neon,cc=false,shadow=false})
		bob(arc,cx+math.cos(a)*r,Y+17,cz+math.sin(a)*r,1.5,0.12+i*0.04)
	end
	addLight(top,6,40,Color3.fromRGB(150,200,255))
	makeBillboard(base,"⚡ TESLA COIL",Color3.fromRGB(180,220,255),24,220,46,85)
end

-- C_NN: 🔭 Observatory
local function buildObservatory(cx, cz, f)
	local Y = DECK_TOP
	local plat = P({name="M",par=f,sz=Vector3.new(18,3,18),pos=Vector3.new(cx,Y+1.7,cz),col=Color3.fromRGB(45,42,55),mat=PM})
	for _, off in ipairs({{-6,0},{6,0},{0,-6},{0,6}}) do
		P({name="M",par=f,sz=Vector3.new(2,6,2),pos=Vector3.new(cx+off[1],Y+6,cz+off[2]),col=Color3.fromRGB(50,45,62),mat=PM,cc=false})
	end
	CYL({name="M",par=f,sz=Vector3.new(8,14,14),cf=CFrame.new(cx,Y+7.5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(55,50,68),mat=PM,cc=false})
	CYL({name="M",par=f,sz=Vector3.new(8.2,15.5,15.5),cf=CFrame.new(cx,Y+7.5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(80,72,98),mat=PM,cc=false,tr=0.6})
	P({name="M",par=f,sz=Vector3.new(1.5,2,12),pos=Vector3.new(cx,Y+12,cz),col=Color3.fromRGB(40,35,52),mat=PM,cc=false})
	local scope = P({name="M",par=f,sz=Vector3.new(1.2,10,1.2),cf=CFrame.new(cx,Y+13,cz+2)*CFrame.Angles(math.rad(20),0,0),col=Color3.fromRGB(70,65,85),mat=PM,cc=false})
	CYL({name="M",par=f,sz=Vector3.new(1,2.2,2.2),cf=CFrame.new(cx,Y+17,cz-1)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(120,180,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	spinWorldY(scope, cx, Y+13, cz+2, 0.4, CFrame.Angles(math.rad(20),0,0))
	addLight(plat,3,30,Color3.fromRGB(120,160,255))
	makeBillboard(plat,"🔭 OBSERVATORY",Color3.fromRGB(140,180,255),22,220,46,85)
end

-- C_SS: 🧪 Chemical Reactor
local function buildReactor(cx, cz, f)
	local Y = DECK_TOP
	local tank = CYL({name="M",par=f,sz=Vector3.new(14,8,8),cf=CFrame.new(cx,Y+9,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(38,36,50),mat=PM})
	CYL({name="M",par=f,sz=Vector3.new(3,9,9),cf=CFrame.new(cx-5.5,Y+9,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(48,44,60),mat=PM,cc=false})
	CYL({name="M",par=f,sz=Vector3.new(3,9,9),cf=CFrame.new(cx+5.5,Y+9,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(48,44,60),mat=PM,cc=false})
	CYL({name="M",par=f,sz=Vector3.new(14.5,1.2,1.2),cf=CFrame.new(cx,Y+13,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(200,80,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	CYL({name="M",par=f,sz=Vector3.new(14.5,1.2,1.2),cf=CFrame.new(cx,Y+5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(0,160,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	for _, ox in ipairs({-4,0,4}) do
		CYL({name="M",par=f,sz=Vector3.new(6,1.5,1.5),cf=CFrame.new(cx+ox,Y+11.5,cz+5)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(60,58,72),mat=PM,cc=false})
	end
	P({name="M",par=f,sz=Vector3.new(8,0.5,4),pos=Vector3.new(cx,Y+16.5,cz),col=Color3.fromRGB(46,44,58),mat=PM,cc=false,shadow=false})
	local glow = CYL({name="M",par=f,sz=Vector3.new(1,7.8,7.8),cf=CFrame.new(cx,Y+9,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(0,220,255),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.4})
	addLight(tank,4,34,Color3.fromRGB(0,200,255))
	makeBillboard(tank,"🧪 CHEMICAL REACTOR",Color3.fromRGB(60,240,255),12,240,46,90)
end

-- LL_S: 🚀 Rocket Silo
local function buildRocketSilo(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(16,2,16),pos=Vector3.new(cx,Y+1.1,cz),col=Color3.fromRGB(35,33,45),mat=PM})
	CYL({name="M",par=f,sz=Vector3.new(19,5,5),cf=CFrame.new(cx,Y+11.5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(225,220,230),mat=PM,cc=false})
	CYL({name="M",par=f,sz=Vector3.new(4,4.8,4.8),cf=CFrame.new(cx,Y+21.5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,60,30),mat=Enum.Material.Neon,cc=false,shadow=false})
	CYL({name="M",par=f,sz=Vector3.new(2,3.5,3.5),cf=CFrame.new(cx,Y+24.5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(220,218,225),mat=PM,cc=false})
	for i=0,3 do
		local a=math.rad(i*90)
		P({name="M",par=f,sz=Vector3.new(0.8,20,0.8),pos=Vector3.new(cx+math.cos(a)*7,Y+11,cz+math.sin(a)*7),col=Color3.fromRGB(55,52,65),mat=PM,cc=false,shadow=false})
		P({name="M",par=f,sz=Vector3.new(6,0.8,0.8),cf=CFrame.new(cx+math.cos(a)*4,Y+15,cz+math.sin(a)*4)*CFrame.Angles(0,a,0),col=Color3.fromRGB(55,52,65),mat=PM,cc=false,shadow=false})
	end
	local exhaust=CYL({name="M",par=f,sz=Vector3.new(3,5.5,5.5),cf=CFrame.new(cx,Y+4,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,140,0),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.3})
	bob(exhaust,cx,Y+4,cz,1.2,0.1,CFrame.Angles(0,0,math.rad(90)))
	local body=P({name="M",par=f,sz=Vector3.new(1,1,1),pos=Vector3.new(cx,Y+14,cz),col=Color3.fromRGB(0,0,0),tr=1,cc=false,par=f})
	addLight(body,5,38,Color3.fromRGB(255,120,0))
	makeBillboard(exhaust,"🚀 ROCKET SILO",Color3.fromRGB(255,180,80),30,220,46,90)
end

-- RR_N: 💎 Crystal Forge
local function buildCrystalForge(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(14,3,14),pos=Vector3.new(cx,Y+1.7,cz),col=Color3.fromRGB(30,25,40),mat=PM})
	local heights = {14,11,9,13,10,12,8}
	local offsets = {{0,0},{5,2},{-5,3},{4,-4},{-3,-5},{6,-2},{-4,4}}
	for i,o in ipairs(offsets) do
		P({name="M",par=f,sz=Vector3.new(2.5,heights[i],2.5),
			cf=CFrame.new(cx+o[1],Y+heights[i]/2+2,cz+o[2])*CFrame.Angles(0,math.rad(i*37),math.rad(8)),
			col=Color3.fromRGB(100,50+i*20,200+i*5),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.1})
	end
	local core=P({name="M",par=f,sz=Vector3.new(3,3,3),pos=Vector3.new(cx,Y+6,cz),col=Color3.fromRGB(255,255,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	P({name="M",par=f,sz=Vector3.new(8,3,6),pos=Vector3.new(cx,Y+2.5,cz-3),col=Color3.fromRGB(60,50,35),mat=PM})
	P({name="M",par=f,sz=Vector3.new(5,2,5),pos=Vector3.new(cx,Y+3.8,cz-3),col=Color3.fromRGB(255,160,60),mat=Enum.Material.Neon,cc=false,shadow=false})
	addLight(core,6,42,Color3.fromRGB(180,120,255))
	makeBillboard(core,"💎 CRYSTAL FORGE",Color3.fromRGB(200,150,255),12,220,46,90)
end

-- RR_S: 🕰️ Clockwork Engine
local function buildClockEngine(cx, cz, f)
	local Y = DECK_TOP
	local face=P({name="M",par=f,sz=Vector3.new(0.8,14,14),pos=Vector3.new(cx,Y+8,cz),col=Color3.fromRGB(28,22,18),mat=PM})
	P({name="M",par=f,sz=Vector3.new(0.9,15.5,15.5),pos=Vector3.new(cx,Y+8,cz),col=Color3.fromRGB(90,65,28),mat=PM,cc=false,shadow=false,tr=0.8})
	CYL({name="M",par=f,sz=Vector3.new(1,14,14),cf=CFrame.new(cx,Y+8,cz),col=Color3.fromRGB(200,160,60),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.85})
	for i=0,11 do
		local a=math.rad(i*30); local r=6
		P({name="M",par=f,sz=Vector3.new(1.2,0.5,0.5),
			pos=Vector3.new(cx,Y+8+math.cos(a)*r,cz+math.sin(a)*r),
			col=Color3.fromRGB(220,180,80),mat=Enum.Material.Neon,cc=false,shadow=false})
	end
	local bigGear=CYL({name="M",par=f,sz=Vector3.new(1.5,11,11),cf=CFrame.new(cx+2.5,Y+7,cz+4),col=Color3.fromRGB(80,60,30),mat=PM,cc=false})
	spinX(bigGear,4)
	local smallGear=CYL({name="M",par=f,sz=Vector3.new(1.5,5,5),cf=CFrame.new(cx+3,Y+3,cz-4),col=Color3.fromRGB(70,52,25),mat=PM,cc=false})
	spinX(smallGear,-8)
	P({name="M",par=f,sz=Vector3.new(10,3,8),pos=Vector3.new(cx,Y+1.7,cz),col=Color3.fromRGB(45,35,20),mat=PM})
	addLight(face,3.5,30,Color3.fromRGB(220,180,80))
	makeBillboard(face,"🕰️ CLOCKWORK ENGINE",Color3.fromRGB(220,180,80),11,240,46,90)
end

-- L_NN: 🌊 Wave Condenser
local function buildWaveCondenser(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(18,2,10),pos=Vector3.new(cx,Y+1.2,cz),col=Color3.fromRGB(25,35,55),mat=PM})
	local pts = {{-7,0},{-5,4},{-2,7},{1,9},{4,7},{7,4},{9,0}}
	for i=1,#pts-1 do
		local ax,ay=pts[i][1],pts[i][2]; local bx,by=pts[i+1][1],pts[i+1][2]
		local mx,my=(ax+bx)/2,(ay+by)/2
		local dx,dy=bx-ax,by-ay; local len=math.sqrt(dx*dx+dy*dy)
		local angle=math.atan2(dy,dx)
		P({name="M",par=f,sz=Vector3.new(len+0.5,2.5,6),
			cf=CFrame.new(cx+mx,Y+3+my,cz)*CFrame.Angles(0,0,-angle),
			col=Color3.fromRGB(0,160,220),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.15})
		P({name="M",par=f,sz=Vector3.new(len+1,2,5),
			cf=CFrame.new(cx+mx,Y+3+my,cz)*CFrame.Angles(0,0,-angle),
			col=Color3.fromRGB(20,80,140),mat=PM,cc=false,shadow=false})
	end
	P({name="M",par=f,sz=Vector3.new(5,4,6),pos=Vector3.new(cx-9,Y+3,cz),col=Color3.fromRGB(30,55,80),mat=PM,cc=false})
	local anchor=P({name="M",par=f,sz=Vector3.new(1,1,1),pos=Vector3.new(cx,Y+10,cz),tr=1,cc=false})
	addLight(anchor,4,36,Color3.fromRGB(0,180,255))
	makeBillboard(anchor,"🌊 WAVE CONDENSER",Color3.fromRGB(60,200,255),5,240,46,90)
end

-- R_NN: 🧬 DNA Tower
local function buildDNATower(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(10,2,10),pos=Vector3.new(cx,Y+1.1,cz),col=Color3.fromRGB(22,22,30),mat=PM})
	local N=18; local radius=4; local height=22
	for i=0,N-1 do
		local t=i/N; local a1=t*6*math.pi; local a2=a1+math.pi
		local y=Y+3+t*height
		local x1,z1=cx+math.cos(a1)*radius,cz+math.sin(a1)*radius
		local x2,z2=cx+math.cos(a2)*radius,cz+math.sin(a2)*radius
		CYL({name="M",par=f,sz=Vector3.new(0.5,0.9,0.9),cf=CFrame.new(x1,y,z1)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,60,80),mat=Enum.Material.Neon,cc=false,shadow=false})
		CYL({name="M",par=f,sz=Vector3.new(0.5,0.9,0.9),cf=CFrame.new(x2,y,z2)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(60,120,255),mat=Enum.Material.Neon,cc=false,shadow=false})
		if i%3==0 then
			local mx,my,mz=(x1+x2)/2,y,(z1+z2)/2
			local dx,dz=x2-x1,z2-z1; local len=math.sqrt(dx*dx+dz*dz)
			P({name="M",par=f,sz=Vector3.new(0.4,len,0.4),
				cf=CFrame.new(mx,my,mz)*CFrame.Angles(0,math.atan2(dz,dx),math.rad(90)),
				col=Color3.fromRGB(200,200,60),mat=Enum.Material.Neon,cc=false,shadow=false})
		end
	end
	local top=P({name="M",par=f,sz=Vector3.new(3,3,3),pos=Vector3.new(cx,Y+27,cz),col=Color3.fromRGB(255,80,100),mat=Enum.Material.Neon,cc=false,shadow=false})
	addLight(top,5,42,Color3.fromRGB(255,80,100))
	makeBillboard(top,"🧬 DNA TOWER",Color3.fromRGB(255,100,120),8,210,46,90)
end

-- L_SS: 💣 Coin Cannon Array
local function buildCoinCannon(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(18,4,10),pos=Vector3.new(cx,Y+2.2,cz),col=Color3.fromRGB(35,30,20),mat=PM})
	for _, ox in ipairs({-5,0,5}) do
		P({name="M",par=f,sz=Vector3.new(4,4,4),pos=Vector3.new(cx+ox,Y+5.5,cz),col=Color3.fromRGB(50,40,25),mat=PM,cc=false})
		local barrel=CYL({name="M",par=f,sz=Vector3.new(10,2.5,2.5),cf=CFrame.new(cx+ox,Y+5.5,cz-5)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(40,35,22),mat=PM,cc=false})
		CYL({name="M",par=f,sz=Vector3.new(10.2,2.7,2.7),cf=CFrame.new(cx+ox,Y+5.5,cz-5)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,190,0),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.7})
		bob(barrel,cx+ox,Y+5.5,cz-5,0.5,0.18,CFrame.Angles(0,0,math.rad(90)))
	end
	P({name="M",par=f,sz=Vector3.new(5,6,4),pos=Vector3.new(cx+7.5,Y+5,cz+1),col=Color3.fromRGB(45,38,22),mat=PM,cc=false})
	for i=0,2 do P({name="M",par=f,sz=Vector3.new(4.5,1.5,3.5),pos=Vector3.new(cx+7.5,Y+2+i*1.8,cz+1),col=Color3.fromRGB(200,150,20),mat=PM,cc=false,shadow=false}) end
	local anchor=P({name="M",par=f,sz=Vector3.new(1,1,1),pos=Vector3.new(cx,Y+8,cz),tr=1,cc=false})
	addLight(anchor,3.5,30,Color3.fromRGB(255,200,0))
	makeBillboard(anchor,"💣 COIN CANNONS",Color3.fromRGB(255,210,80),10,220,46,90)
end

-- R_SS: ⛏️ Mining Rig
local function buildMiningRig(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(18,2,18),pos=Vector3.new(cx,Y+1.1,cz),col=Color3.fromRGB(40,35,25),mat=PM})
	for _, pos in ipairs({{-7,-7},{-7,7},{7,-7},{7,7}}) do
		P({name="M",par=f,sz=Vector3.new(1.5,16,1.5),pos=Vector3.new(cx+pos[1],Y+9,cz+pos[2]),col=Color3.fromRGB(60,50,32),mat=PM,cc=false,shadow=false})
	end
	for h in ({4,8,12}) do
		P({name="M",par=f,sz=Vector3.new(16,0.8,16),pos=Vector3.new(cx,Y+h,cz),col=Color3.fromRGB(50,42,28),mat=PM,cc=false,shadow=false})
	end
	local drillHead=CYL({name="M",par=f,sz=Vector3.new(8,4.5,4.5),cf=CFrame.new(cx,Y+5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(80,65,35),mat=PM})
	spinX(drillHead,12)
	CYL({name="M",par=f,sz=Vector3.new(8.5,1.2,1.2),cf=CFrame.new(cx,Y+5,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,150,0),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.2})
	P({name="M",par=f,sz=Vector3.new(7,2.5,4),pos=Vector3.new(cx+6,Y+2,cz),col=Color3.fromRGB(55,40,20),mat=PM,cc=false})
	for i=0,2 do P({name="M",par=f,sz=Vector3.new(6.5,1.2,3.5),pos=Vector3.new(cx+6,Y+1.2+i*1.4,cz),col=Color3.fromRGB(200,180,20),mat=PM,cc=false,shadow=false}) end
	local beacon=P({name="M",par=f,sz=Vector3.new(2,2,2),pos=Vector3.new(cx,Y+17,cz),col=Color3.fromRGB(255,120,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	addLight(beacon,4,36,Color3.fromRGB(255,140,0))
	makeBillboard(beacon,"⛏️ MINING RIG",Color3.fromRGB(255,160,60),6,210,46,90)
end

-- RR_NN: 🌋 Lava Core
local function buildLavaCore(cx, cz, f)
	local Y = DECK_TOP
	local sizes={{18,3,18},{14,4,14},{11,5,11},{8,5,8},{6,5,6},{4,4,4}}
	for i,s in ipairs(sizes) do
		P({name="M",par=f,sz=Vector3.new(s[1],s[2],s[3]),
			pos=Vector3.new(cx,Y+s[2]/2+(i-1)*3.5,cz),
			col=Color3.fromRGB(35+i*5,20,15),mat=Enum.Material.SmoothPlastic})
	end
	CYL({name="M",par=f,sz=Vector3.new(8,5.5,5.5),cf=CFrame.new(cx,Y+24,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,80,0),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.15})
	local core=CYL({name="M",par=f,sz=Vector3.new(6,4,4),cf=CFrame.new(cx,Y+24,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(255,200,0),mat=Enum.Material.Neon,cc=false,shadow=false})
	bob(core,cx,Y+24,cz,1.5,0.06,CFrame.Angles(0,0,math.rad(90)))
	for i=0,5 do
		local a=math.rad(i*60); local r=8+i%2*2; local h=4+i*3
		P({name="M",par=f,sz=Vector3.new(1.5,4,1.5),
			cf=CFrame.new(cx+math.cos(a)*r,Y+h,cz+math.sin(a)*r)*CFrame.Angles(0,0,math.rad(15+i*5)),
			col=Color3.fromRGB(200+i*8,60,0),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.25})
	end
	addLight(core,8,52,Color3.fromRGB(255,160,0))
	makeBillboard(core,"🌋 LAVA CORE",Color3.fromRGB(255,140,40),10,210,46,100)
end

-- LL_SS: 🔮 Arcane Spire
local function buildArcaneSpire(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(14,3,14),pos=Vector3.new(cx,Y+1.7,cz),col=Color3.fromRGB(25,18,38),mat=PM})
	local widths={12,10,8,6,5,4,3,2}
	for i,w in ipairs(widths) do
		P({name="M",par=f,sz=Vector3.new(w,3.5,w),pos=Vector3.new(cx,Y+3+i*3.2,cz),
			cf=CFrame.new(cx,Y+3+i*3.2,cz)*CFrame.Angles(0,math.rad(i*22.5),0),
			col=Color3.fromRGB(50+i*8,20+i*5,80+i*12),mat=PM,cc=false})
	end
	P({name="M",par=f,sz=Vector3.new(1.5,6,1.5),pos=Vector3.new(cx,Y+29,cz),col=Color3.fromRGB(180,50,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	local tip=P({name="M",par=f,sz=Vector3.new(2,2,2),pos=Vector3.new(cx,Y+32,cz),col=Color3.fromRGB(255,255,255),mat=Enum.Material.Neon,cc=false,shadow=false})
	for i=0,4 do
		local a=math.rad(i*72)
		local crystal=P({name="M",par=f,sz=Vector3.new(1.2,5,1.2),
			cf=CFrame.new(cx+math.cos(a)*8,Y+18,cz+math.sin(a)*8)*CFrame.Angles(0,0,math.rad(20)),
			col=Color3.fromRGB(160+i*12,40,200+i*8),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.1})
		bob(crystal,cx+math.cos(a)*8,Y+18,cz+math.sin(a)*8,3,0.06+i*0.025,CFrame.Angles(0,0,math.rad(20)))
	end
	addLight(tip,7,52,Color3.fromRGB(200,80,255))
	makeBillboard(tip,"🔮 ARCANE SPIRE",Color3.fromRGB(210,100,255),8,220,46,100)
end

-- RR_SS: 🛸 UFO Harvester
local function buildUFO(cx, cz, f)
	local Y = DECK_TOP
	P({name="M",par=f,sz=Vector3.new(14,1.5,14),pos=Vector3.new(cx,Y+0.9,cz),col=Color3.fromRGB(22,22,28),mat=PM})
	local disc=CYL({name="M",par=f,sz=Vector3.new(4,19,19),cf=CFrame.new(cx,Y+14,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(55,52,68),mat=PM})
	CYL({name="M",par=f,sz=Vector3.new(4.2,21,21),cf=CFrame.new(cx,Y+14,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(0,220,80),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.6})
	CYL({name="M",par=f,sz=Vector3.new(5,8,8),cf=CFrame.new(cx,Y+17,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(60,58,78),mat=PM,cc=false})
	CYL({name="M",par=f,sz=Vector3.new(5.2,9.5,9.5),cf=CFrame.new(cx,Y+17,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(160,220,255),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.7})
	for i=0,7 do
		local a=math.rad(i*45)
		P({name="M",par=f,sz=Vector3.new(1,1,1),pos=Vector3.new(cx+math.cos(a)*10,Y+13,cz+math.sin(a)*10),col=Color3.fromRGB(0,220,80),mat=Enum.Material.Neon,cc=false,shadow=false})
	end
	CYL({name="M",par=f,sz=Vector3.new(14,5,5),cf=CFrame.new(cx,Y+7,cz)*CFrame.Angles(0,0,math.rad(90)),col=Color3.fromRGB(0,220,80),mat=Enum.Material.Neon,cc=false,shadow=false,tr=0.75})
	spinWorldY(disc,cx,Y+14,cz,0.8,CFrame.Angles(0,0,math.rad(90)))
	addLight(disc,6,48,Color3.fromRGB(0,220,80))
	makeBillboard(disc,"🛸 UFO HARVESTER",Color3.fromRGB(80,255,160),12,220,46,100)
end

-- ── PER-PLOT MACHINE ASSIGNMENT (each plot gets a unique machine) ──
local PLOT_MACHINE = {
	-- Ring 1 (2000)
	L_N  = buildMagnet,
	R_N  = buildAlchemyCauldron,
	L_S  = buildSlotMachine,
	R_S  = buildPrinter,
	-- Ring 2 (10000)
	LL_M = buildRoomba,
	RR_M = buildTeslaCoil,
	C_NN = buildObservatory,
	C_SS = buildReactor,
	-- Ring 3 (25000)
	LL_N = buildFactory,
	LL_S = buildRocketSilo,
	RR_N = buildCrystalForge,
	RR_S = buildClockEngine,
	L_NN = buildWaveCondenser,
	R_NN = buildDNATower,
	L_SS = buildCoinCannon,
	R_SS = buildMiningRig,
	-- Ring 4 (50000)
	LL_NN = buildVault,
	RR_NN = buildLavaCore,
	LL_SS = buildArcaneSpire,
	RR_SS = buildUFO,
}

local function doUnlock(plotId, ownerPlayer)
	local state = plotState[plotId]
	if not state or state.unlocked then return end
	state.unlocked      = true
	state.ownerUserId   = ownerPlayer and ownerPlayer.UserId or nil
	state.raidFlashing  = false
	for _, p in ipairs(state.folder:GetChildren()) do p:Destroy() end
	local def   = state.def

	-- Tier-colored floor overlay — store ref so raid can flash it
	local floorCol = getFloorCol(def.cost)
	local floor = P({name="PlotFloor", par=state.folder,
		sz=Vector3.new(PLOT_W-1, 0.08, PLOT_D-1),
		pos=Vector3.new(def.cx, DECK_TOP+0.12, def.cz),
		col=floorCol, mat=PM, cc=false, tr=0.1})
	state.floorPart     = floor
	state.floorOrigCol  = floorCol

	-- Spawn this plot's unique machine
	local builder = PLOT_MACHINE[def.id]
	if builder then
		builder(def.cx, def.cz, state.folder)
	end

	-- Owner nameplate — anchor height matches ticker so it sits just above the machine
	if ownerPlayer then
		local a = Instance.new("Part", state.folder)
		a.Anchored = true; a.CanCollide = false
		a.Size = Vector3.new(1,1,1)
		a.CFrame = CFrame.new(def.cx, tickerHeight + 4, def.cz)
		a.Transparency = 1
		makeBillboard(a, "⚡ "..ownerPlayer.Name, Color3.fromRGB(255,200,0), 4, 220, 50, 80)
	end

	-- ── INCOME TICKER VISUAL ──────────────────────────────────────
	-- A floating coin that orbits above the machine to show it's earning money.
	-- Clients see the rate via MachineRate_RE; this just shows activity.
	local tickerHeight = DECK_TOP + (def.cost >= 200000 and 36 or def.cost >= 75000 and 30 or def.cost >= 25000 and 24 or 20)
	local tickerCoin = CYL({par=state.folder, name="IncomeCoin",
		sz=Vector3.new(0.4, 2.8, 2.8),
		cf=CFrame.new(def.cx + 8, tickerHeight, def.cz) * CFrame.Angles(0, 0, math.rad(90)),
		col=Color3.fromRGB(255,215,0), mat=Enum.Material.Neon, cc=false, shadow=false})
	addLight(tickerCoin, 1.2, 12, Color3.fromRGB(255,200,0))
	spinWorldY(tickerCoin, def.cx, tickerHeight, def.cz, 2.0)

	state.rateBB     = nil
	state.rateAnchor = nil

	print("[MoneyIsland] Plot", plotId, "→", ownerPlayer and ownerPlayer.Name or "anonymous")
end

local function doLock(plotId)
	local state = plotState[plotId]
	if not state or not state.unlocked then return end
	state.unlocked      = false
	state.ownerUserId   = nil
	state.floorPart     = nil
	state.floorOrigCol  = nil
	state.raidFlashing  = false
	state.rateBB        = nil
	state.rateAnchor    = nil
	for _, p in ipairs(state.folder:GetChildren()) do p:Destroy() end
	buildLockedPlot(state)
	print("[MoneyIsland] Plot", plotId, "re-locked")
end

-- ── GEYSER SYSTEM ─────────────────────────────────────────────
local GEYSER_ACTIVE   = 8   -- seconds active per cycle
local GEYSER_INACTIVE = 14  -- seconds inactive after burst (22s full cycle per geyser)
local GEYSER_STAGGER  = 4   -- seconds delay between each geyser starting
local GEYSER_CAP      = 4   -- coins per player per geyser per burst (enforced server-side)
local contestedList   = {}  -- filled during plot init

local function buildGeyserPad(cx, cz, folder)
	-- Dark base platform
	P({name="GeyserPad", par=folder,
		sz=Vector3.new(PLOT_W-2, 0.25, PLOT_D-2),
		pos=Vector3.new(cx, DECK_TOP+0.15, cz),
		col=Color3.fromRGB(25,25,25), mat=Enum.Material.SmoothPlastic, cc=false, tr=0.15})

	-- Glow ring (Neon cylinder, color changes on activate)
	local ring = CYL({par=folder, name="GeyserRing",
		sz=Vector3.new(1.2, 24, 24),
		cf=CFrame.new(cx, DECK_TOP+0.2, cz) * CFrame.Angles(0,0,math.rad(90)),
		col=Color3.fromRGB(50,50,50), mat=Enum.Material.Neon, cc=false, tr=0.65})
	local light = addLight(ring, 0.8, 18, Color3.fromRGB(100,80,0))

	-- Small center pillar
	P({name="GeyserPillar", par=folder,
		sz=Vector3.new(4,3,4),
		pos=Vector3.new(cx, DECK_TOP+1.5, cz),
		col=Color3.fromRGB(60,40,15), mat=PM})

	-- "CONTESTED" label
	local a = Instance.new("Part", folder)
	a.Anchored = true; a.CanCollide = false
	a.Size = Vector3.new(1,1,1)
	a.CFrame = CFrame.new(cx, DECK_TOP+8, cz)
	a.Transparency = 1
	makeBillboard(a, "⚔️ CONTESTED\nGrab coins to earn!", Color3.fromRGB(255,80,80), 4, 260, 70, 65)

	return ring, light
end

local function spawnGeyserBurst(cx, cz, geyserIdx, isMega)
	-- Scale burst size with player count so income stays fair at all server sizes
	local playerCount = #Players:GetPlayers()
	local baseCount   = isMega and 15 or (5 + math.random(0,1))
	local scaledBonus = math.floor(math.max(0, playerCount - 1) / 2) * 2
	local count       = baseCount + scaledBonus
	local halfW  = PLOT_W/2 - 5
	local halfD  = PLOT_D/2 - 5
	for _ = 1, count do
		local angle  = math.random() * 2 * math.pi
		local radius = math.random(4, 19)
		local sx = cx + math.cos(angle) * math.min(radius, halfW)
		local sz = cz + math.sin(angle) * math.min(radius, halfD)

		local isRare   = math.random() < 0.05
		local coinCol  = isRare and Color3.fromRGB(0,220,220) or Color3.fromRGB(255,200,0)
		local coinGlow = isRare and Color3.fromRGB(0,200,255) or Color3.fromRGB(255,210,50)

		local coin = CYL({par=coinsF, name="GeyserCoin",
			sz=Vector3.new(0.5,3.2,3.2),
			cf=CFrame.new(sx, DECK_TOP+2, sz) * CFrame.Angles(0, math.rad(math.random(0,360)), math.rad(90)),
			col=coinCol, mat=Enum.Material.Neon, cc=false})
		coin:SetAttribute("IsCoin",    true)
		coin:SetAttribute("GeyserCoin",true)
		coin:SetAttribute("GeyserIdx", geyserIdx)
		if isRare then coin:SetAttribute("RareCoin", true) end
		addLight(coin, isRare and 1.5 or 0.5, isRare and 10 or 6, coinGlow)

		-- Per-coin per-player debounce — prevents hammering from same player
		local debounce = {}
		coin.Touched:Connect(function(hit)
			if not coin.Parent then return end
			local char = hit.Parent
			local player = Players:GetPlayerFromCharacter(char)
			if not player then
				char = hit.Parent.Parent
				player = Players:GetPlayerFromCharacter(char)
			end
			if not player then return end
			local uid = player.UserId
			if debounce[uid] then return end
			debounce[uid] = true
			task.delay(0.8, function() debounce[uid] = nil end)
			-- Server decides: credit + destroy, or ignore (player hit cap)
			coinBE:Fire(player, isRare, geyserIdx, coin, isMega)
		end)

		-- Auto-despawn after 15s if uncollected
		task.delay(15, function()
			if coin.Parent then coin:Destroy() end
		end)
	end
end

-- ── INIT ALL PLOTS ────────────────────────────────────────────
for _, def in ipairs(PLOT_DEFS) do
	local folder = Instance.new("Folder", farmF); folder.Name = "Plot_"..def.id
	local state  = {unlocked=def.contested or false, ownerUserId=nil, folder=folder, def=def}
	plotState[def.id]              = state
	plotByPos[def.cx.."_"..def.cz] = state

	if def.contested then
		local ring, light = buildGeyserPad(def.cx, def.cz, folder)
		table.insert(contestedList, {cx=def.cx, cz=def.cz, idx=#contestedList+1, ring=ring, light=light})
	else
		buildLockedPlot(state)
	end
end

-- All locked plot signs start visible — any reachable plot is purchasable
for _, state in pairs(plotState) do
	if not state.unlocked and state.signBB then
		state.signBB.Enabled = true
	end
end

-- ── GEYSER ACTIVATION LOOPS (staggered) ──────────────────────
for i, cd in ipairs(contestedList) do
	local ring  = cd.ring
	local light = cd.light
	local initialDelay = (i-1) * GEYSER_STAGGER
	task.delay(initialDelay, function()
		while true do
			-- Activate
			ring.Color        = Color3.fromRGB(255,190,0)
			ring.Transparency = 0.05
			light.Brightness  = 6
			light.Color       = Color3.fromRGB(255,200,0)
			GeyserActivateBE:Fire(i)            -- server resets per-player caps
			GeyserStateRE:FireAllClients(i, true) -- tell clients this geyser is active
			spawnGeyserBurst(cd.cx, cd.cz, i)

			task.wait(GEYSER_ACTIVE)

			-- Deactivate
			ring.Color        = Color3.fromRGB(50,50,50)
			ring.Transparency = 0.65
			light.Brightness  = 0.8
			light.Color       = Color3.fromRGB(100,80,0)
			GeyserStateRE:FireAllClients(i, false)

			task.wait(GEYSER_INACTIVE)
		end
	end)
end

-- ── MEGA BURST EVENT (every 5 minutes, random geyser, 3× coins, no cap) ──
task.delay(60, function()  -- first mega burst 60s after map loads
	while true do
		task.wait(300)  -- then every 5 minutes
		if #contestedList == 0 then continue end
		local pick = contestedList[math.random(1, #contestedList)]
		-- Visual: flash geyser ring red/white for drama
		local ring = pick.ring; local light = pick.light
		ring.Color = Color3.fromRGB(255,60,60); light.Brightness = 10; light.Color = Color3.fromRGB(255,80,0)
		GeyserActivateBE:Fire(pick.idx)
		GeyserStateRE:FireAllClients(pick.idx, true, true)  -- 3rd arg = isMega for client HUD
		MegaBurstBE:Fire(pick.idx)                          -- server clears cap for this geyser
		spawnGeyserBurst(pick.cx, pick.cz, pick.idx, true)  -- triple coins, isMega=true
		task.wait(GEYSER_ACTIVE + 2)
		ring.Color = Color3.fromRGB(50,50,50); light.Brightness = 0.8; light.Color = Color3.fromRGB(100,80,0)
		GeyserStateRE:FireAllClients(pick.idx, false)
	end
end)

-- ── COIN DESTROY HANDLER ──────────────────────────────────────
-- Server fires this when a coin is successfully credited (so it disappears from world)
CoinDestroyBE.Event:Connect(function(coinRef)
	if coinRef and coinRef.Parent then coinRef:Destroy() end
end)

-- ── COIN RAIN EVENT ───────────────────────────────────────────
-- Fires during CoinRain random event: dump a burst at every geyser simultaneously
CoinRainBE.Event:Connect(function()
	for _, cd in ipairs(contestedList) do
		spawnGeyserBurst(cd.cx, cd.cz, cd.idx, false)
		cd.ring.Color        = Color3.fromRGB(255,215,0)
		cd.ring.Transparency = 0.05
		cd.light.Brightness  = 8
		cd.light.Color       = Color3.fromRGB(255,215,0)
		GeyserStateRE:FireAllClients(cd.idx, true)
		task.delay(GEYSER_ACTIVE, function()
			cd.ring.Color        = Color3.fromRGB(50,50,50)
			cd.ring.Transparency = 0.65
			cd.light.Brightness  = 0.8
			cd.light.Color       = Color3.fromRGB(100,80,0)
			GeyserStateRE:FireAllClients(cd.idx, false)
		end)
	end
end)

-- ── GEYSER SURGE EVENT ────────────────────────────────────────
-- Fires during GeyserSurge random event: all geysers mega-burst together
GeyserSurgeBE.Event:Connect(function()
	for _, cd in ipairs(contestedList) do
		cd.ring.Color        = Color3.fromRGB(255,80,0)
		cd.ring.Transparency = 0.02
		cd.light.Brightness  = 10
		cd.light.Color       = Color3.fromRGB(255,120,0)
		GeyserActivateBE:Fire(cd.idx)
		GeyserStateRE:FireAllClients(cd.idx, true, true)
		spawnGeyserBurst(cd.cx, cd.cz, cd.idx, true)
		task.delay(GEYSER_ACTIVE + 2, function()
			cd.ring.Color        = Color3.fromRGB(50,50,50)
			cd.ring.Transparency = 0.65
			cd.light.Brightness  = 0.8
			cd.light.Color       = Color3.fromRGB(100,80,0)
			GeyserStateRE:FireAllClients(cd.idx, false)
		end)
	end
end)

-- ── PLOT EVENT HANDLERS ───────────────────────────────────────
-- plotUnlockedBE: MainGameServer fires when plot is successfully purchased
plotUnlockedBE.Event:Connect(function(id, player)
	doUnlock(id, player)
end)

-- PlotRelockBE: MainGameServer fires when player leaves (their plots release)
PlotRelockBE.Event:Connect(function(plotId)
	doLock(plotId)
end)

-- PrestigeResetBE: MainGameServer fires on prestige with the userId
-- Only re-locks plots owned by that specific player
PrestigeResetBE.Event:Connect(function(userId)
	for plotId, state in pairs(plotState) do
		if state.unlocked and state.ownerUserId == userId then
			doLock(plotId)
		end
	end
	-- Refresh signs after mass relock
	for _, state in pairs(plotState) do
		if not state.unlocked and not state.def.contested and state.signBB then
			state.signBB.Enabled = hasUnlockedNeighbor(state.def)
		end
	end
	print("[MoneyIsland] Plots re-locked for userId:", userId)
end)

-- PlotTransferBE: MainGameServer fires on successful raid — rebuild plot for new owner
PlotTransferBE.Event:Connect(function(plotId, newOwnerPlayer)
	local state = plotState[plotId]
	if not state then return end
	doLock(plotId)
	task.wait(0.05)
	if newOwnerPlayer and newOwnerPlayer.Parent then
		doUnlock(plotId, newOwnerPlayer)
	end
	print("[MoneyIsland] Plot", plotId, "raided → transferred to", newOwnerPlayer and newOwnerPlayer.Name or "nobody")
end)

-- ── RAID FLASH HANDLER ────────────────────────────────────────
-- MainGameServer fires PlotRaidAlert_BE(plotId, isActive) when a raid starts/stops.
-- We pulse the plot floor red while the raid is active.
local TweenService = game:GetService("TweenService")

PlotRaidAlertBE.Event:Connect(function(plotId, isActive)
	local state = plotState[plotId]
	if not state or not state.unlocked then return end
	local floor = state.floorPart
	if not floor then return end

	if isActive and not state.raidFlashing then
		state.raidFlashing = true
		-- Pulse floor between red and original color while raiding
		task.spawn(function()
			while state.raidFlashing and floor.Parent do
				TweenService:Create(floor, TweenInfo.new(0.4, Enum.EasingStyle.Sine),
					{Color = Color3.fromRGB(220, 30, 30)}):Play()
				task.wait(0.4)
				if not state.raidFlashing then break end
				TweenService:Create(floor, TweenInfo.new(0.4, Enum.EasingStyle.Sine),
					{Color = Color3.fromRGB(255, 80, 80)}):Play()
				task.wait(0.4)
			end
		end)
		-- Large "⚠️ RAID!" billboard above the plot
		if not state.raidBillboardPart then
			local rba = Instance.new("Part", state.folder)
			rba.Name = "RaidAlertAnchor"
			rba.Anchored = true; rba.CanCollide = false
			rba.Size = Vector3.new(1,1,1); rba.Transparency = 1
			rba.CFrame = CFrame.new(state.def.cx, DECK_TOP + 26, state.def.cz)
			local rbl = makeBillboard(rba, "🚨 RAID IN PROGRESS! 🚨", Color3.fromRGB(255, 60, 60), 0, 340, 56, 120)
			rbl.Name = "RaidAlertBB"
			state.raidBillboardPart = rba
		end
	elseif not isActive and state.raidFlashing then
		state.raidFlashing = false
		-- Restore floor color
		if floor.Parent then
			TweenService:Create(floor, TweenInfo.new(0.5, Enum.EasingStyle.Sine),
				{Color = state.floorOrigCol or Color3.fromRGB(108,75,38)}):Play()
		end
		-- Remove raid billboard
		if state.raidBillboardPart then
			state.raidBillboardPart:Destroy()
			state.raidBillboardPart = nil
		end
	end
end)

-- ── TWILIGHT SKYBOX + LIGHTING ───────────────────────────────
-- Late-evening twilight: dark enough for neon glow but bright enough to see
Lighting.ClockTime      = 7.0     -- early morning / dawn
Lighting.Brightness     = 1.4
Lighting.Ambient        = Color3.fromRGB(85, 95, 145)   -- visible blue-tinted ambient
Lighting.OutdoorAmbient = Color3.fromRGB(110, 122, 175)
Lighting.GlobalShadows  = true
Lighting.ShadowSoftness = 0.4
Lighting.FogEnd         = 2200
Lighting.FogColor       = Color3.fromRGB(22, 28, 55)

-- Sky with stars + visible sun
local sky = Instance.new("Sky", Lighting)
sky.StarCount       = 3000
sky.MoonAngularSize = 9
sky.SunAngularSize  = 8

-- Bloom: neon machines glow but scene stays readable
local bloom = Instance.new("BloomEffect", Lighting)
bloom.Intensity  = 0.55
bloom.Size       = 22
bloom.Threshold  = 0.91

-- Color grade: slight warm tint so machines pop
local cc = Instance.new("ColorCorrectionEffect", Lighting)
cc.Saturation = 0.14; cc.Brightness = 0.04; cc.Contrast = 0.06
cc.TintColor  = Color3.fromRGB(215, 218, 255)

local atmo = Instance.new("Atmosphere", Lighting)
atmo.Density = 0.11; atmo.Offset = 0.04
atmo.Color   = Color3.fromRGB(95, 108, 168)
atmo.Decay   = Color3.fromRGB(45, 55, 100)
atmo.Glare   = 0.04; atmo.Haze = 0.3

print("[MoneyIsland] Map v26 built! 20 unique machines, night skybox, CoinRain/GeyserSurge events.")

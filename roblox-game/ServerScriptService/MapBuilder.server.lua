-- MapBuilder.server.lua (v25 - Free plot access + machine raiding + PVP hot zone)

local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

-- MainGameServer creates CoinCollected_BE first
local coinBE = ReplicatedStorage:WaitForChild("CoinCollected_BE", 15)

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
	-- ── OWNED PLOTS ring 1 (adjacent to contested, cost 2000) ──
	{id="L_N",  cx=COLS[2], cz=ROWS[4], cost=2000,  color=Color3.fromRGB(80,255,120), label="2,000 Coins"},
	{id="R_N",  cx=COLS[4], cz=ROWS[4], cost=2000,  color=Color3.fromRGB(80,255,120), label="2,000 Coins"},
	{id="L_S",  cx=COLS[2], cz=ROWS[2], cost=2000,  color=Color3.fromRGB(80,255,120), label="2,000 Coins"},
	{id="R_S",  cx=COLS[4], cz=ROWS[2], cost=2000,  color=Color3.fromRGB(80,255,120), label="2,000 Coins"},
	-- ── OWNED PLOTS ring 2 (cost 10000) ──
	{id="LL_M", cx=COLS[1], cz=ROWS[3], cost=10000, color=Color3.fromRGB(255,160,0),  label="10,000 Coins"},
	{id="RR_M", cx=COLS[5], cz=ROWS[3], cost=10000, color=Color3.fromRGB(255,160,0),  label="10,000 Coins"},
	{id="C_NN", cx=COLS[3], cz=ROWS[5], cost=10000, color=Color3.fromRGB(255,160,0),  label="10,000 Coins"},
	{id="C_SS", cx=COLS[3], cz=ROWS[1], cost=10000, color=Color3.fromRGB(255,160,0),  label="10,000 Coins"},
	-- ── OWNED PLOTS ring 3 (cost 25000) ──
	{id="LL_N", cx=COLS[1], cz=ROWS[4], cost=25000, color=Color3.fromRGB(255,200,0),  label="25,000 Coins"},
	{id="LL_S", cx=COLS[1], cz=ROWS[2], cost=25000, color=Color3.fromRGB(255,200,0),  label="25,000 Coins"},
	{id="RR_N", cx=COLS[5], cz=ROWS[4], cost=25000, color=Color3.fromRGB(255,200,0),  label="25,000 Coins"},
	{id="RR_S", cx=COLS[5], cz=ROWS[2], cost=25000, color=Color3.fromRGB(255,200,0),  label="25,000 Coins"},
	{id="L_NN", cx=COLS[2], cz=ROWS[5], cost=25000, color=Color3.fromRGB(255,200,0),  label="25,000 Coins"},
	{id="R_NN", cx=COLS[4], cz=ROWS[5], cost=25000, color=Color3.fromRGB(255,200,0),  label="25,000 Coins"},
	{id="L_SS", cx=COLS[2], cz=ROWS[1], cost=25000, color=Color3.fromRGB(255,200,0),  label="25,000 Coins"},
	{id="R_SS", cx=COLS[4], cz=ROWS[1], cost=25000, color=Color3.fromRGB(255,200,0),  label="25,000 Coins"},
	-- ── OWNED PLOTS ring 4 corners (cost 50000) ──
	{id="LL_NN",cx=COLS[1], cz=ROWS[5], cost=50000, color=Color3.fromRGB(220,80,255), label="50,000 Coins"},
	{id="RR_NN",cx=COLS[5], cz=ROWS[5], cost=50000, color=Color3.fromRGB(220,80,255), label="50,000 Coins"},
	{id="LL_SS",cx=COLS[1], cz=ROWS[1], cost=50000, color=Color3.fromRGB(220,80,255), label="50,000 Coins"},
	{id="RR_SS",cx=COLS[5], cz=ROWS[1], cost=50000, color=Color3.fromRGB(220,80,255), label="50,000 Coins"},
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
	makeBillboard(body,"🏭 COIN FACTORY",Color3.fromRGB(255,190,60),14,220,46,90)
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

local MACHINE_BUILDERS = {
	[2000]  = buildPrinter,
	[10000] = buildRoomba,
	[25000] = buildFactory,
	[50000] = buildVault,
}

local function doUnlock(plotId, ownerPlayer)
	local state = plotState[plotId]
	if not state or state.unlocked then return end
	state.unlocked    = true
	state.ownerUserId = ownerPlayer and ownerPlayer.UserId or nil
	for _, p in ipairs(state.folder:GetChildren()) do p:Destroy() end
	local def   = state.def

	-- Tier-colored floor overlay
	local floor = P({name="PlotFloor", par=state.folder,
		sz=Vector3.new(PLOT_W-1, 0.08, PLOT_D-1),
		pos=Vector3.new(def.cx, DECK_TOP+0.12, def.cz),
		col=getFloorCol(def.cost), mat=PM, cc=false, tr=0.1})

	-- Spawn the tier machine
	local builder = MACHINE_BUILDERS[def.cost]
	if builder then
		builder(def.cx, def.cz, state.folder)
	end

	-- Owner nameplate (anchored to invisible part above center)
	if ownerPlayer then
		local a = Instance.new("Part", state.folder)
		a.Anchored = true; a.CanCollide = false
		a.Size = Vector3.new(1,1,1)
		a.CFrame = CFrame.new(def.cx, DECK_TOP+1, def.cz)
		a.Transparency = 1
		makeBillboard(a, "⚡ "..ownerPlayer.Name, Color3.fromRGB(255,200,0), 22, 220, 50, 80)
	end

	print("[MoneyIsland] Plot", plotId, "→", ownerPlayer and ownerPlayer.Name or "anonymous")
end

local function doLock(plotId)
	local state = plotState[plotId]
	if not state or not state.unlocked then return end
	state.unlocked    = false
	state.ownerUserId = nil
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

-- ── LIGHTING & ATMOSPHERE ─────────────────────────────────────
Lighting.Brightness     = 2.2
Lighting.ClockTime      = 14
Lighting.Ambient        = Color3.fromRGB(85,82,70)
Lighting.OutdoorAmbient = Color3.fromRGB(128,120,102)
Lighting.GlobalShadows  = true
Lighting.ShadowSoftness = 0.2

local cc = Instance.new("ColorCorrectionEffect", Lighting)
cc.Saturation = 0.12; cc.Brightness = 0.02; cc.Contrast = 0.04

local atmo = Instance.new("Atmosphere", Lighting)
atmo.Density = 0.32; atmo.Offset = 0.08
atmo.Color   = Color3.fromRGB(199,199,199)
atmo.Decay   = Color3.fromRGB(106,127,153)
atmo.Glare   = 0.08; atmo.Haze = 1.2

print("[MoneyIsland] Map v25 built! Free plot access, machine raiding, PVP hot zone.")

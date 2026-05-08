-- MainGameServer.server.lua (v18 - HP death, 4 weapons, building upgrades, random events, bug fixes)

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

Players.RespawnTime = 5

local coinBE = Instance.new("BindableEvent")
coinBE.Name   = "CoinCollected_BE"
coinBE.Parent = ReplicatedStorage

local CoinDestroyBE=nil; local GeyserActivateBE=nil; local PlotRelockBE=nil
local PrestigeResetBE=nil; local plotUnlockedBE=nil; local PlotTransferBE=nil
local PlotRaidAlertBE=nil
task.spawn(function()
	CoinDestroyBE    = ReplicatedStorage:WaitForChild("CoinDestroy_BE",    20)
	GeyserActivateBE = ReplicatedStorage:WaitForChild("GeyserActivate_BE", 20)
	PlotRelockBE     = ReplicatedStorage:WaitForChild("PlotRelock_BE",     20)
	PrestigeResetBE  = ReplicatedStorage:WaitForChild("PrestigeReset_BE",  20)
	plotUnlockedBE   = ReplicatedStorage:WaitForChild("PlotUnlocked",      20)
	PlotTransferBE   = ReplicatedStorage:WaitForChild("PlotTransfer_BE",   20)
	PlotRaidAlertBE  = ReplicatedStorage:WaitForChild("PlotRaidAlert_BE",  20)
end)

-- ── CONFIG ────────────────────────────────────────────────────
local GP = {
	DOUBLE_COINS=1821720069, MEGA_MAGNET=1822515059, LUCKY_CHARM=1821659972,
	SPEED_DEMON=1822655551,  PRESTIGE_BOOST=1822649609, AUTO_FARM=1823064828,
}
local PRODUCTS = {
	COINS_SMALL=3586040050, COINS_MEDIUM=3586040263,
	COINS_LARGE=3586040422, RESET=3586040561,
}

local BASE_COIN_VALUE = 100
local REBIRTH_MULT    = 2
local DAILY_REWARDS   = {500,1000,2000,3500,5000,8000,15000}
local TICK_BASE       = 8
local TICK_FLOOR      = 1
local GEYSER_CAP      = 4

-- ── PVP ───────────────────────────────────────────────────────
local MAX_HP        = 100
local KILL_COIN_PCT = 0.20

-- ── WEAPONS ───────────────────────────────────────────────────
local WEAPONS = {
	{id="CoinBlade",     name="⚔️ Coin Blade",     desc="Classic melee sword.",
	 damage=25, range=8,  cooldown=1.2, cost=0,
	 isProjectile=false, isAoE=false,
	 color=Color3.fromRGB(255,215,0),  glow=Color3.fromRGB(255,200,0)},
	{id="LaserStaff",    name="🔮 Laser Staff",    desc="Long-range projectile bolt.",
	 damage=32, range=55, cooldown=2.0, cost=5000,
	 isProjectile=true,  isAoE=false,
	 color=Color3.fromRGB(80,160,255), glow=Color3.fromRGB(60,120,255)},
	{id="ThunderHammer", name="🔨 Thunder Hammer", desc="Shockwave hits ALL nearby enemies!",
	 damage=18, range=14, cooldown=4.0, cost=15000,
	 isProjectile=false, isAoE=true,
	 color=Color3.fromRGB(255,255,60), glow=Color3.fromRGB(255,220,0)},
	{id="ShadowBlade",   name="🌑 Shadow Blade",   desc="Fast dark blade, high damage.",
	 damage=42, range=11, cooldown=1.6, cost=40000,
	 isProjectile=false, isAoE=false,
	 color=Color3.fromRGB(160,40,255), glow=Color3.fromRGB(120,0,200)},
}
local weaponById = {}
for _,w in ipairs(WEAPONS) do weaponById[w.id]=w end
local WEAPON_UPGRADE_COSTS = {2000,6000,15000,40000}  -- lv1→2, 2→3, 3→4, 4→5

-- ── BUILDING UPGRADE PATHS ───────────────────────────────────
local PLOT_PATHS = {
	A={name="⚡ Production", desc="More coins per tick",       costs={500,2500,10000,30000}, mults={1.5,2.0,3.0,5.0}},
	B={name="⏱️ Efficiency",  desc="Faster tick interval",      costs={750,3500,12000,35000}, reds={1,2,3,5}},
	C={name="🛡️ Defense",     desc="Raid protection & bonuses", costs={1000,6000,20000,50000},
	   labels={"Raiders need 8s","8min raid immunity","Earn while defending","Golden: 3x income"}},
}

-- ── RANDOM EVENTS ─────────────────────────────────────────────
local RANDOM_EVENTS = {
	{id="DoubleIncome",    name="⚡ DOUBLE INCOME!",   desc="All machines 2× for 60s!",        col="green",dur=60},
	{id="PvPFrenzy",       name="💥 PVP FRENZY!",      desc="All weapon damage 2× for 30s!",   col="red",  dur=30},
	{id="GeyserSurge",     name="💧 GEYSER SURGE!",    desc="All geysers erupt at once!",       col="blue", dur=20},
	{id="GoldenHour",      name="✨ GOLDEN HOUR!",     desc="A lucky machine earns 10×!",       col="gold", dur=60},
	{id="BountyHunt",      name="🎯 BOUNTY HUNT!",     desc="+500 bonus coins per kill! 45s",   col="red",  dur=45},
	{id="MachineRebellion",name="🤖 MACHINE RISE!",    desc="All machines 3× for 20s!",         col="green",dur=20},
	{id="CoinRain",        name="🌧️ COIN RAIN!",       desc="Bonus geyser burst — grab coins!", col="gold", dur=25},
}

-- ── UPGRADES ──────────────────────────────────────────────────
local UPGRADES = {
	{key="coinMagnet", name="Magnet Range",  icon="🧲", desc="Requires Mega Magnet pass.",
	 maxLevel=9999, baseCost=120,  costMult=1.15, effect=function(l) return 5+l*3 end},
	{key="touchSpeed", name="Plot Speed",    icon="⚡", desc="Faster auto-tick.",
	 maxLevel=7,    baseCost=80,   costMult=1.2,  effect=function(l) return math.max(TICK_FLOOR,TICK_BASE-l) end},
	{key="coinValue",  name="Coin Value",    icon="💰", desc="More coins per tick/collect.",
	 maxLevel=9999, baseCost=200,  costMult=1.15, effect=function(l) return 1+l*0.5 end},
	{key="offlineVault",name="Offline Vault",icon="🏦", desc="Earn coins while offline.",
	 maxLevel=8,    baseCost=500,  costMult=2.0,  effect=function(l) return l end},
}
local function getUpgrade(key) for _,u in ipairs(UPGRADES) do if u.key==key then return u end end end
local function getUpgradeCost(u,l) return math.floor(u.baseCost*(u.costMult^l)) end

-- ── REMOTES ───────────────────────────────────────────────────
local function ensureRemote(cls,name)
	local r=ReplicatedStorage:FindFirstChild(name)
	if not r then r=Instance.new(cls);r.Name=name;r.Parent=ReplicatedStorage end
	return r
end
local RE={
	UpdateStats    =ensureRemote("RemoteEvent",   "UpdateStats"),
	BuyUpgrade     =ensureRemote("RemoteEvent",   "BuyUpgrade"),
	Rebirth        =ensureRemote("RemoteEvent",   "Rebirth"),
	ClaimDaily     =ensureRemote("RemoteEvent",   "ClaimDaily"),
	ShowShop       =ensureRemote("RemoteEvent",   "ShowShop"),
	NotifyPlayer   =ensureRemote("RemoteEvent",   "NotifyPlayer"),
	RequestData    =ensureRemote("RemoteFunction","RequestData"),
	MagnetCollect  =ensureRemote("RemoteEvent",   "MagnetCollect"),
	PlotTick       =ensureRemote("RemoteEvent",   "PlotTick_RE"),
	RaidStatus     =ensureRemote("RemoteEvent",   "RaidStatus_RE"),
	MagnetBroadcast=ensureRemote("RemoteEvent",   "MagnetBroadcast_RE"),
	MachineRate    =ensureRemote("RemoteEvent",   "MachineRate_RE"),
	HPUpdate       =ensureRemote("RemoteEvent",   "HPUpdate_RE"),
	PlayerDied     =ensureRemote("RemoteEvent",   "PlayerDied_RE"),
	WeaponHit      =ensureRemote("RemoteEvent",   "WeaponHit_RE"),
	WeaponActivate =ensureRemote("RemoteEvent",   "WeaponActivate_RE"),
	WeaponShopBuy  =ensureRemote("RemoteEvent",   "WeaponShopBuy_RE"),
	PlotUpgradeBuy =ensureRemote("RemoteEvent",   "PlotUpgradeBuy_RE"),
	UseAbility     =ensureRemote("RemoteEvent",   "UseAbility_RE"),
	AbilityCooldown=ensureRemote("RemoteEvent",   "AbilityCooldown_RE"),
	RandomEvent    =ensureRemote("RemoteEvent",   "RandomEvent_RE"),
	WeaponInfo     =ensureRemote("RemoteEvent",   "WeaponInfo_RE"),
}
local SwordHitRE = ensureRemote("RemoteEvent","SwordHit_RE")  -- backward compat

-- ── PLOT CENTERS ──────────────────────────────────────────────
local PLOT_CENTERS={
	L_N={cx=-50,cz=50,cost=4000},   R_N={cx=50,cz=50,cost=4000},
	L_S={cx=-50,cz=-50,cost=4000},  R_S={cx=50,cz=-50,cost=4000},
	LL_M={cx=-100,cz=0,cost=25000}, RR_M={cx=100,cz=0,cost=25000},
	C_NN={cx=0,cz=100,cost=25000},  C_SS={cx=0,cz=-100,cost=25000},
	LL_N={cx=-100,cz=50,cost=75000}, LL_S={cx=-100,cz=-50,cost=75000},
	RR_N={cx=100,cz=50,cost=75000},  RR_S={cx=100,cz=-50,cost=75000},
	L_NN={cx=-50,cz=100,cost=75000}, R_NN={cx=50,cz=100,cost=75000},
	L_SS={cx=-50,cz=-100,cost=75000},R_SS={cx=50,cz=-100,cost=75000},
	LL_NN={cx=-100,cz=100,cost=200000},RR_NN={cx=100,cz=100,cost=200000},
	LL_SS={cx=-100,cz=-100,cost=200000},RR_SS={cx=100,cz=-100,cost=200000},
}
local PLOT_HALF=25
local HOT_ZONE_CENTERS={{cx=0,cz=0},{cx=-50,cz=0},{cx=50,cz=0},{cx=0,cz=50},{cx=0,cz=-50}}

-- ── RAID STATE ────────────────────────────────────────────────
local RAID_TIME=5; local RAID_IMMUNE=240
local raidProgress={}; local raidImmune={}; local raidWarned={}; local raidActiveOnPlot={}

-- ── DATA STORE ────────────────────────────────────────────────
local DS = DataStoreService:GetDataStore("MoneyIsland_v19")
local DEFAULT_DATA={
	coins=0,totalEarned=0,rebirths=0,upgrades={},
	lastDaily=0,dailyStreak=0,lastSave=0,playTime=0,
	prestigeStreak=0,lastPrestige=0,
	ownedWeapons={"CoinBlade"},equippedWeapon="CoinBlade",
	weaponLevels={CoinBlade=1},plotUpgrades={},
}

local playerData={}; local playerGP={}; local serverPlotOwners={}
local geyserLimits={}; local megaBurstActive={}; local plotTickLast={}
local playerHP={}; local playerDead={}; local playerBlocking={}
local weaponHitCDs={}; local abilityCDs={}; local activeEvents={}
local goldenPlotData=nil

local function deepCopy(t)
	local c={}; for k,v in pairs(t) do c[k]=type(v)=="table" and deepCopy(v) or v end; return c
end

local function loadData(player)
	local ok,data=pcall(function() return DS:GetAsync("MI19_"..player.UserId) end)
	local d=deepCopy(DEFAULT_DATA)
	if ok and data then for k,v in pairs(data) do d[k]=v end end
	if not d.ownedWeapons  then d.ownedWeapons={"CoinBlade"} end
	if not d.equippedWeapon then d.equippedWeapon="CoinBlade" end
	if not d.weaponLevels  then d.weaponLevels={CoinBlade=1} end
	if not d.plotUpgrades  then d.plotUpgrades={} end
	-- Offline vault bonus
	if d.lastSave and d.lastSave>0 then
		local secs=os.time()-d.lastSave; local vLvl=d.upgrades["offlineVault"] or 0
		if vLvl>0 then
			local eff=math.min(secs,vLvl*3600)
			local cd=math.max(TICK_FLOOR,TICK_BASE-(d.upgrades["touchSpeed"] or 0))
			local cv=d.upgrades["coinValue"] or 0
			local val=math.floor(BASE_COIN_VALUE*(1+cv*0.5)*(REBIRTH_MULT^(d.rebirths or 0)))
			local earned=math.floor(eff/cd)*val
			if earned>0 then d.coins=d.coins+earned; d.totalEarned=d.totalEarned+earned; d._offlineBonus=earned end
		end
	end
	d.lastSave=os.time(); d.ownedPlots={}
	playerData[player.UserId]=d; return d
end

local function saveData(player)
	local d=playerData[player.UserId]; if not d then return end
	d.lastSave=os.time()
	local s=deepCopy(d); s._gp=nil; s.ownedPlots=nil; s._offlineBonus=nil
	pcall(function() DS:SetAsync("MI19_"..player.UserId,s) end)
end

local cachedRanking={}; local lastRankBuild=0
local function buildRanking()
	if os.time()-lastRankBuild<8 then return cachedRanking end
	lastRankBuild=os.time(); local e={}
	for uid,d in pairs(playerData) do
		local p=Players:GetPlayerByUserId(uid)
		if p then table.insert(e,{name=p.Name,coins=math.floor(d.coins),rebirths=d.rebirths}) end
	end
	table.sort(e,function(a,b) return a.coins>b.coins end)
	cachedRanking=e; return e
end

local function pushStats(player)
	local d=playerData[player.UserId]; if not d then return end
	d._gp=playerGP[player.UserId] or {}; d._ranking=buildRanking()
	RE.UpdateStats:FireClient(player,d,UPGRADES)
end

-- ── GAMEPASSES ────────────────────────────────────────────────
local function checkGamepasses(player)
	local gps={}
	for _,c in ipairs({
		{key="doubleCoin",id=GP.DOUBLE_COINS},{key="megaMagnet",id=GP.MEGA_MAGNET},
		{key="luckyCharm",id=GP.LUCKY_CHARM},{key="speedDemon",id=GP.SPEED_DEMON},
		{key="prestigeBoost",id=GP.PRESTIGE_BOOST},{key="autoFarm",id=GP.AUTO_FARM},
	}) do
		local ok,owns=pcall(MarketplaceService.UserOwnsGamePassAsync,MarketplaceService,player.UserId,c.id)
		gps[c.key]=ok and owns or false
	end
	playerGP[player.UserId]=gps; return gps
end

local function applySpeedDemon(player)
	local gp=playerGP[player.UserId]; local char=player.Character
	if not gp or not gp.speedDemon or not char then return end
	local h=char:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=19 end
end

-- ── COIN VALUE ────────────────────────────────────────────────
local function getCoinValue(player)
	local d=playerData[player.UserId]; if not d then return BASE_COIN_VALUE end
	local gp=playerGP[player.UserId] or {}; local mult=1
	local cv=d.upgrades["coinValue"] or 0; if cv>0 then mult=mult*(1+cv*0.5) end
	local rb=gp.prestigeBoost and 3 or REBIRTH_MULT; mult=mult*(rb^d.rebirths)
	if gp.doubleCoin then mult=mult*2 end
	local str=d.prestigeStreak or 0; if str>0 then mult=mult*(1+0.1*math.min(str,5)) end
	if activeEvents["DoubleIncome"]     then mult=mult*2  end
	if activeEvents["MachineRebellion"] then mult=mult*3  end
	return math.floor(BASE_COIN_VALUE*mult)
end

local function getTickInterval(player)
	local d=playerData[player.UserId]; if not d then return TICK_BASE end
	local gp=playerGP[player.UserId] or {}
	local cd=math.max(TICK_FLOOR,TICK_BASE-(d.upgrades["touchSpeed"] or 0))
	if gp.autoFarm then cd=math.max(TICK_FLOOR,math.floor(cd/2)) end; return cd
end

local function getPlotCoinValue(player,plotId)
	local base=getCoinValue(player); local d=playerData[player.UserId]; if not d then return base end
	local upg=d.plotUpgrades and d.plotUpgrades[plotId]; if not upg then return base end
	local mult=1
	for i=1,(upg.A or 0) do mult=mult*(PLOT_PATHS.A.mults[i] or 1) end
	if (upg.C or 0)>=4 then mult=mult*3 end
	if goldenPlotData and goldenPlotData.uid==player.UserId and goldenPlotData.plotId==plotId then mult=mult*10 end
	return math.floor(base*mult)
end

local function getPlotTickInterval(player,plotId)
	local base=getTickInterval(player); local d=playerData[player.UserId]; if not d then return base end
	local upg=d.plotUpgrades and d.plotUpgrades[plotId]; if not upg then return base end
	local red=0
	for i=1,(upg.B or 0) do red=red+(PLOT_PATHS.B.reds[i] or 0) end
	return math.max(TICK_FLOOR,base-red)
end

local function getRaidTime(plotId)
	local uid=serverPlotOwners[plotId]; if not uid then return RAID_TIME end
	local d=playerData[uid]; if not d then return RAID_TIME end
	local upg=d.plotUpgrades and d.plotUpgrades[plotId]
	return (upg and (upg.C or 0)>=1) and 8 or RAID_TIME
end

local function getRaidImmune(plotId)
	local uid=serverPlotOwners[plotId]; if not uid then return RAID_IMMUNE end
	local d=playerData[uid]; if not d then return RAID_IMMUNE end
	local upg=d.plotUpgrades and d.plotUpgrades[plotId]
	return (upg and (upg.C or 0)>=2) and 480 or RAID_IMMUNE
end

-- ── GEYSER LIMITS ────────────────────────────────────────────
task.spawn(function()
	while not GeyserActivateBE do task.wait(0.1) end
	GeyserActivateBE.Event:Connect(function(idx) geyserLimits[idx]={} end)
end)
task.spawn(function()
	local mb=ReplicatedStorage:WaitForChild("MegaBurst_BE",20); if not mb then return end
	mb.Event:Connect(function(idx)
		megaBurstActive[idx]=true
		RE.NotifyPlayer:FireAllClients("⚡ MEGA BURST!","Geyser "..idx.." — no cap for 10s!","gold")
		task.delay(12,function() megaBurstActive[idx]=nil end)
	end)
end)

-- ── COIN COLLECTION (BUG FIX: accessories) ───────────────────
coinBE.Event:Connect(function(player,isRare,geyserIdx,coinRef,isMega)
	if not coinRef or not coinRef.Parent then return end
	if coinRef:GetAttribute("Collected") then return end
	coinRef:SetAttribute("Collected",true)
	local d=playerData[player.UserId]; local gp=playerGP[player.UserId] or {}
	if not d then return end
	if CoinDestroyBE then CoinDestroyBE:Fire(coinRef) end
	local coins=getCoinValue(player)
	if isRare then
		coins=coins*5; d.coins=d.coins+coins; d.totalEarned=(d.totalEarned or 0)+coins
		player:SetAttribute("Coins",d.coins); pushStats(player)
		RE.NotifyPlayer:FireClient(player,"💎 RARE COIN! ×5","+"..coins.." coins!","blue"); return
	end
	local jc=gp.luckyCharm and 6 or 3
	if math.random(100)<=jc then coins=coins*10; RE.NotifyPlayer:FireClient(player,"🍀 JACKPOT!","×10 coins!","green") end
	d.coins=d.coins+coins; d.totalEarned=(d.totalEarned or 0)+coins
	player:SetAttribute("Coins",d.coins); pushStats(player)
end)

-- ── MAGNET COLLECT ────────────────────────────────────────────
local magnetCDs={}
RE.MagnetCollect.OnServerEvent:Connect(function(player,coinRef)
	if magnetCDs[player.UserId] then return end
	magnetCDs[player.UserId]=true; task.delay(0.2,function() magnetCDs[player.UserId]=nil end)
	if not coinRef or not coinRef.Parent then return end
	if coinRef:GetAttribute("Collected") then return end
	if not coinRef:GetAttribute("GeyserCoin") then return end
	local gp=playerGP[player.UserId] or {}; if not gp.megaMagnet then return end
	local char=player.Character; if not char then return end
	local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local d=playerData[player.UserId]; if not d then return end
	local lvl=d.upgrades["coinMagnet"] or 0; local range=5+lvl*3+15
	if (hrp.Position-coinRef.Position).Magnitude>range then return end
	local gIdx=coinRef:GetAttribute("GeyserIdx")
	if gIdx then
		local g=geyserLimits[gIdx]; if not g then g={}; geyserLimits[gIdx]=g end
		local cnt=g[player.UserId] or 0; if cnt>=GEYSER_CAP then return end
		g[player.UserId]=cnt+1
	end
	coinRef:SetAttribute("Collected",true)
	local isRare=coinRef:GetAttribute("RareCoin"); local coins=getCoinValue(player)
	if isRare then coins=coins*5 end
	if CoinDestroyBE and coinRef.Parent then CoinDestroyBE:Fire(coinRef) end
	d.coins=d.coins+coins; d.totalEarned=(d.totalEarned or 0)+coins
	player:SetAttribute("Coins",d.coins); pushStats(player)
	if isRare then RE.NotifyPlayer:FireClient(player,"💎 RARE COIN! ×5","+"..coins.." magnet!","blue") end
end)

-- ── MAGNET BROADCAST ──────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(0.25); local md={}
		for _,p in ipairs(Players:GetPlayers()) do
			local gp=playerGP[p.UserId] or {}; local d=playerData[p.UserId]
			if gp.megaMagnet and d and p.Character then
				local hrp=p.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local lvl=d.upgrades["coinMagnet"] or 0
					table.insert(md,{userId=p.UserId,name=p.Name,pos=hrp.Position,range=5+lvl*3+15})
				end
			end
		end
		if #md>0 then RE.MagnetBroadcast:FireAllClients(md) end
	end
end)

-- ── AUTO-TICK ─────────────────────────────────────────────────
local statsDirty={}
task.spawn(function()
	while true do
		task.wait(1); local now=os.time()
		for _,player in ipairs(Players:GetPlayers()) do
			local uid=player.UserId; local d=playerData[uid]
			if not d or not d.ownedPlots then continue end
			if not plotTickLast[uid] then plotTickLast[uid]={} end
			local pts=plotTickLast[uid]; local earned=0; local ticked={}
			for plotId,owned in pairs(d.ownedPlots) do
				if owned then
					local last=pts[plotId] or 0
					local pcd=getPlotTickInterval(player,plotId)
					local pv=getPlotCoinValue(player,plotId)
					if (now-last)>=pcd then
						pts[plotId]=now; earned=earned+pv
						table.insert(ticked,{plotId=plotId,coins=pv,cd=pcd})
						-- Path C lv3: earn while defending
						local upg=d.plotUpgrades and d.plotUpgrades[plotId]
						if upg and (upg.C or 0)>=3 and raidActiveOnPlot[plotId] then
							earned=earned+math.floor(pv*0.5)
						end
					end
				end
			end
			if earned>0 then
				d.coins=d.coins+earned; d.totalEarned=(d.totalEarned or 0)+earned
				player:SetAttribute("Coins",d.coins); statsDirty[uid]=true
				RE.PlotTick:FireClient(player,earned,ticked)
			end
		end
	end
end)

-- Prestige race warning
local prestigeWarned={}
task.spawn(function()
	while true do
		task.wait(5)
		for _,player in ipairs(Players:GetPlayers()) do
			local uid=player.UserId; local d=playerData[uid]; if not d then continue end
			local cost=math.floor(75000*(2^d.rebirths)); local pct=d.coins/math.max(1,cost)
			if pct>=0.8 and not prestigeWarned[uid] then
				prestigeWarned[uid]=true
				for _,p in ipairs(Players:GetPlayers()) do
					if p~=player then RE.NotifyPlayer:FireClient(p,"⚠️ "..player.Name.." close to prestige!","Rush the geysers!","red") end
				end
			elseif pct<0.7 then prestigeWarned[uid]=nil end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(5)
		for _,player in ipairs(Players:GetPlayers()) do
			if statsDirty[player.UserId] then
				statsDirty[player.UserId]=nil; pushStats(player)
				local ls=player:FindFirstChild("leaderstats")
				if ls then
					local d=playerData[player.UserId]; if not d then continue end
					local cv=ls:FindFirstChild("Coins");        if cv then cv.Value=math.floor(d.coins) end
					local rv=ls:FindFirstChild("Rebirths");     if rv then rv.Value=d.rebirths end
					local tv=ls:FindFirstChild("Total Earned"); if tv then tv.Value=math.floor(d.totalEarned) end
				end
			end
		end
	end
end)

-- ── WEAPON TOOL BUILDER ───────────────────────────────────────
local function buildWeaponTool(weaponId)
	local w=weaponById[weaponId]; if not w then return nil end
	local tool=Instance.new("Tool")
	tool.Name=weaponId; tool.RequiresHandle=true
	tool.CanBeDropped=false; tool.ToolTip=w.name.." — "..w.desc

	local handle=Instance.new("Part",tool)
	handle.Name="Handle"; handle.CanCollide=false

	if weaponId=="CoinBlade" then
		handle.Size=Vector3.new(0.4,4.5,0.4); handle.BrickColor=BrickColor.new("Bright yellow")
		handle.Material=Enum.Material.Neon
		local g=Instance.new("Part",tool); g.Name="Guard"
		g.Size=Vector3.new(2.4,0.3,0.3); g.BrickColor=BrickColor.new("Bright yellow")
		g.Material=Enum.Material.Neon; g.CanCollide=false
		local gw=Instance.new("Weld",g); gw.Part0=handle; gw.Part1=g; gw.C0=CFrame.new(0,1.5,0)

	elseif weaponId=="LaserStaff" then
		handle.Size=Vector3.new(0.5,5.0,0.5); handle.BrickColor=BrickColor.new("Bright blue")
		handle.Material=Enum.Material.Neon
		local orb=Instance.new("Part",tool); orb.Name="Orb"; orb.Shape=Enum.PartType.Ball
		orb.Size=Vector3.new(1.5,1.5,1.5); orb.BrickColor=BrickColor.new("Cyan")
		orb.Material=Enum.Material.Neon; orb.CanCollide=false
		local ow=Instance.new("Weld",orb); ow.Part0=handle; ow.Part1=orb; ow.C0=CFrame.new(0,2.9,0)
		local ring=Instance.new("Part",tool); ring.Name="Ring"
		ring.Size=Vector3.new(0.2,2.0,2.0); ring.BrickColor=BrickColor.new("Bright blue")
		ring.Material=Enum.Material.Neon; ring.CanCollide=false
		local rw=Instance.new("Weld",ring); rw.Part0=orb; rw.Part1=ring; rw.C0=CFrame.new(0,0,0)*CFrame.Angles(0,0,math.rad(90))

	elseif weaponId=="ThunderHammer" then
		handle.Size=Vector3.new(0.6,4.0,0.6); handle.BrickColor=BrickColor.new("Dark orange")
		handle.Material=Enum.Material.SmoothPlastic
		local head=Instance.new("Part",tool); head.Name="Head"
		head.Size=Vector3.new(3.8,2.6,1.6); head.BrickColor=BrickColor.new("Bright yellow")
		head.Material=Enum.Material.Neon; head.CanCollide=false
		local hw=Instance.new("Weld",head); hw.Part0=handle; hw.Part1=head; hw.C0=CFrame.new(0,2.5,0)

	elseif weaponId=="ShadowBlade" then
		handle.Size=Vector3.new(0.4,4.0,0.7); handle.BrickColor=BrickColor.new("Royal purple")
		handle.Material=Enum.Material.Neon
		local tip=Instance.new("Part",tool); tip.Name="Tip"
		tip.Size=Vector3.new(0.3,2.8,0.6); tip.BrickColor=BrickColor.new("Dark indigo")
		tip.Material=Enum.Material.Neon; tip.CanCollide=false
		local tw=Instance.new("Weld",tip); tw.Part0=handle; tw.Part1=tip; tw.C0=CFrame.new(0,3.3,0)
	end

	local pl=Instance.new("PointLight",handle); pl.Brightness=3; pl.Range=12; pl.Color=w.glow
	return tool
end

-- ── HP HELPERS ────────────────────────────────────────────────
local function sendHP(player)
	RE.HPUpdate:FireClient(player,playerHP[player.UserId] or MAX_HP,MAX_HP)
end

-- ── COMBAT ────────────────────────────────────────────────────
local function handlePlayerDeath(attacker,victim)
	local auid=attacker.UserId; local vuid=victim.UserId
	local ad=playerData[auid]; local vd=playerData[vuid]
	if not ad or not vd then return end
	local stolen=math.floor(vd.coins*KILL_COIN_PCT)
	if stolen<1 and vd.coins>0 then stolen=1 end
	vd.coins=math.max(0,vd.coins-stolen); ad.coins=ad.coins+stolen
	victim:SetAttribute("Coins",vd.coins); attacker:SetAttribute("Coins",ad.coins)
	if activeEvents["BountyHunt"] then
		ad.coins=ad.coins+500; attacker:SetAttribute("Coins",ad.coins)
		RE.NotifyPlayer:FireClient(attacker,"🎯 Bounty! +500","Bounty Hunt kill bonus!","gold")
	end
	RE.NotifyPlayer:FireClient(attacker,"💀 KILL! ⚔️","+"..stolen.." coins stolen from "..victim.Name.."!","gold")
	RE.NotifyPlayer:FireClient(victim,"💀 You died!",attacker.Name.." got "..stolen.." of your coins! (20%)","red")
	RE.PlayerDied:FireClient(victim,attacker.Name,5)
	local char=victim.Character
	if char then
		local hum=char:FindFirstChildOfClass("Humanoid"); if hum then hum.Health=0 end
	end
	playerHP[vuid]=MAX_HP; playerDead[vuid]=true
	task.delay(6,function() playerDead[vuid]=nil end)
	statsDirty[auid]=true; statsDirty[vuid]=true
end

local function dealDamage(attacker,victim,damage)
	if not attacker or not victim or attacker==victim then return end
	local vuid=victim.UserId
	if playerDead[vuid] then return end
	if playerBlocking[vuid] and (os.time()-playerBlocking[vuid])<2 then
		damage=math.floor(damage*0.15)
		RE.NotifyPlayer:FireClient(victim,"🛡️ Blocked!","Absorbed "..attacker.Name.."'s hit!","blue")
		RE.NotifyPlayer:FireClient(attacker,"🛡️ Blocked!",victim.Name.." is blocking!","blue")
	end
	if activeEvents["PvPFrenzy"] then damage=damage*2 end
	if not playerHP[vuid] then playerHP[vuid]=MAX_HP end
	playerHP[vuid]=math.max(0,playerHP[vuid]-damage)
	sendHP(victim)
	if playerHP[vuid]<=0 then
		handlePlayerDeath(attacker,victim)
	else
		RE.NotifyPlayer:FireClient(victim,"⚔️ Hit! -"..damage.."hp",attacker.Name.." attacked! HP: "..playerHP[vuid].."/100","red")
		RE.NotifyPlayer:FireClient(attacker,"⚔️ Hit! -"..damage.."hp","Enemy HP: "..playerHP[vuid].."/100","gold")
	end
end

local function handleWeaponHit(attacker,victim,weaponId)
	if not attacker or not victim or attacker==victim then return end
	local now=os.time(); local auid=attacker.UserId; local vuid=victim.UserId
	if playerDead[vuid] or playerDead[auid] then return end
	local w=weaponById[weaponId] or weaponById["CoinBlade"]
	weaponHitCDs[auid]=weaponHitCDs[auid] or {}
	local key=vuid..weaponId; local last=weaponHitCDs[auid][key] or 0
	if (now-last)<w.cooldown then return end
	weaponHitCDs[auid][key]=now
	local ac=attacker.Character; local vc=victim.Character
	if not ac or not vc then return end
	local ahrp=ac:FindFirstChild("HumanoidRootPart")
	local vhrp=vc:FindFirstChild("HumanoidRootPart")
	if not ahrp or not vhrp then return end
	local maxR=w.isProjectile and (w.range+12) or (w.range+5)
	if (ahrp.Position-vhrp.Position).Magnitude>maxR then return end
	local d=playerData[auid]; local lvl=(d and d.weaponLevels and d.weaponLevels[weaponId]) or 1
	local dmg=math.floor(w.damage*(1+(lvl-1)*0.15))
	dealDamage(attacker,victim,dmg)
end

local function handleWeaponAoE(attacker,weaponId)
	if not attacker then return end
	local auid=attacker.UserId; if playerDead[auid] then return end
	local w=weaponById[weaponId]; if not w or not w.isAoE then return end
	local now=os.time()
	weaponHitCDs[auid]=weaponHitCDs[auid] or {}
	local key="AoE_"..weaponId; if (now-(weaponHitCDs[auid][key] or 0))<w.cooldown then return end
	weaponHitCDs[auid][key]=now
	local ac=attacker.Character; if not ac then return end
	local ahrp=ac:FindFirstChild("HumanoidRootPart"); if not ahrp then return end
	local d=playerData[auid]; local lvl=(d and d.weaponLevels and d.weaponLevels[weaponId]) or 1
	local dmg=math.floor(w.damage*(1+(lvl-1)*0.15)); local hits=0
	for _,p in ipairs(Players:GetPlayers()) do
		if p==attacker or playerDead[p.UserId] then continue end
		local vc=p.Character; if not vc then continue end
		local vhrp=vc:FindFirstChild("HumanoidRootPart"); if not vhrp then continue end
		if (ahrp.Position-vhrp.Position).Magnitude<=w.range then
			dealDamage(attacker,p,dmg); hits=hits+1
		end
	end
	if hits==0 then RE.NotifyPlayer:FireClient(attacker,"🔨 Miss!","No enemies in range!","blue")
	else RE.NotifyPlayer:FireClient(attacker,"🔨 Hit "..hits.."!","AoE struck "..hits.." player(s)!","gold") end
end

RE.WeaponHit.OnServerEvent:Connect(function(att,vic,wId) handleWeaponHit(att,vic,wId or "CoinBlade") end)
SwordHitRE.OnServerEvent:Connect(function(att,vic)         handleWeaponHit(att,vic,"CoinBlade") end)
RE.WeaponActivate.OnServerEvent:Connect(function(att,wId)  handleWeaponAoE(att,wId) end)

-- ── ABILITY SYSTEM ────────────────────────────────────────────
local ABILITY_CD={dash=8,block=15}
RE.UseAbility.OnServerEvent:Connect(function(player,abilityName)
	abilityName=string.lower(abilityName or "")
	local uid=player.UserId; local now=os.time()
	abilityCDs[uid]=abilityCDs[uid] or {}
	local last=abilityCDs[uid][abilityName] or 0
	local cd=ABILITY_CD[abilityName] or 10
	if (now-last)<cd then RE.AbilityCooldown:FireClient(player,abilityName,cd-(now-last)); return end
	abilityCDs[uid][abilityName]=now
	RE.AbilityCooldown:FireClient(player,abilityName,cd)
	if abilityName=="dash" then
		local char=player.Character; if not char then return end
		local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
		local look=hrp.CFrame.LookVector; local np=hrp.Position+look*16
		hrp.CFrame=CFrame.new(np,np+look)
		RE.NotifyPlayer:FireClient(player,"💨 DASH!","","blue")
	elseif abilityName=="block" then
		playerBlocking[uid]=now
		RE.NotifyPlayer:FireClient(player,"🛡️ BLOCKING!","Damage reduced 85% for 2s!","blue")
		task.delay(2,function() if playerBlocking[uid]==now then playerBlocking[uid]=nil end end)
	end
end)

-- ── WEAPON SHOP ───────────────────────────────────────────────
RE.WeaponShopBuy.OnServerEvent:Connect(function(player,weaponId,action)
	local d=playerData[player.UserId]; if not d then return end
	local w=weaponById[weaponId]; if not w then return end
	local function replaceWeapon()
		d.equippedWeapon=weaponId
		local char=player.Character
		if char then
			for _,o in ipairs(char:GetChildren()) do if o:IsA("Tool") then o:Destroy() end end
		end
		local bp=player.Backpack
		if bp then for _,o in ipairs(bp:GetChildren()) do if o:IsA("Tool") then o:Destroy() end end end
		local tool=buildWeaponTool(weaponId)
		if tool then tool.Parent=char or player.Backpack end
	end
	if action=="buy" then
		local owned=false
		for _,ww in ipairs(d.ownedWeapons or {}) do if ww==weaponId then owned=true;break end end
		if owned then
			replaceWeapon(); pushStats(player)
			RE.NotifyPlayer:FireClient(player,"⚔️ Equipped!",w.name.." equipped!","green"); return
		end
		if d.coins<w.cost then
			RE.NotifyPlayer:FireClient(player,"❌ Not enough!","Need "..w.cost.." coins","red"); return
		end
		d.coins=d.coins-w.cost
		d.ownedWeapons=d.ownedWeapons or {}; table.insert(d.ownedWeapons,weaponId)
		d.weaponLevels=d.weaponLevels or {}; d.weaponLevels[weaponId]=1
		replaceWeapon(); pushStats(player)
		RE.NotifyPlayer:FireClient(player,"✅ Purchased!",w.name.." unlocked & equipped!","green")
	elseif action=="equip" then
		local owned=false
		for _,ww in ipairs(d.ownedWeapons or {}) do if ww==weaponId then owned=true;break end end
		if owned then
			replaceWeapon(); pushStats(player)
			RE.NotifyPlayer:FireClient(player,"⚔️ Equipped!",w.name.." equipped!","green")
		else
			RE.NotifyPlayer:FireClient(player,"❌ Not owned!","Buy "..w.name.." first!","red")
		end
	elseif action=="upgrade" then
		d.weaponLevels=d.weaponLevels or {}
		local lvl=d.weaponLevels[weaponId] or 1
		if lvl>=5 then RE.NotifyPlayer:FireClient(player,"MAX!",w.name.." is max level!","blue"); return end
		local cost=WEAPON_UPGRADE_COSTS[lvl]
		if d.coins<cost then RE.NotifyPlayer:FireClient(player,"❌ Need "..cost.." coins","","red"); return end
		d.coins=d.coins-cost; d.weaponLevels[weaponId]=lvl+1; pushStats(player)
		RE.NotifyPlayer:FireClient(player,"⬆️ "..w.name.." Lv"..(lvl+1).."!","+15% damage","green")
	end
end)

-- ── PLOT UPGRADE SHOP ─────────────────────────────────────────
RE.PlotUpgradeBuy.OnServerEvent:Connect(function(player,plotId,path)
	local d=playerData[player.UserId]; if not d then return end
	if not (d.ownedPlots and d.ownedPlots[plotId]) then
		RE.NotifyPlayer:FireClient(player,"❌ Not your plot!","","red"); return
	end
	local pd=PLOT_PATHS[path]; if not pd then return end
	d.plotUpgrades=d.plotUpgrades or {}
	d.plotUpgrades[plotId]=d.plotUpgrades[plotId] or {A=0,B=0,C=0}
	local lvl=d.plotUpgrades[plotId][path] or 0
	if lvl>=4 then RE.NotifyPlayer:FireClient(player,"MAX!",pd.name.." maxed!","blue"); return end
	local cost=pd.costs[lvl+1]
	if d.coins<cost then RE.NotifyPlayer:FireClient(player,"❌ Need "..cost.." coins","","red"); return end
	d.coins=d.coins-cost; d.plotUpgrades[plotId][path]=lvl+1
	local label=pd.labels and pd.labels[lvl+1] or (pd.name.." Lv "..(lvl+1))
	RE.NotifyPlayer:FireClient(player,"✅ "..pd.name.." Lv"..(lvl+1).."!",plotId..": "..label,"green")
	RE.MachineRate:FireClient(player,plotId,getPlotCoinValue(player,plotId),getPlotTickInterval(player,plotId))
	pushStats(player)
end)

-- ── GIVE WEAPON ON SPAWN ──────────────────────────────────────
local function giveWeapon(player)
	task.wait(0.5)
	local char=player.Character; if not char then return end
	for _,o in ipairs(char:GetChildren()) do if o:IsA("Tool") then o:Destroy() end end
	local bp=player.Backpack
	if bp then for _,o in ipairs(bp:GetChildren()) do if o:IsA("Tool") then o:Destroy() end end end
	local d=playerData[player.UserId]
	local wId=(d and d.equippedWeapon) or "CoinBlade"
	local tool=buildWeaponTool(wId); if tool then tool.Parent=char end
end

-- ── RAID SYSTEM ───────────────────────────────────────────────
local function isInPlot(pos,pdef)
	return math.abs(pos.X-pdef.cx)<=PLOT_HALF and math.abs(pos.Z-pdef.cz)<=PLOT_HALF
end
local function fireRaidAlert(plotId,active)
	if PlotRaidAlertBE then PlotRaidAlertBE:Fire(plotId,active) end
end

task.spawn(function()
	while true do
		task.wait(0.5); local now=os.time()
		for plotId,t in pairs(raidImmune) do
			if (now-t)>=getRaidImmune(plotId) then raidImmune[plotId]=nil end
		end
		for _,player in ipairs(Players:GetPlayers()) do
			local uid=player.UserId; local char=player.Character; if not char then continue end
			local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
			local pos=hrp.Position
			raidProgress[uid]=raidProgress[uid] or {}
			local myProg=raidProgress[uid]
			for plotId,ownerUid in pairs(serverPlotOwners) do
				if ownerUid==uid then
					local pdef=PLOT_CENTERS[plotId]
					if pdef and isInPlot(pos,pdef) then
						for rid,prog in pairs(raidProgress) do
							if rid~=uid and prog[plotId] and prog[plotId]>0 then
								prog[plotId]=nil
								local raider=Players:GetPlayerByUserId(rid)
								if raider then
									RE.RaidStatus:FireClient(raider,plotId,"",-1)
									RE.NotifyPlayer:FireClient(raider,"🛡️ Blocked!",player.Name.." defended!","red")
								end
								RE.NotifyPlayer:FireClient(player,"🛡️ DEFENDED!","You blocked the raid!","green")
							end
						end
						if raidActiveOnPlot[plotId] then raidActiveOnPlot[plotId]=nil; fireRaidAlert(plotId,false) end
					end
					continue
				end
				local pdef=PLOT_CENTERS[plotId]; if not pdef then continue end
				if raidImmune[plotId] and (now-raidImmune[plotId])<getRaidImmune(plotId) then
					if myProg[plotId] then myProg[plotId]=nil; RE.RaidStatus:FireClient(player,plotId,"",-1)
						if raidActiveOnPlot[plotId] then raidActiveOnPlot[plotId]=nil; fireRaidAlert(plotId,false) end end
					continue
				end
				local ownerPlayer=Players:GetPlayerByUserId(ownerUid)
				if ownerPlayer and ownerPlayer.Character then
					local ohrp=ownerPlayer.Character:FindFirstChild("HumanoidRootPart")
					if ohrp and isInPlot(ohrp.Position,pdef) then
						if myProg[plotId] then myProg[plotId]=nil; RE.RaidStatus:FireClient(player,plotId,"",-1) end
						continue
					end
				end
				if isInPlot(pos,pdef) then
					myProg[plotId]=(myProg[plotId] or 0)+0.5
					local rt=getRaidTime(plotId)
					local ownerName=ownerPlayer and ownerPlayer.Name or "Someone"
					RE.RaidStatus:FireClient(player,plotId,ownerName,math.min(1,myProg[plotId]/rt))
					if not raidActiveOnPlot[plotId] then raidActiveOnPlot[plotId]=true; fireRaidAlert(plotId,true) end
					if ownerPlayer then
						local warned=(raidWarned[ownerUid] or {})[plotId] or 0
						if (now-warned)>=2 then
							raidWarned[ownerUid]=raidWarned[ownerUid] or {}
							raidWarned[ownerUid][plotId]=now
							RE.RaidStatus:FireClient(ownerPlayer,plotId,player.Name,-99)
							RE.NotifyPlayer:FireClient(ownerPlayer,"🚨 RAID!",player.Name.." is stealing your "..plotId.."! STAND ON IT!","red")
						end
					end
					if myProg[plotId]>=rt then
						myProg[plotId]=nil; RE.RaidStatus:FireClient(player,plotId,"",-1)
						local d=playerData[uid]; local oldD=playerData[ownerUid]; if not d then continue end
						local fee=math.floor(pdef.cost*0.25)
						if d.coins<fee then
							RE.NotifyPlayer:FireClient(player,"❌ Raid Failed!","Need "..fee.." coins fee","red")
							if raidActiveOnPlot[plotId] then raidActiveOnPlot[plotId]=nil; fireRaidAlert(plotId,false) end
							continue
						end
						d.coins=d.coins-fee
						if oldD and oldD.ownedPlots then oldD.ownedPlots[plotId]=nil end
						if plotTickLast[ownerUid] then plotTickLast[ownerUid][plotId]=nil end
						d.ownedPlots=d.ownedPlots or {}; d.ownedPlots[plotId]=true
						serverPlotOwners[plotId]=uid
						plotTickLast[uid]=plotTickLast[uid] or {}; plotTickLast[uid][plotId]=now
						raidImmune[plotId]=now
						if raidActiveOnPlot[plotId] then raidActiveOnPlot[plotId]=nil; fireRaidAlert(plotId,false) end
						for rid2,prog2 in pairs(raidProgress) do
							if rid2~=uid and prog2[plotId] then prog2[plotId]=nil
								local r2=Players:GetPlayerByUserId(rid2)
								if r2 then RE.RaidStatus:FireClient(r2,plotId,"",-1) end
							end
						end
						RE.NotifyPlayer:FireClient(player,"⚔️ Machine Raided!","Stolen! (-"..fee.." fee)","green")
						if ownerPlayer then RE.NotifyPlayer:FireClient(ownerPlayer,"💀 Stolen!",player.Name.." raided your "..plotId.."!","red") end
						for _,p in ipairs(Players:GetPlayers()) do
							if p~=player and p~=ownerPlayer then
								RE.NotifyPlayer:FireClient(p,"⚔️ Raid!",player.Name.." stole "..plotId.."!","red")
							end
						end
						if PlotTransferBE then PlotTransferBE:Fire(plotId,player) end
						RE.MachineRate:FireClient(player,plotId,getPlotCoinValue(player,plotId),getPlotTickInterval(player,plotId))
						pushStats(player)
						if oldD then local op=Players:GetPlayerByUserId(ownerUid); if op then pushStats(op) end end
					end
				else
					if myProg[plotId] then
						myProg[plotId]=nil; RE.RaidStatus:FireClient(player,plotId,"",-1)
						local still=false
						for rid2,prog2 in pairs(raidProgress) do
							if rid2~=uid and prog2[plotId] and prog2[plotId]>0 then still=true;break end
						end
						if not still and raidActiveOnPlot[plotId] then raidActiveOnPlot[plotId]=nil; fireRaidAlert(plotId,false) end
					end
				end
			end
		end
	end
end)

-- ── HOT ZONE PICKPOCKET ───────────────────────────────────────
local function isInHotZone(pos)
	for _,c in ipairs(HOT_ZONE_CENTERS) do
		if math.abs(pos.X-c.cx)<=PLOT_HALF and math.abs(pos.Z-c.cz)<=PLOT_HALF then return true end
	end
	return false
end
task.spawn(function()
	while true do
		task.wait(10); local hot={}
		for _,p in ipairs(Players:GetPlayers()) do
			local c=p.Character; if not c then continue end
			local hrp=c:FindFirstChild("HumanoidRootPart")
			if hrp and isInHotZone(hrp.Position) then table.insert(hot,p) end
		end
		if #hot<2 then continue end
		for _,thief in ipairs(hot) do
			if math.random()>0.25 then continue end
			local vs={}; for _,p in ipairs(hot) do if p~=thief then table.insert(vs,p) end end
			if #vs==0 then continue end
			local vic=vs[math.random(#vs)]
			local td=playerData[thief.UserId]; local vd=playerData[vic.UserId]
			if not td or not vd or vd.coins<10 then continue end
			local st=math.max(10,math.min(300,math.floor(vd.coins*0.08)))
			if vd.coins<st then continue end
			vd.coins=vd.coins-st; td.coins=td.coins+st
			vic:SetAttribute("Coins",vd.coins); thief:SetAttribute("Coins",td.coins)
			RE.NotifyPlayer:FireClient(thief,"🦹 Pickpocket!","Stole "..st.." from "..vic.Name.."!","green")
			RE.NotifyPlayer:FireClient(vic,"💸 Pickpocketed!",thief.Name.." stole "..st.." in the hot zone!","red")
			statsDirty[thief.UserId]=true; statsDirty[vic.UserId]=true
		end
	end
end)

-- ── RANDOM EVENTS ─────────────────────────────────────────────
local CoinRainBE=Instance.new("BindableEvent",ReplicatedStorage); CoinRainBE.Name="CoinRain_BE"
local GeyserSurgeBE=Instance.new("BindableEvent",ReplicatedStorage); GeyserSurgeBE.Name="GeyserSurge_BE"

task.spawn(function()
	task.wait(120)
	while true do
		task.wait(math.random(180,360))
		local avail={}
		for _,ev in ipairs(RANDOM_EVENTS) do
			if not activeEvents[ev.id] then table.insert(avail,ev) end
		end
		if #avail==0 then continue end
		local ev=avail[math.random(#avail)]
		activeEvents[ev.id]={id=ev.id,expires=os.time()+ev.dur}
		RE.NotifyPlayer:FireAllClients("🌟 "..ev.name,ev.desc,ev.col)
		RE.RandomEvent:FireAllClients(ev.id,ev.name,ev.desc,ev.col,ev.dur)
		if ev.id=="CoinRain" then CoinRainBE:Fire()
		elseif ev.id=="GeyserSurge" then GeyserSurgeBE:Fire()
		elseif ev.id=="GoldenHour" then
			local picks={}
			for plotId,uid in pairs(serverPlotOwners) do table.insert(picks,{plotId=plotId,uid=uid}) end
			if #picks>0 then
				local pick=picks[math.random(#picks)]
				goldenPlotData={uid=pick.uid,plotId=pick.plotId}
				local owner=Players:GetPlayerByUserId(pick.uid)
				if owner then RE.NotifyPlayer:FireClient(owner,"✨ GOLDEN MACHINE!","Your "..pick.plotId.." earns 10× for "..ev.dur.."s!","gold") end
				task.delay(ev.dur,function() goldenPlotData=nil end)
			end
		end
		task.delay(ev.dur,function()
			activeEvents[ev.id]=nil
			RE.RandomEvent:FireAllClients(ev.id.."_END",ev.name,"Event ended!","blue",0)
		end)
	end
end)

-- ── PLAYER JOIN / LEAVE ───────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	local d=loadData(player)
	player:SetAttribute("Rebirths",d.rebirths)
	playerHP[player.UserId]=MAX_HP
	task.spawn(function()
		checkGamepasses(player)
		if player.Character then applySpeedDemon(player); giveWeapon(player) end
		pushStats(player); sendHP(player)
		task.wait(1)
		if player.Parent then
			RE.WeaponInfo:FireClient(player,WEAPONS,WEAPON_UPGRADE_COSTS,PLOT_PATHS)
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		playerHP[player.UserId]=MAX_HP; playerDead[player.UserId]=nil
		applySpeedDemon(player); giveWeapon(player); sendHP(player)
	end)
	if d._offlineBonus and d._offlineBonus>0 then
		local bonus=d._offlineBonus; d._offlineBonus=nil
		task.delay(3,function()
			if player.Parent then RE.NotifyPlayer:FireClient(player,"💤 Offline Bonus!","+"..bonus.." coins while away!","gold") end
		end)
	end
	task.spawn(function()
		while player.Parent do task.wait(60); if player.Parent then d.playTime=(d.playTime or 0)+60; saveData(player) end end
	end)
	local ls=Instance.new("Folder",player); ls.Name="leaderstats"
	local cv=Instance.new("IntValue",ls); cv.Name="Coins";       cv.Value=0
	local rv=Instance.new("IntValue",ls); rv.Name="Rebirths";    rv.Value=d.rebirths
	local tv=Instance.new("IntValue",ls); tv.Name="Total Earned";tv.Value=d.totalEarned
end)

Players.PlayerRemoving:Connect(function(player)
	local uid=player.UserId; local d=playerData[uid]
	if d and d.ownedPlots then
		for plotId,owned in pairs(d.ownedPlots) do
			if owned and serverPlotOwners[plotId]==uid then
				serverPlotOwners[plotId]=nil
				if PlotRelockBE then PlotRelockBE:Fire(plotId) end
			end
		end
	end
	saveData(player)
	playerData[uid]=nil; playerGP[uid]=nil; plotTickLast[uid]=nil
	statsDirty[uid]=nil; magnetCDs[uid]=nil; raidProgress[uid]=nil
	raidWarned[uid]=nil; weaponHitCDs[uid]=nil; abilityCDs[uid]=nil
	playerHP[uid]=nil; playerDead[uid]=nil; playerBlocking[uid]=nil
end)
game:BindToClose(function() for _,p in ipairs(Players:GetPlayers()) do saveData(p) end; task.wait(2) end)

-- ── BUY UPGRADE ───────────────────────────────────────────────
RE.BuyUpgrade.OnServerEvent:Connect(function(player,upgradeKey)
	local d=playerData[player.UserId]; if not d then return end
	local upg=getUpgrade(upgradeKey); if not upg then return end
	local level=d.upgrades[upgradeKey] or 0
	if level>=upg.maxLevel then RE.NotifyPlayer:FireClient(player,"MAX",upg.name.." maxed!","blue"); return end
	local cost=getUpgradeCost(upg,level)
	if d.coins<cost then RE.NotifyPlayer:FireClient(player,"❌ Need "..cost.." coins","","red"); return end
	d.coins=d.coins-cost; d.upgrades[upgradeKey]=level+1; pushStats(player)
	RE.NotifyPlayer:FireClient(player,"✅ Upgraded!",upg.icon.." "..upg.name.." → Lv "..(level+1),"green")
	if upgradeKey=="touchSpeed" or upgradeKey=="coinValue" then
		if d.ownedPlots then
			for plotId,owned in pairs(d.ownedPlots) do
				if owned then RE.MachineRate:FireClient(player,plotId,getPlotCoinValue(player,plotId),getPlotTickInterval(player,plotId)) end
			end
		end
	end
end)

-- ── REBIRTH ───────────────────────────────────────────────────
RE.Rebirth.OnServerEvent:Connect(function(player)
	local d=playerData[player.UserId]; if not d then return end
	local cost=math.floor(75000*(2^d.rebirths))
	if d.coins<cost then RE.NotifyPlayer:FireClient(player,"❌ Need "..cost.." coins","Prestige costs more","red"); return end
	local uid=player.UserId
	for plotId,owned in pairs(d.ownedPlots or {}) do
		if owned and serverPlotOwners[plotId]==uid then serverPlotOwners[plotId]=nil end
	end
	plotTickLast[uid]=nil
	local now=os.time()
	if (now-(d.lastPrestige or 0))<=3600 then d.prestigeStreak=math.min((d.prestigeStreak or 0)+1,5)
	else d.prestigeStreak=0 end
	d.lastPrestige=now
	local keptU={}; local kc=0
	for k,v in pairs(d.upgrades) do local kept=math.floor(v*0.25); if kept>0 then keptU[k]=kept; kc=kc+1 end end
	d.coins=0; d.upgrades=keptU; d.ownedPlots={}; d.plotUpgrades={}; d.rebirths=d.rebirths+1
	prestigeWarned[uid]=nil; player:SetAttribute("Rebirths",d.rebirths); pushStats(player)
	local gp=playerGP[uid] or {}; local mult=gp.prestigeBoost and "3x" or "2x"
	local tags={"🔥 REBORN","⚡ ASCENDED","🌙 TRANSCENDED","🌌 LEGENDARY"}
	local tag=tags[math.min(d.rebirths,#tags)] or "🌌 LEGENDARY"
	local str=d.prestigeStreak>0 and (" 🔥×"..d.prestigeStreak) or ""
	RE.NotifyPlayer:FireClient(player,tag.." x"..d.rebirths,mult.." income mult!"..str,"gold")
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=player then RE.NotifyPlayer:FireClient(p,"🔥 "..player.Name,tag.." prestige ×"..d.rebirths.."!","gold") end
	end
	if PrestigeResetBE then PrestigeResetBE:Fire(uid) end
	task.defer(function()
		local char=player.Character; if not char then return end
		local hrp=char:FindFirstChild("HumanoidRootPart"); if hrp then hrp.CFrame=CFrame.new(0,4,0) end
	end)
end)

-- ── DAILY REWARD ──────────────────────────────────────────────
RE.ClaimDaily.OnServerEvent:Connect(function(player)
	local d=playerData[player.UserId]; if not d then return end
	local now=os.time(); local h=(now-(d.lastDaily or 0))/3600
	if h<20 then RE.NotifyPlayer:FireClient(player,"⏰ Too soon","Daily resets in "..math.ceil(20-h).."h","blue"); return end
	if h>48 then d.dailyStreak=0 end
	d.dailyStreak=math.min((d.dailyStreak or 0)+1,#DAILY_REWARDS)
	local reward=DAILY_REWARDS[d.dailyStreak]
	d.coins=d.coins+reward; d.totalEarned=(d.totalEarned or 0)+reward; d.lastDaily=now
	pushStats(player)
	RE.NotifyPlayer:FireClient(player,"🎁 Day "..d.dailyStreak.." Reward!","+"..reward.." coins!","gold")
end)

-- ── REQUEST DATA ──────────────────────────────────────────────
RE.RequestData.OnServerInvoke=function(player)
	local d=playerData[player.UserId]; if d then d._gp=playerGP[player.UserId] or {} end
	return d,UPGRADES
end

-- ── MARKETPLACE ───────────────────────────────────────────────
MarketplaceService.ProcessReceipt=function(info)
	local player=Players:GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local d=playerData[player.UserId]
	if not d then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local amounts={[PRODUCTS.COINS_SMALL]=500,[PRODUCTS.COINS_MEDIUM]=2500,[PRODUCTS.COINS_LARGE]=10000}
	if amounts[info.ProductId] then
		local amt=amounts[info.ProductId]; d.coins=d.coins+amt; d.totalEarned=d.totalEarned+amt
		pushStats(player); RE.NotifyPlayer:FireClient(player,"💰 Purchase!","+"..amt.." coins!","gold")
		saveData(player); return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif info.ProductId==PRODUCTS.RESET then
		d.upgrades={}; pushStats(player)
		RE.NotifyPlayer:FireClient(player,"🔄 Reset!","Upgrades cleared!","blue")
		saveData(player); return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ── PLOT PURCHASE ─────────────────────────────────────────────
local PlotPurchaseBE=ReplicatedStorage:WaitForChild("PlotPurchase",15)
PlotPurchaseBE.Event:Connect(function(player,plotId,cost)
	local d=playerData[player.UserId]
	if not d then RE.NotifyPlayer:FireClient(player,"❌ Data not loaded","Try again","red"); return end
	if d.ownedPlots and d.ownedPlots[plotId] then return end
	if d.coins<cost then RE.NotifyPlayer:FireClient(player,"❌ Not enough coins!","Need "..tostring(cost).." coins","red"); return end
	d.coins=d.coins-cost; d.ownedPlots=d.ownedPlots or {}; d.ownedPlots[plotId]=true
	serverPlotOwners[plotId]=player.UserId
	plotTickLast[player.UserId]=plotTickLast[player.UserId] or {}
	plotTickLast[player.UserId][plotId]=os.time()
	pushStats(player)
	RE.NotifyPlayer:FireClient(player,"✅ Plot Claimed!","Auto-earning "..getPlotCoinValue(player,plotId).." every "..getPlotTickInterval(player,plotId).."s!","green")
	if plotUnlockedBE then plotUnlockedBE:Fire(plotId,player) end
	RE.MachineRate:FireClient(player,plotId,getPlotCoinValue(player,plotId),getPlotTickInterval(player,plotId))
end)

print("[MoneyIsland] ✅ Server v19 loaded! HP PvP, 4 weapons, building upgrades, random events.")

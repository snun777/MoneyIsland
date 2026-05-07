-- MainGameServer.server.lua (v15 - Free plot access, raiding, hot-zone pickpocket, magnet premium-only)

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- Create CoinCollected_BE first — MapBuilder WaitForChild's for it
local coinBE = Instance.new("BindableEvent")
coinBE.Name   = "CoinCollected_BE"
coinBE.Parent = ReplicatedStorage

-- Wait for events created by MapBuilder
local CoinDestroyBE    = nil
local GeyserActivateBE = nil
local PlotRelockBE     = nil
local PrestigeResetBE  = nil
local plotUnlockedBE   = nil
local PlotTransferBE   = nil
task.spawn(function()
	CoinDestroyBE    = ReplicatedStorage:WaitForChild("CoinDestroy_BE",    20)
	GeyserActivateBE = ReplicatedStorage:WaitForChild("GeyserActivate_BE", 20)
	PlotRelockBE     = ReplicatedStorage:WaitForChild("PlotRelock_BE",     20)
	PrestigeResetBE  = ReplicatedStorage:WaitForChild("PrestigeReset_BE",  20)
	plotUnlockedBE   = ReplicatedStorage:WaitForChild("PlotUnlocked",      20)
	PlotTransferBE   = ReplicatedStorage:WaitForChild("PlotTransfer_BE",   20)
end)

-- ── CONFIG ────────────────────────────────────────────────────
local GP = {
	DOUBLE_COINS   = 1821720069,
	MEGA_MAGNET    = 1822515059,
	LUCKY_CHARM    = 1821659972,
	SPEED_DEMON    = 1822655551,
	PRESTIGE_BOOST = 1822649609,
	AUTO_FARM      = 1823064828,
}
local PRODUCTS = {
	COINS_SMALL  = 3586040050,
	COINS_MEDIUM = 3586040263,
	COINS_LARGE  = 3586040422,
	RESET        = 3586040561,
}

local BASE_COIN_VALUE = 5
local REBIRTH_MULT    = 2
local DAILY_REWARDS   = {100,200,350,500,750,1000,2500}

-- Auto-tick: owned plots generate coins at this interval (modified by touchSpeed upgrade)
local TICK_BASE       = 30  -- seconds between ticks at level 0
local TICK_FLOOR      = 1   -- minimum tick interval

-- Geyser: max coins a single player can collect per geyser per burst
local GEYSER_CAP      = 4

-- ── UPGRADES ──────────────────────────────────────────────────
local UPGRADES = {
	{
		key="coinMagnet", name="Magnet Range", icon="🧲",
		desc="Requires Mega Magnet pass. Widens grab range.",
		maxLevel=9999, baseCost=120, costMult=1.15,
		effect=function(lvl) return 5 + lvl*3 end,
	},
	{
		key="touchSpeed", name="Plot Speed", icon="⚡",
		desc="Faster auto-tick on owned plots",
		maxLevel=29, baseCost=80, costMult=1.2,
		effect=function(lvl) return math.max(TICK_FLOOR, TICK_BASE - lvl) end,
	},
	{
		key="coinValue", name="Coin Value", icon="💰",
		desc="More coins per tick and per collect",
		maxLevel=9999, baseCost=200, costMult=1.15,
		effect=function(lvl) return 1 + lvl*0.5 end,
	},
	{
		key="offlineVault", name="Offline Vault", icon="🏦",
		desc="Earn coins while offline (1h per level)",
		maxLevel=8, baseCost=500, costMult=2.0,
		effect=function(lvl) return lvl end,
	},
}

local function getUpgrade(key)
	for _,u in ipairs(UPGRADES) do if u.key==key then return u end end
end

local function getUpgradeCost(upg, level)
	return math.floor(upg.baseCost * (upg.costMult ^ level))
end

-- ── REMOTES ───────────────────────────────────────────────────
local function ensureRemote(class, name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then r = Instance.new(class); r.Name = name; r.Parent = ReplicatedStorage end
	return r
end

local RE = {
	UpdateStats  = ensureRemote("RemoteEvent",    "UpdateStats"),
	BuyUpgrade   = ensureRemote("RemoteEvent",    "BuyUpgrade"),
	Rebirth      = ensureRemote("RemoteEvent",    "Rebirth"),
	ClaimDaily   = ensureRemote("RemoteEvent",    "ClaimDaily"),
	ShowShop     = ensureRemote("RemoteEvent",    "ShowShop"),
	NotifyPlayer = ensureRemote("RemoteEvent",    "NotifyPlayer"),
	RequestData  = ensureRemote("RemoteFunction", "RequestData"),
	MagnetCollect= ensureRemote("RemoteEvent",    "MagnetCollect"),
	PlotTick     = ensureRemote("RemoteEvent",    "PlotTick_RE"),
	RaidStatus   = ensureRemote("RemoteEvent",    "RaidStatus_RE"),
}

-- ── PLOT POSITION LOOKUP (matches MapBuilder PLOT_DEFS) ──────────
-- Used server-side for raid proximity checks
local PLOT_CENTERS = {
	L_N   = {cx=-50,  cz=50,   cost=2000},
	R_N   = {cx=50,   cz=50,   cost=2000},
	L_S   = {cx=-50,  cz=-50,  cost=2000},
	R_S   = {cx=50,   cz=-50,  cost=2000},
	LL_M  = {cx=-100, cz=0,    cost=10000},
	RR_M  = {cx=100,  cz=0,    cost=10000},
	C_NN  = {cx=0,    cz=100,  cost=10000},
	C_SS  = {cx=0,    cz=-100, cost=10000},
	LL_N  = {cx=-100, cz=50,   cost=25000},
	LL_S  = {cx=-100, cz=-50,  cost=25000},
	RR_N  = {cx=100,  cz=50,   cost=25000},
	RR_S  = {cx=100,  cz=-50,  cost=25000},
	L_NN  = {cx=-50,  cz=100,  cost=25000},
	R_NN  = {cx=50,   cz=100,  cost=25000},
	L_SS  = {cx=-50,  cz=-100, cost=25000},
	R_SS  = {cx=50,   cz=-100, cost=25000},
	LL_NN = {cx=-100, cz=100,  cost=50000},
	RR_NN = {cx=100,  cz=100,  cost=50000},
	LL_SS = {cx=-100, cz=-100, cost=50000},
	RR_SS = {cx=100,  cz=-100, cost=50000},
}
local PLOT_HALF = 25  -- half of PLOT_W (50)

-- Geyser centers for hot-zone pickpocket detection
local HOT_ZONE_CENTERS = {
	{cx=0,   cz=0},
	{cx=-50, cz=0},
	{cx=50,  cz=0},
	{cx=0,   cz=50},
	{cx=0,   cz=-50},
}

-- ── RAID STATE ────────────────────────────────────────────────────
local RAID_TIME    = 4    -- seconds standing on enemy plot to complete a raid
local RAID_IMMUNE  = 240  -- 4 minutes immunity after being raided
local raidProgress = {}   -- [raiderId][plotId] = seconds accumulated
local raidImmune   = {}   -- [plotId] = os.time() when last raided
local raidWarned   = {}   -- [ownerUid][plotId] = last warn timestamp (throttle spam)

-- ── DATA STORE ────────────────────────────────────────────────
local DS = DataStoreService:GetDataStore("MoneyIsland_v17")

local DEFAULT_DATA = {
	coins=0, totalEarned=0, rebirths=0,
	upgrades={},
	lastDaily=0, dailyStreak=0,
	lastSave=0, playTime=0,
	prestigeStreak=0, lastPrestige=0,
}

local playerData = {}
local playerGP   = {}  -- userId → {doubleCoin, megaMagnet, ...}

-- Session-only: plot ownership (not persisted, resets each server session)
local serverPlotOwners = {}  -- plotId → userId

-- Geyser burst limits (reset on each geyser activation)
local geyserLimits  = {}  -- geyserLimits[geyserIdx][userId] = count
local megaBurstActive = {} -- megaBurstActive[geyserIdx] = true during mega burst (no cap)

-- Auto-tick state: last time each player's plot ticked
local plotTickLast = {}  -- plotTickLast[userId][plotId] = os.time()

local function deepCopy(t)
	local c = {}
	for k,v in pairs(t) do c[k] = type(v)=="table" and deepCopy(v) or v end
	return c
end

local function loadData(player)
	local ok, data = pcall(function()
		return DS:GetAsync("MI17_"..player.UserId)
	end)
	local d = deepCopy(DEFAULT_DATA)
	if ok and data then
		for k,v in pairs(data) do d[k]=v end
	end

	-- Offline vault bonus (based on how long they were away)
	if d.lastSave and d.lastSave > 0 then
		local offlineSecs = os.time() - d.lastSave
		local vaultLvl   = d.upgrades["offlineVault"] or 0
		if vaultLvl > 0 then
			local maxSecs      = vaultLvl * 3600
			local effectiveSecs= math.min(offlineSecs, maxSecs)
			local cd           = math.max(TICK_FLOOR, TICK_BASE - (d.upgrades["touchSpeed"] or 0))
			local cvLvl        = d.upgrades["coinValue"] or 0
			local rebirthBase  = REBIRTH_MULT
			local coinVal      = math.floor(BASE_COIN_VALUE * (1 + cvLvl*0.5) * (rebirthBase ^ (d.rebirths or 0)))
			-- Offline vault simulates a single plot's tick rate × vault hours
			local ticks  = math.floor(effectiveSecs / cd)
			local earned = ticks * coinVal
			if earned > 0 then
				d.coins       = d.coins + earned
				d.totalEarned = d.totalEarned + earned
				d._offlineBonus = earned
			end
		end
	end

	d.lastSave  = os.time()
	d.ownedPlots = {}  -- always start session with no owned plots (session-only ownership)
	playerData[player.UserId] = d
	return d
end

local function saveData(player)
	local d = playerData[player.UserId]
	if not d then return end
	d.lastSave = os.time()
	local toSave = deepCopy(d)
	toSave._gp        = nil
	toSave.ownedPlots  = nil  -- not persisted; session-only
	toSave._offlineBonus = nil
	pcall(function() DS:SetAsync("MI17_"..player.UserId, toSave) end)
end

local cachedRanking  = {}
local lastRankBuild  = 0
local function buildRanking()
	if os.time() - lastRankBuild < 8 then return cachedRanking end
	lastRankBuild = os.time()
	local entries = {}
	for uid, d in pairs(playerData) do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			table.insert(entries, {name=p.Name, coins=math.floor(d.coins), rebirths=d.rebirths})
		end
	end
	table.sort(entries, function(a,b) return a.coins > b.coins end)
	cachedRanking = entries
	return entries
end

local function pushStats(player)
	local d = playerData[player.UserId]
	if not d then return end
	d._gp      = playerGP[player.UserId] or {}
	d._ranking = buildRanking()
	RE.UpdateStats:FireClient(player, d, UPGRADES)
end

-- ── GAMEPASS CHECKS ───────────────────────────────────────────
local function checkGamepasses(player)
	local gps = {}
	for _, c in ipairs({
		{key="doubleCoin",    id=GP.DOUBLE_COINS},
		{key="megaMagnet",    id=GP.MEGA_MAGNET},
		{key="luckyCharm",    id=GP.LUCKY_CHARM},
		{key="speedDemon",    id=GP.SPEED_DEMON},
		{key="prestigeBoost", id=GP.PRESTIGE_BOOST},
		{key="autoFarm",      id=GP.AUTO_FARM},
	}) do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, c.id)
		gps[c.key] = ok and owns or false
	end
	playerGP[player.UserId] = gps
	return gps
end

local function applySpeedDemon(player)
	local gp   = playerGP[player.UserId]
	local char = player.Character
	if not gp or not gp.speedDemon or not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = math.floor(hum.WalkSpeed * 1.2) end
end

-- ── COIN VALUE ────────────────────────────────────────────────
local function getCoinValue(player)
	local d  = playerData[player.UserId]
	if not d then return BASE_COIN_VALUE end
	local gp = playerGP[player.UserId] or {}
	local mult  = 1
	local cvLvl = d.upgrades["coinValue"] or 0
	if cvLvl > 0 then mult = mult * (1 + cvLvl*0.5) end
	local rebirthBase = gp.prestigeBoost and 3 or REBIRTH_MULT
	mult = mult * (rebirthBase ^ d.rebirths)
	if gp.doubleCoin then mult = mult * 2 end
	-- Prestige streak: +10% per consecutive prestige within 1h, up to +50%
	local streak = d.prestigeStreak or 0
	if streak > 0 then mult = mult * (1 + 0.1 * math.min(streak, 5)) end
	return math.floor(BASE_COIN_VALUE * mult)
end

local function getTickInterval(player)
	local d  = playerData[player.UserId]
	if not d then return TICK_BASE end
	local gp = playerGP[player.UserId] or {}
	local cd = math.max(TICK_FLOOR, TICK_BASE - (d.upgrades["touchSpeed"] or 0))
	if gp.autoFarm then cd = math.max(TICK_FLOOR, math.floor(cd/2)) end
	return cd
end

-- ── GEYSER LIMIT TRACKING ─────────────────────────────────────
-- Called by MapBuilder when a geyser activates (resets per-player cap for that geyser)
task.spawn(function()
	while not GeyserActivateBE do task.wait(0.1) end
	GeyserActivateBE.Event:Connect(function(geyserIdx)
		geyserLimits[geyserIdx] = {}
	end)
end)

-- MegaBurst: fired by MapBuilder — disable cap for that geyser for 12s
task.spawn(function()
	local MegaBurstBE = ReplicatedStorage:WaitForChild("MegaBurst_BE", 20)
	if not MegaBurstBE then return end
	MegaBurstBE.Event:Connect(function(geyserIdx)
		megaBurstActive[geyserIdx] = true
		RE.NotifyPlayer:FireAllClients("⚡ MEGA BURST!", "Geyser "..geyserIdx.." — no cap for 10s!", "gold")
		task.delay(12, function() megaBurstActive[geyserIdx] = nil end)
	end)
end)

-- ── COIN COLLECTION HANDLER ───────────────────────────────────
-- fired by MapBuilder's geyser coin Touched: (player, isRare, geyserIdx, coinRef, isMega)
coinBE.Event:Connect(function(player, isRare, geyserIdx, coinRef, isMega)
	local d  = playerData[player.UserId]
	local gp = playerGP[player.UserId] or {}
	if not d then return end

	-- No per-player cap for walking collection — only magnet is limited
	-- Destroy the coin (server-authoritative — only happens when credit succeeds)
	if CoinDestroyBE and coinRef and coinRef.Parent then
		CoinDestroyBE:Fire(coinRef)
	end

	local coins = getCoinValue(player)

	if isRare then
		coins = coins * 5
		d.coins = d.coins + coins; d.totalEarned = (d.totalEarned or 0) + coins
		player:SetAttribute("Coins", d.coins)
		player:SetAttribute("TotalEarned", d.totalEarned)
		pushStats(player)
		RE.NotifyPlayer:FireClient(player, "💎 RARE COIN! ×5", "+"..coins.." coins!", "blue")
		return
	end

	local jackpotChance = gp.luckyCharm and 6 or 3
	if math.random(100) <= jackpotChance then
		coins = coins * 10
		RE.NotifyPlayer:FireClient(player, "🍀 JACKPOT!", "×10 coins!", "green")
	end

	d.coins = d.coins + coins; d.totalEarned = (d.totalEarned or 0) + coins
	player:SetAttribute("Coins", d.coins)
	player:SetAttribute("TotalEarned", d.totalEarned)
	pushStats(player)
	RE.NotifyPlayer:FireClient(player, "💰 +"..coins, "coin!", "gold")
end)

-- ── MAGNET COLLECT ────────────────────────────────────────────
-- Client sends the specific coin Part it wants to collect; server validates + credits
local magnetCooldowns = {}

RE.MagnetCollect.OnServerEvent:Connect(function(player, coinRef)
	if magnetCooldowns[player.UserId] then return end
	magnetCooldowns[player.UserId] = true
	task.delay(0.2, function() magnetCooldowns[player.UserId] = nil end)

	-- Validate coin still exists and is a geyser coin
	if not coinRef or not coinRef.Parent then return end
	if not coinRef:GetAttribute("GeyserCoin") then return end

	-- Magnet requires the Mega Magnet gamepass
	local gp = playerGP[player.UserId] or {}
	if not gp.megaMagnet then return end

	-- Distance check (server-side, can't be spoofed)
	local char = player.Character
	if not char then return end
	local hrp  = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local d  = playerData[player.UserId]
	if not d then return end

	local magnetLvl = d.upgrades["coinMagnet"] or 0
	local range     = 5 + magnetLvl*3 + 15  -- always +15 since megaMagnet is required
	if (hrp.Position - coinRef.Position).Magnitude > range then return end

	-- Geyser cap check
	local geyserIdx = coinRef:GetAttribute("GeyserIdx")
	if geyserIdx then
		local g = geyserLimits[geyserIdx]
		if not g then g = {}; geyserLimits[geyserIdx] = g end
		local count = g[player.UserId] or 0
		if count >= GEYSER_CAP then return end
		g[player.UserId] = count + 1
	end

	-- Credit and destroy
	local isRare = coinRef:GetAttribute("RareCoin")
	local coins  = getCoinValue(player)
	if isRare then coins = coins * 5 end

	if CoinDestroyBE and coinRef.Parent then CoinDestroyBE:Fire(coinRef) end

	d.coins = d.coins + coins; d.totalEarned = (d.totalEarned or 0) + coins
	player:SetAttribute("Coins", d.coins)
	player:SetAttribute("TotalEarned", d.totalEarned)
	pushStats(player)
	if isRare then
		RE.NotifyPlayer:FireClient(player, "💎 RARE COIN! ×5", "+"..coins.." magnet!", "blue")
	end
end)

-- ── AUTO-TICK: OWNED PLOT INCOME ──────────────────────────────
-- Every second, check each player's owned plots and credit them on their tick interval
local statsDirty = {}  -- userId → true (batch pushStats every 5s)

task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, player in ipairs(Players:GetPlayers()) do
			local uid = player.UserId
			local d   = playerData[uid]
			if not d or not d.ownedPlots then continue end

			local cd    = getTickInterval(player)
			local coins = getCoinValue(player)

			if not plotTickLast[uid] then plotTickLast[uid] = {} end
			local pts     = plotTickLast[uid]
			local earned  = 0

			for plotId, owned in pairs(d.ownedPlots) do
				if owned then
					local last = pts[plotId] or 0
					if (now - last) >= cd then
						pts[plotId] = now
						earned      = earned + coins
					end
				end
			end

			if earned > 0 then
				d.coins       = d.coins + earned
				d.totalEarned = (d.totalEarned or 0) + earned
				player:SetAttribute("Coins", d.coins)
				player:SetAttribute("TotalEarned", d.totalEarned)
				statsDirty[uid] = true
				RE.PlotTick:FireClient(player, earned, cd)
			end
		end
	end
end)

-- Prestige race: warn all other players when someone hits 80% of prestige cost
local prestigeWarned = {}   -- userId → true when 80% warning has fired this prestige cycle
task.spawn(function()
	while true do
		task.wait(5)
		local allPlayers = Players:GetPlayers()
		for _, player in ipairs(allPlayers) do
			local uid = player.UserId
			local d   = playerData[uid]
			if not d then continue end
			local cost = math.floor(10000 * (3 ^ d.rebirths))
			local pct  = d.coins / math.max(1, cost)
			if pct >= 0.8 and not prestigeWarned[uid] then
				prestigeWarned[uid] = true
				for _, p in ipairs(allPlayers) do
					if p ~= player then
						RE.NotifyPlayer:FireClient(p,
							"⚠️ "..player.Name.." is almost ready!",
							"Rush the geysers — they're close to prestige!", "red")
					end
				end
			elseif pct < 0.7 then
				prestigeWarned[uid] = nil
			end
		end
	end
end)

-- Batch push stats every 5s to avoid flooding clients
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in ipairs(Players:GetPlayers()) do
			if statsDirty[player.UserId] then
				statsDirty[player.UserId] = nil
				pushStats(player)
				-- Sync leaderstats
				local ls = player:FindFirstChild("leaderstats")
				if ls then
					local d = playerData[player.UserId]
					if d then
						local cv = ls:FindFirstChild("Coins");        if cv then cv.Value = math.floor(d.coins) end
						local rv = ls:FindFirstChild("Rebirths");     if rv then rv.Value = d.rebirths end
						local tv = ls:FindFirstChild("Total Earned"); if tv then tv.Value = math.floor(d.totalEarned) end
					end
				end
			end
		end
	end
end)

-- ── RAID SYSTEM ───────────────────────────────────────────────────
-- Stand on an enemy plot for RAID_TIME seconds to steal it.
-- Owner can cancel by returning to their machine. Raider pays 25% base cost as fee.
-- 4-minute immunity per plot after a successful raid.
local function isInPlotBounds(pos, pdef)
	return math.abs(pos.X - pdef.cx) <= PLOT_HALF
	   and math.abs(pos.Z - pdef.cz) <= PLOT_HALF
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.time()

		-- Clean up expired immunities
		for plotId, t in pairs(raidImmune) do
			if (now - t) >= RAID_IMMUNE then raidImmune[plotId] = nil end
		end

		for _, player in ipairs(Players:GetPlayers()) do
			local uid  = player.UserId
			local char = player.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end
			local pos = hrp.Position

			if not raidProgress[uid] then raidProgress[uid] = {} end
			local myProgress = raidProgress[uid]

			for plotId, ownerUid in pairs(serverPlotOwners) do
				if ownerUid == uid then
					-- Owner must physically be on their plot to block raids
					local ownPdef = PLOT_CENTERS[plotId]
					if ownPdef and isInPlotBounds(pos, ownPdef) then
						for raiderId, prog in pairs(raidProgress) do
							if raiderId ~= uid and prog[plotId] and prog[plotId] > 0 then
								prog[plotId] = nil
								local raider = Players:GetPlayerByUserId(raiderId)
								if raider then
									RE.RaidStatus:FireClient(raider, plotId, "", -1)
									RE.NotifyPlayer:FireClient(raider, "🛡️ Raid Blocked!", player.Name.." defended their machine!", "red")
								end
								RE.NotifyPlayer:FireClient(player, "🛡️ Defended!", "You chased off a raider!", "green")
							end
						end
					end
					continue
				end

				local pdef = PLOT_CENTERS[plotId]
				if not pdef then continue end

				-- Raid immunity check
				if raidImmune[plotId] and (now - raidImmune[plotId]) < RAID_IMMUNE then
					if myProgress[plotId] then
						myProgress[plotId] = nil
						RE.RaidStatus:FireClient(player, plotId, "", -1)
					end
					continue
				end

				if isInPlotBounds(pos, pdef) then
					myProgress[plotId] = (myProgress[plotId] or 0) + 0.5

					local ownerPlayer = Players:GetPlayerByUserId(ownerUid)
					local ownerName   = ownerPlayer and ownerPlayer.Name or "Someone"

					-- Send progress to raider
					RE.RaidStatus:FireClient(player, plotId, ownerName, math.min(1, myProgress[plotId] / RAID_TIME))

					-- Warn owner (throttled to once per 2s)
					if ownerPlayer then
						local warned = (raidWarned[ownerUid] or {})[plotId] or 0
						if (now - warned) >= 2 then
							raidWarned[ownerUid] = raidWarned[ownerUid] or {}
							raidWarned[ownerUid][plotId] = now
							RE.NotifyPlayer:FireClient(ownerPlayer, "⚔️ "..player.Name.." is raiding!", "Run back to defend!", "red")
						end
					end

					-- Raid complete
					if myProgress[plotId] >= RAID_TIME then
						myProgress[plotId] = nil
						RE.RaidStatus:FireClient(player, plotId, "", -1)

						local d        = playerData[uid]
						local oldOwnerD = playerData[ownerUid]
						if not d then continue end

						-- Fee: 25% of base plot cost
						local fee = math.floor(pdef.cost * 0.25)
						if d.coins < fee then
							RE.NotifyPlayer:FireClient(player, "❌ Raid Failed!", "Need "..fee.." coins for the transfer fee.", "red")
							continue
						end
						d.coins = d.coins - fee

						-- Remove from old owner's data
						if oldOwnerD and oldOwnerD.ownedPlots then
							oldOwnerD.ownedPlots[plotId] = nil
						end
						if plotTickLast[ownerUid] then plotTickLast[ownerUid][plotId] = nil end

						-- Give to raider
						d.ownedPlots = d.ownedPlots or {}
						d.ownedPlots[plotId] = true
						serverPlotOwners[plotId] = uid
						if not plotTickLast[uid] then plotTickLast[uid] = {} end
						plotTickLast[uid][plotId] = now

						-- Start immunity timer
						raidImmune[plotId] = now

						-- Cancel other raiders on this same plot
						for raiderId2, prog2 in pairs(raidProgress) do
							if raiderId2 ~= uid and prog2[plotId] then
								prog2[plotId] = nil
								local r2 = Players:GetPlayerByUserId(raiderId2)
								if r2 then RE.RaidStatus:FireClient(r2, plotId, "", -1) end
							end
						end

						-- Notifications
						RE.NotifyPlayer:FireClient(player, "⚔️ Machine Raided!", "Plot stolen! (-"..fee.." fee, 4m shield)", "green")
						if ownerPlayer then
							RE.NotifyPlayer:FireClient(ownerPlayer, "💀 Machine Stolen!", player.Name.." raided your "..plotId.."!", "red")
						end

						-- Tell MapBuilder to rebuild the plot for the new owner
						if PlotTransferBE then PlotTransferBE:Fire(plotId, player) end

						pushStats(player)
						if oldOwnerD then
							local op = Players:GetPlayerByUserId(ownerUid)
							if op then pushStats(op) end
						end
					end
				else
					-- Left the plot — reset progress
					if myProgress[plotId] then
						myProgress[plotId] = nil
						RE.RaidStatus:FireClient(player, plotId, "", -1)
					end
				end
			end
		end
	end
end)

-- ── HOT ZONE PICKPOCKET ───────────────────────────────────────────
-- Players in the geyser zone risk having coins stolen by other players there.
-- Creates real risk/reward tension: stay to collect more, or leave with what you have.
local PICKPOCKET_CHANCE = 0.25  -- 25% per player per 10s interval
local PICKPOCKET_PCT    = 0.08  -- steal 8% of current coins
local PICKPOCKET_MIN    = 10    -- minimum steal
local PICKPOCKET_MAX    = 300   -- cap so early-game isn't destroyed

local function isInHotZone(pos)
	for _, center in ipairs(HOT_ZONE_CENTERS) do
		if math.abs(pos.X - center.cx) <= PLOT_HALF
		and math.abs(pos.Z - center.cz) <= PLOT_HALF then
			return true
		end
	end
	return false
end

task.spawn(function()
	while true do
		task.wait(10)
		local hotPlayers = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp and isInHotZone(hrp.Position) then
				table.insert(hotPlayers, player)
			end
		end
		if #hotPlayers < 2 then continue end

		for _, thief in ipairs(hotPlayers) do
			if math.random() > PICKPOCKET_CHANCE then continue end
			local victims = {}
			for _, p in ipairs(hotPlayers) do
				if p ~= thief then table.insert(victims, p) end
			end
			if #victims == 0 then continue end
			local victim  = victims[math.random(#victims)]
			local thiefD  = playerData[thief.UserId]
			local victimD = playerData[victim.UserId]
			if not thiefD or not victimD or victimD.coins < PICKPOCKET_MIN then continue end
			local stolen = math.floor(victimD.coins * PICKPOCKET_PCT)
			stolen = math.max(PICKPOCKET_MIN, math.min(PICKPOCKET_MAX, stolen))
			if victimD.coins < stolen then continue end
			victimD.coins = victimD.coins - stolen
			thiefD.coins  = thiefD.coins  + stolen
			victim:SetAttribute("Coins", victimD.coins)
			thief:SetAttribute("Coins",  thiefD.coins)
			RE.NotifyPlayer:FireClient(thief,  "🦹 Pickpocket!",  "Stole "..stolen.." from "..victim.Name.."!", "green")
			RE.NotifyPlayer:FireClient(victim, "💸 Pickpocketed!", thief.Name.." stole "..stolen.." coins in the hot zone!", "red")
			statsDirty[thief.UserId]  = true
			statsDirty[victim.UserId] = true
		end
	end
end)

-- ── PLAYER JOIN / LEAVE ───────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	local d = loadData(player)
	player:SetAttribute("Rebirths", d.rebirths)

	task.spawn(function()
		checkGamepasses(player)
		if player.Character then applySpeedDemon(player) end
		pushStats(player)
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applySpeedDemon(player)
	end)

	-- Offline bonus notification
	if d._offlineBonus and d._offlineBonus > 0 then
		local bonus = d._offlineBonus
		d._offlineBonus = nil
		task.delay(3, function()
			if player.Parent then
				RE.NotifyPlayer:FireClient(player,"💤 Offline Bonus!","+"..bonus.." coins while away!","gold")
			end
		end)
	end

	task.delay(1, function()
		if player.Parent then pushStats(player) end
	end)

	-- Auto-save every 60s
	task.spawn(function()
		while player.Parent do
			task.wait(60)
			if player.Parent then
				d.playTime = (d.playTime or 0) + 60
				saveData(player)
			end
		end
	end)

	-- Leaderstats (polled by the batch stat loop above)
	local ls = Instance.new("Folder",player); ls.Name = "leaderstats"
	local cv = Instance.new("IntValue",ls); cv.Name="Coins";        cv.Value=0
	local rv = Instance.new("IntValue",ls); rv.Name="Rebirths";     rv.Value=d.rebirths
	local tv = Instance.new("IntValue",ls); tv.Name="Total Earned"; tv.Value=d.totalEarned
end)

Players.PlayerRemoving:Connect(function(player)
	local uid = player.UserId
	local d   = playerData[uid]

	-- Release owned plots so other players can claim them
	if d and d.ownedPlots then
		for plotId, owned in pairs(d.ownedPlots) do
			if owned and serverPlotOwners[plotId] == uid then
				serverPlotOwners[plotId] = nil
				if PlotRelockBE then PlotRelockBE:Fire(plotId) end
			end
		end
	end

	saveData(player)
	playerData[uid]      = nil
	playerGP[uid]        = nil
	plotTickLast[uid]    = nil
	statsDirty[uid]      = nil
	magnetCooldowns[uid] = nil
	raidProgress[uid]    = nil
	raidWarned[uid]      = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do saveData(p) end
	task.wait(2)
end)

-- ── BUY UPGRADE ───────────────────────────────────────────────
RE.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeKey)
	local d = playerData[player.UserId]
	if not d then return end
	local upg   = getUpgrade(upgradeKey)
	if not upg  then return end
	local level = d.upgrades[upgradeKey] or 0
	if level >= upg.maxLevel then
		RE.NotifyPlayer:FireClient(player,"MAX LEVEL",upg.name.." is maxed!","blue")
		return
	end
	local cost = getUpgradeCost(upg, level)
	if d.coins < cost then
		RE.NotifyPlayer:FireClient(player,"❌ Not enough coins","Need "..cost.." coins","red")
		return
	end
	d.coins = d.coins - cost
	d.upgrades[upgradeKey] = level + 1
	pushStats(player)
	RE.NotifyPlayer:FireClient(player,"✅ Upgraded!",upg.icon.." "..upg.name.." → Lv "..(level+1),"green")
end)

-- ── REBIRTH ───────────────────────────────────────────────────
RE.Rebirth.OnServerEvent:Connect(function(player)
	local d  = playerData[player.UserId]
	if not d then return end
	local cost = math.floor(10000 * (3 ^ d.rebirths))
	if d.coins < cost then
		RE.NotifyPlayer:FireClient(player,"❌ Need more coins","Rebirth costs "..cost.." coins","red")
		return
	end
	local uid = player.UserId

	-- Release this player's plots back to neutral
	for plotId, owned in pairs(d.ownedPlots or {}) do
		if owned and serverPlotOwners[plotId] == uid then
			serverPlotOwners[plotId] = nil
		end
	end
	plotTickLast[uid] = nil

	-- Prestige streak: consecutive prestiges within 1h stack a bonus (up to +50%)
	local now = os.time()
	if (now - (d.lastPrestige or 0)) <= 3600 then
		d.prestigeStreak = math.min((d.prestigeStreak or 0) + 1, 5)
	else
		d.prestigeStreak = 0
	end
	d.lastPrestige = now

	d.coins       = 0
	d.upgrades    = {}
	d.ownedPlots  = {}
	d.rebirths    = d.rebirths + 1
	prestigeWarned[uid] = nil
	player:SetAttribute("Rebirths", d.rebirths)
	pushStats(player)

	local gp   = playerGP[uid] or {}
	local mult = gp.prestigeBoost and "3x" or "2x"
	local tags = {"🔥 REBORN","⚡ ASCENDED","🌙 TRANSCENDED","🌌 LEGENDARY"}
	local tag  = tags[math.min(d.rebirths, #tags)] or "🌌 LEGENDARY"
	local streakStr = d.prestigeStreak > 0 and (" 🔥×"..d.prestigeStreak.." streak +"..(d.prestigeStreak*10).."%") or ""
	RE.NotifyPlayer:FireClient(player, tag.." x"..d.rebirths, mult.." mult!"..streakStr, "gold")
	-- Announce to all other players
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			RE.NotifyPlayer:FireClient(p, "🔥 "..player.Name, tag.." — prestige ×"..d.rebirths.."!", "gold")
		end
	end

	-- Tell MapBuilder to re-lock only this player's plots
	if PrestigeResetBE then PrestigeResetBE:Fire(uid) end

	-- Teleport to spawn
	task.defer(function()
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CFrame = CFrame.new(0, 4, 0) end
		end
	end)
end)

-- ── DAILY REWARD ──────────────────────────────────────────────
RE.ClaimDaily.OnServerEvent:Connect(function(player)
	local d = playerData[player.UserId]
	if not d then return end
	local now        = os.time()
	local hoursSince = (now - (d.lastDaily or 0)) / 3600
	if hoursSince < 20 then
		RE.NotifyPlayer:FireClient(player,"⏰ Too soon","Daily resets in "..math.ceil(20-hoursSince).."h","blue")
		return
	end
	if hoursSince > 48 then d.dailyStreak = 0 end
	d.dailyStreak = math.min((d.dailyStreak or 0)+1, #DAILY_REWARDS)
	local reward  = DAILY_REWARDS[d.dailyStreak]
	d.coins = d.coins + reward; d.totalEarned = (d.totalEarned or 0) + reward; d.lastDaily = now
	pushStats(player)
	RE.NotifyPlayer:FireClient(player,"🎁 Day "..d.dailyStreak.." Reward!","+"..reward.." coins!","gold")
end)

-- ── REQUEST DATA ──────────────────────────────────────────────
RE.RequestData.OnServerInvoke = function(player)
	local d = playerData[player.UserId]
	if d then d._gp = playerGP[player.UserId] or {} end
	return d, UPGRADES
end

-- ── MARKETPLACE ───────────────────────────────────────────────
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local d = playerData[player.UserId]
	if not d then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local amounts = {
		[PRODUCTS.COINS_SMALL]=500,
		[PRODUCTS.COINS_MEDIUM]=2500,
		[PRODUCTS.COINS_LARGE]=10000,
	}
	if amounts[info.ProductId] then
		local amt = amounts[info.ProductId]
		d.coins = d.coins + amt; d.totalEarned = d.totalEarned + amt
		pushStats(player)
		RE.NotifyPlayer:FireClient(player,"💰 Purchase!","+"..amt.." coins!","gold")
		saveData(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif info.ProductId == PRODUCTS.RESET then
		d.upgrades = {}
		pushStats(player)
		RE.NotifyPlayer:FireClient(player,"🔄 Reset!","Upgrades cleared!","blue")
		saveData(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ── PLOT PURCHASE ─────────────────────────────────────────────
local PlotPurchaseBE = ReplicatedStorage:WaitForChild("PlotPurchase", 15)

PlotPurchaseBE.Event:Connect(function(player, plotId, cost)
	local d = playerData[player.UserId]
	if not d then
		RE.NotifyPlayer:FireClient(player,"❌ Data not loaded","Try again in a moment","red")
		return
	end

	-- Check if already owned by this player this session
	if d.ownedPlots and d.ownedPlots[plotId] then
		return  -- already owns it (shouldn't happen since locked vis prevents re-click)
	end

	-- Multiple players may own the same plot independently (income tracked per-player)

	if d.coins < cost then
		RE.NotifyPlayer:FireClient(player,"❌ Not enough coins!","Need "..tostring(cost).." coins","red")
		return
	end

	d.coins = d.coins - cost
	d.ownedPlots = d.ownedPlots or {}
	d.ownedPlots[plotId] = true
	serverPlotOwners[plotId] = player.UserId

	-- Initialize tick timer so first tick fires at correct interval
	if not plotTickLast[player.UserId] then plotTickLast[player.UserId] = {} end
	plotTickLast[player.UserId][plotId] = os.time()

	pushStats(player)
	RE.NotifyPlayer:FireClient(player,"✅ Plot Claimed!","Auto-earning coins now!","green")

	-- Tell MapBuilder to show this plot as owned (unlocked + nameplate)
	if plotUnlockedBE then plotUnlockedBE:Fire(plotId, player) end
end)

print("[MoneyIsland] ✅ Server v15 loaded! Free plots, raiding, hot-zone pickpocket, premium magnet.")

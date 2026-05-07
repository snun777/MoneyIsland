-- ============================================================
-- MONEY ISLAND TYCOON — MainGameServer.lua
-- Place in: ServerScriptService
-- ============================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- CREATE BINDABLE FIRST so MapBuilder's WaitForChild succeeds immediately
local coinBE = Instance.new("BindableEvent")
coinBE.Name   = "CoinCollected_BE"
coinBE.Parent = ReplicatedStorage

-- ============================================================
-- CONFIG — tweak these to balance the game economy
-- ============================================================
local CONFIG = {
	-- Gamepass IDs
	GAMEPASS_VIP        = 1821720069, -- Ultimate Ultra VIP experience!!!
	GAMEPASS_AUTOFARM   = 1822515059, -- Auto Farm Upgrade
	GAMEPASS_REBIRTH    = 1821659972, -- Rebirth (Jesus experience)

	-- Developer Product IDs
	PRODUCT_COINS_SMALL  = 3586040050, -- Small Coin Pack  R$50
	PRODUCT_COINS_MEDIUM = 3586040263, -- Medium Coin Pack R$199
	PRODUCT_COINS_LARGE  = 3586040422, -- Large Coin Pack  R$699
	PRODUCT_RESET_ISLAND = 3586040561, -- Reset Island     R$49

	-- Economy
	BASE_COINS_PER_TICK = 1,          -- coins earned per farm tick
	TICK_INTERVAL       = 2,          -- seconds between farm ticks
	VIP_MULTIPLIER      = 2,
	REBIRTH_MULTIPLIER  = 1.5,        -- per rebirth level

	-- DataStore
	DATA_KEY_PREFIX = "MoneyIsland_v3_",

	-- Daily reward amounts (day 1–7)
	DAILY_REWARDS = {100, 150, 200, 300, 400, 500, 1000},
}

-- ============================================================
-- SETUP — RemoteEvents & RemoteFunctions
-- ============================================================
local function ensureRemote(class, name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end

local RE = {
	UpdateStats      = ensureRemote("RemoteEvent",    "UpdateStats"),
	CollectCoin      = ensureRemote("RemoteEvent",    "CollectCoin"),
	BuyUpgrade       = ensureRemote("RemoteEvent",    "BuyUpgrade"),
	Rebirth          = ensureRemote("RemoteEvent",    "Rebirth"),
	ClaimDaily       = ensureRemote("RemoteEvent",    "ClaimDaily"),
	ShowShop         = ensureRemote("RemoteEvent",    "ShowShop"),
	NotifyPlayer     = ensureRemote("RemoteEvent",    "NotifyPlayer"),
	RequestData      = ensureRemote("RemoteFunction", "RequestData"),
}

-- Coin click handler (BindableEvent fired by MapBuilder ClickDetectors)
coinBE.Event:Connect(function(player)
	print("[MoneyIsland] Coin clicked by", player.Name)
	local data = playerData[player.UserId]
	if not data then
		print("[MoneyIsland] WARNING: No data for", player.Name, "- still loading?")
		return
	end
	if not data then return end
	local mult = getPlayerMultiplier(player)
	local coins = math.floor(CONFIG.BASE_COINS_PER_TICK * mult * 5) -- click = 5x tick value
	data.coins = data.coins + coins
	data.totalEarned = (data.totalEarned or 0) + coins
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("TotalEarned", data.totalEarned)
	RE.UpdateStats:FireClient(player, data, UPGRADES)
	RE.NotifyPlayer:FireClient(player, "💰 +"..coins, "coin collected!", "gold")
end)

-- ============================================================
-- DATA STORE
-- ============================================================
local DS = DataStoreService:GetDataStore("MoneyIslandData")

local DEFAULT_DATA = {
	coins       = 0,
	totalEarned = 0,
	rebirths    = 0,
	upgrades    = {},       -- { [upgradeName] = level }
	lastDaily   = 0,        -- os.time() of last claim
	dailyStreak = 0,
	islandLayout= {},       -- saved plot state
	joinDate    = os.time(),
	playTime    = 0,
}

local playerData = {}  -- [userId] = data table

local function deepCopy(t)
	local copy = {}
	for k,v in pairs(t) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local function loadData(player)
	local key = CONFIG.DATA_KEY_PREFIX .. player.UserId
	local success, data = pcall(function()
		return DS:GetAsync(key)
	end)
	if success and data then
		-- merge with defaults so new fields don't break old saves
		local merged = deepCopy(DEFAULT_DATA)
		for k,v in pairs(data) do merged[k] = v end
		playerData[player.UserId] = merged
	else
		playerData[player.UserId] = deepCopy(DEFAULT_DATA)
	end
	return playerData[player.UserId]
end

local function saveData(player)
	local data = playerData[player.UserId]
	if not data then return end
	local key = CONFIG.DATA_KEY_PREFIX .. player.UserId
	local ok, err = pcall(function()
		DS:SetAsync(key, data)
	end)
	if not ok then
		warn("[MoneyIsland] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- ============================================================
-- UPGRADE DEFINITIONS
-- ============================================================
local UPGRADES = {
	{
		name     = "Farm Speed",
		key      = "farmSpeed",
		maxLevel = 10,
		baseCost = 50,
		costMult = 1.8,
		-- effect: reduces tick interval (min 0.5s)
		effect   = function(level) return math.max(0.5, CONFIG.TICK_INTERVAL - (level * 0.15)) end,
		desc     = "Farms collect faster",
		icon     = "⚡",
	},
	{
		name     = "Coin Magnet",
		key      = "coinMagnet",
		maxLevel = 10,
		baseCost = 100,
		costMult = 2.0,
		-- effect: coins per tick multiplier
		effect   = function(level) return 1 + (level * 0.5) end,
		desc     = "More coins per collect",
		icon     = "🧲",
	},
	{
		name     = "Lucky Strike",
		key      = "luckyStrike",
		maxLevel = 5,
		baseCost = 500,
		costMult = 3.0,
		-- effect: chance % for 10x coin drop
		effect   = function(level) return level * 5 end,
		desc     = "Chance for 10x jackpot",
		icon     = "🍀",
	},
	{
		name     = "Island Expander",
		key      = "islandSize",
		maxLevel = 5,
		baseCost = 1000,
		costMult = 4.0,
		-- effect: unlocks more farm plots
		effect   = function(level) return level * 2 end,  -- extra plots
		desc     = "Unlock more farm slots",
		icon     = "🏝️",
	},
	{
		name     = "Treasure Vault",
		key      = "vault",
		maxLevel = 8,
		baseCost = 300,
		costMult = 2.5,
		-- effect: offline earnings cap (minutes)
		effect   = function(level) return level * 10 end,
		desc     = "Earn coins offline",
		icon     = "🏦",
	},
}

local function getUpgradeCost(upgrade, currentLevel)
	return math.floor(upgrade.baseCost * (upgrade.costMult ^ currentLevel))
end

local function getPlayerMultiplier(player)
	local data = playerData[player.UserId]
	if not data then return 1 end
	local mult = 1
	-- VIP gamepass
	if MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.GAMEPASS_VIP) then
		mult = mult * CONFIG.VIP_MULTIPLIER
	end
	-- Rebirths
	mult = mult * (CONFIG.REBIRTH_MULTIPLIER ^ data.rebirths)
	-- Coin magnet upgrade
	local magnetLevel = data.upgrades["coinMagnet"] or 0
	if magnetLevel > 0 then
		for _, upg in ipairs(UPGRADES) do
			if upg.key == "coinMagnet" then
				mult = mult * upg.effect(magnetLevel)
				break
			end
		end
	end
	return mult
end

-- ============================================================
-- PLAYER JOIN / LEAVE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	local data = loadData(player)

	-- offline earnings (vault upgrade)
	local vaultLevel = data.upgrades["vault"] or 0
	if vaultLevel > 0 and data.lastSave then
		local offlineSeconds = os.time() - data.lastSave
		local maxOfflineSeconds = vaultLevel * 10 * 60
		local earned = math.floor(
			math.min(offlineSeconds, maxOfflineSeconds)
			* CONFIG.BASE_COINS_PER_TICK / CONFIG.TICK_INTERVAL
		)
		if earned > 0 then
			data.coins = data.coins + earned
			data.totalEarned = data.totalEarned + earned
			-- notify player of offline earnings after a short delay
			task.delay(3, function()
				if player and player.Parent then
					RE.NotifyPlayer:FireClient(player, "💤 Offline Bonus!", "+"..earned.." coins while you were away!", "gold")
				end
			end)
		end
	end
	data.lastSave = os.time()

	-- push initial data to client
	task.delay(1, function()
		if player and player.Parent then
			RE.UpdateStats:FireClient(player, data, UPGRADES)
		end
	end)

	-- auto-save every 60 seconds
	task.spawn(function()
		while player and player.Parent do
			task.wait(60)
			if player and player.Parent then
				data.playTime = (data.playTime or 0) + 60
				data.lastSave = os.time()
				saveData(player)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local data = playerData[player.UserId]
	if data then
		data.lastSave = os.time()
		saveData(player)
		playerData[player.UserId] = nil
	end
end)

-- save all on server shutdown
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = playerData[player.UserId]
		if data then
			data.lastSave = os.time()
			saveData(player)
		end
	end
	task.wait(2) -- give DS time to flush
end)

-- ============================================================
-- FARM TICK LOOP (server-side coin generation)
-- ============================================================
task.spawn(function()
	while true do
		task.wait(CONFIG.TICK_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player.UserId]
			if data then
				local mult   = getPlayerMultiplier(player)
				local base   = CONFIG.BASE_COINS_PER_TICK * mult

				-- Lucky Strike jackpot
				local luckyLevel = data.upgrades["luckyStrike"] or 0
				local jackpotChance = 0
				if luckyLevel > 0 then
					for _, upg in ipairs(UPGRADES) do
						if upg.key == "luckyStrike" then
							jackpotChance = upg.effect(luckyLevel)
							break
						end
					end
				end
				local coins = base
				local jackpot = false
				if jackpotChance > 0 and math.random(1, 100) <= jackpotChance then
					coins = base * 10
					jackpot = true
				end

				coins = math.floor(coins)
				data.coins       = data.coins + coins
				data.totalEarned = (data.totalEarned or 0) + coins

				-- send update to client
				RE.UpdateStats:FireClient(player, data, UPGRADES)
				if jackpot then
					RE.NotifyPlayer:FireClient(player, "🍀 JACKPOT!", "+"..coins.." coins!", "green")
				end
			end
		end
	end
end)

-- ============================================================
-- REMOTE: Client requests their data
-- ============================================================
RE.RequestData.OnServerInvoke = function(player)
	return playerData[player.UserId], UPGRADES
end

-- ============================================================
-- REMOTE: Buy upgrade
-- ============================================================
RE.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeKey)
	local data = playerData[player.UserId]
	if not data then return end

	local upgrade = nil
	for _, u in ipairs(UPGRADES) do
		if u.key == upgradeKey then upgrade = u break end
	end
	if not upgrade then return end

	local currentLevel = data.upgrades[upgradeKey] or 0
	if currentLevel >= upgrade.maxLevel then
		RE.NotifyPlayer:FireClient(player, "MAX LEVEL", upgrade.name.." is maxed out!", "blue")
		return
	end

	local cost = getUpgradeCost(upgrade, currentLevel)
	if data.coins < cost then
		RE.NotifyPlayer:FireClient(player, "❌ Not enough coins", "Need "..cost.." coins", "red")
		return
	end

	data.coins = data.coins - cost
	data.upgrades[upgradeKey] = currentLevel + 1
	RE.UpdateStats:FireClient(player, data, UPGRADES)
	RE.NotifyPlayer:FireClient(player, "✅ Upgraded!", upgrade.icon.." "..upgrade.name.." → Level "..(currentLevel+1), "green")
end)

-- ============================================================
-- REMOTE: Rebirth
-- ============================================================
RE.Rebirth.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data then return end

	local REBIRTH_COST = 10000 * (2 ^ data.rebirths)  -- cost doubles each rebirth
	if data.coins < REBIRTH_COST then
		RE.NotifyPlayer:FireClient(player, "❌ Need more coins", "Rebirth costs "..REBIRTH_COST.." coins", "red")
		return
	end

	-- check gamepass for early rebirth (otherwise locked until rebirth cost)
	data.coins    = 0
	data.upgrades = {}
	data.rebirths = data.rebirths + 1
	RE.UpdateStats:FireClient(player, data, UPGRADES)
	RE.NotifyPlayer:FireClient(player, "🔥 REBORN!", "x"..CONFIG.REBIRTH_MULTIPLIER.." permanent multiplier!", "gold")
end)

-- ============================================================
-- REMOTE: Claim daily reward
-- ============================================================
RE.ClaimDaily.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data then return end

	local now = os.time()
	local lastClaim = data.lastDaily or 0
	local hoursSince = (now - lastClaim) / 3600

	if hoursSince < 20 then
		local hoursLeft = math.ceil(20 - hoursSince)
		RE.NotifyPlayer:FireClient(player, "⏰ Come back later", "Daily reward in "..hoursLeft.."h", "blue")
		return
	end

	-- check if streak continues (within 48h) or resets
	if hoursSince > 48 then
		data.dailyStreak = 0
	end

	data.dailyStreak = math.min(data.dailyStreak + 1, #CONFIG.DAILY_REWARDS)
	local reward = CONFIG.DAILY_REWARDS[data.dailyStreak]
	data.coins       = data.coins + reward
	data.totalEarned = (data.totalEarned or 0) + reward
	data.lastDaily   = now

	RE.UpdateStats:FireClient(player, data, UPGRADES)
	RE.NotifyPlayer:FireClient(player, "🎁 Day "..data.dailyStreak.." Reward!", "+"..reward.." coins!", "gold")
end)

-- ============================================================
-- MARKETPLACE: Handle developer product purchases
-- ============================================================
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local data = playerData[player.UserId]
	if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local id = receiptInfo.ProductId
	local granted = false

	if id == CONFIG.PRODUCT_COINS_SMALL then
		data.coins = data.coins + 500
		data.totalEarned = data.totalEarned + 500
		RE.NotifyPlayer:FireClient(player, "💰 Purchase Complete!", "+500 coins added!", "gold")
		granted = true
	elseif id == CONFIG.PRODUCT_COINS_MEDIUM then
		data.coins = data.coins + 2500
		data.totalEarned = data.totalEarned + 2500
		RE.NotifyPlayer:FireClient(player, "💰 Purchase Complete!", "+2500 coins added!", "gold")
		granted = true
	elseif id == CONFIG.PRODUCT_COINS_LARGE then
		data.coins = data.coins + 10000
		data.totalEarned = data.totalEarned + 10000
		RE.NotifyPlayer:FireClient(player, "💰 Purchase Complete!", "+10,000 coins added!", "gold")
		granted = true
	elseif id == CONFIG.PRODUCT_RESET_ISLAND then
		data.islandLayout = {}
		RE.NotifyPlayer:FireClient(player, "🏝️ Island Reset!", "Fresh start!", "blue")
		granted = true
	end

	if granted then
		RE.UpdateStats:FireClient(player, data, UPGRADES)
		saveData(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

print("[MoneyIsland] ✅ Server loaded!")

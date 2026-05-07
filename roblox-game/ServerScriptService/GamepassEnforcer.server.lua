-- ============================================================
-- MONEY ISLAND TYCOON — GamepassEnforcer.lua
-- Place in: ServerScriptService
-- Handles all gamepass perks server-side
-- ============================================================

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- Gamepass IDs (must match MainGameServer.lua)
local GP = {
	VIP        = 1821720069, -- Ultimate Ultra VIP experience!!!
	AUTOFARM   = 1822515059, -- Auto Farm Upgrade
	REBIRTH    = 1821659972, -- Rebirth (Jesus experience)
}

-- VIP barrier reference (set after map loads)
local vipBarrier = nil

task.delay(3, function()
	local map = workspace:WaitForChild("MoneyIslandMap", 10)
	if map then
		local vipZone = map:FindFirstChild("VIPLounge")
		if vipZone then
			vipBarrier = vipZone:FindFirstChild("VIPBarrier")
		end
	end
end)

-- check if a player has a gamepass (cached)
local gpCache = {}
local function hasPass(player, gpId)
	local key = player.UserId .. "_" .. gpId
	if gpCache[key] == nil then
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId)
		end)
		gpCache[key] = ok and result or false
	end
	return gpCache[key]
end

-- On new purchase during session, refresh cache
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gpId, purchased)
	if purchased then
		local key = player.UserId .. "_" .. gpId
		gpCache[key] = true
		applyPerks(player)

		-- notify via remote
		local notify = ReplicatedStorage:FindFirstChild("NotifyPlayer")
		if notify then
			if gpId == GP.VIP then
				notify:FireClient(player, "⭐ VIP ACTIVATED!", "2x coins + VIP Lounge unlocked!", "gold")
			elseif gpId == GP.AUTOFARM then
				notify:FireClient(player, "🤖 AUTO FARM ON!", "Coins collect automatically!", "green")
			elseif gpId == GP.REBIRTH then
				notify:FireClient(player, "🔥 EARLY REBIRTH!", "Rebirth is now unlocked!", "red")
			end
		end
	end
end)

function applyPerks(player)
	-- VIP: allow through barrier (disable collision for them)
	if vipBarrier and hasPass(player, GP.VIP) then
		local char = player.Character
		if char then
			-- use a NoCollisionConstraint or just teleport them past
			-- simplest: create a per-player invisible force field
			local ff = char:FindFirstChild("VIPPass")
			if not ff then
				local tag = Instance.new("BoolValue")
				tag.Name  = "VIPPass"
				tag.Parent = char
			end
		end
	end

	-- AUTO FARM: mark them for auto-collection in MainGameServer
	if hasPass(player, GP.AUTOFARM) then
		local char = player.Character
		if char then
			local tag = char:FindFirstChild("AutoFarm")
			if not tag then
				local t = Instance.new("BoolValue")
				t.Name   = "AutoFarm"
				t.Value  = true
				t.Parent = char
			end
		end
	end
end

-- VIP barrier: reject non-VIP players who touch it
if vipBarrier then
	vipBarrier.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if player and not hasPass(player, GP.VIP) then
			-- push them back
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = hrp.CFrame + Vector3.new(0, 0, 8)
			end
			local notify = ReplicatedStorage:FindFirstChild("NotifyPlayer")
			if notify then
				notify:FireClient(player, "⭐ VIP Only!", "Get the VIP Gamepass to enter! (💎 shop)", "gold")
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.delay(1, function()
			applyPerks(player)
		end)
	end)
end)

print("[MoneyIsland] ✅ Gamepass enforcer loaded!")

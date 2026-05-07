-- ============================================================
-- MONEY ISLAND TYCOON — Leaderboard.lua
-- Place in: ServerScriptService
-- Builds an in-game leaderboard board + Roblox stat leaderboard
-- ============================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ordered datastore for global leaderboard
local LB_STORE = DataStoreService:GetOrderedDataStore("MoneyIsland_TotalEarned_v3")

-- ── ROBLOX DEFAULT LEADERBOARD (shows in tab menu) ──────────
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name   = "Coins"
	coins.Value  = 0
	coins.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name  = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = leaderstats

	local total = Instance.new("IntValue")
	total.Name  = "Total Earned"
	total.Value = 0
	total.Parent = leaderstats

	-- sync from game data
	local RE_UpdateStats = ReplicatedStorage:WaitForChild("UpdateStats", 10)
	if RE_UpdateStats then
		RE_UpdateStats.OnServerEvent:Connect(function() end) -- placeholder
	end

	-- poll player data every 5 seconds to sync leaderboard
	task.spawn(function()
		while player and player.Parent do
			local data = nil
			-- try to read from playerData (shared via _G or attribute)
			-- in production, access via module or bindable
			local ok, result = pcall(function()
				-- Attempt to read the leaderstats attribute set by MainGameServer
				return player:GetAttribute("Coins"), player:GetAttribute("TotalEarned"), player:GetAttribute("Rebirths")
			end)

			local c, t, r = player:GetAttribute("Coins"), player:GetAttribute("TotalEarned"), player:GetAttribute("Rebirths")
			if c then coins.Value   = math.floor(c) end
			if t then total.Value   = math.floor(t) end
			if r then rebirths.Value= math.floor(r) end

			task.wait(5)
		end
	end)
end)

-- ── SYNC PLAYER ATTRIBUTES (called by MainGameServer updates) ──
-- MainGameServer should call this after UpdateStats:
-- Add to MainGameServer in the farm tick loop:
--   player:SetAttribute("Coins", data.coins)
--   player:SetAttribute("TotalEarned", data.totalEarned)
--   player:SetAttribute("Rebirths", data.rebirths)

-- ── GLOBAL TOP 10 LEADERBOARD (physical board in-world) ────
local function buildLeaderboardBoard()
	local map = workspace:WaitForChild("MoneyIslandMap", 15)
	if not map then return end
	local spawnZone = map:WaitForChild("SpawnZone", 10)
	if not spawnZone then return end

	-- Board frame
	local board = Instance.new("Part")
	board.Name            = "LeaderboardBoard"
	board.Anchored        = true
	board.Size            = Vector3.new(20, 18, 1)
	board.Position        = Vector3.new(22, 10, -15)
	board.Color           = Color3.fromRGB(10, 10, 24)
	board.Material        = Enum.Material.SmoothPlastic
	board.TopSurface      = Enum.SurfaceType.Smooth
	board.BottomSurface   = Enum.SurfaceType.Smooth
	board.CFrame          = CFrame.new(22, 10, -15) * CFrame.Angles(0, math.rad(-20), 0)
	board.Parent          = spawnZone

	local stroke = Instance.new("SelectionBox")
	stroke.Parent = board

	-- Neon border
	for _,data in ipairs({
		{Vector3.new(20,0.5,0.5), Vector3.new(22,20,-14.7)},
		{Vector3.new(20,0.5,0.5), Vector3.new(22,1,-14.7)},
		{Vector3.new(0.5,19,0.5), Vector3.new(12,10.5,-14.7)},
		{Vector3.new(0.5,19,0.5), Vector3.new(32,10.5,-14.7)},
	}) do
		local b = Instance.new("Part")
		b.Anchored = true; b.Size = data[1]; b.Position = data[2]
		b.Color = Color3.fromRGB(255,200,0); b.Material = Enum.Material.Neon
		b.TopSurface = Enum.SurfaceType.Smooth
		b.BottomSurface = Enum.SurfaceType.Smooth
		b.CanCollide = false; b.Parent = spawnZone
	end

	-- SurfaceGui on the board
	local sg = Instance.new("SurfaceGui")
	sg.Name         = "LeaderboardGui"
	sg.Face         = Enum.NormalId.Front
	sg.SizingMode   = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud= 50
	sg.Parent       = board

	local bg = Instance.new("Frame", sg)
	bg.Size              = UDim2.new(1,0,1,0)
	bg.BackgroundColor3  = Color3.fromRGB(8,8,20)
	bg.BorderSizePixel   = 0

	local titleLbl = Instance.new("TextLabel", bg)
	titleLbl.Size         = UDim2.new(1,0,0,60)
	titleLbl.Position     = UDim2.new(0,0,0,0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text         = "🏆 TOP EARNERS"
	titleLbl.TextColor3   = Color3.fromRGB(255,215,0)
	titleLbl.Font         = Enum.Font.GothamBold
	titleLbl.TextScaled   = true

	local rowContainer = Instance.new("Frame", bg)
	rowContainer.Name    = "Rows"
	rowContainer.Size    = UDim2.new(1,-20,1,-70)
	rowContainer.Position= UDim2.new(0,10,0,65)
	rowContainer.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout", rowContainer)
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0,4)

	local function refreshBoard()
		-- clear old rows
		for _, c in ipairs(rowContainer:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end

		local ok, pages = pcall(function()
			return LB_STORE:GetSortedAsync(false, 10)
		end)

		if not ok then return end

		local medals = {"🥇","🥈","🥉","4️⃣","5️⃣","6️⃣","7️⃣","8️⃣","9️⃣","🔟"}
		local rank = 0

		local currentPage = pages:GetCurrentPage()
		for _, entry in ipairs(currentPage) do
			rank = rank + 1
			local name = "[player]"
			pcall(function()
				name = game:GetService("Players"):GetNameFromUserIdAsync(entry.key)
			end)

			local row = Instance.new("Frame", rowContainer)
			row.Size = UDim2.new(1,0,0,36)
			row.BackgroundColor3 = rank % 2 == 0 and Color3.fromRGB(14,14,28) or Color3.fromRGB(18,18,35)
			row.BorderSizePixel = 0
			Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)

			local medal = Instance.new("TextLabel", row)
			medal.Size = UDim2.new(0,40,1,0)
			medal.BackgroundTransparency = 1
			medal.Text = medals[rank] or tostring(rank)
			medal.TextScaled = true
			medal.Font = Enum.Font.GothamBold

			local nameLbl = Instance.new("TextLabel", row)
			nameLbl.Size = UDim2.new(0.55,0,1,0)
			nameLbl.Position = UDim2.new(0,44,0,0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = name
			nameLbl.TextColor3 = Color3.fromRGB(220,220,240)
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextScaled = true
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left

			local scoreLbl = Instance.new("TextLabel", row)
			scoreLbl.Size = UDim2.new(0.38,0,1,0)
			scoreLbl.Position = UDim2.new(0.62,0,0,0)
			scoreLbl.BackgroundTransparency = 1
			local v = entry.value
			local formatted = v >= 1e6 and string.format("%.1fM",v/1e6)
				or v >= 1e3 and string.format("%.1fK",v/1e3)
				or tostring(v)
			scoreLbl.Text = "💰"..formatted
			scoreLbl.TextColor3 = Color3.fromRGB(255,200,0)
			scoreLbl.Font = Enum.Font.GothamBold
			scoreLbl.TextScaled = true
			scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
		end
	end

	-- initial load + refresh every 60s
	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(60)
		end
	end)
end

task.spawn(buildLeaderboardBoard)

-- ── SAVE TOTAL EARNED TO ORDERED DS ON PLAYER LEAVE ────────
Players.PlayerRemoving:Connect(function(player)
	local total = player:GetAttribute("TotalEarned") or 0
	if total > 0 then
		pcall(function()
			LB_STORE:SetAsync(tostring(player.UserId), math.floor(total))
		end)
	end
end)

print("[MoneyIsland] ✅ Leaderboard loaded!")

-- GunTycoon Leaderboard v1
-- Updates the physical leaderboard board in the map every 60s

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local LB_STORE = DataStoreService:GetOrderedDataStore("GunTycoon_TotalEarned_v1")

local function fmt(n)
    if n >= 1e9 then return string.format("%.1fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

-- Save a player's totalEarned to the ordered DS
local function saveLB(userId, totalEarned)
    if totalEarned <= 0 then return end
    pcall(function()
        LB_STORE:SetAsync(tostring(userId), math.floor(totalEarned))
    end)
end

-- ============================================================
-- Refresh the physical board in Workspace
-- ============================================================

local RANK_COLS = {
    Color3.fromRGB(255,215,0),
    Color3.fromRGB(200,210,220),
    Color3.fromRGB(200,130,60),
}

local function refreshBoard()
    local ok, pages = pcall(function()
        return LB_STORE:GetSortedAsync(false, 10)
    end)
    if not ok or not pages then return end

    local ok2, data = pcall(function()
        return pages:GetCurrentPage()
    end)
    if not ok2 or not data then return end

    -- Find the surface gui pre-built by MapBuilder
    local board = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("LeaderboardBoard", true)
    if not board then return end
    local sg = board:FindFirstChild("LBSurface")
    if not sg then return end
    local entries = sg:FindFirstChild("Entries")
    if not entries then return end

    for rank = 1, 10 do
        local entry = entries:FindFirstChild("R" .. rank)
        if not entry then continue end
        local item = data[rank]
        if item then
            local name = "[" .. item.key .. "]"
            -- Try to get display name from online players
            local p = Players:GetPlayerByUserId(tonumber(item.key))
            if p then name = p.DisplayName end
            local rankStr = rank == 1 and "#1" or rank == 2 and "#2" or rank == 3 and "#3" or "#" .. rank
            entry.Text = rankStr .. "  " .. name .. "  " .. fmt(item.value)
            entry.TextColor3 = rank <= 3 and RANK_COLS[rank] or Color3.fromRGB(195,195,195)
        else
            entry.Text = "#" .. rank .. "  --"
        end
    end
end

-- ============================================================
-- Track total earned via PlayerRemoving + periodic flush
-- ============================================================

-- MainGameServer exposes totalEarned via player attribute on save
-- We hook into PlayerRemoving to capture final value
Players.PlayerRemoving:Connect(function(player)
    local earned = player:GetAttribute("TotalEarned") or 0
    saveLB(player.UserId, earned)
end)

Players.PlayerAdded:Connect(function(player)
    task.wait(5)
    if player.Parent then
        local earned = player:GetAttribute("TotalEarned") or 0
        saveLB(player.UserId, earned)
    end
end)

-- Refresh board loop
task.delay(8, function()
    while true do
        refreshBoard()
        task.wait(60)
    end
end)

print("[Leaderboard] GunTycoon leaderboard ready")

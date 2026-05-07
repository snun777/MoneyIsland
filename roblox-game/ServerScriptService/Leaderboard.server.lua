-- Leaderboard.server.lua (v3 - Redesigned board GUI)

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")

local LB_STORE = DataStoreService:GetOrderedDataStore("MoneyIsland_TotalEarned_v4")

-- ── SAVE TO ORDERED DS ────────────────────────────────────
local function saveToLB(player)
    local total = player:GetAttribute("TotalEarned") or 0
    if total > 0 then
        pcall(function()
            LB_STORE:SetAsync(tostring(player.UserId), math.floor(total))
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    task.delay(5, function()
        if player.Parent then saveToLB(player) end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    saveToLB(player)
end)

-- ── HELPERS ───────────────────────────────────────────────
local function fmt(n)
    if n >= 1e9 then return string.format("%.1fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

local function lbl(parent, props)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1
    l.Font       = props.font or Enum.Font.GothamBold
    l.TextScaled = props.scaled ~= false
    l.TextColor3 = props.col or Color3.new(1,1,1)
    l.Text       = props.text or ""
    l.Size       = props.size or UDim2.new(1,0,1,0)
    l.Position   = props.pos  or UDim2.new(0,0,0,0)
    l.TextXAlignment = props.align or Enum.TextXAlignment.Center
    l.ZIndex     = props.z or 1
    return l
end

-- Row accent colors: gold, silver, bronze, then plain
local ROW_BG = {
    Color3.fromRGB(80, 60,  5),   -- #1 gold tint
    Color3.fromRGB(50, 50, 60),   -- #2 silver tint
    Color3.fromRGB(70, 38, 12),   -- #3 bronze tint
}
local ROW_BG_DEFAULT_A = Color3.fromRGB(18, 18, 32)
local ROW_BG_DEFAULT_B = Color3.fromRGB(24, 24, 42)

local RANK_COL = {
    Color3.fromRGB(255,215,  0),  -- gold
    Color3.fromRGB(200,210,220),  -- silver
    Color3.fromRGB(200,130, 60),  -- bronze
}
local RANK_LABELS = {"1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th"}

-- ── PHYSICAL LEADERBOARD BOARD ─────────────────────────────
local function buildLeaderboardBoard()
    local map = workspace:WaitForChild("MoneyIslandMap", 20)
    if not map then warn("[LB] MoneyIslandMap not found"); return end
    local lbArea = map:WaitForChild("LeaderboardArea", 15)
    if not lbArea then warn("[LB] LeaderboardArea not found"); return end
    local board = lbArea:WaitForChild("LeaderboardBoard", 10)
    if not board then warn("[LB] LeaderboardBoard not found"); return end

    -- Destroy old gui if it exists (for hot-reload safety)
    local old = board:FindFirstChild("LeaderboardGui")
    if old then old:Destroy() end

    local sg = Instance.new("SurfaceGui")
    sg.Name          = "LeaderboardGui"
    sg.Face          = Enum.NormalId.Front
    sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 50
    sg.AlwaysOnTop   = false
    sg.Parent        = board

    -- Root frame
    local root = Instance.new("Frame", sg)
    root.Size = UDim2.new(1,0,1,0)
    root.BackgroundColor3 = Color3.fromRGB(10, 10, 22)
    root.BorderSizePixel  = 0
    Instance.new("UICorner", root).CornerRadius = UDim.new(0, 8)

    -- Gold top header bar
    local header = Instance.new("Frame", root)
    header.Size = UDim2.new(1,0,0,90)
    header.BackgroundColor3 = Color3.fromRGB(160, 110, 0)
    header.BorderSizePixel  = 0
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

    -- Extend header corners down so top-corners-only look right
    local headerFill = Instance.new("Frame", root)
    headerFill.Size = UDim2.new(1,0,0,20)
    headerFill.Position = UDim2.new(0,0,0,70)
    headerFill.BackgroundColor3 = Color3.fromRGB(160, 110, 0)
    headerFill.BorderSizePixel  = 0

    lbl(header, {text="🏆  TOP EARNERS", col=Color3.fromRGB(255,240,180),
        size=UDim2.new(1,-16,0.55,0), pos=UDim2.new(0,8,0,6),
        font=Enum.Font.GothamBlack})

    lbl(header, {text="All-time total coins earned",
        col=Color3.fromRGB(255,220,120),
        size=UDim2.new(1,-16,0.35,0), pos=UDim2.new(0,8,0.6,0),
        font=Enum.Font.Gotham, scaled=true})

    -- Divider line
    local div = Instance.new("Frame", root)
    div.Size = UDim2.new(1,-24,0,2)
    div.Position = UDim2.new(0,12,0,92)
    div.BackgroundColor3 = Color3.fromRGB(255,200,0)
    div.BorderSizePixel  = 0

    -- Row container
    local rowContainer = Instance.new("ScrollingFrame", root)
    rowContainer.Name     = "Rows"
    rowContainer.Size     = UDim2.new(1,-16,1,-102)
    rowContainer.Position = UDim2.new(0,8,0,98)
    rowContainer.BackgroundTransparency = 1
    rowContainer.ScrollBarThickness = 0
    rowContainer.CanvasSize = UDim2.new(0,0,0,0)
    rowContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    rowContainer.ClipsDescendants = true

    local list = Instance.new("UIListLayout", rowContainer)
    list.FillDirection = Enum.FillDirection.Vertical
    list.Padding       = UDim.new(0, 5)

    local function refreshBoard()
        for _, c in ipairs(rowContainer:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end

        local ok, pages = pcall(function()
            return LB_STORE:GetSortedAsync(false, 10)
        end)
        if not ok then return end

        local rank = 0
        for _, entry in ipairs(pages:GetCurrentPage()) do
            rank = rank + 1

            local name = "[unknown]"
            pcall(function()
                name = Players:GetNameFromUserIdAsync(entry.key)
            end)

            local isTop3 = rank <= 3
            local rowH = isTop3 and 58 or 46

            local row = Instance.new("Frame", rowContainer)
            row.Size = UDim2.new(1,0,0,rowH)
            row.BackgroundColor3 = ROW_BG[rank] or (rank % 2 == 0 and ROW_BG_DEFAULT_A or ROW_BG_DEFAULT_B)
            row.BorderSizePixel  = 0
            Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)

            -- Rank badge
            local rankCol = RANK_COL[rank] or Color3.fromRGB(160,160,180)
            local badge = Instance.new("Frame", row)
            badge.Size = UDim2.new(0, 54, 1, -8)
            badge.Position = UDim2.new(0, 6, 0, 4)
            badge.BackgroundColor3 = rankCol
            badge.BackgroundTransparency = isTop3 and 0.3 or 0.6
            badge.BorderSizePixel = 0
            Instance.new("UICorner", badge).CornerRadius = UDim.new(0,5)

            lbl(badge, {text=RANK_LABELS[rank] or tostring(rank),
                col=rankCol, size=UDim2.new(1,0,1,0), scaled=true,
                font=Enum.Font.GothamBlack})

            -- Player name
            local nameLbl = lbl(row, {
                text = name,
                col  = isTop3 and Color3.fromRGB(255,240,180) or Color3.fromRGB(210,210,230),
                size = UDim2.new(0.5,0,1,-8),
                pos  = UDim2.new(0,66,0,4),
                align = Enum.TextXAlignment.Left,
                font = isTop3 and Enum.Font.GothamBlack or Enum.Font.GothamBold,
            })

            -- Score
            lbl(row, {
                text  = "💰 "..fmt(entry.value),
                col   = rankCol,
                size  = UDim2.new(0.38,0,1,-8),
                pos   = UDim2.new(0.62,-4,0,4),
                align = Enum.TextXAlignment.Right,
                font  = Enum.Font.GothamBold,
            })
        end

        if rank == 0 then
            lbl(rowContainer, {
                text="No entries yet!\nPlay to appear here.",
                col=Color3.fromRGB(160,160,180),
                size=UDim2.new(1,0,0,80),
                font=Enum.Font.Gotham,
            })
        end
    end

    task.spawn(function()
        while true do
            refreshBoard()
            task.wait(60)
        end
    end)
end

task.spawn(buildLeaderboardBoard)

print("[MoneyIsland] ✅ Leaderboard v3 loaded!")

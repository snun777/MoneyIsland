-- CoinSpin.client.lua
-- 1. Floating +X text on coin collect
-- 2. Coin magnet with float animation
-- 3. Countdown timer display on each coin (color changed server-side)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local RE_Notify = ReplicatedStorage:WaitForChild("NotifyPlayer", 30)
local RE_Update = ReplicatedStorage:WaitForChild("UpdateStats",  30)
local MagnetRE  = ReplicatedStorage:WaitForChild("MagnetCollect", 30)

local playerCooldown = 30  -- seconds, kept in sync with touchSpeed upgrade via RE_Update

-- ── FLOATING TEXT ─────────────────────────────────────────
local function floatText(text, color)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local part = Instance.new("Part")
    part.Anchored = true; part.CanCollide = false
    part.Transparency = 1; part.Size = Vector3.new(1,1,1)
    part.Position = hrp.Position + Vector3.new(math.random(-3,3), 4, math.random(-2,2))
    part.Parent = workspace

    local bb = Instance.new("BillboardGui", part)
    bb.Size = UDim2.new(0,90,0,36); bb.MaxDistance = 40

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(255,215,0)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 22
    lbl.TextStrokeTransparency = 0.3; lbl.TextStrokeColor3 = Color3.new(0,0,0)

    TweenService:Create(part,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = part.Position + Vector3.new(0,5,0)}):Play()
    TweenService:Create(lbl,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {TextTransparency = 1, TextStrokeTransparency = 1}):Play()

    game:GetService("Debris"):AddItem(part, 0.9)
end

RE_Notify.OnClientEvent:Connect(function(title)
    if title:find("💰") then
        floatText(title, Color3.fromRGB(255,215,0))
    elseif title:find("🍀") or title:find("JACKPOT") then
        floatText(title, Color3.fromRGB(80,255,120))
    end
end)


-- ── MAGNET ────────────────────────────────────────────────
local magnetRadius = 0

-- ── MAGNET RANGE RING (thin neon ring on ground) ─────────────
local ringParts = {}

local function clearRing()
    for _, p in ipairs(ringParts) do pcall(function() p:Destroy() end) end
    ringParts = {}
end

local function buildRing(cx, cy, cz)
    clearRing()
    if magnetRadius <= 0 then return end
    local N = 40  -- number of segments
    local r = magnetRadius
    local tw = 0.45  -- tube width
    local segArc = (2 * math.pi) / N
    local segLen = 2 * r * math.sin(segArc / 2) + 0.05
    for i = 0, N - 1 do
        local a = i * segArc
        local x = cx + math.cos(a) * r
        local z = cz + math.sin(a) * r
        local seg = Instance.new("Part")
        seg.Anchored = true; seg.CanCollide = false; seg.CastShadow = false
        seg.Size = Vector3.new(segLen, tw, tw)
        seg.CFrame = CFrame.new(x, cy, z) * CFrame.Angles(0, -(a + math.pi/2), 0)
        seg.Color = Color3.fromRGB(0, 220, 255)
        seg.Material = Enum.Material.Neon
        seg.Transparency = 0
        seg.TopSurface = Enum.SurfaceType.Smooth
        seg.BottomSurface = Enum.SurfaceType.Smooth
        seg.Parent = workspace
        table.insert(ringParts, seg)
    end
end

local function updateRing()
    clearRing()
    if magnetRadius <= 0 then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    buildRing(hrp.Position.X, hrp.Position.Y - 2.8, hrp.Position.Z)
end

-- Move ring every heartbeat - raycast each segment to stick to ground
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.Heartbeat:Connect(function()
    if #ringParts == 0 then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Exclude the ring parts and character from raycast
    -- Exclude character and the ring parts themselves
    local exclude = {char}
    for _, p in ipairs(ringParts) do table.insert(exclude, p) end
    rayParams.FilterDescendantsInstances = exclude
    local cx, cz = hrp.Position.X, hrp.Position.Z
    local N = #ringParts
    local r = magnetRadius
    local segArc = (2 * math.pi) / N
    for i, seg in ipairs(ringParts) do
        local a = (i-1) * segArc
        local sx = cx + math.cos(a) * r
        local sz = cz + math.sin(a) * r
        -- Raycast down from above to find ground Y
        local hit = workspace:Raycast(Vector3.new(sx, hrp.Position.Y + 5, sz), Vector3.new(0,-20,0), rayParams)
        local sy = hit and (hit.Position.Y + 0.08) or (hrp.Position.Y - 2.8)
        seg.CFrame = CFrame.new(sx, sy, sz) * CFrame.Angles(0, -(a + math.pi/2), 0)
    end
end)

player.CharacterRemoving:Connect(function()
    clearRing()
end)

RE_Update.OnClientEvent:Connect(function(data)
    if not data or not data.upgrades then return end
    local hasMegaMagnet = data._gp and data._gp.megaMagnet
    local newRadius = 0
    if hasMegaMagnet then
        -- Base 5 + upgrades, plus 15 from the gamepass itself
        local lvl   = data.upgrades["coinMagnet"] or 0
        newRadius   = (5 + lvl * 3) + 15
    end
    if newRadius ~= magnetRadius then
        magnetRadius = newRadius
        updateRing()
    end
    local tsLvl = data.upgrades["touchSpeed"] or 0
    playerCooldown = math.max(1, 30 - tsLvl)
end)

-- ── COIN GLOW (client-side SelectionBox on geyser coins) ─────
local camera = workspace.CurrentCamera
local function addCoinGlow(coin)
    local sel = Instance.new("SelectionBox")
    sel.Adornee              = coin
    sel.Color3               = Color3.fromRGB(255, 215, 0)
    sel.SurfaceTransparency  = 0.85
    sel.LineThickness        = 0.03
    sel.Parent               = camera
    coin.AncestryChanged:Connect(function()
        if not coin.Parent then sel:Destroy() end
    end)
end

-- Only geyser coins exist as physical objects in the new model
local function getGeyserCoins()
    local coins = {}
    local map = workspace:FindFirstChild("MoneyIslandMap")
    if not map then return coins end
    local farm = map:FindFirstChild("FarmZone")
    if not farm then return coins end
    local models = farm:FindFirstChild("CoinModels")
    if not models then return coins end
    for _, c in ipairs(models:GetChildren()) do
        if c:IsA("Part") and c:GetAttribute("GeyserCoin") then
            table.insert(coins, c)
            addCoinGlow(c)
        end
    end
    return coins
end

task.delay(2, function()
    local coins = getGeyserCoins()

    -- Watch for new geyser coins spawning
    local map = workspace:FindFirstChild("MoneyIslandMap")
    if map then
        local farm = map:FindFirstChild("FarmZone")
        if farm then
            local models = farm:FindFirstChild("CoinModels")
            if models then
                models.ChildAdded:Connect(function(c)
                    if c:IsA("Part") and c:GetAttribute("GeyserCoin") then
                        table.insert(coins, c)
                        addCoinGlow(c)
                    end
                end)
            end
        end
    end

    -- Per-coin lock so we don't fire for the same coin twice before server destroys it
    local magnetLocked = {}

    RunService.Heartbeat:Connect(function()
        if magnetRadius <= 0 then return end
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local playerPos = hrp.Position

        for _, coin in ipairs(coins) do
            if not coin.Parent then continue end   -- already destroyed by server
            if magnetLocked[coin] then continue end

            local dist = (coin.Position - playerPos).Magnitude
            if dist <= magnetRadius then
                magnetLocked[coin] = true
                -- Send the coin reference — server validates range, geyser cap, then destroys it
                MagnetRE:FireServer(coin)

                task.spawn(function()
                    -- Animate a clone flying to player for visual feedback
                    local clone = coin:Clone()
                    clone.Parent = workspace
                    clone.CanCollide = false
                    TweenService:Create(clone,
                        TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                        {CFrame = CFrame.new(playerPos + Vector3.new(0,2,0))
                            * CFrame.Angles(0,0,math.rad(90))}):Play()
                    task.wait(0.16)
                    clone:Destroy()
                    -- Hold lock briefly; cleared once coin is destroyed or 1.5s passes
                    local t = 0
                    while t < 1.5 do
                        task.wait(0.05); t = t + 0.05
                        if not coin.Parent then break end
                    end
                    magnetLocked[coin] = nil
                end)
            end
        end
    end)
end)

print("[MoneyIsland] CoinSpin: ready")

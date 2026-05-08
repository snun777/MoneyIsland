-- CoinSpin.client.lua
-- 1. Floating +X text on coin collect
-- 2. Coin magnet with float animation (fixes coin-stuck-on-floor bug)
-- 3. Other players' magnet rings visible (pink/magenta)
-- 4. Sword PvP client — equip CoinSword → click to attack nearby players

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local RE_Notify = ReplicatedStorage:WaitForChild("NotifyPlayer",      30)
local RE_Update = ReplicatedStorage:WaitForChild("UpdateStats",       30)
local MagnetRE  = ReplicatedStorage:WaitForChild("MagnetCollect",     30)
local MagnetBroadcastRE = ReplicatedStorage:WaitForChild("MagnetBroadcast_RE", 30)
local SwordHitRE        = ReplicatedStorage:WaitForChild("SwordHit_RE",       30)

local playerCooldown = 8  -- kept in sync with server TICK_BASE via RE_Update

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

-- ── OWN MAGNET RING (cyan) ─────────────────────────────────
local ringParts = {}

local function clearRing()
    for _, p in ipairs(ringParts) do pcall(function() p:Destroy() end) end
    ringParts = {}
end

local function buildRing(cx, cy, cz, radius, col)
    local N = 40
    local r = radius
    local tw = 0.45
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
        seg.Color = col or Color3.fromRGB(0, 220, 255)
        seg.Material = Enum.Material.Neon
        seg.Transparency = 0
        seg.TopSurface = Enum.SurfaceType.Smooth
        seg.BottomSurface = Enum.SurfaceType.Smooth
        seg.Parent = workspace
        table.insert(ringParts, seg)
    end
    return ringParts
end

local function updateRing()
    clearRing()
    if magnetRadius <= 0 then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    buildRing(hrp.Position.X, hrp.Position.Y - 2.8, hrp.Position.Z, magnetRadius, Color3.fromRGB(0, 220, 255))
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.Heartbeat:Connect(function()
    if #ringParts == 0 then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
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
        local hit = workspace:Raycast(Vector3.new(sx, hrp.Position.Y + 5, sz), Vector3.new(0,-20,0), rayParams)
        local sy = hit and (hit.Position.Y + 0.08) or (hrp.Position.Y - 2.8)
        seg.CFrame = CFrame.new(sx, sy, sz) * CFrame.Angles(0, -(a + math.pi/2), 0)
    end
end)

local otherMagnetRings = {}  -- [userId] = {parts={}, lastSeen=tick(), pos, range}

player.CharacterRemoving:Connect(function()
    clearRing()
    for uid, data in pairs(otherMagnetRings) do
        for _, p in ipairs(data.parts or {}) do pcall(function() p:Destroy() end) end
    end
    otherMagnetRings = {}
end)

RE_Update.OnClientEvent:Connect(function(data)
    if not data or not data.upgrades then return end
    local hasMegaMagnet = data._gp and data._gp.megaMagnet
    local newRadius = 0
    if hasMegaMagnet then
        local lvl   = data.upgrades["coinMagnet"] or 0
        newRadius   = (5 + lvl * 3) + 15
    end
    if newRadius ~= magnetRadius then
        magnetRadius = newRadius
        updateRing()
    end
    local tsLvl = data.upgrades["touchSpeed"] or 0
    playerCooldown = math.max(1, 8 - tsLvl)
end)

-- ── OTHER PLAYERS' MAGNET RINGS (pink/magenta) ───────────────
-- MagnetBroadcast_RE sends all active magnet players every 0.25s.
-- We render rings for everyone EXCEPT ourselves (already rendered above).

local function buildOtherRing(uid, pos, range)
    -- Clear old ring if it exists
    local old = otherMagnetRings[uid]
    if old then
        for _, p in ipairs(old.parts or {}) do pcall(function() p:Destroy() end) end
    end

    local parts = {}
    local N = 32
    local r = range
    local tw = 0.35
    local segArc = (2 * math.pi) / N
    local segLen = 2 * r * math.sin(segArc / 2) + 0.05
    local cy = pos.Y - 2.8
    for i = 0, N-1 do
        local a = i * segArc
        local x = pos.X + math.cos(a) * r
        local z = pos.Z + math.sin(a) * r
        local seg = Instance.new("Part")
        seg.Anchored = true; seg.CanCollide = false; seg.CastShadow = false
        seg.Size = Vector3.new(segLen, tw, tw)
        seg.CFrame = CFrame.new(x, cy, z) * CFrame.Angles(0, -(a + math.pi/2), 0)
        seg.Color = Color3.fromRGB(255, 60, 220)  -- pink/magenta for other players
        seg.Material = Enum.Material.Neon
        seg.Transparency = 0.3
        seg.TopSurface = Enum.SurfaceType.Smooth
        seg.BottomSurface = Enum.SurfaceType.Smooth
        seg.Parent = workspace
        table.insert(parts, seg)
    end
    otherMagnetRings[uid] = {parts = parts, lastSeen = tick(), pos = pos, range = range}
end

-- Update other-player ring positions every heartbeat
RunService.Heartbeat:Connect(function()
    for uid, data in pairs(otherMagnetRings) do
        -- Remove stale rings (not seen in >1s = player moved away / lost magnet)
        if tick() - data.lastSeen > 1.0 then
            for _, p in ipairs(data.parts or {}) do pcall(function() p:Destroy() end) end
            otherMagnetRings[uid] = nil
        end
    end
end)

MagnetBroadcastRE.OnClientEvent:Connect(function(magnetData)
    local myUid = player.UserId
    for _, entry in ipairs(magnetData) do
        if entry.userId ~= myUid then
            -- Update or create ring for this player
            local existing = otherMagnetRings[entry.userId]
            local needRebuild = not existing
                or math.abs(existing.range - entry.range) > 0.5
                or (existing.pos - entry.pos).Magnitude > 3

            if needRebuild then
                buildOtherRing(entry.userId, entry.pos, entry.range)
            else
                -- Just update lastSeen and move the parts
                existing.lastSeen = tick()
                local pos = entry.pos
                local N = #existing.parts
                local r = existing.range
                local segArc = (2 * math.pi) / N
                local cy = pos.Y - 2.8
                for i, seg in ipairs(existing.parts) do
                    local a = (i-1) * segArc
                    local sx = pos.X + math.cos(a) * r
                    local sz = pos.Z + math.sin(a) * r
                    seg.CFrame = CFrame.new(sx, cy, sz) * CFrame.Angles(0, -(a + math.pi/2), 0)
                end
                existing.pos = pos
            end
        end
    end
    -- Clear rings for players no longer in the broadcast
    local activeIds = {}
    for _, entry in ipairs(magnetData) do activeIds[entry.userId] = true end
    for uid, data in pairs(otherMagnetRings) do
        if not activeIds[uid] then
            for _, p in ipairs(data.parts or {}) do pcall(function() p:Destroy() end) end
            otherMagnetRings[uid] = nil
        end
    end
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

    local magnetLocked = {}

    RunService.Heartbeat:Connect(function()
        if magnetRadius <= 0 then return end
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local playerPos = hrp.Position

        for _, coin in ipairs(coins) do
            if not coin.Parent then continue end
            if magnetLocked[coin] then continue end

            local dist = (coin.Position - playerPos).Magnitude
            if dist <= magnetRadius then
                magnetLocked[coin] = true

                -- ── BUG FIX: immediately hide the original coin so it doesn't
                --    linger on the floor while waiting for server destruction.
                coin.Transparency = 1
                coin.CanCollide   = false

                MagnetRE:FireServer(coin)

                task.spawn(function()
                    local clone = coin:Clone()
                    clone.Transparency = 0  -- clone is visible for animation
                    clone.Parent = workspace
                    clone.CanCollide = false
                    TweenService:Create(clone,
                        TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                        {CFrame = CFrame.new(playerPos + Vector3.new(0,2,0))
                            * CFrame.Angles(0,0,math.rad(90))}):Play()
                    task.wait(0.16)
                    clone:Destroy()
                    -- Wait for server to destroy the real coin; if it doesn't (rejected),
                    -- restore visibility so the player can try again.
                    local t = 0
                    while t < 1.5 do
                        task.wait(0.05); t = t + 0.05
                        if not coin.Parent then break end
                    end
                    -- If coin still exists but server rejected (geyser cap), show it again
                    if coin.Parent then
                        coin.Transparency = 0
                        coin.CanCollide   = true
                    end
                    magnetLocked[coin] = nil
                end)
            end
        end
    end)
end)

-- ── SWORD PvP CLIENT ──────────────────────────────────────────
-- Detects when CoinSword tool is equipped, handles Activated (click/tap)
-- to find the closest enemy player in range and fire SwordHit_RE to server.

local swingSFX = Instance.new("Sound", script)
swingSFX.Volume = 0.6; swingSFX.PlaybackSpeed = 1.1
-- swingSFX.SoundId = "rbxassetid://0"  -- replace with a sword swing audio ID

local swordCooldownActive = false
local SWORD_RANGE         = 10  -- studs

local function showSlashVFX(hrpCFrame)
    -- A brief golden arc that expands and fades
    local slash = Instance.new("Part")
    slash.Anchored    = true
    slash.CanCollide  = false
    slash.CastShadow  = false
    slash.Size        = Vector3.new(0.3, 1.5, 7)
    slash.Material    = Enum.Material.Neon
    slash.Color       = Color3.fromRGB(255, 220, 50)
    slash.Transparency = 0
    slash.CFrame      = hrpCFrame * CFrame.new(0, 1, -3.5)
    slash.Parent      = workspace

    TweenService:Create(slash, TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {Transparency = 1, Size = Vector3.new(0.1, 0.8, 9)}):Play()
    game:GetService("Debris"):AddItem(slash, 0.35)
end

local function findNearestEnemy(hrp)
    local nearest, nearestDist = nil, SWORD_RANGE
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        local c = p.Character
        if not c then continue end
        local ohrp = c:FindFirstChild("HumanoidRootPart")
        if not ohrp then continue end
        local d = (ohrp.Position - hrp.Position).Magnitude
        if d < nearestDist then
            nearest    = p
            nearestDist = d
        end
    end
    return nearest
end

local function onSwordActivated()
    if swordCooldownActive then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    swordCooldownActive = true
    -- swingSFX:Play()

    showSlashVFX(hrp.CFrame)

    local victim = findNearestEnemy(hrp)
    if victim then
        SwordHitRE:FireServer(victim)
        floatText("⚔️", Color3.fromRGB(255,100,50))
    else
        floatText("⚔️ Miss!", Color3.fromRGB(200,200,200))
    end

    -- Show cooldown visually: a short flash on screen handled by ClientUI via its own systems.
    -- Reset cooldown after 1.2s
    task.delay(1.2, function()
        swordCooldownActive = false
    end)
end

-- Listen for sword being equipped to the character
local function attachSwordListeners(char)
    if not char then return end
    local function tryBind(tool)
        if tool:IsA("Tool") and tool.Name == "CoinSword" then
            tool.Activated:Connect(onSwordActivated)
        end
    end
    -- Already in character
    for _, obj in ipairs(char:GetChildren()) do tryBind(obj) end
    char.ChildAdded:Connect(tryBind)
end

if player.Character then attachSwordListeners(player.Character) end
player.CharacterAdded:Connect(attachSwordListeners)

print("[MoneyIsland] CoinSpin: ready (v2 — coin fix, magnet broadcast, sword client)")

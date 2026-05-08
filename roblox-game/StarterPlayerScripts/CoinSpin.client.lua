-- CoinSpin.client.lua  (v4 — magnet removed)
-- 1. Floating +X text on coin collect
-- 2. Coin glow (SelectionBox on geyser coins)
-- 3. Multi-weapon PvP client — equip weapon → click to attack nearby players
-- 4. Dash (Q) & Block (E) abilities

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Debris            = game:GetService("Debris")

local player    = Players.LocalPlayer
local RE_Notify = ReplicatedStorage:WaitForChild("NotifyPlayer",      30)
local RE_Update = ReplicatedStorage:WaitForChild("UpdateStats",       30)
local WeaponHitRE       = ReplicatedStorage:WaitForChild("WeaponHit_RE",       30)
local UseAbilityRE      = ReplicatedStorage:WaitForChild("UseAbility_RE",      30)
local AbilityCooldownRE = ReplicatedStorage:WaitForChild("AbilityCooldown_RE", 30)
local SwordHitRE        = WeaponHitRE  -- backward compat alias

local playerCooldown = 8  -- kept in sync with server TICK_BASE via RE_Update

-- ── FLOATING TEXT ─────────────────────────────────────────────
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

RE_Update.OnClientEvent:Connect(function(data)
    if not data or not data.upgrades then return end
    local tsLvl = data.upgrades["touchSpeed"] or 0
    playerCooldown = math.max(1, 8 - tsLvl)
end)

-- ── COIN GLOW (SelectionBox on geyser coins) ──────────────────
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
    getGeyserCoins()
    local map = workspace:FindFirstChild("MoneyIslandMap")
    if map then
        local farm = map:FindFirstChild("FarmZone")
        if farm then
            local models = farm:FindFirstChild("CoinModels")
            if models then
                models.ChildAdded:Connect(function(c)
                    if c:IsA("Part") and c:GetAttribute("GeyserCoin") then
                        addCoinGlow(c)
                    end
                end)
            end
        end
    end
end)

-- ── MULTI-WEAPON PvP CLIENT ───────────────────────────────────
local WEAPON_DATA = {
    CoinBlade     = {range=10, col=Color3.fromRGB(255,215,0),  isAoE=false, isProj=false, cooldown=1.2},
    CoinSword     = {range=10, col=Color3.fromRGB(255,215,0),  isAoE=false, isProj=false, cooldown=1.2},
    LaserStaff    = {range=55, col=Color3.fromRGB(80,160,255), isAoE=false, isProj=true,  cooldown=2.0},
    ThunderHammer = {range=14, col=Color3.fromRGB(255,255,60), isAoE=true,  isProj=false, cooldown=4.0},
    ShadowBlade   = {range=11, col=Color3.fromRGB(160,40,255), isAoE=false, isProj=false, cooldown=1.6},
}
local WEAPON_NAMES_SET = {}
for k in pairs(WEAPON_DATA) do WEAPON_NAMES_SET[k] = true end

local weaponCooldownActive = false
local equippedWeaponName   = nil

-- ── VFX helpers ───────────────────────────────────────────────
local function showSlashVFX(hrpCFrame, col)
    local slash = Instance.new("Part")
    slash.Anchored = true; slash.CanCollide = false; slash.CastShadow = false
    slash.Size = Vector3.new(0.5, 3, 10); slash.Material = Enum.Material.Neon
    slash.Color = col or Color3.fromRGB(255,220,50); slash.Transparency = 0
    slash.CFrame = hrpCFrame * CFrame.new(0, 1, -5); slash.Parent = workspace
    TweenService:Create(slash, TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {Transparency=1, Size=Vector3.new(0.1,1.5,13)}):Play()
    Debris:AddItem(slash, 0.35)
    -- Trailing slash
    local slash2 = Instance.new("Part")
    slash2.Anchored = true; slash2.CanCollide = false; slash2.CastShadow = false
    slash2.Size = Vector3.new(0.3, 2, 8); slash2.Material = Enum.Material.Neon
    slash2.Color = col or Color3.fromRGB(255,220,50); slash2.Transparency = 0.4
    slash2.CFrame = hrpCFrame * CFrame.new(0.8, 0.5, -4) * CFrame.Angles(0,0,math.rad(15))
    slash2.Parent = workspace
    TweenService:Create(slash2, TweenInfo.new(0.25), {Transparency=1}):Play()
    Debris:AddItem(slash2, 0.3)
    -- Gold hit-ring that expands at the blade tip
    local ring = Instance.new("Part")
    ring.Anchored = true; ring.CanCollide = false; ring.CastShadow = false
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(1, 0.3, 1); ring.Material = Enum.Material.Neon
    ring.Color = col or Color3.fromRGB(255,215,0); ring.Transparency = 0.1
    ring.CFrame = hrpCFrame * CFrame.new(0, 0, -6) * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = workspace
    TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad),
        {Size=Vector3.new(1,6,6), Transparency=1}):Play()
    Debris:AddItem(ring, 0.3)
end

local function showProjectileVFX(origin, direction, col)
    local bolt = Instance.new("Part")
    bolt.Anchored = true; bolt.CanCollide = false; bolt.CastShadow = false
    bolt.Size = Vector3.new(0.7, 0.7, 4); bolt.Material = Enum.Material.Neon
    bolt.Color = col or Color3.fromRGB(80,160,255); bolt.Transparency = 0
    bolt.CFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -1)
    bolt.Parent = workspace
    local target = origin + direction.Unit * 60
    TweenService:Create(bolt, TweenInfo.new(0.35, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(target, target + direction), Transparency = 0.5}):Play()
    Debris:AddItem(bolt, 0.4)
    local glow = Instance.new("Part")
    glow.Anchored = true; glow.CanCollide = false; glow.CastShadow = false
    glow.Size = Vector3.new(1.4, 1.4, 5); glow.Material = Enum.Material.Neon
    glow.Color = col or Color3.fromRGB(160,210,255); glow.Transparency = 0.65
    glow.CFrame = bolt.CFrame; glow.Parent = workspace
    TweenService:Create(glow, TweenInfo.new(0.35, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(target, target + direction), Transparency = 1}):Play()
    Debris:AddItem(glow, 0.4)
end

local function showAoEVFX(pos, range, col)
    local ring = Instance.new("Part")
    ring.Anchored = true; ring.CanCollide = false; ring.CastShadow = false
    ring.Size = Vector3.new(2, 0.6, 2); ring.Material = Enum.Material.Neon
    ring.Shape = Enum.PartType.Cylinder
    ring.Color = col or Color3.fromRGB(255,255,60); ring.Transparency = 0.1
    ring.CFrame = CFrame.new(pos.X, pos.Y+0.3, pos.Z) * CFrame.Angles(0,0,math.rad(90))
    ring.Parent = workspace
    TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        {Size = Vector3.new(range*2+12, 0.2, range*2+12), Transparency = 1}):Play()
    Debris:AddItem(ring, 0.6)
    for i = 1, 5 do
        local spike = Instance.new("Part")
        spike.Anchored = true; spike.CanCollide = false; spike.CastShadow = false
        local angle = (i/5) * math.pi * 2
        spike.Size = Vector3.new(0.4, 6, 0.4); spike.Material = Enum.Material.Neon
        spike.Color = col or Color3.fromRGB(255,255,60); spike.Transparency = 0.2
        spike.CFrame = CFrame.new(pos.X + math.cos(angle)*range*0.6, pos.Y+3, pos.Z + math.sin(angle)*range*0.6)
        spike.Parent = workspace
        TweenService:Create(spike, TweenInfo.new(0.4), {Transparency=1, Size=Vector3.new(0.1,8,0.1)}):Play()
        Debris:AddItem(spike, 0.5)
    end
end

local function showShadowFlash(hrpCFrame)
    for i = 1, 5 do
        local flash = Instance.new("Part")
        flash.Anchored = true; flash.CanCollide = false; flash.CastShadow = false
        flash.Size = Vector3.new(2.5, 5, 0.4); flash.Material = Enum.Material.Neon
        flash.Color = Color3.fromRGB(160, 40, 255); flash.Transparency = 0.1
        flash.CFrame = hrpCFrame * CFrame.new(math.random(-3,3), 0, -2.5 - i*0.8) * CFrame.Angles(0, math.rad(i*25), 0)
        flash.Parent = workspace
        TweenService:Create(flash, TweenInfo.new(0.3), {Transparency = 1, Size=Vector3.new(0.1,6,0.1)}):Play()
        Debris:AddItem(flash, 0.35)
    end
    local ring = Instance.new("Part")
    ring.Anchored = true; ring.CanCollide = false; ring.CastShadow = false
    ring.Size = Vector3.new(3,0.3,3); ring.Material = Enum.Material.Neon
    ring.Shape = Enum.PartType.Cylinder
    ring.Color = Color3.fromRGB(80,0,140); ring.Transparency = 0.2
    ring.CFrame = hrpCFrame * CFrame.new(0,-2.5,0) * CFrame.Angles(0,0,math.rad(90))
    ring.Parent = workspace
    TweenService:Create(ring, TweenInfo.new(0.4), {Size=Vector3.new(14,0.2,14), Transparency=1}):Play()
    Debris:AddItem(ring, 0.45)
end

local activeBlockShield = nil
local function showBlockShield(char)
    if activeBlockShield then pcall(function() activeBlockShield:Destroy() end) end
    local hrp = char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local shield = Instance.new("Part")
    shield.Anchored = false; shield.CanCollide = false; shield.CastShadow = false
    shield.Shape = Enum.PartType.Ball
    shield.Size = Vector3.new(8, 8, 8); shield.Material = Enum.Material.Neon
    shield.Color = Color3.fromRGB(100, 180, 255); shield.Transparency = 0.45
    shield.CFrame = hrp.CFrame; shield.Parent = workspace
    local weld = Instance.new("Weld", shield)
    weld.Part0 = hrp; weld.Part1 = shield; weld.C0 = CFrame.new(0,0,0)
    activeBlockShield = shield
    TweenService:Create(shield, TweenInfo.new(1.8, Enum.EasingStyle.Quad), {Transparency=1}):Play()
    Debris:AddItem(shield, 2.1)
    task.delay(2.1, function() if activeBlockShield == shield then activeBlockShield = nil end end)
end

-- ── Hit detection ──────────────────────────────────────────────
local function findEnemiesInRange(hrp, range, isAoE)
    local results = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        local c = p.Character; if not c then continue end
        local ohrp = c:FindFirstChild("HumanoidRootPart"); if not ohrp then continue end
        local d = (ohrp.Position - hrp.Position).Magnitude
        if d <= range then
            table.insert(results, p)
            if not isAoE then break end
        end
    end
    if not isAoE and #results > 1 then
        table.sort(results, function(a, b)
            local ap = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
            local bp = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
            if not ap or not bp then return false end
            return (ap.Position-hrp.Position).Magnitude < (bp.Position-hrp.Position).Magnitude
        end)
        return {results[1]}
    end
    return results
end

local function onWeaponActivated(weaponId)
    if weaponCooldownActive then return end
    local wdata = WEAPON_DATA[weaponId]; if not wdata then return end
    local char = player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

    weaponCooldownActive = true

    if wdata.isProj then
        local fwd = hrp.CFrame.LookVector
        showProjectileVFX(hrp.Position + Vector3.new(0,1,0), fwd, wdata.col)
    elseif wdata.isAoE then
        showAoEVFX(hrp.Position, wdata.range, wdata.col)
    elseif weaponId == "ShadowBlade" then
        showShadowFlash(hrp.CFrame)
    else
        showSlashVFX(hrp.CFrame, wdata.col)
    end

    local victims = findEnemiesInRange(hrp, wdata.range, wdata.isAoE)
    if #victims > 0 then
        for _, v in ipairs(victims) do
            WeaponHitRE:FireServer(v, weaponId)
        end
        floatText(#victims > 1 and ("⚔️ ×" .. #victims) or "⚔️ Hit!", wdata.col)
    else
        floatText("⚔️ Miss!", Color3.fromRGB(180,180,180))
    end

    task.delay(wdata.cooldown, function()
        weaponCooldownActive = false
    end)
end

-- ── Weapon attachment ──────────────────────────────────────────
local function attachWeaponListeners(char)
    if not char then return end
    local function tryBind(tool)
        if not tool:IsA("Tool") then return end
        if not WEAPON_NAMES_SET[tool.Name] then return end
        equippedWeaponName = tool.Name
        tool.Activated:Connect(function() onWeaponActivated(tool.Name) end)
        tool.Unequipped:Connect(function()
            if equippedWeaponName == tool.Name then equippedWeaponName = nil end
            weaponCooldownActive = false
        end)
    end
    for _, obj in ipairs(char:GetChildren()) do tryBind(obj) end
    char.ChildAdded:Connect(tryBind)
end

if player.Character then attachWeaponListeners(player.Character) end
player.CharacterAdded:Connect(function(char)
    weaponCooldownActive = false
    equippedWeaponName   = nil
    attachWeaponListeners(char)
end)

AbilityCooldownRE.OnClientEvent:Connect(function(abilityName, cd)
    if abilityName == "Weapon" then
        task.delay(cd, function() weaponCooldownActive = false end)
    end
end)

-- ── DASH (Q) & BLOCK (E) input ────────────────────────────────
local dashCooldown  = false
local blockCooldown = false

local function showDashTrail(startPos, endPos)
    local mid = (startPos + endPos) / 2
    local len = math.max(1, (endPos - startPos).Magnitude)
    local trail = Instance.new("Part")
    trail.Anchored = true; trail.CanCollide = false; trail.CastShadow = false
    trail.Size = Vector3.new(1.2, 1.2, len); trail.Material = Enum.Material.Neon
    trail.Color = Color3.fromRGB(80,180,255); trail.Transparency = 0.1
    trail.CFrame = CFrame.new(mid, endPos); trail.Parent = workspace
    TweenService:Create(trail, TweenInfo.new(0.35), {Transparency = 1, Size=Vector3.new(0.1,0.1,len)}):Play()
    Debris:AddItem(trail, 0.4)
    local halo = Instance.new("Part")
    halo.Anchored = true; halo.CanCollide = false; halo.CastShadow = false
    halo.Size = Vector3.new(2.5, 2.5, len); halo.Material = Enum.Material.Neon
    halo.Color = Color3.fromRGB(160,220,255); halo.Transparency = 0.6
    halo.CFrame = CFrame.new(mid, endPos); halo.Parent = workspace
    TweenService:Create(halo, TweenInfo.new(0.3), {Transparency = 1}):Play()
    Debris:AddItem(halo, 0.35)
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == Enum.KeyCode.Q and not dashCooldown then
        local char = player.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        dashCooldown = true
        local startPos = hrp.Position
        UseAbilityRE:FireServer("dash")
        task.delay(0.08, function()
            if hrp.Parent then showDashTrail(startPos, hrp.Position) end
        end)
        floatText("💨 Dash!", Color3.fromRGB(80,200,255))
        task.delay(8, function() dashCooldown = false end)

    elseif input.KeyCode == Enum.KeyCode.E and not blockCooldown then
        blockCooldown = true
        UseAbilityRE:FireServer("block")
        local char = player.Character
        if char then showBlockShield(char) end
        floatText("🛡️ Block!", Color3.fromRGB(100,180,255))
        task.delay(15, function() blockCooldown = false end)
    end
end)

print("[MoneyIsland] CoinSpin v4: weapon PvP + coin glow (magnet removed)")

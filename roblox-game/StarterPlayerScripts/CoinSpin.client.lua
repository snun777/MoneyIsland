-- GunTycoon WeaponHandler v1
-- Handles firearm shooting, bullet visuals, hit effects, cooldown tracking

local Players          = game:GetService("Players")
local RS               = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Inline config (no module dependency)
local BULLET_COLORS = {
    Color3.fromRGB(255,240,160), Color3.fromRGB(160,220,255),
    Color3.fromRGB(255,100,50),  Color3.fromRGB(200,80,255),
}
local MAX_HP = 150

local WeaponFire     = RS:WaitForChild("WeaponFire",     30)
local WeaponEquipped = RS:WaitForChild("WeaponEquipped", 30)

-- ============================================================
-- State
-- ============================================================

local currentWeapon = {name="Pistol",damage=12,range=65,cooldown=0.75,speed=250,isAoe=false}
local currentFloor  = 1
local lastFired     = 0
local canShoot      = true
local isShooting    = false

-- ============================================================
-- Bullet visual
-- ============================================================

local function spawnBullet(origin, direction, range, color)
    local bulletLen = 4
    local bullet    = Instance.new("Part")
    bullet.Size     = Vector3.new(0.25, 0.25, bulletLen)
    bullet.CFrame   = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -bulletLen/2)
    bullet.Material = Enum.Material.Neon
    bullet.Color    = color or Color3.fromRGB(255, 240, 160)
    bullet.Anchored = true
    bullet.CanCollide = false
    bullet.CastShadow = false
    bullet.Parent   = workspace

    local trail = Instance.new("Trail", bullet)
    local a0 = Instance.new("Attachment", bullet); a0.Position = Vector3.new(0,0,-bulletLen/2)
    local a1 = Instance.new("Attachment", bullet); a1.Position = Vector3.new(0,0, bulletLen/2)
    trail.Attachment0 = a0; trail.Attachment1 = a1
    trail.Color = ColorSequence.new(color or Color3.fromRGB(255,240,160), Color3.fromRGB(255,200,80))
    trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    trail.Lifetime = 0.08
    trail.WidthScale = NumberSequence.new(1)

    local dist     = range
    local speed    = currentWeapon.speed or 300
    local travelT  = dist / speed
    local targetCF = CFrame.new(origin + direction * dist, origin + direction * dist + direction) * CFrame.new(0,0,-bulletLen/2)

    local ti = TweenInfo.new(travelT, Enum.EasingStyle.Linear)
    local tw = TweenService:Create(bullet, ti, {CFrame = targetCF})
    tw:Play()
    tw.Completed:Connect(function() bullet:Destroy() end)
    task.delay(travelT + 0.1, function()
        if bullet.Parent then bullet:Destroy() end
    end)
    return bullet
end

local function spawnHitEffect(pos, color)
    local sparks = Instance.new("Part")
    sparks.Size      = Vector3.new(0.5,0.5,0.5)
    sparks.CFrame    = CFrame.new(pos)
    sparks.Anchored  = true
    sparks.CanCollide= false
    sparks.Transparency = 1
    sparks.Parent    = workspace

    local pe = Instance.new("ParticleEmitter", sparks)
    pe.Color     = ColorSequence.new(color or Color3.fromRGB(255,200,50))
    pe.LightEmission = 0.8
    pe.Speed     = NumberRange.new(12, 28)
    pe.SpreadAngle = Vector2.new(80, 80)
    pe.Rate      = 0
    pe.Lifetime  = NumberRange.new(0.15, 0.4)
    pe.Size      = NumberSequence.new({NumberSequenceKeypoint.new(0,0.4), NumberSequenceKeypoint.new(1,0)})
    pe:Emit(18)

    task.delay(0.5, function() sparks:Destroy() end)
end

local function screenShake(intensity)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local orig = camera.CFrame
    for _ = 1, 4 do
        local offset = Vector3.new(
            (math.random()-0.5)*intensity,
            (math.random()-0.5)*intensity,
            0
        )
        camera.CFrame = camera.CFrame * CFrame.new(offset)
        task.wait(0.03)
    end
    camera.CFrame = orig
end

-- ============================================================
-- Muzzle flash
-- ============================================================

local function muzzleFlash(pos)
    local fl = Instance.new("Part")
    fl.Size      = Vector3.new(1,1,1)
    fl.CFrame    = CFrame.new(pos)
    fl.Anchored  = true
    fl.CanCollide= false
    fl.Material  = Enum.Material.Neon
    fl.Color     = Color3.fromRGB(255,240,140)
    fl.Parent    = workspace
    local pl = Instance.new("PointLight", fl)
    pl.Range = 20; pl.Brightness = 6; pl.Color = Color3.fromRGB(255,220,120)
    TweenService:Create(fl, TweenInfo.new(0.08), {Size=Vector3.new(0.1,0.1,0.1), Transparency=1}):Play()
    task.delay(0.1, function() fl:Destroy() end)
end

-- ============================================================
-- Find target player from raycast
-- ============================================================

local function getShootTarget()
    local char = player.Character
    if not char then return nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end

    local origin = camera.CFrame.Position
    local direction = camera.CFrame.LookVector

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}

    local result = workspace:Raycast(origin, direction * currentWeapon.range, params)

    local hitPos = result and result.Position or (origin + direction * currentWeapon.range)
    local hitPart = result and result.Instance

    local targetPlayer = nil
    if hitPart then
        local hitChar = hitPart:FindFirstAncestorOfClass("Model")
        if hitChar then
            local p = Players:GetPlayerFromCharacter(hitChar)
            if p and p ~= player then
                targetPlayer = p
            end
        end
    end

    return targetPlayer, hitPos, origin + (root.CFrame.LookVector * 2) + Vector3.new(0, 1.5, 0)
end

-- ============================================================
-- Fire weapon
-- ============================================================

local function fire()
    if not canShoot then return end
    local wData = currentWeapon
    local now   = tick()
    if now - lastFired < wData.cooldown then return end

    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    lastFired = now
    canShoot  = false

    -- Raycast
    local targetPlayer, hitPos, muzzlePos = getShootTarget()
    local bulletDir = (hitPos - muzzlePos).Unit
    local bulletColor = BULLET_COLORS[currentFloor]

    -- Visuals
    spawnBullet(muzzlePos, bulletDir, currentWeapon.range, bulletColor)
    muzzleFlash(muzzlePos)
    if wData.damage >= 80 then
        task.spawn(screenShake, 0.6)
    elseif wData.damage >= 40 then
        task.spawn(screenShake, 0.3)
    end

    -- Hit effect
    if hitPos then
        task.delay(currentWeapon.range / (currentWeapon.speed or 300), function()
            spawnHitEffect(hitPos, bulletColor)
        end)
    end

    -- Send to server
    if targetPlayer then
        WeaponFire:FireServer(targetPlayer)
    end

    -- Floating hit text on local screen
    if targetPlayer and _G.GunTycoon_ShowToast then
        -- brief "HIT" indicator
    end

    -- Cooldown bar
    if _G.GunTycoon_SetCooldown then
        _G.GunTycoon_SetCooldown(0)
        local startT  = tick()
        local dur     = wData.cooldown
        local conn
        conn = RunService.Heartbeat:Connect(function()
            local elapsed = tick() - startT
            local pct = math.min(elapsed / dur, 1)
            _G.GunTycoon_SetCooldown(pct)
            if pct >= 1 then
                canShoot = true
                conn:Disconnect()
            end
        end)
    else
        task.delay(wData.cooldown, function() canShoot = true end)
    end
end

-- ============================================================
-- Input: left click to fire
-- ============================================================

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isShooting = true
        fire()
    end
end)

UserInputService.InputEnded:Connect(function(input, _)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isShooting = false
    end
end)

-- Auto-fire for full-auto weapons (cooldown < 0.5s)
RunService.Heartbeat:Connect(function()
    if isShooting and (currentWeapon.cooldown or 1) < 0.5 then
        fire()
    end
end)

-- ============================================================
-- Weapon switch from server
-- ============================================================

WeaponEquipped.OnClientEvent:Connect(function(floor, wi, wData)
    currentFloor  = floor
    currentWeapon = wData
    canShoot      = true
    lastFired     = 0
end)

-- ============================================================
-- Dropper glow ping animation
-- ============================================================

local DropperPing = RS:WaitForChild("DropperPing", 30)

DropperPing.OnClientEvent:Connect(function(floor, di)
    local tycoons = workspace:FindFirstChild("Tycoons")
    if not tycoons then return end
    local plrData = _G.GunTycoon_GetLocalStats and _G.GunTycoon_GetLocalStats()
    if not plrData or not plrData.slot then return end
    local t = tycoons:FindFirstChild("Tycoon_" .. plrData.slot)
    if not t then return end
    local glow = t:FindFirstChild("DGlow_F"..floor.."_"..di, true)
    if not glow then return end
    local origColor = glow.Color
    glow.Color = Color3.fromRGB(255,255,200)
    TweenService:Create(glow, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Color = origColor}):Play()
end)

-- ============================================================
-- Income tick visual feedback: periodic "+X" text near player
-- ============================================================

local IncomeUpdate = RS:WaitForChild("IncomeUpdate", 30)

IncomeUpdate.OnClientEvent:Connect(function(amount)
    if amount <= 0 then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    -- Project character position to screen
    local screenPos, onScreen = camera:WorldToScreenPoint(root.Position + Vector3.new(0, 4, 0))
    if onScreen and _G.GunTycoon_ShowFloat then
        local stats = _G.GunTycoon_GetLocalStats and _G.GunTycoon_GetLocalStats()
        local income = stats and stats.income or amount
        -- Only show if on tycoon (avoid spam when away)
        _G.GunTycoon_ShowFloat("+" .. (amount >= 1000 and string.format("%.0fK", amount/1000) or tostring(amount)), Vector2.new(screenPos.X, screenPos.Y), Color3.fromRGB(255,200,50))
    end
end)

print("[WeaponHandler] GunTycoon weapon system ready")

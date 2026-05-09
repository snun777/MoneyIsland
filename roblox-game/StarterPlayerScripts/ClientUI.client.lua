-- ============================================================
-- MONEY ISLAND TYCOON — ClientUI.lua  (v3 LocalScript)
-- Place in: StarterPlayerScripts
-- ============================================================

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── wait for all remotes ──────────────────────────────────
local function waitRE(name) return ReplicatedStorage:WaitForChild(name, 30) end
local RE_UpdateStats  = waitRE("UpdateStats")
local RE_BuyUpgrade   = waitRE("BuyUpgrade")
local RE_Rebirth      = waitRE("Rebirth")
local RE_ClaimDaily   = waitRE("ClaimDaily")
local RE_ShowShop     = waitRE("ShowShop")
local RE_NotifyPlayer = waitRE("NotifyPlayer")
local RE_RequestData  = waitRE("RequestData")
local RE_GeyserState  = waitRE("GeyserState")
local RE_PlotTick     = waitRE("PlotTick_RE")
local RE_RaidStatus   = waitRE("RaidStatus_RE")
local RE_MachineRate  = waitRE("MachineRate_RE")
local RE_HPUpdate     = waitRE("HPUpdate_RE")
local RE_PlayerDied   = waitRE("PlayerDied_RE")
local RE_RandomEvent  = waitRE("RandomEvent_RE")
local RE_WeaponInfo   = waitRE("WeaponInfo_RE")
local RE_AbilityCD    = waitRE("AbilityCooldown_RE")
local RE_WeaponShop   = waitRE("WeaponShopBuy_RE")
local RE_PlotUpgrade  = waitRE("PlotUpgradeBuy_RE")

-- ── SOUND SYSTEM ─────────────────────────────────────────
local SoundService = game:GetService("SoundService")
local function makeSound(id, vol, pitch)
    local s = Instance.new("Sound")
    if id and id ~= 0 then
        s.SoundId = "rbxassetid://"..tostring(id)
    end
    s.Volume  = vol or 0.5
    s.PlaybackSpeed = pitch or 1
    s.RollOffMaxDistance = 0
    s.Parent = SoundService
    return s
end
local SFX = {
    coin      = makeSound(0, 0.4, 1.1),
    jackpot   = makeSound(0, 0.7, 1.0),
    geyser    = makeSound(0, 0.55, 0.9),
    megaBurst = makeSound(0, 0.8, 1.0),
    plotBuy   = makeSound(0, 0.6, 0.85),
    prestige  = makeSound(0, 0.9, 1.0),
    raidAlert = makeSound(0, 0.9, 0.8),
    swordHit  = makeSound(0, 0.7, 1.0),
}

-- ── PLOT POSITIONS (mirrors server PLOT_CENTERS) ─────────
local PLOT_CENTERS_CLIENT = {
    L_N   = Vector3.new(-50,  1,  50),
    R_N   = Vector3.new( 50,  1,  50),
    L_S   = Vector3.new(-50,  1, -50),
    R_S   = Vector3.new( 50,  1, -50),
    LL_M  = Vector3.new(-100, 1,   0),
    RR_M  = Vector3.new( 100, 1,   0),
    C_NN  = Vector3.new(  0,  1, 100),
    C_SS  = Vector3.new(  0,  1,-100),
    LL_N  = Vector3.new(-100, 1,  50),
    LL_S  = Vector3.new(-100, 1, -50),
    RR_N  = Vector3.new( 100, 1,  50),
    RR_S  = Vector3.new( 100, 1, -50),
    L_NN  = Vector3.new( -50, 1, 100),
    R_NN  = Vector3.new(  50, 1, 100),
    L_SS  = Vector3.new( -50, 1,-100),
    R_SS  = Vector3.new(  50, 1,-100),
    LL_NN = Vector3.new(-100, 1, 100),
    RR_NN = Vector3.new( 100, 1, 100),
    LL_SS = Vector3.new(-100, 1,-100),
    RR_SS = Vector3.new( 100, 1,-100),
}

-- ── PLOT FRIENDLY NAMES ──────────────────────────────────
local PLOT_NAMES = {
    L_N="🧲 Magnet",          R_N="⚗️ Alchemy Cauldron", L_S="🎰 Slot Machine",   R_S="💸 Coin Printer",
    LL_M="🤖 Roomba",         RR_M="⚡ Tesla Coil",       C_NN="🔭 Observatory",   C_SS="☢️ Reactor",
    LL_N="🏭 Factory",        LL_S="🚀 Rocket Silo",      RR_N="💎 Crystal Forge", RR_S="⏰ Clock Engine",
    L_NN="🌊 Wave Condenser", R_NN="🧬 DNA Tower",        L_SS="💣 Coin Cannon",   R_SS="⛏️ Mining Rig",
    LL_NN="🏦 Vault",         RR_NN="🌋 Lava Core",       LL_SS="🔮 Arcane Spire", RR_SS="🛸 UFO",
}

-- ── state ────────────────────────────────────────────────
local currentData  = nil
local upgradesDef  = nil
local shopOpen     = false
local lastRebirths = -1
local machineRates = {}  -- [plotId] = {coinVal, cd}

-- Ability cooldown state (tracked here so Heartbeat can access them)
local dashCdEnd  = 0   -- os.clock() when dash cooldown expires
local blockCdEnd = 0
local DASH_CD    = 8
local BLOCK_CD   = 15

-- ── FORMAT ───────────────────────────────────────────────
local function fmt(n)
    if n>=1e9 then return string.format("%.1fB",n/1e9)
    elseif n>=1e6 then return string.format("%.1fM",n/1e6)
    elseif n>=1e3 then return string.format("%.1fK",n/1e3)
    else return tostring(math.floor(n)) end
end

-- ============================================================
-- BUILD GUI
-- ============================================================
local old = playerGui:FindFirstChild("MoneyIslandUI")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name           = "MoneyIslandUI"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = playerGui

-- ── HUD ──────────────────────────────────────────────────
local hud = Instance.new("Frame", sg)
hud.Name            = "HUD"
hud.Size            = UDim2.new(0,340,0,56)
hud.Position        = UDim2.new(0.5,-170,0,10)
hud.BackgroundColor3= Color3.fromRGB(8,8,18)
hud.BorderSizePixel = 0
Instance.new("UICorner",hud).CornerRadius = UDim.new(0,12)
local hudStroke = Instance.new("UIStroke",hud)
hudStroke.Color = Color3.fromRGB(255,200,0); hudStroke.Thickness=1.5

local coinLbl = Instance.new("TextLabel",hud)
coinLbl.Name="CoinLbl"; coinLbl.Size=UDim2.new(0.6,0,1,0)
coinLbl.Position=UDim2.new(0,8,0,0); coinLbl.BackgroundTransparency=1
coinLbl.Text="💰 0"; coinLbl.TextColor3=Color3.fromRGB(255,215,0)
coinLbl.Font=Enum.Font.GothamBold; coinLbl.TextSize=24
coinLbl.TextXAlignment=Enum.TextXAlignment.Left

local rebirthLbl = Instance.new("TextLabel",hud)
rebirthLbl.Name="RebirthLbl"; rebirthLbl.Size=UDim2.new(0.28,0,1,0)
rebirthLbl.Position=UDim2.new(0.62,0,0,0); rebirthLbl.BackgroundTransparency=1
rebirthLbl.Text="🔥 x0"; rebirthLbl.TextColor3=Color3.fromRGB(255,120,0)
rebirthLbl.Font=Enum.Font.GothamBold; rebirthLbl.TextSize=18
rebirthLbl.TextXAlignment=Enum.TextXAlignment.Right

-- ── RANK BADGE ───────────────────────────────────────────
local rankBadge = Instance.new("Frame", hud)
rankBadge.Size = UDim2.new(0, 46, 0, 26); rankBadge.Position = UDim2.new(1,-52,0.5,-13)
rankBadge.BackgroundColor3 = Color3.fromRGB(40,30,0); rankBadge.BorderSizePixel = 0
Instance.new("UICorner", rankBadge).CornerRadius = UDim.new(0,6)
local rankLbl = Instance.new("TextLabel", rankBadge)
rankLbl.Size = UDim2.new(1,0,1,0); rankLbl.BackgroundTransparency = 1
rankLbl.Text = "#-"; rankLbl.TextColor3 = Color3.fromRGB(255,215,0)
rankLbl.Font = Enum.Font.GothamBold; rankLbl.TextSize = 14

-- ── PRESTIGE PROGRESS BAR ────────────────────────────────
local pBarBg = Instance.new("Frame", hud)
pBarBg.Size = UDim2.new(1,-20,0,4); pBarBg.Position = UDim2.new(0,10,1,-7)
pBarBg.BackgroundColor3 = Color3.fromRGB(25,20,40); pBarBg.BorderSizePixel = 0
Instance.new("UICorner", pBarBg).CornerRadius = UDim.new(1,0)
local pBarFill = Instance.new("Frame", pBarBg)
pBarFill.Size = UDim2.new(0,0,1,0); pBarFill.BackgroundColor3 = Color3.fromRGB(255,100,0)
pBarFill.BorderSizePixel = 0
Instance.new("UICorner", pBarFill).CornerRadius = UDim.new(1,0)

-- ── SWORD COOLDOWN INDICATOR (below HUD) ────────────────
local swordBar = Instance.new("Frame", sg)
swordBar.Size = UDim2.new(0, 200, 0, 22); swordBar.Position = UDim2.new(0, 10, 1, -225)
swordBar.BackgroundColor3 = Color3.fromRGB(20, 8, 8); swordBar.BorderSizePixel = 0
swordBar.Visible = false
Instance.new("UICorner", swordBar).CornerRadius = UDim.new(0, 6)
local swordStroke = Instance.new("UIStroke", swordBar)
swordStroke.Color = Color3.fromRGB(200, 80, 0); swordStroke.Thickness = 1.5
local swordFill = Instance.new("Frame", swordBar)
swordFill.Size = UDim2.new(1, 0, 1, 0)
swordFill.BackgroundColor3 = Color3.fromRGB(255, 180, 40); swordFill.BorderSizePixel = 0
Instance.new("UICorner", swordFill).CornerRadius = UDim.new(0, 6)
local swordLbl = Instance.new("TextLabel", swordBar)
swordLbl.Size = UDim2.new(1,0,1,0); swordLbl.BackgroundTransparency = 1
swordLbl.Text = "⚔️ READY"; swordLbl.Font = Enum.Font.GothamBold; swordLbl.TextSize = 11
swordLbl.TextColor3 = Color3.fromRGB(255,240,200)

-- Show sword bar once sword is equipped
local function updateSwordBar(ready)
    swordBar.Visible = true
    if ready then
        swordFill.BackgroundColor3 = Color3.fromRGB(255,180,40)
        TweenService:Create(swordFill, TweenInfo.new(0.2), {Size = UDim2.new(1,0,1,0)}):Play()
        swordLbl.Text = "⚔️ READY  (click to swing)"
    else
        swordFill.BackgroundColor3 = Color3.fromRGB(120, 40, 0)
        TweenService:Create(swordFill, TweenInfo.new(1.2, Enum.EasingStyle.Linear),
            {Size = UDim2.new(0, 0, 1, 0)}):Play()
        swordLbl.Text = "⚔️ Cooldown..."
        task.delay(1.2, function()
            updateSwordBar(true)
        end)
    end
end

-- Listen for sword equip
local WEAPON_NAMES = {CoinBlade=true, LaserStaff=true, ThunderHammer=true, ShadowBlade=true, CoinSword=true}
local function watchSword(char)
    if not char then return end
    local function bind(tool)
        if tool:IsA("Tool") and WEAPON_NAMES[tool.Name] then
            swordBar.Visible = true
            swordLbl.Text = "⚔️ " .. tool.Name .. " — READY"
            tool.Activated:Connect(function() updateSwordBar(false) end)
            tool.Unequipped:Connect(function() swordBar.Visible = false end)
        end
    end
    for _, t in ipairs(char:GetChildren()) do bind(t) end
    char.ChildAdded:Connect(bind)
end
if player.Character then watchSword(player.Character) end
player.CharacterAdded:Connect(watchSword)

-- ── GEYSER INDICATOR BAR ─────────────────────────────────
local GEYSER_COUNT = 5
local geyserBar = Instance.new("Frame", sg)
geyserBar.Size            = UDim2.new(0, 252, 0, 26)
geyserBar.Position        = UDim2.new(0, 10, 1, -200)
geyserBar.BackgroundColor3= Color3.fromRGB(8,8,18)
geyserBar.BorderSizePixel = 0
Instance.new("UICorner", geyserBar).CornerRadius = UDim.new(0,8)
local geyserLayout = Instance.new("UIListLayout", geyserBar)
geyserLayout.FillDirection        = Enum.FillDirection.Horizontal
geyserLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
geyserLayout.VerticalAlignment    = Enum.VerticalAlignment.Center
geyserLayout.Padding              = UDim.new(0,6)

local geyserTitle = Instance.new("TextLabel", geyserBar)
geyserTitle.Size = UDim2.new(0, 86, 0, 20)
geyserTitle.BackgroundTransparency = 1
geyserTitle.Text = "⛲ GEYSERS"
geyserTitle.TextColor3 = Color3.fromRGB(130, 130, 200)
geyserTitle.Font = Enum.Font.GothamBold; geyserTitle.TextSize = 11
geyserTitle.TextXAlignment = Enum.TextXAlignment.Left

local geyserDots = {}
for i = 1, GEYSER_COUNT do
    local dot = Instance.new("Frame", geyserBar)
    dot.Size              = UDim2.new(0,18,0,18)
    dot.BackgroundColor3  = Color3.fromRGB(50,50,50)
    dot.BorderSizePixel   = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    local lbl = Instance.new("TextLabel", dot)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = tostring(i)
    lbl.TextColor3 = Color3.fromRGB(80,80,80)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
    geyserDots[i] = {frame=dot, lbl=lbl}
end

local function setGeyserDot(idx, active, isMega)
    local d = geyserDots[idx]; if not d then return end
    if isMega then
        d.frame.BackgroundColor3 = Color3.fromRGB(255,60,60)
        d.lbl.TextColor3         = Color3.fromRGB(255,255,255)
    elseif active then
        d.frame.BackgroundColor3 = Color3.fromRGB(255,190,0)
        d.lbl.TextColor3         = Color3.fromRGB(255,255,200)
    else
        d.frame.BackgroundColor3 = Color3.fromRGB(35,35,35)
        d.lbl.TextColor3         = Color3.fromRGB(70,70,70)
    end
end

local GEYSER_ACTIVE_TIME   = 8
local GEYSER_INACTIVE_TIME = 14
local geyserCountdown = {}

RunService.Heartbeat:Connect(function(dt)
    for i = 1, GEYSER_COUNT do
        local cd = geyserCountdown[i]; if not cd then continue end
        cd.remaining = math.max(0, cd.remaining - dt)
        local dot = geyserDots[i]; if not dot then continue end
        local secs = math.ceil(cd.remaining)
        dot.lbl.Text = secs > 0 and tostring(secs) or (cd.isActive and "!" or "●")
    end
    if plotHasPlots and plotTickRemaining > 0 then
        plotTickRemaining = math.max(0, plotTickRemaining - dt)
        local secs = math.ceil(plotTickRemaining)
        if secs > 0 then plotTickLbl.Text = "📈 income in " .. secs .. "s" end
    end
end)

RE_GeyserState.OnClientEvent:Connect(function(geyserIdx, isActive, isMega)
    setGeyserDot(geyserIdx, isActive, isMega)
    local isOn = isActive or isMega
    geyserCountdown[geyserIdx] = {
        remaining = isOn and GEYSER_ACTIVE_TIME or GEYSER_INACTIVE_TIME,
        isActive  = isOn,
    }
    if isActive and isMega then
        SFX.megaBurst:Play()
    elseif isActive then
        SFX.geyser:Play()
    end
end)

-- ── PLOT INCOME COUNTDOWN BAR ─────────────────────────────
local plotBar = Instance.new("Frame", sg)
plotBar.Size = UDim2.new(0, 240, 0, 22); plotBar.Position = UDim2.new(0, 10, 1, -165)
plotBar.BackgroundColor3 = Color3.fromRGB(8,18,8); plotBar.BorderSizePixel = 0
plotBar.Visible = false
Instance.new("UICorner", plotBar).CornerRadius = UDim.new(0, 8)
local plotTickLbl = Instance.new("TextLabel", plotBar)
plotTickLbl.Size = UDim2.new(1,0,1,0); plotTickLbl.BackgroundTransparency = 1
plotTickLbl.TextColor3 = Color3.fromRGB(100, 220, 120)
plotTickLbl.Font = Enum.Font.GothamBold; plotTickLbl.TextSize = 12
plotTickLbl.Text = "📈 earning..."

local plotTickCd        = 8
local plotTickRemaining = 0
local plotHasPlots      = false

-- ── RAID BAR (BIG) ───────────────────────────────────────
local raidBar = Instance.new("Frame", sg)
raidBar.Size = UDim2.new(0, 300, 0, 48); raidBar.Position = UDim2.new(0, 10, 1, -105)
raidBar.BackgroundColor3 = Color3.fromRGB(40, 5, 5); raidBar.BorderSizePixel = 0
raidBar.Visible = false
Instance.new("UICorner", raidBar).CornerRadius = UDim.new(0, 10)
local raidStroke = Instance.new("UIStroke", raidBar)
raidStroke.Color = Color3.fromRGB(255, 40, 40); raidStroke.Thickness = 2.5

local raidFill = Instance.new("Frame", raidBar)
raidFill.Size = UDim2.new(0, 0, 1, 0); raidFill.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
raidFill.BorderSizePixel = 0
Instance.new("UICorner", raidFill).CornerRadius = UDim.new(0, 10)

local raidLbl = Instance.new("TextLabel", raidBar)
raidLbl.Size = UDim2.new(1, 0, 0.55, 0); raidLbl.BackgroundTransparency = 1
raidLbl.Position = UDim2.new(0, 0, 0, 0)
raidLbl.TextColor3 = Color3.fromRGB(255, 210, 210)
raidLbl.Font = Enum.Font.GothamBold; raidLbl.TextSize = 14
raidLbl.Text = "⚔️ Raiding..."

local raidSubLbl = Instance.new("TextLabel", raidBar)
raidSubLbl.Size = UDim2.new(1, 0, 0.45, 0); raidSubLbl.BackgroundTransparency = 1
raidSubLbl.Position = UDim2.new(0, 0, 0.55, 0)
raidSubLbl.TextColor3 = Color3.fromRGB(200, 140, 140)
raidSubLbl.Font = Enum.Font.Gotham; raidSubLbl.TextSize = 11
raidSubLbl.Text = "Stand on the plot to steal it"

-- ── DEFENDER RAID PROGRESS BAR ───────────────────────────────
-- Shows to the OWNER how far the raid has progressed
local defRaidBar = Instance.new("Frame", sg)
defRaidBar.Name = "DefenderRaidBar"
defRaidBar.Size = UDim2.new(0, 310, 0, 48)
defRaidBar.Position = UDim2.new(1, -322, 1, -105)
defRaidBar.BackgroundColor3 = Color3.fromRGB(5, 25, 5)
defRaidBar.BorderSizePixel = 0; defRaidBar.Visible = false
Instance.new("UICorner", defRaidBar).CornerRadius = UDim.new(0, 10)
local defRaidStroke = Instance.new("UIStroke", defRaidBar)
defRaidStroke.Color = Color3.fromRGB(255, 130, 0); defRaidStroke.Thickness = 2.5

local defRaidFill = Instance.new("Frame", defRaidBar)
defRaidFill.Size = UDim2.new(0, 0, 1, 0)
defRaidFill.BackgroundColor3 = Color3.fromRGB(255, 90, 0)
defRaidFill.BorderSizePixel = 0
Instance.new("UICorner", defRaidFill).CornerRadius = UDim.new(0, 10)

local defRaidLbl = Instance.new("TextLabel", defRaidBar)
defRaidLbl.Size = UDim2.new(1, -8, 0.55, 0); defRaidLbl.Position = UDim2.new(0, 4, 0, 0)
defRaidLbl.BackgroundTransparency = 1
defRaidLbl.TextColor3 = Color3.fromRGB(255, 220, 140)
defRaidLbl.Font = Enum.Font.GothamBold; defRaidLbl.TextSize = 13
defRaidLbl.Text = "🚨 Being Raided!"

local defRaidSubLbl = Instance.new("TextLabel", defRaidBar)
defRaidSubLbl.Size = UDim2.new(1, -8, 0.45, 0); defRaidSubLbl.Position = UDim2.new(0, 4, 0.55, 0)
defRaidSubLbl.BackgroundTransparency = 1
defRaidSubLbl.TextColor3 = Color3.fromRGB(200, 170, 100)
defRaidSubLbl.Font = Enum.Font.Gotham; defRaidSubLbl.TextSize = 11
defRaidSubLbl.Text = "Return to defend!"

-- ── RAID DEFENDER ALERT ──────────────────────────────────
-- Shows when the player is the one being raided
local defenseAlert = Instance.new("Frame", sg)
defenseAlert.Size = UDim2.new(0, 400, 0, 70); defenseAlert.Position = UDim2.new(0.5, -200, 0.15, 0)
defenseAlert.BackgroundColor3 = Color3.fromRGB(60, 0, 0); defenseAlert.BorderSizePixel = 0
defenseAlert.Visible = false
Instance.new("UICorner", defenseAlert).CornerRadius = UDim.new(0, 12)
local defStroke = Instance.new("UIStroke", defenseAlert)
defStroke.Color = Color3.fromRGB(255, 40, 40); defStroke.Thickness = 3

local defLbl1 = Instance.new("TextLabel", defenseAlert)
defLbl1.Size = UDim2.new(1, -12, 0, 36); defLbl1.Position = UDim2.new(0, 6, 0, 4)
defLbl1.BackgroundTransparency = 1
defLbl1.Text = "🚨 YOUR MACHINE IS BEING RAIDED!"
defLbl1.TextColor3 = Color3.fromRGB(255, 80, 80)
defLbl1.Font = Enum.Font.GothamBold; defLbl1.TextSize = 18
defLbl1.TextXAlignment = Enum.TextXAlignment.Center

local defLbl2 = Instance.new("TextLabel", defenseAlert)
defLbl2.Size = UDim2.new(1, -12, 0, 26); defLbl2.Position = UDim2.new(0, 6, 0, 38)
defLbl2.BackgroundTransparency = 1
defLbl2.Text = "🏃 Run back and STAND ON YOUR MACHINE to defend!"
defLbl2.TextColor3 = Color3.fromRGB(255, 200, 80)
defLbl2.Font = Enum.Font.GothamBold; defLbl2.TextSize = 12
defLbl2.TextXAlignment = Enum.TextXAlignment.Center

-- Pulse the defense alert
local defenseAlertThread = nil
local function showDefenseAlert(raiderName, plotId)
    defLbl1.Text = "🚨 " .. raiderName .. " IS RAIDING " .. plotId .. "!"
    defenseAlert.Visible = true
    SFX.raidAlert:Play()
    if defenseAlertThread then task.cancel(defenseAlertThread) end
    -- Pulse border color
    task.spawn(function()
        for _ = 1, 6 do
            TweenService:Create(defStroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(255,255,60)}):Play()
            task.wait(0.25)
            TweenService:Create(defStroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(255,40,40)}):Play()
            task.wait(0.25)
        end
    end)
    defenseAlertThread = task.delay(8, function()
        TweenService:Create(defenseAlert, TweenInfo.new(0.4), {Size = UDim2.new(0,400,0,0)}):Play()
        task.wait(0.45)
        defenseAlert.Visible = false
        defenseAlert.Size = UDim2.new(0,400,0,70)
    end)
end

-- ── RED VIGNETTE (shows when raiding) ────────────────────
local vignette = Instance.new("Frame", sg)
vignette.Name = "RaidVignette"; vignette.Size = UDim2.new(1,0,1,0)
vignette.Position = UDim2.new(0,0,0,0); vignette.BackgroundTransparency = 1
vignette.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
vignette.BorderSizePixel = 0; vignette.ZIndex = 0; vignette.Visible = false
-- Gradient from edges inward
local vigGrad = Instance.new("UIGradient", vignette)
vigGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.4),
    NumberSequenceKeypoint.new(0.5, 1),
    NumberSequenceKeypoint.new(1, 0.4),
})
local vignetteActive = false
local vignetteThread = nil

local function startVignette()
    if vignetteActive then return end
    vignetteActive = true
    vignette.Visible = true
    task.spawn(function()
        while vignetteActive do
            TweenService:Create(vignette, TweenInfo.new(0.4, Enum.EasingStyle.Sine),
                {BackgroundTransparency = 0.55}):Play()
            task.wait(0.4)
            if not vignetteActive then break end
            TweenService:Create(vignette, TweenInfo.new(0.4, Enum.EasingStyle.Sine),
                {BackgroundTransparency = 0.8}):Play()
            task.wait(0.4)
        end
        TweenService:Create(vignette, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        task.wait(0.55)
        vignette.Visible = false
        vignette.BackgroundTransparency = 1
    end)
end

local function stopVignette()
    vignetteActive = false
end

-- ── MACHINE INCOME ANIMATION ─────────────────────────────
-- When a plot ticks, spawn a floating "+coins" text in 3D world space above the machine.
local function showMachineIncome(worldPos, coinsEarned)
    local part = Instance.new("Part")
    part.Anchored = true; part.CanCollide = false
    part.Transparency = 1; part.Size = Vector3.new(1,1,1)
    part.Position = worldPos + Vector3.new(math.random(-2,2), 8, math.random(-2,2))
    part.Parent = workspace

    local bb = Instance.new("BillboardGui", part)
    bb.Size = UDim2.new(0,120,0,40); bb.MaxDistance = 60
    bb.StudsOffset = Vector3.new(0, 0, 0)

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = "💰 +"..fmt(coinsEarned)
    lbl.TextColor3 = Color3.fromRGB(255,235,80)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 20
    lbl.TextStrokeTransparency = 0.2; lbl.TextStrokeColor3 = Color3.new(0,0,0)

    TweenService:Create(part,
        TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = part.Position + Vector3.new(0, 6, 0)}):Play()
    TweenService:Create(lbl,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {TextTransparency = 1, TextStrokeTransparency = 1}):Play()

    game:GetService("Debris"):AddItem(part, 1.4)
end

-- Machine rate billboard (floating in 3D above the machine showing income/s)
local machineRateParts = {}  -- [plotId] = Part

local function updateMachineRateBB(plotId, coinVal, cd)
    machineRates[plotId] = {coinVal=coinVal, cd=cd}

    -- Remove old billboard if exists
    if machineRateParts[plotId] then
        pcall(function() machineRateParts[plotId]:Destroy() end)
        machineRateParts[plotId] = nil
    end

    local pos = PLOT_CENTERS_CLIENT[plotId]
    if not pos then return end

    local part = Instance.new("Part")
    part.Anchored = true; part.CanCollide = false; part.Transparency = 1
    part.Size = Vector3.new(1,1,1)
    part.CFrame = CFrame.new(pos.X, pos.Y + 28, pos.Z)
    part.Parent = workspace

    local bb = Instance.new("BillboardGui", part)
    bb.Size = UDim2.new(0,200,0,48); bb.MaxDistance = 50
    bb.StudsOffset = Vector3.new(0,0,0)

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1,0,0.55,0); lbl.BackgroundTransparency = 1
    local perMin = math.floor(coinVal * (60/cd))
    lbl.Text = "⚡ +"..fmt(coinVal).." every "..cd.."s"
    lbl.TextColor3 = Color3.fromRGB(180,255,160)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Center

    local lbl2 = Instance.new("TextLabel", bb)
    lbl2.Size = UDim2.new(1,0,0.45,0); lbl2.Position = UDim2.new(0,0,0.55,0)
    lbl2.BackgroundTransparency = 1
    lbl2.Text = "≈ "..fmt(perMin).." /min"
    lbl2.TextColor3 = Color3.fromRGB(140,220,140)
    lbl2.Font = Enum.Font.Gotham; lbl2.TextSize = 11
    lbl2.TextXAlignment = Enum.TextXAlignment.Center

    machineRateParts[plotId] = part
end

RE_MachineRate.OnClientEvent:Connect(function(plotId, coinVal, cd)
    updateMachineRateBB(plotId, coinVal, cd)
end)

-- Raid status handler.
-- progress == -99  → initial alert (owner being raided for first time)
-- progress == -1   → raid cancelled/ended (clear bar)
-- progress 0..1   → live progress
-- isDefender==true → this update is for the owner's defender bar
RE_RaidStatus.OnClientEvent:Connect(function(plotId, ownerOrRaiderName, progress, isDefender)
    if progress == -99 then
        -- Big popup alert for the owner
        showDefenseAlert(ownerOrRaiderName, plotId)
    elseif isDefender then
        -- Defender's own bar (bottom-right)
        if progress < 0 then
            defRaidBar.Visible = false
        else
            defRaidBar.Visible = true
            local pct = math.clamp(progress, 0, 1)
            TweenService:Create(defRaidFill, TweenInfo.new(0.3), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
            defRaidFill.BackgroundColor3 = pct > 0.6
                and Color3.fromRGB(220, 40, 40)
                or  Color3.fromRGB(255, 130, 0)
            defRaidLbl.Text    = "🚨 " .. ownerOrRaiderName .. " raiding " .. plotId .. "! " .. math.floor(pct*100) .. "%"
            defRaidSubLbl.Text = "Return NOW! ~" .. math.ceil((1-pct)*5) .. "s left"
        end
    elseif progress < 0 then
        -- Attacker bar cleared
        raidBar.Visible = false
        stopVignette()
    else
        -- Attacker bar (bottom-left)
        raidBar.Visible = true
        startVignette()
        TweenService:Create(raidFill, TweenInfo.new(0.3), {Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)}):Play()
        raidLbl.Text    = "⚔️ Raiding " .. ownerOrRaiderName .. "!  " .. math.floor(progress * 100) .. "%"
        raidSubLbl.Text = "Stay on the plot — " .. math.ceil((1-progress)*5) .. "s to steal!"
    end
end)

RE_PlotTick.OnClientEvent:Connect(function(earned, ticked)
    plotBar.Visible  = true
    plotTickLbl.Text = "📈 +" .. fmt(earned) .. " coins!"
    local maxCd = plotTickCd
    if ticked and #ticked > 0 then
        for _, entry in ipairs(ticked) do
            local pos = PLOT_CENTERS_CLIENT[entry.plotId]
            if pos then showMachineIncome(pos, entry.coins) end
            if entry.cd and entry.cd > maxCd then maxCd = entry.cd end
        end
    end
    plotTickCd        = maxCd
    plotTickRemaining = maxCd
    task.delay(1.2, function()
        if plotTickRemaining > 0 then
            plotTickLbl.Text = "📈 income in " .. math.ceil(plotTickRemaining) .. "s"
        end
    end)
end)

-- ── HP BAR ───────────────────────────────────────────────
local hpBarFrame = Instance.new("Frame", sg)
hpBarFrame.Size = UDim2.new(0, 200, 0, 14); hpBarFrame.Position = UDim2.new(0.5, -100, 0, 68)
hpBarFrame.BackgroundColor3 = Color3.fromRGB(20,8,8); hpBarFrame.BorderSizePixel = 0
Instance.new("UICorner", hpBarFrame).CornerRadius = UDim.new(0, 5)
local hpStroke = Instance.new("UIStroke", hpBarFrame)
hpStroke.Color = Color3.fromRGB(180, 40, 40); hpStroke.Thickness = 1.2
local hpFill = Instance.new("Frame", hpBarFrame)
hpFill.Size = UDim2.new(1,0,1,0); hpFill.BackgroundColor3 = Color3.fromRGB(220,40,40)
hpFill.BorderSizePixel = 0
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 5)
local hpLbl = Instance.new("TextLabel", hpBarFrame)
hpLbl.Size = UDim2.new(1,0,1,0); hpLbl.BackgroundTransparency = 1
hpLbl.Text = "❤️ 100 / 100"; hpLbl.Font = Enum.Font.GothamBold; hpLbl.TextSize = 10
hpLbl.TextColor3 = Color3.fromRGB(255,220,220)

RE_HPUpdate.OnClientEvent:Connect(function(hp, maxHp)
    local pct = math.clamp(hp / math.max(1, maxHp), 0, 1)
    TweenService:Create(hpFill, TweenInfo.new(0.3), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
    hpFill.BackgroundColor3 = pct > 0.5 and Color3.fromRGB(60,200,60)
        or pct > 0.25 and Color3.fromRGB(220,160,0)
        or Color3.fromRGB(220,40,40)
    hpLbl.Text = "❤️ " .. math.ceil(hp) .. " / " .. maxHp
end)

-- ── DEATH / RESPAWN SCREEN ────────────────────────────────
local deathScreen = Instance.new("Frame", sg)
deathScreen.Name = "DeathScreen"; deathScreen.Size = UDim2.new(1,0,1,0)
deathScreen.BackgroundColor3 = Color3.fromRGB(0,0,0); deathScreen.BackgroundTransparency = 0.3
deathScreen.BorderSizePixel = 0; deathScreen.Visible = false; deathScreen.ZIndex = 100

local deathLbl = Instance.new("TextLabel", deathScreen)
deathLbl.Size = UDim2.new(1,0,0,80); deathLbl.Position = UDim2.new(0,0,0.4,0)
deathLbl.BackgroundTransparency = 1; deathLbl.Text = "💀 YOU DIED"
deathLbl.TextColor3 = Color3.fromRGB(255,60,60); deathLbl.Font = Enum.Font.GothamBold
deathLbl.TextSize = 48; deathLbl.TextXAlignment = Enum.TextXAlignment.Center; deathLbl.ZIndex = 101

local respawnLbl = Instance.new("TextLabel", deathScreen)
respawnLbl.Size = UDim2.new(1,0,0,36); respawnLbl.Position = UDim2.new(0,0,0.4,88)
respawnLbl.BackgroundTransparency = 1; respawnLbl.Text = "Respawning in 5..."
respawnLbl.TextColor3 = Color3.fromRGB(255,200,200); respawnLbl.Font = Enum.Font.GothamBold
respawnLbl.TextSize = 22; respawnLbl.TextXAlignment = Enum.TextXAlignment.Center; respawnLbl.ZIndex = 101

local coinsLostLbl = Instance.new("TextLabel", deathScreen)
coinsLostLbl.Size = UDim2.new(1,0,0,28); coinsLostLbl.Position = UDim2.new(0,0,0.4,130)
coinsLostLbl.BackgroundTransparency = 1; coinsLostLbl.Text = ""
coinsLostLbl.TextColor3 = Color3.fromRGB(255,180,50); coinsLostLbl.Font = Enum.Font.GothamBold
coinsLostLbl.TextSize = 17; coinsLostLbl.TextXAlignment = Enum.TextXAlignment.Center; coinsLostLbl.ZIndex = 101

RE_PlayerDied.OnClientEvent:Connect(function(killerName, coinsLost)
    coinsLostLbl.Text = killerName
        and ("💸 " .. killerName .. " took " .. fmt(coinsLost or 0) .. " coins from you!")
        or  ("💸 You dropped " .. fmt(coinsLost or 0) .. " coins!")
    deathScreen.Visible = true
    TweenService:Create(hpFill, TweenInfo.new(0.2), {Size = UDim2.new(0,0,1,0)}):Play()
    hpLbl.Text = "❤️ 0 / 100"
    for t = 5, 1, -1 do
        respawnLbl.Text = "Respawning in " .. t .. "..."
        task.wait(1)
    end
    deathScreen.Visible = false
end)

-- ── FULL-SCREEN EVENT FLASH ───────────────────────────────
local eventFlash = Instance.new("Frame", sg)
eventFlash.Name = "EventFlash"; eventFlash.Size = UDim2.new(1,0,1,0)
eventFlash.BackgroundColor3 = Color3.fromRGB(255,200,0)
eventFlash.BackgroundTransparency = 1; eventFlash.BorderSizePixel = 0
eventFlash.ZIndex = 60; eventFlash.Visible = false

-- ── RANDOM EVENT BANNER ───────────────────────────────────
local eventBanner = Instance.new("Frame", sg)
eventBanner.Name = "EventBanner"; eventBanner.Size = UDim2.new(0, 480, 0, 84)
eventBanner.Position = UDim2.new(0.5, -240, 0, -100)
eventBanner.BackgroundColor3 = Color3.fromRGB(8,8,22); eventBanner.BorderSizePixel = 0
Instance.new("UICorner", eventBanner).CornerRadius = UDim.new(0, 16)
local evStroke = Instance.new("UIStroke", eventBanner)
evStroke.Color = Color3.fromRGB(255,200,0); evStroke.Thickness = 3

local evTitle = Instance.new("TextLabel", eventBanner)
evTitle.Size = UDim2.new(1,-12,0,44); evTitle.Position = UDim2.new(0,6,0,4)
evTitle.BackgroundTransparency = 1; evTitle.Text = "🌟 EVENT"
evTitle.TextColor3 = Color3.fromRGB(255,215,0); evTitle.Font = Enum.Font.GothamBold
evTitle.TextSize = 26; evTitle.TextXAlignment = Enum.TextXAlignment.Center

local evDesc = Instance.new("TextLabel", eventBanner)
evDesc.Size = UDim2.new(1,-12,0,28); evDesc.Position = UDim2.new(0,6,0,50)
evDesc.BackgroundTransparency = 1; evDesc.Text = ""
evDesc.TextColor3 = Color3.fromRGB(220,220,255); evDesc.Font = Enum.Font.GothamBold
evDesc.TextSize = 14; evDesc.TextXAlignment = Enum.TextXAlignment.Center

-- ── ACTIVE EVENT CHIP (persistent while event runs) ───────────
local eventChip = Instance.new("Frame", sg)
eventChip.Name = "EventChip"; eventChip.Size = UDim2.new(0, 260, 0, 26)
eventChip.Position = UDim2.new(0.5, -130, 0, 78)
eventChip.BackgroundColor3 = Color3.fromRGB(18,10,40)
eventChip.BorderSizePixel = 0; eventChip.Visible = false
Instance.new("UICorner", eventChip).CornerRadius = UDim.new(0, 8)
local ecStroke = Instance.new("UIStroke", eventChip)
ecStroke.Color = Color3.fromRGB(255,200,0); ecStroke.Thickness = 1.5
local ecLbl = Instance.new("TextLabel", eventChip)
ecLbl.Size = UDim2.new(1,0,1,0); ecLbl.BackgroundTransparency = 1
ecLbl.TextColor3 = Color3.fromRGB(255,215,0); ecLbl.Font = Enum.Font.GothamBold
ecLbl.TextSize = 12; ecLbl.Text = "⚡ EVENT ACTIVE"

local evPulseThread = nil

RE_RandomEvent.OnClientEvent:Connect(function(evId, evName, evDesc_txt, evCol, evDur)
    local isEnd = evId:sub(-4) == "_END"
    local colMap2 = {
        gold=Color3.fromRGB(255,200,0), green=Color3.fromRGB(0,210,80),
        red=Color3.fromRGB(255,55,55),  blue=Color3.fromRGB(55,155,255),
    }
    local flashCol = colMap2[evCol] or Color3.fromRGB(255,200,0)

    if isEnd then
        if evPulseThread then task.cancel(evPulseThread); evPulseThread = nil end
        TweenService:Create(eventBanner, TweenInfo.new(0.3),
            {Position = UDim2.new(0.5,-240,0,-100)}):Play()
        TweenService:Create(eventChip, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
        task.delay(0.35, function()
            eventChip.Visible = false
            eventChip.BackgroundTransparency = 0
        end)
        return
    end

    -- Full-screen flash
    eventFlash.BackgroundColor3 = flashCol
    eventFlash.Visible = true
    TweenService:Create(eventFlash, TweenInfo.new(0.18), {BackgroundTransparency = 0.45}):Play()
    task.delay(0.18, function()
        TweenService:Create(eventFlash, TweenInfo.new(0.45), {BackgroundTransparency = 1}):Play()
        task.delay(0.5, function() eventFlash.Visible = false end)
    end)

    -- Banner
    evStroke.Color = flashCol
    evTitle.TextColor3 = flashCol
    evTitle.Text = "🌟 " .. evName
    evDesc.Text  = evDesc_txt
    TweenService:Create(eventBanner,
        TweenInfo.new(0.55, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5,-240,0,10)}):Play()

    -- Persistent chip
    ecStroke.Color = flashCol
    ecLbl.TextColor3 = flashCol
    ecLbl.Text = "⚡ " .. evName
    eventChip.Visible = true

    -- Pulse the banner border while active
    if evPulseThread then task.cancel(evPulseThread); evPulseThread = nil end
    local dur = evDur or 30
    evPulseThread = task.spawn(function()
        local endClock = os.clock() + dur
        while os.clock() < endClock do
            TweenService:Create(evStroke, TweenInfo.new(0.45), {Color=Color3.fromRGB(255,255,120)}):Play()
            TweenService:Create(ecStroke, TweenInfo.new(0.45), {Color=Color3.fromRGB(255,255,120)}):Play()
            task.wait(0.45)
            TweenService:Create(evStroke, TweenInfo.new(0.45), {Color=flashCol}):Play()
            TweenService:Create(ecStroke, TweenInfo.new(0.45), {Color=flashCol}):Play()
            task.wait(0.45)
        end
        evPulseThread = nil
    end)

    -- Slide banner out after duration
    task.delay(dur, function()
        TweenService:Create(eventBanner, TweenInfo.new(0.3),
            {Position = UDim2.new(0.5,-240,0,-100)}):Play()
    end)
end)

-- ── ABILITY COOLDOWN DISPLAY ──────────────────────────────
local abilityBar = Instance.new("Frame", sg)
abilityBar.Size = UDim2.new(0, 214, 0, 52); abilityBar.Position = UDim2.new(0, 10, 1, -279)
abilityBar.BackgroundTransparency = 1; abilityBar.BorderSizePixel = 0
abilityBar.Visible = false

-- Dash row
local dashRow = Instance.new("Frame", abilityBar)
dashRow.Size = UDim2.new(1,0,0,22); dashRow.Position = UDim2.new(0,0,0,0)
dashRow.BackgroundColor3 = Color3.fromRGB(10,8,22); dashRow.BorderSizePixel = 0
Instance.new("UICorner", dashRow).CornerRadius = UDim.new(0,6)
local dashStroke = Instance.new("UIStroke", dashRow)
dashStroke.Color = Color3.fromRGB(80,160,255); dashStroke.Thickness = 1.2

local dashKeyLbl = Instance.new("TextLabel", dashRow)
dashKeyLbl.Size = UDim2.new(0,46,1,0); dashKeyLbl.BackgroundTransparency = 1
dashKeyLbl.Text = "Q DASH"; dashKeyLbl.Font = Enum.Font.GothamBold; dashKeyLbl.TextSize = 9
dashKeyLbl.TextColor3 = Color3.fromRGB(100,200,255)

local dashFillBg = Instance.new("Frame", dashRow)
dashFillBg.Size = UDim2.new(1,-86,1,-6); dashFillBg.Position = UDim2.new(0,46,0,3)
dashFillBg.BackgroundColor3 = Color3.fromRGB(25,25,55); dashFillBg.BorderSizePixel = 0
Instance.new("UICorner", dashFillBg).CornerRadius = UDim.new(1,0)
local dashFill = Instance.new("Frame", dashFillBg)
dashFill.Size = UDim2.new(1,0,1,0); dashFill.BackgroundColor3 = Color3.fromRGB(80,180,255)
dashFill.BorderSizePixel = 0
Instance.new("UICorner", dashFill).CornerRadius = UDim.new(1,0)

local dashTimeLbl = Instance.new("TextLabel", dashRow)
dashTimeLbl.Size = UDim2.new(0,36,1,0); dashTimeLbl.Position = UDim2.new(1,-36,0,0)
dashTimeLbl.BackgroundTransparency = 1; dashTimeLbl.Text = "READY"
dashTimeLbl.Font = Enum.Font.GothamBold; dashTimeLbl.TextSize = 9
dashTimeLbl.TextColor3 = Color3.fromRGB(100,200,255)
dashTimeLbl.TextXAlignment = Enum.TextXAlignment.Right

-- Block row
local blockRow = Instance.new("Frame", abilityBar)
blockRow.Size = UDim2.new(1,0,0,22); blockRow.Position = UDim2.new(0,0,0,28)
blockRow.BackgroundColor3 = Color3.fromRGB(10,8,22); blockRow.BorderSizePixel = 0
Instance.new("UICorner", blockRow).CornerRadius = UDim.new(0,6)
local blockStroke = Instance.new("UIStroke", blockRow)
blockStroke.Color = Color3.fromRGB(255,180,40); blockStroke.Thickness = 1.2

local blockKeyLbl = Instance.new("TextLabel", blockRow)
blockKeyLbl.Size = UDim2.new(0,50,1,0); blockKeyLbl.BackgroundTransparency = 1
blockKeyLbl.Text = "E BLOCK"; blockKeyLbl.Font = Enum.Font.GothamBold; blockKeyLbl.TextSize = 9
blockKeyLbl.TextColor3 = Color3.fromRGB(255,200,80)

local blockFillBg = Instance.new("Frame", blockRow)
blockFillBg.Size = UDim2.new(1,-90,1,-6); blockFillBg.Position = UDim2.new(0,50,0,3)
blockFillBg.BackgroundColor3 = Color3.fromRGB(25,25,55); blockFillBg.BorderSizePixel = 0
Instance.new("UICorner", blockFillBg).CornerRadius = UDim.new(1,0)
local blockFill = Instance.new("Frame", blockFillBg)
blockFill.Size = UDim2.new(1,0,1,0); blockFill.BackgroundColor3 = Color3.fromRGB(255,200,60)
blockFill.BorderSizePixel = 0
Instance.new("UICorner", blockFill).CornerRadius = UDim.new(1,0)

local blockTimeLbl = Instance.new("TextLabel", blockRow)
blockTimeLbl.Size = UDim2.new(0,36,1,0); blockTimeLbl.Position = UDim2.new(1,-36,0,0)
blockTimeLbl.BackgroundTransparency = 1; blockTimeLbl.Text = "READY"
blockTimeLbl.Font = Enum.Font.GothamBold; blockTimeLbl.TextSize = 9
blockTimeLbl.TextColor3 = Color3.fromRGB(255,200,80)
blockTimeLbl.TextXAlignment = Enum.TextXAlignment.Right

-- Heartbeat: count down the bars smoothly
RunService.Heartbeat:Connect(function()
    local now2 = os.clock()
    if dashCdEnd > 0 then
        local rem = math.max(0, dashCdEnd - now2)
        local pct = 1 - rem / DASH_CD
        dashFill.Size = UDim2.new(math.clamp(pct,0,1), 0, 1, 0)
        if rem > 0 then
            dashTimeLbl.Text = string.format("%.1fs", rem)
            dashTimeLbl.TextColor3 = Color3.fromRGB(100,100,140)
            dashKeyLbl.TextColor3  = Color3.fromRGB(100,100,140)
        else
            dashTimeLbl.Text = "READY"; dashTimeLbl.TextColor3 = Color3.fromRGB(100,200,255)
            dashKeyLbl.TextColor3 = Color3.fromRGB(100,200,255)
            dashFill.Size = UDim2.new(1,0,1,0)
        end
    end
    if blockCdEnd > 0 then
        local rem = math.max(0, blockCdEnd - now2)
        local pct = 1 - rem / BLOCK_CD
        blockFill.Size = UDim2.new(math.clamp(pct,0,1), 0, 1, 0)
        if rem > 0 then
            blockTimeLbl.Text = string.format("%.1fs", rem)
            blockTimeLbl.TextColor3 = Color3.fromRGB(140,120,60)
            blockKeyLbl.TextColor3  = Color3.fromRGB(140,120,60)
        else
            blockTimeLbl.Text = "READY"; blockTimeLbl.TextColor3 = Color3.fromRGB(255,200,80)
            blockKeyLbl.TextColor3 = Color3.fromRGB(255,200,80)
            blockFill.Size = UDim2.new(1,0,1,0)
        end
    end
end)

RE_AbilityCD.OnClientEvent:Connect(function(abilityName, cooldown)
    abilityBar.Visible = true
    if abilityName == "dash" then
        dashCdEnd = os.clock() + cooldown
    elseif abilityName == "block" then
        blockCdEnd = os.clock() + cooldown
    end
end)

-- ── WEAPON SHOP PANEL ─────────────────────────────────────
-- prestigeReq must match server WEAPONS table exactly
local WEAPONS_CLIENT = {
    {id="CoinBlade",     name="⚔️ Coin Blade",     desc="Classic melee sword.",             cost=0,        col=Color3.fromRGB(255,215,0)},
    {id="LaserStaff",    name="🔮 Laser Staff",    desc="Long-range precision bolt.",        cost=20000,    col=Color3.fromRGB(80,160,255)},
    {id="ThunderHammer", name="🔨 Thunder Hammer", desc="Shockwave hits ALL nearby enemies!",cost=1500000,  col=Color3.fromRGB(255,255,60)},
    {id="ShadowBlade",   name="🌑 Shadow Blade",   desc="Fast dark blade, lethal damage.",   cost=10000000, col=Color3.fromRGB(160,40,255)},
}
local WEAPON_UPGRADE_COSTS_CLIENT = {15000, 80000, 350000, 1500000}

local weaponPanel = Instance.new("Frame", sg)
weaponPanel.Name = "WeaponPanel"; weaponPanel.Visible = false
weaponPanel.Size = UDim2.new(0, 400, 0, 490)
weaponPanel.Position = UDim2.new(0.5, -200, 0.5, -245)
weaponPanel.BackgroundColor3 = Color3.fromRGB(8,8,22); weaponPanel.BorderSizePixel = 0
Instance.new("UICorner", weaponPanel).CornerRadius = UDim.new(0,14)
local wpStroke = Instance.new("UIStroke", weaponPanel)
wpStroke.Color = Color3.fromRGB(200,80,255); wpStroke.Thickness = 2

local wpTitle = Instance.new("TextLabel", weaponPanel)
wpTitle.Size = UDim2.new(1,-50,0,44); wpTitle.Position = UDim2.new(0,12,0,6)
wpTitle.BackgroundTransparency = 1; wpTitle.Text = "🗡️ WEAPON SHOP"
wpTitle.TextColor3 = Color3.fromRGB(200,80,255); wpTitle.Font = Enum.Font.GothamBold
wpTitle.TextSize = 22; wpTitle.TextXAlignment = Enum.TextXAlignment.Left

local wpClose = Instance.new("TextButton", weaponPanel)
wpClose.Size = UDim2.new(0,34,0,34); wpClose.Position = UDim2.new(1,-42,0,8)
wpClose.BackgroundColor3 = Color3.fromRGB(180,25,25); wpClose.Text = "✕"
wpClose.TextColor3 = Color3.new(1,1,1); wpClose.Font = Enum.Font.GothamBold; wpClose.TextSize = 16
Instance.new("UICorner", wpClose).CornerRadius = UDim.new(0,8)
wpClose.MouseButton1Click:Connect(function() weaponPanel.Visible = false end)

local wpScroll = Instance.new("ScrollingFrame", weaponPanel)
wpScroll.Size = UDim2.new(1,-16,1,-56); wpScroll.Position = UDim2.new(0,8,0,52)
wpScroll.BackgroundTransparency = 1; wpScroll.ScrollBarThickness = 4
wpScroll.ScrollBarImageColor3 = Color3.fromRGB(200,80,255); wpScroll.CanvasSize = UDim2.new(0,0,0,0)
wpScroll.BorderSizePixel = 0
Instance.new("UIListLayout", wpScroll).Padding = UDim.new(0,8)

local function buildWeaponShop(ownedWeapons, weaponLevels, equippedWeapon, coins)
    for _, c in ipairs(wpScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local total = 0
    for _, w in ipairs(WEAPONS_CLIENT) do
        local owned    = ownedWeapons and ownedWeapons[w.id]
        local level    = (weaponLevels and weaponLevels[w.id]) or 1
        local equipped = equippedWeapon == w.id
        local upgIdx   = math.min(level, #WEAPON_UPGRADE_COSTS_CLIENT)
        local upgCost  = WEAPON_UPGRADE_COSTS_CLIENT[upgIdx]
        local maxed    = level >= 5

        local card = Instance.new("Frame", wpScroll)
        card.Size = UDim2.new(1,0,0,96)
        card.BackgroundColor3 = Color3.fromRGB(16,16,32)
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0,10)
        local cs = Instance.new("UIStroke", card)
        cs.Color = equipped and w.col or (owned and Color3.fromRGB(60,60,90) or Color3.fromRGB(35,35,55))
        cs.Thickness = equipped and 2.5 or 1.2

        local nm = Instance.new("TextLabel", card); nm.Size = UDim2.new(0.6,0,0,26)
        nm.Position = UDim2.new(0,10,0,6); nm.BackgroundTransparency = 1
        nm.Text = w.name
        nm.TextColor3 = w.col; nm.Font = Enum.Font.GothamBold; nm.TextSize = 15
        nm.TextXAlignment = Enum.TextXAlignment.Left

        local dsc = Instance.new("TextLabel", card); dsc.Size = UDim2.new(0.6,0,0,18)
        dsc.Position = UDim2.new(0,10,0,30); dsc.BackgroundTransparency = 1
        dsc.Text = w.desc
        dsc.TextColor3 = Color3.fromRGB(140,140,170)
        dsc.Font = Enum.Font.Gotham; dsc.TextSize = 11
        dsc.TextXAlignment = Enum.TextXAlignment.Left

        local statusRow = owned and ("Lv " .. level .. " / 5" .. (maxed and " MAX" or "")) or "Not owned"
        local lvl = Instance.new("TextLabel", card); lvl.Size = UDim2.new(0.6,0,0,18)
        lvl.Position = UDim2.new(0,10,0,50); lvl.BackgroundTransparency = 1
        lvl.Text = statusRow
        lvl.TextColor3 = owned and Color3.fromRGB(255,200,0) or Color3.fromRGB(100,100,120)
        lvl.Font = Enum.Font.GothamBold; lvl.TextSize = 12; lvl.TextXAlignment = Enum.TextXAlignment.Left

        local equippedTag = Instance.new("TextLabel", card); equippedTag.Size = UDim2.new(0.6,0,0,16)
        equippedTag.Position = UDim2.new(0,10,0,70); equippedTag.BackgroundTransparency = 1
        equippedTag.Text = equipped and "✓ EQUIPPED" or ""
        equippedTag.TextColor3 = w.col; equippedTag.Font = Enum.Font.GothamBold; equippedTag.TextSize = 11
        equippedTag.TextXAlignment = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton", card); btn.Size = UDim2.new(0,100,0,38)
        btn.Position = UDim2.new(1,-112,0.5,-19)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

        if not owned then
            btn.BackgroundColor3 = coins >= w.cost and Color3.fromRGB(80,20,120) or Color3.fromRGB(40,30,50)
            btn.Text = w.cost == 0 and "FREE" or ("💰 " .. fmt(w.cost))
            btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
            btn.MouseButton1Click:Connect(function() RE_WeaponShop:FireServer(w.id, "buy") end)
        elseif equipped then
            if not maxed then
                btn.BackgroundColor3 = coins >= upgCost and Color3.fromRGB(20,80,20) or Color3.fromRGB(25,40,25)
                btn.Text = "⬆️ " .. fmt(upgCost)
                btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
                btn.MouseButton1Click:Connect(function() RE_WeaponShop:FireServer(w.id, "upgrade") end)
            else
                btn.BackgroundColor3 = Color3.fromRGB(20,50,20)
                btn.Text = "MAX ✓"; btn.TextColor3 = Color3.fromRGB(0,210,80)
                btn.Font = Enum.Font.GothamBold; btn.TextSize = 13
            end
        else
            btn.BackgroundColor3 = Color3.fromRGB(20,60,70)
            btn.Text = "Equip"; btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 13
            btn.MouseButton1Click:Connect(function() RE_WeaponShop:FireServer(w.id, "equip") end)
        end
        total = total + 96 + 8
    end
    wpScroll.CanvasSize = UDim2.new(0,0,0,total)
end

RE_WeaponInfo.OnClientEvent:Connect(function(ownedWeapons, weaponLevels, equippedWeapon)
    if weaponPanel.Visible and currentData then
        buildWeaponShop(ownedWeapons, weaponLevels, equippedWeapon, currentData.coins or 0)
    end
end)

local weaponPanelOpen = false
local function openWeaponShop()
    weaponPanelOpen = not weaponPanelOpen
    weaponPanel.Visible = weaponPanelOpen
    if weaponPanelOpen and currentData then
        buildWeaponShop(currentData.ownedWeapons, currentData.weaponLevels,
            currentData.equippedWeapon, currentData.coins or 0)
    end
end

-- ── BUILDING UPGRADE PANEL ────────────────────────────────
local PATHS = {
    A={name="⚡ Production", desc="More coins per tick",  col=Color3.fromRGB(255,200,0),  costs={2000,15000,75000,350000},  labels={"1.5×","2.0×","3.0×","5.0×"}},
    B={name="⏱️ Efficiency",  desc="Faster tick interval", col=Color3.fromRGB(80,220,255),  costs={3000,20000,100000,500000}, labels={"-1s","-2s","-3s","-5s"}},
    C={name="🛡️ Defense",     desc="Raid protection",      col=Color3.fromRGB(255,80,200),  costs={5000,30000,150000,700000}, labels={"8s harder","8min shield","Earn while defending","Golden: 3×"}},
    D={name="🔰 Auto-Shield", desc="Blocks 1 raid / 4min", col=Color3.fromRGB(80,255,180),  costs={8000000},                  labels={"Auto-Shield every 4min"}},
}

local buildPanel = Instance.new("Frame", sg)
buildPanel.Name = "BuildPanel"; buildPanel.Visible = false
buildPanel.Size = UDim2.new(0, 420, 0, 520)
buildPanel.Position = UDim2.new(0.5, -210, 0.5, -260)
buildPanel.BackgroundColor3 = Color3.fromRGB(8,8,22); buildPanel.BorderSizePixel = 0
Instance.new("UICorner", buildPanel).CornerRadius = UDim.new(0,14)
local bpStroke = Instance.new("UIStroke", buildPanel)
bpStroke.Color = Color3.fromRGB(255,160,40); bpStroke.Thickness = 2

local bpTitle = Instance.new("TextLabel", buildPanel)
bpTitle.Size = UDim2.new(1,-50,0,44); bpTitle.Position = UDim2.new(0,12,0,6)
bpTitle.BackgroundTransparency = 1; bpTitle.Text = "🔧 MACHINE UPGRADES"
bpTitle.TextColor3 = Color3.fromRGB(255,160,40); bpTitle.Font = Enum.Font.GothamBold
bpTitle.TextSize = 20; bpTitle.TextXAlignment = Enum.TextXAlignment.Left

local bpClose = Instance.new("TextButton", buildPanel)
bpClose.Size = UDim2.new(0,34,0,34); bpClose.Position = UDim2.new(1,-42,0,8)
bpClose.BackgroundColor3 = Color3.fromRGB(180,25,25); bpClose.Text = "✕"
bpClose.TextColor3 = Color3.new(1,1,1); bpClose.Font = Enum.Font.GothamBold; bpClose.TextSize = 16
Instance.new("UICorner", bpClose).CornerRadius = UDim.new(0,8)
bpClose.MouseButton1Click:Connect(function() buildPanel.Visible = false end)

local bpScroll = Instance.new("ScrollingFrame", buildPanel)
bpScroll.Size = UDim2.new(1,-16,1,-56); bpScroll.Position = UDim2.new(0,8,0,52)
bpScroll.BackgroundTransparency = 1; bpScroll.ScrollBarThickness = 4
bpScroll.ScrollBarImageColor3 = Color3.fromRGB(255,160,40); bpScroll.CanvasSize = UDim2.new(0,0,0,0)
bpScroll.BorderSizePixel = 0
Instance.new("UIListLayout", bpScroll).Padding = UDim.new(0,6)

local function buildUpgradePanel(data)
    for _, c in ipairs(bpScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local ownedPlots = data.ownedPlots or {}
    local plotUpgrades = data.plotUpgrades or {}
    local coins = data.coins or 0
    local total = 0

    local hasPlots = false
    for plotId, owned in pairs(ownedPlots) do
        if not owned then continue end
        hasPlots = true

        -- Plot header
        local header = Instance.new("Frame", bpScroll)
        header.Size = UDim2.new(1,0,0,26); header.BackgroundColor3 = Color3.fromRGB(20,16,30)
        header.BorderSizePixel = 0
        Instance.new("UICorner", header).CornerRadius = UDim.new(0,6)
        local hl = Instance.new("TextLabel", header); hl.Size = UDim2.new(1,-10,1,0)
        hl.Position = UDim2.new(0,8,0,0); hl.BackgroundTransparency = 1
        hl.Text = PLOT_NAMES[plotId] or ("🏗️ "..plotId); hl.TextColor3 = Color3.fromRGB(255,200,100)
        hl.Font = Enum.Font.GothamBold; hl.TextSize = 13; hl.TextXAlignment = Enum.TextXAlignment.Left
        total = total + 32

        -- Three path buttons per plot
        local plotUpg = plotUpgrades[plotId] or {}
        for _, pathKey in ipairs({"A","B","C","D"}) do
            local path = PATHS[pathKey]
            local level = plotUpg[pathKey] or 0
            local maxed = level >= #path.costs
            local cost  = not maxed and path.costs[level + 1] or 0
            local canBuy= not maxed and coins >= cost
            local nextLabel = not maxed and path.labels[level + 1] or "MAX"

            local card = Instance.new("Frame", bpScroll)
            card.Size = UDim2.new(1,0,0,56); card.BackgroundColor3 = Color3.fromRGB(14,14,28)
            card.BorderSizePixel = 0
            Instance.new("UICorner", card).CornerRadius = UDim.new(0,8)
            local cs2 = Instance.new("UIStroke", card)
            cs2.Color = canBuy and path.col or Color3.fromRGB(45,45,65); cs2.Thickness = 1.2

            local pnm = Instance.new("TextLabel", card); pnm.Size = UDim2.new(0.55,0,0,22)
            pnm.Position = UDim2.new(0,8,0,4); pnm.BackgroundTransparency = 1
            pnm.Text = path.name; pnm.TextColor3 = path.col; pnm.Font = Enum.Font.GothamBold; pnm.TextSize = 13
            pnm.TextXAlignment = Enum.TextXAlignment.Left

            local pst = Instance.new("TextLabel", card); pst.Size = UDim2.new(0.55,0,0,18)
            pst.Position = UDim2.new(0,8,0,28); pst.BackgroundTransparency = 1
            pst.Text = "Lv " .. level .. "/" .. #path.costs .. "  Next: " .. nextLabel
            pst.TextColor3 = Color3.fromRGB(160,160,190); pst.Font = Enum.Font.Gotham; pst.TextSize = 11
            pst.TextXAlignment = Enum.TextXAlignment.Left

            local pbtn = Instance.new("TextButton", card); pbtn.Size = UDim2.new(0,96,0,36)
            pbtn.Position = UDim2.new(1,-104,0.5,-18)
            pbtn.BackgroundColor3 = maxed and Color3.fromRGB(20,50,20)
                or canBuy and Color3.fromRGB(30,55,20) or Color3.fromRGB(30,25,40)
            pbtn.Text = maxed and "MAX ✓" or ("💰 " .. fmt(cost))
            pbtn.TextColor3 = maxed and Color3.fromRGB(0,210,80) or Color3.new(1,1,1)
            pbtn.Font = Enum.Font.GothamBold; pbtn.TextSize = 12
            Instance.new("UICorner", pbtn).CornerRadius = UDim.new(0,8)
            if not maxed then
                local pid, pk = plotId, pathKey
                pbtn.MouseButton1Click:Connect(function()
                    RE_PlotUpgrade:FireServer(pid, pk)
                end)
            end
            total = total + 62
        end
    end

    if not hasPlots then
        local noPlots = Instance.new("TextLabel", bpScroll)
        noPlots.Size = UDim2.new(1,0,0,60); noPlots.BackgroundTransparency = 1
        noPlots.Text = "Buy machines to unlock upgrade paths!"
        noPlots.TextColor3 = Color3.fromRGB(120,120,150); noPlots.Font = Enum.Font.GothamBold
        noPlots.TextSize = 14; noPlots.TextXAlignment = Enum.TextXAlignment.Center
        total = 60
    end
    bpScroll.CanvasSize = UDim2.new(0,0,0,total + 10)
end

local buildPanelOpen = false
local function openBuildPanel()
    buildPanelOpen = not buildPanelOpen
    buildPanel.Visible = buildPanelOpen
    if buildPanelOpen and currentData then
        buildUpgradePanel(currentData)
    end
end

-- ── SIDE BUTTONS ─────────────────────────────────────────
local btnFrame = Instance.new("Frame",sg)
btnFrame.Size=UDim2.new(0,60,0,292); btnFrame.AnchorPoint=Vector2.new(1,0.5)
btnFrame.Position=UDim2.new(1,-8,0.5,0); btnFrame.BackgroundTransparency=1
local btnLayout=Instance.new("UIListLayout",btnFrame)
btnLayout.FillDirection=Enum.FillDirection.Vertical; btnLayout.Padding=UDim.new(0,8)
btnLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center

local function makeBtn(emoji, bgColor, onClick)
    local b = Instance.new("TextButton",btnFrame)
    b.Size=UDim2.new(0,52,0,52); b.BackgroundColor3=bgColor
    b.Text=emoji; b.TextScaled=true; b.Font=Enum.Font.GothamBold
    b.TextColor3=Color3.new(1,1,1); b.AutoButtonColor=false; b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
    b.MouseButton1Click:Connect(onClick)
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.08),{Size=UDim2.new(0,46,0,46)}):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.08),{Size=UDim2.new(0,52,0,52)}):Play()
    end)
    return b
end

-- ── SHOP PANEL ───────────────────────────────────────────
local shopPanel = Instance.new("Frame",sg)
shopPanel.Name="ShopPanel"; shopPanel.Visible=false
shopPanel.Size=UDim2.new(0,420,0,520); shopPanel.Position=UDim2.new(0.5,-210,0.5,-260)
shopPanel.BackgroundColor3=Color3.fromRGB(10,10,22); shopPanel.BorderSizePixel=0
Instance.new("UICorner",shopPanel).CornerRadius=UDim.new(0,14)
local spStroke=Instance.new("UIStroke",shopPanel)
spStroke.Color=Color3.fromRGB(255,200,0); spStroke.Thickness=2

local spTitle=Instance.new("TextLabel",shopPanel)
spTitle.Size=UDim2.new(1,-50,0,44); spTitle.Position=UDim2.new(0,12,0,6)
spTitle.BackgroundTransparency=1; spTitle.Text="⚡ UPGRADES"
spTitle.TextColor3=Color3.fromRGB(255,215,0); spTitle.Font=Enum.Font.GothamBold
spTitle.TextSize=24; spTitle.TextXAlignment=Enum.TextXAlignment.Left

local spClose=Instance.new("TextButton",shopPanel)
spClose.Size=UDim2.new(0,34,0,34); spClose.Position=UDim2.new(1,-42,0,8)
spClose.BackgroundColor3=Color3.fromRGB(180,25,25); spClose.Text="✕"
spClose.TextColor3=Color3.new(1,1,1); spClose.Font=Enum.Font.GothamBold; spClose.TextSize=16
Instance.new("UICorner",spClose).CornerRadius=UDim.new(0,8)
spClose.MouseButton1Click:Connect(function()
    shopOpen=false; shopPanel.Visible=false
end)

local scroll=Instance.new("ScrollingFrame",shopPanel)
scroll.Size=UDim2.new(1,-16,1,-56); scroll.Position=UDim2.new(0,8,0,52)
scroll.BackgroundTransparency=1; scroll.ScrollBarThickness=4
scroll.ScrollBarImageColor3=Color3.fromRGB(255,200,0); scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.BorderSizePixel=0
local scrollLayout=Instance.new("UIListLayout",scroll)
scrollLayout.FillDirection=Enum.FillDirection.Vertical; scrollLayout.Padding=UDim.new(0,8)

-- ── TOAST ────────────────────────────────────────────────
local toast=Instance.new("Frame",sg)
toast.Name="Toast"; toast.Size=UDim2.new(0,320,0,64)
toast.Position=UDim2.new(0,10,1,20)
toast.BackgroundColor3=Color3.fromRGB(12,12,28); toast.BorderSizePixel=0
Instance.new("UICorner",toast).CornerRadius=UDim.new(0,12)
local toastStroke=Instance.new("UIStroke",toast)
toastStroke.Color=Color3.fromRGB(0,220,100); toastStroke.Thickness=2

local toastTitle=Instance.new("TextLabel",toast)
toastTitle.Name="Title"; toastTitle.Size=UDim2.new(1,-12,0,28)
toastTitle.Position=UDim2.new(0,6,0,4); toastTitle.BackgroundTransparency=1
toastTitle.Text=""; toastTitle.TextColor3=Color3.new(1,1,1)
toastTitle.Font=Enum.Font.GothamBold; toastTitle.TextSize=16
toastTitle.TextXAlignment=Enum.TextXAlignment.Left

local toastBody=Instance.new("TextLabel",toast)
toastBody.Name="Body"; toastBody.Size=UDim2.new(1,-12,0,24)
toastBody.Position=UDim2.new(0,6,0,34); toastBody.BackgroundTransparency=1
toastBody.Text=""; toastBody.TextColor3=Color3.fromRGB(170,170,190)
toastBody.Font=Enum.Font.Gotham; toastBody.TextSize=13
toastBody.TextXAlignment=Enum.TextXAlignment.Left

-- ============================================================
-- TOAST SYSTEM
-- ============================================================
local toastQueue={}; local toastBusy=false
local colorMap={
    gold =Color3.fromRGB(255,200,0),
    green=Color3.fromRGB(0,210,90),
    red  =Color3.fromRGB(255,55,55),
    blue =Color3.fromRGB(55,155,255),
}

local function showToast(title,body,colorKey)
    table.insert(toastQueue,{title=title,body=body,col=colorKey})
    if toastBusy then return end
    local function pop()
        if #toastQueue==0 then toastBusy=false return end
        toastBusy=true
        local item=table.remove(toastQueue,1)
        toastStroke.Color=colorMap[item.col] or colorMap.green
        toastTitle.Text=item.title; toastBody.Text=item.body
        TweenService:Create(toast,TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Position=UDim2.new(0,10,1,-80)}):Play()
        task.delay(2.6,function()
            TweenService:Create(toast,TweenInfo.new(0.25),
                {Position=UDim2.new(0,10,1,20)}):Play()
            task.delay(0.3,pop)
        end)
    end
    pop()
end

RE_NotifyPlayer.OnClientEvent:Connect(function(title,body,col)
    showToast(title,body,col)
    if title:find("JACKPOT") or title:find("RARE") then
        SFX.jackpot:Play()
    elseif title:find("💰") and not title:find("MEGA") then
        SFX.coin:Play()
    elseif title:find("Plot Claimed") or title:find("Unlocked") then
        SFX.plotBuy:Play()
    elseif title:find("REBORN") or title:find("ASCENDED") or title:find("TRANSCENDED") or title:find("LEGENDARY") then
        SFX.prestige:Play()
    elseif title:find("MEGA BURST") then
        SFX.megaBurst:Play()
    elseif title:find("Hit!") or title:find("Struck!") then
        SFX.swordHit:Play()
    elseif title:find("RAID") or title:find("Stolen") then
        SFX.raidAlert:Play()
    end
end)

-- ============================================================
-- HUD UPDATE
-- ============================================================

-- ── PRESTIGE THEMES ──────────────────────────────────────
local PRESTIGE_THEMES = {
    [0]={tint=Color3.new(1,1,1),              sat=0,    bright=0,     stroke=Color3.fromRGB(255,200,0),  rcol=Color3.fromRGB(255,120,0)},
    [1]={tint=Color3.fromRGB(255,235,180),    sat=0.12, bright=0.04,  stroke=Color3.fromRGB(255,210,80), rcol=Color3.fromRGB(255,190,50)},
    [2]={tint=Color3.fromRGB(255,165,110),    sat=0.22, bright=0.0,   stroke=Color3.fromRGB(255,90,20),  rcol=Color3.fromRGB(255,80,30)},
    [3]={tint=Color3.fromRGB(190,140,255),    sat=0.4,  bright=-0.06, stroke=Color3.fromRGB(190,60,255), rcol=Color3.fromRGB(200,80,255)},
}

local function applyPrestigeTheme(rebirths)
    if rebirths == lastRebirths then return end
    lastRebirths = rebirths
    local lighting = game:GetService("Lighting")
    for _, e in ipairs(lighting:GetChildren()) do
        if e.Name == "PrestigeCC" then e:Destroy() end
    end
    local t = PRESTIGE_THEMES[math.min(rebirths, 3)]
    if not t then return end
    local cc = Instance.new("ColorCorrectionEffect", lighting)
    cc.Name = "PrestigeCC"; cc.TintColor = t.tint; cc.Saturation = t.sat; cc.Brightness = t.bright
    TweenService:Create(hudStroke,   TweenInfo.new(0.6), {Color      = t.stroke}):Play()
    TweenService:Create(rebirthLbl, TweenInfo.new(0.6), {TextColor3 = t.rcol}):Play()
end

-- Prestige cost: 100000 × 3^rebirths (P1=100k, P2=300k, P3=900k, P4=2.7M, P5=8.1M)
local PRESTIGE_BASE_COST = 100000
local function updateHUD(data)
    coinLbl.Text    = "💰 "..fmt(data.coins or 0)
    rebirthLbl.Text = "🔥 x"..(data.rebirths or 0)
    applyPrestigeTheme(data.rebirths or 0)
    local cost = PRESTIGE_BASE_COST * (3 ^ (data.rebirths or 0))
    local pct  = math.min(1, (data.coins or 0) / cost)
    TweenService:Create(pBarFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        {Size = UDim2.new(pct, 0, 1, 0)}):Play()
    pBarFill.BackgroundColor3 = pct >= 1
        and Color3.fromRGB(255, 215, 0)
        or  Color3.fromRGB(255, 100, 0)
end

-- ============================================================
-- UPGRADE SHOP
-- ============================================================
local function buildShop(data,upgrades)
    for _,c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local gp = data._gp or {}
    local total=0
    for i,upg in ipairs(upgrades) do
        local level=data.upgrades and data.upgrades[upg.key] or 0
        local maxed=level>=upg.maxLevel
        local cost=not maxed and math.floor(upg.baseCost*(upg.costMult^level)) or 0
        local canBuy=not maxed and (data.coins or 0)>=cost

        local card=Instance.new("Frame",scroll)
        card.Name="Card"..i; card.Size=UDim2.new(1,0,0,104)
        card.BackgroundColor3=Color3.fromRGB(18,18,36); card.BorderSizePixel=0
        card.LayoutOrder=i
        Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
        local cs=Instance.new("UIStroke",card)
        cs.Color=canBuy and Color3.fromRGB(0,190,70) or Color3.fromRGB(50,50,80); cs.Thickness=1.5

        local ico=Instance.new("TextLabel",card); ico.Size=UDim2.new(0,46,1,0)
        ico.BackgroundTransparency=1; ico.Text=upg.icon; ico.TextScaled=true

        local nm=Instance.new("TextLabel",card); nm.Size=UDim2.new(0,200,0,22)
        nm.Position=UDim2.new(0,50,0,6); nm.BackgroundTransparency=1
        nm.Text=upg.name; nm.TextColor3=Color3.fromRGB(230,230,250)
        nm.Font=Enum.Font.GothamBold; nm.TextSize=14; nm.TextXAlignment=Enum.TextXAlignment.Left

        local lvlTxt=Instance.new("TextLabel",card); lvlTxt.Size=UDim2.new(0,160,0,16)
        lvlTxt.Position=UDim2.new(0,50,0,28); lvlTxt.BackgroundTransparency=1
        lvlTxt.Text=maxed and "✓ MAX LEVEL" or "Lv "..level.." / "..upg.maxLevel
        lvlTxt.TextColor3=maxed and Color3.fromRGB(0,210,90) or Color3.fromRGB(255,200,0)
        lvlTxt.Font=Enum.Font.GothamBold; lvlTxt.TextSize=12
        lvlTxt.TextXAlignment=Enum.TextXAlignment.Left

        local effectText
        if upg.key=="touchSpeed" then
            effectText = "Now: "..(math.max(1,8-level)).."s recharge"
        elseif upg.key=="coinValue" then
            local mult = 1 + level*0.5
            effectText = string.format("Value: %.1fx", mult)
        elseif upg.key=="offlineVault" then
            effectText = level > 0 and ("Saves up to "..level.."h offline") or "No offline earning yet"
        else effectText = "" end

        local ef=Instance.new("TextLabel",card); ef.Size=UDim2.new(0,195,0,14)
        ef.Position=UDim2.new(0,50,0,46); ef.BackgroundTransparency=1
        ef.Text=effectText; ef.TextColor3=Color3.fromRGB(80,200,255)
        ef.Font=Enum.Font.GothamBold; ef.TextSize=11; ef.TextXAlignment=Enum.TextXAlignment.Left

        local dc=Instance.new("TextLabel",card); dc.Size=UDim2.new(0,195,0,14)
        dc.Position=UDim2.new(0,50,0,60); dc.BackgroundTransparency=1
        dc.Text=upg.desc; dc.TextColor3=Color3.fromRGB(120,120,150)
        dc.Font=Enum.Font.Gotham; dc.TextSize=11; dc.TextXAlignment=Enum.TextXAlignment.Left

        local bg=Instance.new("Frame",card); bg.Size=UDim2.new(0,185,0,6)
        bg.Position=UDim2.new(0,50,0,76); bg.BackgroundColor3=Color3.fromRGB(35,35,55); bg.BorderSizePixel=0
        Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)
        local fill=Instance.new("Frame",bg)
        fill.Size=UDim2.new(math.min(1, level/math.max(1,upg.maxLevel)),0,1,0)
        fill.BackgroundColor3=maxed and Color3.fromRGB(0,210,90) or Color3.fromRGB(255,200,0)
        fill.BorderSizePixel=0
        Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

        local btn=Instance.new("TextButton",card); btn.Size=UDim2.new(0,96,0,40)
        btn.Position=UDim2.new(1,-104,0.5,-20)
        btn.BackgroundColor3=maxed and Color3.fromRGB(35,75,35)
            or canBuy and Color3.fromRGB(18,130,55)
            or Color3.fromRGB(55,35,35)
        btn.Text=maxed and "MAX ✓" or "💰 "..fmt(cost)
        btn.TextColor3=Color3.new(1,1,1); btn.Font=Enum.Font.GothamBold; btn.TextSize=13
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
        if not maxed then
            btn.MouseButton1Click:Connect(function()
                RE_BuyUpgrade:FireServer(upg.key)
            end)
        end
        total=total+112
    end
    scroll.CanvasSize=UDim2.new(0,0,0,total)
end

local function openShop()
    shopOpen=not shopOpen
    shopPanel.Visible=shopOpen
    if shopOpen and currentData and upgradesDef then
        buildShop(currentData,upgradesDef)
    end
end

-- ── DAILY REWARD ─────────────────────────────────────────
local DAILY_REWARDS_CLIENT = {2000, 5000, 12000, 30000, 80000, 200000, 750000}

local function openDaily()
    local old2 = sg:FindFirstChild("DailyPanel")
    if old2 then old2:Destroy() return end

    local panel = Instance.new("Frame", sg); panel.Name = "DailyPanel"
    panel.Size = UDim2.new(0, 320, 0, 230); panel.Position = UDim2.new(0.5,-160,0.5,-115)
    panel.BackgroundColor3 = Color3.fromRGB(10,8,22); panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0,14)
    local ds = Instance.new("UIStroke", panel); ds.Color = Color3.fromRGB(130,40,180); ds.Thickness = 2

    local cl = Instance.new("TextButton", panel); cl.Size = UDim2.new(0,32,0,32)
    cl.Position = UDim2.new(1,-40,0,8); cl.BackgroundColor3 = Color3.fromRGB(160,25,25)
    cl.Text = "✕"; cl.TextColor3 = Color3.new(1,1,1); cl.Font = Enum.Font.GothamBold; cl.TextSize = 15
    Instance.new("UICorner", cl).CornerRadius = UDim.new(0,8)
    cl.MouseButton1Click:Connect(function() panel:Destroy() end)

    local ttl = Instance.new("TextLabel", panel); ttl.Size = UDim2.new(1,-50,0,40)
    ttl.Position = UDim2.new(0,12,0,6); ttl.BackgroundTransparency = 1
    ttl.Text = "🎁 DAILY REWARD"; ttl.TextColor3 = Color3.fromRGB(200,100,255)
    ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 20; ttl.TextXAlignment = Enum.TextXAlignment.Left

    local streak = (currentData and currentData.dailyStreak) or 0
    local nextDay = math.min(streak + 1, #DAILY_REWARDS_CLIENT)
    local nextReward = DAILY_REWARDS_CLIENT[nextDay]

    local info = Instance.new("TextLabel", panel); info.Size = UDim2.new(1,-20,0,36)
    info.Position = UDim2.new(0,10,0,50); info.BackgroundTransparency = 1
    info.Text = "Streak: Day "..streak.." → "..nextDay.."    |    Next: 💰 "..nextReward.." coins\nClaim every 20 hours • streak resets after 48h"
    info.TextColor3 = Color3.fromRGB(160,160,190); info.Font = Enum.Font.Gotham; info.TextSize = 12
    info.TextWrapped = true; info.TextXAlignment = Enum.TextXAlignment.Left

    local strip = Instance.new("Frame", panel); strip.Size = UDim2.new(1,-20,0,58)
    strip.Position = UDim2.new(0,10,0,92); strip.BackgroundTransparency = 1
    local rl = Instance.new("UIListLayout", strip)
    rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0,4)

    for i, reward in ipairs(DAILY_REWARDS_CLIENT) do
        local box = Instance.new("Frame", strip); box.Size = UDim2.new(0,36,0,56)
        box.BackgroundColor3 = i <= streak and Color3.fromRGB(18,70,18)
            or i == nextDay and Color3.fromRGB(70,20,100)
            or Color3.fromRGB(22,22,44)
        box.BorderSizePixel = 0
        Instance.new("UICorner", box).CornerRadius = UDim.new(0,7)
        local lbl = Instance.new("TextLabel", box); lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
        local txt = reward >= 1000 and math.floor(reward/1000).."K" or tostring(reward)
        lbl.Text = i <= streak and "✓" or txt
        lbl.TextColor3 = i <= streak and Color3.fromRGB(0,210,80)
            or i == nextDay and Color3.fromRGB(220,110,255)
            or Color3.fromRGB(100,100,130)
    end

    local claimBtn = Instance.new("TextButton", panel); claimBtn.Size = UDim2.new(1,-20,0,42)
    claimBtn.Position = UDim2.new(0,10,0,162); claimBtn.BorderSizePixel = 0
    claimBtn.BackgroundColor3 = Color3.fromRGB(80,20,120)
    claimBtn.Text = "🎁 Claim Day "..nextDay.." ("..nextReward.." coins)"
    claimBtn.TextColor3 = Color3.new(1,1,1); claimBtn.Font = Enum.Font.GothamBold; claimBtn.TextSize = 14
    Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0,8)
    claimBtn.MouseButton1Click:Connect(function()
        RE_ClaimDaily:FireServer()
        panel:Destroy()
    end)
end

-- ── PRESTIGE PANEL ───────────────────────────────────────
local function openPrestige()
    local old2=sg:FindFirstChild("PrestigePanel")
    if old2 then old2:Destroy() return end

    local rebirths = (currentData and currentData.rebirths) or 0
    local gp       = (currentData and currentData._gp) or {}
    -- Cost: 100000 × 3^rebirths — matches server formula; Prestige Boost pass = -20%
    local cost     = math.floor(100000 * (3 ^ rebirths) * (gp.prestigeBoost and 0.8 or 1))
    local coins    = (currentData and currentData.coins) or 0
    local canDo    = coins >= cost
    local multStr  = "2x"

    local curPow  = math.floor(2 ^ rebirths)
    local nextPow = math.floor(2 ^ (rebirths + 1))

    -- What upgrades the player currently has and would keep 25%
    local upgStr = ""
    if currentData and currentData.upgrades then
        local parts = {}
        for key, lvl in pairs(currentData.upgrades) do
            local kept = math.floor(lvl * 0.25)
            if kept > 0 then
                table.insert(parts, key.."("..lvl.."→"..kept..")")
            end
        end
        if #parts > 0 then
            upgStr = "\n🎁 Keeping 25%% of upgrades: "..table.concat(parts,", ")
        end
    end

    local panel=Instance.new("Frame",sg); panel.Name="PrestigePanel"
    panel.Size=UDim2.new(0,360,0,230); panel.Position=UDim2.new(0.5,-180,0.5,-115)
    panel.BackgroundColor3=Color3.fromRGB(10,8,22); panel.BorderSizePixel=0
    Instance.new("UICorner",panel).CornerRadius=UDim.new(0,14)
    local ps=Instance.new("UIStroke",panel); ps.Color=Color3.fromRGB(255,80,0); ps.Thickness=2

    local ttl=Instance.new("TextLabel",panel); ttl.Size=UDim2.new(1,-50,0,40)
    ttl.Position=UDim2.new(0,12,0,6); ttl.BackgroundTransparency=1
    ttl.Text="🔥 PRESTIGE"; ttl.TextColor3=Color3.fromRGB(255,110,0)
    ttl.Font=Enum.Font.GothamBold; ttl.TextSize=22; ttl.TextXAlignment=Enum.TextXAlignment.Left

    local cl=Instance.new("TextButton",panel); cl.Size=UDim2.new(0,32,0,32)
    cl.Position=UDim2.new(1,-40,0,8); cl.BackgroundColor3=Color3.fromRGB(160,25,25)
    cl.Text="✕"; cl.TextColor3=Color3.new(1,1,1); cl.Font=Enum.Font.GothamBold; cl.TextSize=15
    Instance.new("UICorner",cl).CornerRadius=UDim.new(0,8)
    cl.MouseButton1Click:Connect(function() panel:Destroy() end)

    local info=Instance.new("TextLabel",panel); info.Size=UDim2.new(1,-20,0,110)
    info.Position=UDim2.new(0,10,0,48); info.BackgroundTransparency=1
    info.Text="Resets coins & most upgrades — keeps prestige level.\n"
        .."Each prestige gives a permanent "..multStr.." income multiplier.\n"
        .."You also KEEP 25%% of all your upgrade levels!\n\n"
        .."Income now:  ×"..curPow.."  →  After prestige:  ×"..nextPow.."\n"
        .."Cost: 💰 "..fmt(cost)..(gp.prestigeBoost and "  (🔥 -20%% Boost!)" or "")
        .."    You have: 💰 "..fmt(coins)
        ..upgStr
    info.TextColor3=Color3.fromRGB(180,180,200); info.Font=Enum.Font.Gotham; info.TextSize=13
    info.TextWrapped=true; info.TextXAlignment=Enum.TextXAlignment.Left

    local btn=Instance.new("TextButton",panel); btn.Size=UDim2.new(1,-20,0,44)
    btn.Position=UDim2.new(0,10,0,174)
    btn.BackgroundColor3=canDo and Color3.fromRGB(200,55,0) or Color3.fromRGB(55,30,20)
    btn.Text=canDo and "🔥 Prestige Now!" or ("❌ Need 💰 "..fmt(cost).." coins")
    btn.TextColor3=Color3.new(1,1,1); btn.Font=Enum.Font.GothamBold; btn.TextSize=15
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
    if canDo then
        local confirming = false
        local confirmThread = nil
        btn.MouseButton1Click:Connect(function()
            if not confirming then
                confirming = true
                btn.Text = "⚠️ Confirm? (click again to prestige)"
                btn.BackgroundColor3 = Color3.fromRGB(220,100,0)
                if confirmThread then task.cancel(confirmThread) end
                confirmThread = task.delay(3, function()
                    confirming = false
                    btn.Text = "🔥 Prestige Now!"
                    btn.BackgroundColor3 = Color3.fromRGB(200,55,0)
                end)
            else
                if confirmThread then task.cancel(confirmThread) end
                RE_Rebirth:FireServer()
                panel:Destroy()
                -- Remove machine rate billboards on prestige
                for plotId, part in pairs(machineRateParts) do
                    pcall(function() part:Destroy() end)
                end
                machineRateParts = {}
                machineRates     = {}
            end
        end)
    end
end

-- ── ROBUX SHOP ───────────────────────────────────────────
local function openRobuxShop()
    local old2=sg:FindFirstChild("RobuxShop")
    if old2 then old2:Destroy() return end

    local ownedGP = (currentData and currentData._gp) or {}

    local panel=Instance.new("Frame",sg); panel.Name="RobuxShop"
    panel.Size=UDim2.new(0,420,0,540)
    panel.Position=UDim2.new(0.5,-210,0.5,-270)
    panel.BackgroundColor3=Color3.fromRGB(8,8,22); panel.BorderSizePixel=0
    Instance.new("UICorner",panel).CornerRadius=UDim.new(0,14)
    local rs=Instance.new("UIStroke",panel); rs.Color=Color3.fromRGB(55,140,255); rs.Thickness=2

    local t2=Instance.new("TextLabel",panel); t2.Size=UDim2.new(1,-50,0,44)
    t2.Position=UDim2.new(0,12,0,4); t2.BackgroundTransparency=1
    t2.Text="💎 ROBUX SHOP"; t2.TextColor3=Color3.fromRGB(90,170,255)
    t2.Font=Enum.Font.GothamBold; t2.TextSize=22; t2.TextXAlignment=Enum.TextXAlignment.Left

    local cl=Instance.new("TextButton",panel); cl.Size=UDim2.new(0,32,0,32)
    cl.Position=UDim2.new(1,-40,0,8); cl.BackgroundColor3=Color3.fromRGB(160,25,25)
    cl.Text="✕"; cl.TextColor3=Color3.new(1,1,1); cl.Font=Enum.Font.GothamBold; cl.TextSize=15
    Instance.new("UICorner",cl).CornerRadius=UDim.new(0,8)
    cl.MouseButton1Click:Connect(function() panel:Destroy() end)

    local scr=Instance.new("ScrollingFrame",panel)
    scr.Size=UDim2.new(1,-16,1,-56); scr.Position=UDim2.new(0,8,0,52)
    scr.BackgroundTransparency=1; scr.ScrollBarThickness=4
    scr.ScrollBarImageColor3=Color3.fromRGB(55,140,255)
    scr.BorderSizePixel=0; scr.CanvasSize=UDim2.new(0,0,0,0)

    local y=0
    local function row(lbl, price, cb, bgCol, priceCol)
        local r=Instance.new("TextButton",scr); r.Size=UDim2.new(1,-4,0,50)
        r.Position=UDim2.new(0,2,0,y); r.BackgroundColor3=bgCol; r.Text=""; r.BorderSizePixel=0
        Instance.new("UICorner",r).CornerRadius=UDim.new(0,10)
        local l=Instance.new("TextLabel",r); l.Size=UDim2.new(0.6,0,1,0)
        l.Position=UDim2.new(0,10,0,0); l.BackgroundTransparency=1; l.Text=lbl
        l.TextColor3=Color3.new(1,1,1); l.Font=Enum.Font.GothamBold; l.TextSize=13
        l.TextXAlignment=Enum.TextXAlignment.Left; l.TextWrapped=true
        local p=Instance.new("TextLabel",r); p.Size=UDim2.new(0.38,0,1,0)
        p.Position=UDim2.new(0.6,0,0,0); p.BackgroundTransparency=1; p.Text=price
        p.TextColor3=priceCol or Color3.fromRGB(255,215,0)
        p.Font=Enum.Font.GothamBold; p.TextSize=13
        p.TextXAlignment=Enum.TextXAlignment.Right; p.TextWrapped=true
        r.MouseButton1Click:Connect(cb); y=y+56
    end

    local function sec(text)
        local s=Instance.new("TextLabel",scr); s.Size=UDim2.new(1,-4,0,22)
        s.Position=UDim2.new(0,2,0,y); s.BackgroundTransparency=1; s.Text=text
        s.TextColor3=Color3.fromRGB(140,140,170); s.Font=Enum.Font.GothamBold; s.TextSize=11
        s.TextXAlignment=Enum.TextXAlignment.Left; y=y+28
    end

    -- Coin packs
    sec("── COIN PACKS ──────────────────")
    local COIN_PACKS = {
        {id=3586040050, label="💰 5,000 Coins",    price="R$99"},
        {id=3586040263, label="💰 25,000 Coins",   price="R$299"},
        {id=3586040422, label="💰 75,000 Coins",   price="R$699"},
        {id=3586040561, label="🔄 Reset Upgrades", price="R$49"},
    }
    for _,p in ipairs(COIN_PACKS) do
        local pid=p.id
        row(p.label, p.price,
            function() MarketplaceService:PromptProductPurchase(player,pid) end,
            Color3.fromRGB(14,44,14), nil)
    end

    local function gpRow(lbl, desc, price, cb, bgCol, priceCol)
        local r=Instance.new("TextButton",scr); r.Size=UDim2.new(1,-4,0,68)
        r.Position=UDim2.new(0,2,0,y); r.BackgroundColor3=bgCol; r.Text=""; r.BorderSizePixel=0
        Instance.new("UICorner",r).CornerRadius=UDim.new(0,10)
        local l=Instance.new("TextLabel",r); l.Size=UDim2.new(0.62,0,0,28)
        l.Position=UDim2.new(0,10,0,4); l.BackgroundTransparency=1; l.Text=lbl
        l.TextColor3=Color3.new(1,1,1); l.Font=Enum.Font.GothamBold; l.TextSize=13
        l.TextXAlignment=Enum.TextXAlignment.Left
        local p=Instance.new("TextLabel",r); p.Size=UDim2.new(0.36,0,0,28)
        p.Position=UDim2.new(0.62,0,0,4); p.BackgroundTransparency=1; p.Text=price
        p.TextColor3=priceCol or Color3.fromRGB(255,215,0)
        p.Font=Enum.Font.GothamBold; p.TextSize=13
        p.TextXAlignment=Enum.TextXAlignment.Right
        local d=Instance.new("TextLabel",r); d.Size=UDim2.new(1,-16,0,30)
        d.Position=UDim2.new(0,10,0,34); d.BackgroundTransparency=1; d.Text=desc
        d.TextColor3=Color3.fromRGB(125,125,158); d.Font=Enum.Font.Gotham; d.TextSize=11
        d.TextXAlignment=Enum.TextXAlignment.Left; d.TextWrapped=true
        r.MouseButton1Click:Connect(cb); y=y+76
    end

    -- Gamepasses
    y=y+6
    sec("── GAMEPASSES (permanent!) ─────")
    local GAMEPASSES_LIST = {
        {id=1821720069, label="⭐ VIP",           price="R$499", key="doubleCoin",
         desc="2× coins from everything in the game — machines, geysers, kills. Stacks with all other bonuses. Best value pass."},
        {id=1823064828, label="🤖 Auto Farm",      price="R$349", key="autoFarm",
         desc="Your machines tick at 2× speed automatically. Earn coins even when you're AFK or exploring."},
        {id=1822515059, label="💰 Auto Collect",   price="R$249", key="autoCollect",
         desc="Coins from geysers fly straight to you. No more running around the map to grab them."},
        {id=1822649609, label="🔥 Prestige Boost", price="R$199", key="prestigeBoost",
         desc="Every rebirth costs 20% fewer coins. Makes the prestige grind noticeably faster across every run."},
        {id=1821659972, label="🍀 Lucky Charm",    price="R$199", key="luckyCharm",
         desc="Triples your jackpot chance and boosts the jackpot multiplier to 20×. Big swings when it hits."},
        {id=1822655551, label="⚡ Speed Demon",    price="R$99",  key="speedDemon",
         desc="Walk 8 units/sec faster than other players. Useful for chasing raids, defending plots, and PvP."},
    }
    for _,gp in ipairs(GAMEPASSES_LIST) do
        local gpId=gp.id
        local owned=ownedGP[gp.key]
        gpRow(gp.label, gp.desc, owned and "✓ OWNED" or gp.price,
            function()
                if not owned then MarketplaceService:PromptGamePassPurchase(player,gpId) end
            end,
            owned and Color3.fromRGB(8,28,8) or Color3.fromRGB(22,16,38),
            owned and Color3.fromRGB(0,200,80) or Color3.fromRGB(180,140,255))
    end

    scr.CanvasSize=UDim2.new(0,0,0,y+8)
end

-- ── STATS PANEL ──────────────────────────────────────────
local function openStats()
    local old2 = sg:FindFirstChild("StatsPanel")
    if old2 then old2:Destroy() return end

    local data = currentData or {}
    local gp   = data._gp or {}

    local panel = Instance.new("Frame", sg); panel.Name = "StatsPanel"
    panel.BackgroundColor3 = Color3.fromRGB(10,8,22); panel.BorderSizePixel = 0
    Instance.new("UICorner",panel).CornerRadius = UDim.new(0,14)
    local ss = Instance.new("UIStroke",panel); ss.Color = Color3.fromRGB(0,180,255); ss.Thickness = 2

    local cl = Instance.new("TextButton",panel); cl.Size = UDim2.new(0,32,0,32)
    cl.Position = UDim2.new(1,-40,0,8); cl.BackgroundColor3 = Color3.fromRGB(160,25,25)
    cl.Text = "✕"; cl.TextColor3 = Color3.new(1,1,1); cl.Font = Enum.Font.GothamBold; cl.TextSize = 15
    Instance.new("UICorner",cl).CornerRadius = UDim.new(0,8)
    cl.MouseButton1Click:Connect(function() panel:Destroy() end)

    local ttl = Instance.new("TextLabel",panel); ttl.Size = UDim2.new(1,-50,0,40)
    ttl.Position = UDim2.new(0,12,0,6); ttl.BackgroundTransparency = 1
    ttl.Text = "📊 YOUR STATS"; ttl.TextColor3 = Color3.fromRGB(80,200,255)
    ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 20; ttl.TextXAlignment = Enum.TextXAlignment.Left

    local plotCount = 0
    for _ in pairs(data.ownedPlots or {}) do plotCount = plotCount + 1 end

    local secs = data.playTime or 0
    local timeStr = (math.floor(secs/3600)).."h "..(math.floor((secs%3600)/60)).."m"

    local cvLvl = (data.upgrades and data.upgrades.coinValue) or 0
    local streak = data.prestigeStreak or 0
    local mult  = (1 + cvLvl*0.5)
                  * (2 ^ (data.rebirths or 0))
                  * (1 + 0.1 * math.min(streak, 5))
    local coinVal = math.floor(30 * mult)
    local cd  = math.max(1, 8 - ((data.upgrades and data.upgrades.touchSpeed) or 0))
    if gp.autoFarm then cd = math.max(1, math.floor(cd/2)) end
    local plotIncome = plotCount > 0 and math.floor(plotCount * coinVal * (60/cd)) or 0

    local stats = {
        {"💰 Total Earned",      fmt(data.totalEarned or 0)},
        {"🔥 Prestige Level",    tostring(data.rebirths or 0)},
        {"🔁 Prestige Streak",   streak > 0 and ("×"..streak.." (+"..(streak*10).."%%)") or "None"},
        {"🌾 Plots Owned",       plotCount .. " / 20"},
        {"⏱  Play Time",        timeStr},
        {"📈 Plot Income/min",   plotCount>0 and "~"..fmt(plotIncome) or "Buy plots!"},
        {"💎 Coin Value",        fmt(coinVal).." ea"},
        {"⚔️ Prestige Cost",     fmt(math.floor(100000 * (3 ^ (data.rebirths or 0))))},
    }

    local rowH = 32
    for i, row in ipairs(stats) do
        local y = 44 + (i-1)*(rowH+4)
        local rf = Instance.new("Frame",panel)
        rf.Size = UDim2.new(1,-20,0,rowH); rf.Position = UDim2.new(0,10,0,y)
        rf.BackgroundColor3 = i%2==0 and Color3.fromRGB(16,16,32) or Color3.fromRGB(12,12,26)
        rf.BorderSizePixel = 0
        Instance.new("UICorner",rf).CornerRadius = UDim.new(0,6)
        local kl = Instance.new("TextLabel",rf); kl.Size = UDim2.new(0.56,0,1,0)
        kl.Position = UDim2.new(0,8,0,0); kl.BackgroundTransparency = 1
        kl.Text = row[1]; kl.TextColor3 = Color3.fromRGB(155,155,185)
        kl.Font = Enum.Font.Gotham; kl.TextSize = 13; kl.TextXAlignment = Enum.TextXAlignment.Left
        local vl = Instance.new("TextLabel",rf); vl.Size = UDim2.new(0.44,-8,1,0)
        vl.Position = UDim2.new(0.56,0,0,0); vl.BackgroundTransparency = 1
        vl.Text = row[2]; vl.TextColor3 = Color3.fromRGB(255,215,0)
        vl.Font = Enum.Font.GothamBold; vl.TextSize = 13; vl.TextXAlignment = Enum.TextXAlignment.Right
    end

    local ranking = data._ranking
    local baseH   = 48 + #stats*(rowH+4) + 8
    if ranking and #ranking > 1 then
        local secY = baseH - 4
        local secLbl = Instance.new("TextLabel", panel)
        secLbl.Size = UDim2.new(1,-20,0,20); secLbl.Position = UDim2.new(0,10,0,secY)
        secLbl.BackgroundTransparency = 1; secLbl.Text = "⚔️  LIVE SERVER RACE"
        secLbl.TextColor3 = Color3.fromRGB(255,215,0); secLbl.Font = Enum.Font.GothamBold
        secLbl.TextSize = 12; secLbl.TextXAlignment = Enum.TextXAlignment.Left
        local podium = {Color3.fromRGB(255,215,0), Color3.fromRGB(200,210,220), Color3.fromRGB(200,130,60)}
        for ri, entry in ipairs(ranking) do
            local ry = secY + 24 + (ri-1)*(rowH+4)
            local rrf = Instance.new("Frame", panel)
            rrf.Size = UDim2.new(1,-20,0,rowH); rrf.Position = UDim2.new(0,10,0,ry)
            rrf.BackgroundColor3 = ri%2==0 and Color3.fromRGB(16,16,32) or Color3.fromRGB(12,12,26)
            rrf.BorderSizePixel = 0
            Instance.new("UICorner",rrf).CornerRadius = UDim.new(0,6)
            local col = podium[ri] or Color3.fromRGB(160,160,180)
            local rnk = Instance.new("TextLabel",rrf); rnk.Size = UDim2.new(0,24,1,0)
            rnk.Position = UDim2.new(0,4,0,0); rnk.BackgroundTransparency=1
            rnk.Text="#"..ri; rnk.TextColor3=col; rnk.Font=Enum.Font.GothamBold; rnk.TextSize=12
            local rnm = Instance.new("TextLabel",rrf); rnm.Size = UDim2.new(0.5,0,1,0)
            rnm.Position = UDim2.new(0,30,0,0); rnm.BackgroundTransparency=1
            rnm.Text=entry.name; rnm.TextColor3=Color3.fromRGB(210,210,230)
            rnm.Font=Enum.Font.GothamBold; rnm.TextSize=12; rnm.TextXAlignment=Enum.TextXAlignment.Left
            local rsc = Instance.new("TextLabel",rrf); rsc.Size = UDim2.new(0.38,0,1,0)
            rsc.Position = UDim2.new(0.62,0,0,0); rsc.BackgroundTransparency=1
            rsc.Text="💰 "..fmt(entry.coins).."  ×"..entry.rebirths
            rsc.TextColor3=col; rsc.Font=Enum.Font.Gotham; rsc.TextSize=11
            rsc.TextXAlignment=Enum.TextXAlignment.Right
        end
        local totalH = secY + 28 + #ranking*(rowH+4) + 8
        panel.Size     = UDim2.new(0,300,0,totalH)
        panel.Position = UDim2.new(0.5,-150,0.5,-totalH/2)
    else
        panel.Size     = UDim2.new(0,300,0,baseH)
        panel.Position = UDim2.new(0.5,-150,0.5,-baseH/2)
    end
end

-- ── WIRE BUTTONS ─────────────────────────────────────────
makeBtn("🗡️", Color3.fromRGB(100,20,130), openWeaponShop)
makeBtn("🔧", Color3.fromRGB(130,70,10),  openBuildPanel)
makeBtn("🛒", Color3.fromRGB(25,110,50),  openShop)
makeBtn("🎁", Color3.fromRGB(120,40,140), openDaily)
makeBtn("🔥", Color3.fromRGB(160,55,0),   openPrestige)
makeBtn("💎", Color3.fromRGB(18,75,170),  openRobuxShop)
makeBtn("📊", Color3.fromRGB(0,90,160),   openStats)

-- ── ShowShop remote ───────────────────────────────────────
RE_ShowShop.OnClientEvent:Connect(function()
    shopOpen = true
    shopPanel.Visible = true
    if currentData and upgradesDef then
        buildShop(currentData, upgradesDef)
    end
end)

-- ── Stat updates from server ──────────────────────────────
local prevRank = nil

RE_UpdateStats.OnClientEvent:Connect(function(data, upgrades)
    currentData = data
    upgradesDef = upgrades
    updateHUD(data)
    if shopOpen then buildShop(data, upgrades) end
    if weaponPanelOpen then buildWeaponShop(data.ownedWeapons, data.weaponLevels, data.equippedWeapon, data.coins or 0) end
    if buildPanelOpen  then buildUpgradePanel(data) end
    abilityBar.Visible = true
    local plotCount = 0
    if data.ownedPlots then
        for _, v in pairs(data.ownedPlots) do if v then plotCount += 1 end end
    end
    plotHasPlots = plotCount > 0
    plotBar.Visible = plotHasPlots
    if plotHasPlots and plotTickRemaining <= 0 then
        local tsLvl = (data.upgrades and data.upgrades.touchSpeed) or 0
        plotTickCd        = math.max(1, 8 - tsLvl)
        plotTickRemaining = plotTickCd
    end

    -- Clear machine rate BBs for plots no longer owned (e.g. after prestige/raid)
    for plotId, part in pairs(machineRateParts) do
        if not (data.ownedPlots and data.ownedPlots[plotId]) then
            pcall(function() part:Destroy() end)
            machineRateParts[plotId] = nil
            machineRates[plotId]     = nil
        end
    end

    local ranking = data._ranking
    if ranking and #ranking > 0 then
        local myRank, aboveName = nil, nil
        for ri, entry in ipairs(ranking) do
            if entry.name == player.Name then
                myRank = ri
                if ri > 1 then aboveName = ranking[ri-1].name end
                break
            end
        end
        if myRank then
            local podium = {Color3.fromRGB(255,215,0), Color3.fromRGB(200,210,220), Color3.fromRGB(200,130,60)}
            rankLbl.Text = "#"..myRank
            rankLbl.TextColor3 = podium[myRank] or Color3.fromRGB(180,180,200)
            rankBadge.BackgroundColor3 = myRank == 1 and Color3.fromRGB(60,45,0) or Color3.fromRGB(25,25,40)
            if prevRank and myRank < prevRank then
                local bumped = ranking[myRank + 1]
                showToast("📈 You overtook "..(bumped and bumped.name or "someone").."!",
                    "You're now #"..myRank.." on the server!", "green")
            end
            if aboveName then
                local above = ranking[myRank - 1]
                if above and above.coins > 0 then
                    local gap = (above.coins - (data.coins or 0)) / above.coins
                    local wasClose = rankBadge:GetAttribute("WasClose") == true
                    if gap < 0.1 and not wasClose then
                        rankBadge:SetAttribute("WasClose", true)
                        showToast("⚡ Closing in on "..aboveName.."!", "Almost #"..(myRank-1).."!", "gold")
                    elseif gap >= 0.15 then
                        rankBadge:SetAttribute("WasClose", false)
                    end
                end
            end
            prevRank = myRank
        end
    end
end)

-- ── Welcome toasts ────────────────────────────────────────
task.delay(2, function()
    showToast("Welcome to Money Island!", "Buy machines to earn coins automatically!", "gold")
    task.delay(3.5, function()
        showToast("⚔️ Weapons & Abilities!", "Equip a weapon. Press Q to Dash, E to Block!", "red")
    end)
    task.delay(7, function()
        showToast("🗡️ Weapon Shop!", "Tap 🗡️ to buy and upgrade 4 different weapons!", "blue")
    end)
    task.delay(10, function()
        showToast("🔧 Machine Upgrades!", "Tap 🔧 to upgrade your machines: Production, Efficiency, or Defense path!", "gold")
    end)
    task.delay(14, function()
        showToast("🌟 Random Events!", "Server-wide events trigger every few minutes — look out for the banner!", "green")
    end)
    task.delay(18, function()
        showToast("🎁 Daily Reward!", "Tap 🎁 on the right to claim it!", "blue")
    end)
end)

print("[MoneyIsland] ✅ ClientUI v3 loaded!")

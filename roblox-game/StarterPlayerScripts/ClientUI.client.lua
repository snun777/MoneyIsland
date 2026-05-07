-- ============================================================
-- MONEY ISLAND TYCOON — ClientUI.lua  (LocalScript)
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
-- To add sounds: Studio Toolbox > Audio tab > search free audio > copy the numeric ID
-- Replace each 0 with a real audio asset ID (must be "Audio" type, not Image/Model)
local SFX = {
    coin      = makeSound(0, 0.4, 1.1),   -- coin collect
    jackpot   = makeSound(0, 0.7, 1.0),   -- jackpot/rare coin
    geyser    = makeSound(0, 0.55, 0.9),  -- geyser activates
    megaBurst = makeSound(0, 0.8, 1.0),   -- mega burst event
    plotBuy   = makeSound(0, 0.6, 0.85),  -- plot purchased
    prestige  = makeSound(0, 0.9, 1.0),   -- prestige/rebirth
}

-- ── state ────────────────────────────────────────────────
local currentData  = nil
local upgradesDef  = nil
local shopOpen     = false
local lastRebirths = -1

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

-- ── RANK BADGE (shows #1 / #2 etc. in HUD) ───────────────
local rankBadge = Instance.new("Frame", hud)
rankBadge.Size = UDim2.new(0, 46, 0, 26); rankBadge.Position = UDim2.new(1,-52,0.5,-13)
rankBadge.BackgroundColor3 = Color3.fromRGB(40,30,0); rankBadge.BorderSizePixel = 0
Instance.new("UICorner", rankBadge).CornerRadius = UDim.new(0,6)
local rankLbl = Instance.new("TextLabel", rankBadge)
rankLbl.Size = UDim2.new(1,0,1,0); rankLbl.BackgroundTransparency = 1
rankLbl.Text = "#-"; rankLbl.TextColor3 = Color3.fromRGB(255,215,0)
rankLbl.Font = Enum.Font.GothamBold; rankLbl.TextSize = 14

-- ── PRESTIGE PROGRESS BAR (thin bar at HUD bottom) ───────
local pBarBg = Instance.new("Frame", hud)
pBarBg.Size = UDim2.new(1,-20,0,4); pBarBg.Position = UDim2.new(0,10,1,-7)
pBarBg.BackgroundColor3 = Color3.fromRGB(25,20,40); pBarBg.BorderSizePixel = 0
Instance.new("UICorner", pBarBg).CornerRadius = UDim.new(1,0)
local pBarFill = Instance.new("Frame", pBarBg)
pBarFill.Size = UDim2.new(0,0,1,0); pBarFill.BackgroundColor3 = Color3.fromRGB(255,100,0)
pBarFill.BorderSizePixel = 0
Instance.new("UICorner", pBarFill).CornerRadius = UDim.new(1,0)

-- ── GEYSER INDICATOR BAR (5 dots below HUD) ──────────────
local GEYSER_COUNT = 5
local geyserBar = Instance.new("Frame", sg)
geyserBar.Size            = UDim2.new(0, 252, 0, 26)
geyserBar.Position        = UDim2.new(0.5, -126, 0, 72)
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

-- Countdown timers (must match MapBuilder GEYSER_ACTIVE / GEYSER_INACTIVE)
local GEYSER_ACTIVE_TIME   = 8
local GEYSER_INACTIVE_TIME = 14
local geyserCountdown = {}   -- [i] = {remaining, isActive}

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
plotBar.Size = UDim2.new(0, 210, 0, 22); plotBar.Position = UDim2.new(0.5, -105, 0, 104)
plotBar.BackgroundColor3 = Color3.fromRGB(8,18,8); plotBar.BorderSizePixel = 0
plotBar.Visible = false
Instance.new("UICorner", plotBar).CornerRadius = UDim.new(0, 8)
local plotTickLbl = Instance.new("TextLabel", plotBar)
plotTickLbl.Size = UDim2.new(1,0,1,0); plotTickLbl.BackgroundTransparency = 1
plotTickLbl.TextColor3 = Color3.fromRGB(100, 220, 120)
plotTickLbl.Font = Enum.Font.GothamBold; plotTickLbl.TextSize = 11
plotTickLbl.Text = "📈 earning..."

local plotTickCd        = 30
local plotTickRemaining = 0
local plotHasPlots      = false

-- ── RAID PROGRESS BAR ────────────────────────────────────────
local raidBar = Instance.new("Frame", sg)
raidBar.Size = UDim2.new(0, 280, 0, 30); raidBar.Position = UDim2.new(0.5, -140, 0, 130)
raidBar.BackgroundColor3 = Color3.fromRGB(35, 5, 5); raidBar.BorderSizePixel = 0
raidBar.Visible = false
Instance.new("UICorner", raidBar).CornerRadius = UDim.new(0, 8)
local raidStroke = Instance.new("UIStroke", raidBar)
raidStroke.Color = Color3.fromRGB(220, 40, 40); raidStroke.Thickness = 1.5

local raidFill = Instance.new("Frame", raidBar)
raidFill.Size = UDim2.new(0, 0, 1, 0); raidFill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
raidFill.BorderSizePixel = 0
Instance.new("UICorner", raidFill).CornerRadius = UDim.new(0, 8)

local raidLbl = Instance.new("TextLabel", raidBar)
raidLbl.Size = UDim2.new(1, 0, 1, 0); raidLbl.BackgroundTransparency = 1
raidLbl.TextColor3 = Color3.fromRGB(255, 190, 190)
raidLbl.Font = Enum.Font.GothamBold; raidLbl.TextSize = 11
raidLbl.Text = "⚔️ Raiding..."

RE_RaidStatus.OnClientEvent:Connect(function(plotId, ownerName, progress)
    if progress < 0 then
        raidBar.Visible = false
    else
        raidBar.Visible = true
        TweenService:Create(raidFill, TweenInfo.new(0.3), {Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)}):Play()
        raidLbl.Text = "⚔️ Raiding " .. ownerName .. "!  " .. math.floor(progress * 100) .. "%"
    end
end)

RE_PlotTick.OnClientEvent:Connect(function(earned, cd)
    plotTickCd        = cd
    plotTickRemaining = cd
    plotBar.Visible   = true
    plotTickLbl.Text  = "📈 +" .. fmt(earned) .. " coins!"
    task.delay(1.2, function()
        if plotTickRemaining > 0 then
            plotTickLbl.Text = "📈 income in " .. math.ceil(plotTickRemaining) .. "s"
        end
    end)
end)

-- ── SIDE BUTTONS ─────────────────────────────────────────
local btnFrame = Instance.new("Frame",sg)
-- 5 buttons × 52px + 4 gaps × 8px = 292px
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
toast.Position=UDim2.new(0.5,-160,1,20)
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
            {Position=UDim2.new(0.5,-160,1,-80)}):Play()
        task.delay(2.6,function()
            TweenService:Create(toast,TweenInfo.new(0.25),
                {Position=UDim2.new(0.5,-160,1,20)}):Play()
            task.delay(0.3,pop)
        end)
    end
    pop()
end

RE_NotifyPlayer.OnClientEvent:Connect(function(title,body,col)
    showToast(title,body,col)
    -- Play sounds based on notification type
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
    end
end)

-- ============================================================
-- HUD UPDATE
-- ============================================================
local function fmt(n)
    if n>=1e9 then return string.format("%.1fB",n/1e9)
    elseif n>=1e6 then return string.format("%.1fM",n/1e6)
    elseif n>=1e3 then return string.format("%.1fK",n/1e3)
    else return tostring(math.floor(n)) end
end

-- ── PRESTIGE THEMES (client-side lighting + HUD tint) ────────
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

local PRESTIGE_BASE_COST = 10000
local function updateHUD(data)
    coinLbl.Text    = "💰 "..fmt(data.coins or 0)
    rebirthLbl.Text = "🔥 x"..(data.rebirths or 0)
    applyPrestigeTheme(data.rebirths or 0)
    -- Prestige progress bar (cost = 10000 × 3^rebirths, matches server)
    local cost = PRESTIGE_BASE_COST * (3 ^ (data.rebirths or 0))
    local pct  = math.min(1, (data.coins or 0) / cost)
    TweenService:Create(pBarFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        {Size = UDim2.new(pct, 0, 1, 0)}):Play()
    pBarFill.BackgroundColor3 = pct >= 1
        and Color3.fromRGB(255, 215, 0)   -- gold = ready to prestige
        or  Color3.fromRGB(255, 100, 0)   -- orange = in progress
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

        -- current effect value (includes gamepass bonuses where relevant)
        local effectText
        if upg.key=="touchSpeed" then
            effectText = "Now: "..(math.max(1,30-level)).."s recharge"
        elseif upg.key=="coinMagnet" then
            if not gp.megaMagnet then
                effectText = "🔒 Requires Mega Magnet gamepass"
            else
                local range = (5 + level * 3) + 15
                effectText  = "Range: "..range.." studs (+15 from pass)"
            end
        elseif upg.key=="coinValue" then
            local mult = 1 + level*0.5
            if gp.doubleCoin then mult = mult * 2 end
            effectText = string.format("Value: %.1fx", mult)..(gp.doubleCoin and " (×2 pass)" or "")
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
local DAILY_REWARDS_CLIENT = {100, 200, 350, 500, 750, 1000, 2500}

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

    -- Reward strip
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

    local gp       = (currentData and currentData._gp) or {}
    local rebirths = (currentData and currentData.rebirths) or 0
    local cost     = math.floor(10000*(3^rebirths))
    local coins    = (currentData and currentData.coins) or 0
    local canDo    = coins >= cost
    local multStr  = gp.prestigeBoost and "3x" or "2x"

    local curPow  = math.floor((gp.prestigeBoost and 3 or 2) ^ rebirths)
    local nextPow = math.floor((gp.prestigeBoost and 3 or 2) ^ (rebirths + 1))

    local panel=Instance.new("Frame",sg); panel.Name="PrestigePanel"
    panel.Size=UDim2.new(0,340,0,200); panel.Position=UDim2.new(0.5,-170,0.5,-100)
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

    local info=Instance.new("TextLabel",panel); info.Size=UDim2.new(1,-20,0,82)
    info.Position=UDim2.new(0,10,0,48); info.BackgroundTransparency=1
    info.Text="Resets coins & upgrades — keeps prestige level.\n"
        .."Each prestige gives a permanent "..multStr.." income multiplier.\n\n"
        .."Power now:  ×"..curPow.."  →  After prestige:  ×"..nextPow.."\n"
        .."Cost: 💰 "..fmt(cost).."    You have: 💰 "..fmt(coins)
    info.TextColor3=Color3.fromRGB(180,180,200); info.Font=Enum.Font.Gotham; info.TextSize=13
    info.TextWrapped=true; info.TextXAlignment=Enum.TextXAlignment.Left

    local btn=Instance.new("TextButton",panel); btn.Size=UDim2.new(1,-20,0,44)
    btn.Position=UDim2.new(0,10,0,142)
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
                btn.Text = "⚠️ Confirm? Plots reset! (click again)"
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
            end
        end)
    end
end

-- ── ROBUX SHOP ───────────────────────────────────────────
local PRODUCTS={
    {id=3586040050,label="💰 500 Coins",    price="R$50"},
    {id=3586040263,label="💰 2,500 Coins",  price="R$199"},
    {id=3586040422,label="💰 10,000 Coins", price="R$699"},
}
local PASSES={
    {id=1821720069, gpKey="doubleCoin",    label="💰 2x Coins — all coins doubled",       price="R$499"},
    {id=1822515059, gpKey="megaMagnet",    label="🧲 Mega Magnet — enables coin magnet!",  price="R$349"},
    {id=1821659972, gpKey="luckyCharm",    label="🍀 Lucky Charm — 2x jackpot chance",    price="R$199"},
    {id=1822655551, gpKey="speedDemon",    label="⚡ Speed Demon — +20% walk speed",      price="R$199"},
    {id=1822649609, gpKey="prestigeBoost", label="🏆 Prestige Boost — 3x per prestige",   price="R$349"},
    {id=1823064828, gpKey="autoFarm",      label="🤖 Auto Farm — auto-collect every 45s", price="R$699"},
}

local function openRobuxShop()
    local old2=sg:FindFirstChild("RobuxShop")
    if old2 then old2:Destroy() return end

    local ownedGP = (currentData and currentData._gp) or {}

    local panel=Instance.new("Frame",sg); panel.Name="RobuxShop"
    panel.BackgroundColor3=Color3.fromRGB(8,8,22); panel.BorderSizePixel=0
    Instance.new("UICorner",panel).CornerRadius=UDim.new(0,14)
    local rs=Instance.new("UIStroke",panel); rs.Color=Color3.fromRGB(55,140,255); rs.Thickness=2

    local y=56
    local function row(lbl, price, cb, bgCol, priceCol)
        local r=Instance.new("TextButton",panel); r.Size=UDim2.new(1,-20,0,50)
        r.Position=UDim2.new(0,10,0,y); r.BackgroundColor3=bgCol; r.Text=""; r.BorderSizePixel=0
        Instance.new("UICorner",r).CornerRadius=UDim.new(0,10)
        local l=Instance.new("TextLabel",r); l.Size=UDim2.new(0.65,0,1,0)
        l.Position=UDim2.new(0,10,0,0); l.BackgroundTransparency=1; l.Text=lbl
        l.TextColor3=Color3.new(1,1,1); l.Font=Enum.Font.GothamBold; l.TextSize=13
        l.TextXAlignment=Enum.TextXAlignment.Left; l.TextWrapped=false
        local p=Instance.new("TextLabel",r); p.Size=UDim2.new(0.32,0,1,0)
        p.Position=UDim2.new(0.67,0,0,0); p.BackgroundTransparency=1; p.Text=price
        p.TextColor3=priceCol or Color3.fromRGB(255,215,0)
        p.Font=Enum.Font.GothamBold; p.TextSize=15
        p.TextXAlignment=Enum.TextXAlignment.Right
        r.MouseButton1Click:Connect(cb); y=y+58
    end

    local function sec(text)
        local s=Instance.new("TextLabel",panel); s.Size=UDim2.new(1,-20,0,22)
        s.Position=UDim2.new(0,10,0,y); s.BackgroundTransparency=1; s.Text=text
        s.TextColor3=Color3.fromRGB(150,150,170); s.Font=Enum.Font.GothamBold; s.TextSize=12
        s.TextXAlignment=Enum.TextXAlignment.Left; y=y+26
    end

    sec("COIN PACKS")
    for _,p in ipairs(PRODUCTS) do
        local pid=p.id
        row(p.label, p.price,
            function() MarketplaceService:PromptProductPurchase(player,pid) end,
            Color3.fromRGB(16,48,16), nil)
    end

    sec("BOOSTS (permanent)")
    for _,gp in ipairs(PASSES) do
        local gpid   = gp.id
        local owned  = ownedGP[gp.gpKey] == true
        local bgCol  = owned and Color3.fromRGB(10,38,10) or Color3.fromRGB(16,16,52)
        local priceCol = owned and Color3.fromRGB(0,210,90) or Color3.fromRGB(255,215,0)
        local priceStr = owned and "✓ OWNED" or gp.price
        local cb = owned
            and function() end
            or  function() MarketplaceService:PromptGamePassPurchase(player,gpid) end
        row(gp.label, priceStr, cb, bgCol, priceCol)
    end

    panel.Size=UDim2.new(0,400,0,y+12); panel.Position=UDim2.new(0.5,-200,0.5,-(y+12)/2)

    local cl=Instance.new("TextButton",panel); cl.Size=UDim2.new(0,32,0,32)
    cl.Position=UDim2.new(1,-40,0,8); cl.BackgroundColor3=Color3.fromRGB(160,25,25)
    cl.Text="✕"; cl.TextColor3=Color3.new(1,1,1); cl.Font=Enum.Font.GothamBold; cl.TextSize=15
    Instance.new("UICorner",cl).CornerRadius=UDim.new(0,8)
    cl.MouseButton1Click:Connect(function() panel:Destroy() end)

    local t2=Instance.new("TextLabel",panel); t2.Size=UDim2.new(1,-50,0,44)
    t2.Position=UDim2.new(0,12,0,4); t2.BackgroundTransparency=1
    t2.Text="💎 ROBUX SHOP"; t2.TextColor3=Color3.fromRGB(90,170,255)
    t2.Font=Enum.Font.GothamBold; t2.TextSize=22; t2.TextXAlignment=Enum.TextXAlignment.Left
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

    -- Compute stats
    local plotCount = 0
    for _ in pairs(data.ownedPlots or {}) do plotCount = plotCount + 1 end

    local secs = data.playTime or 0
    local timeStr = (math.floor(secs/3600)).."h "..(math.floor((secs%3600)/60)).."m"

    local cvLvl = (data.upgrades and data.upgrades.coinValue) or 0
    local streak = data.prestigeStreak or 0
    local mult  = (1 + cvLvl*0.5)
                  * (gp.doubleCoin and 2 or 1)
                  * ((gp.prestigeBoost and 3 or 2) ^ (data.rebirths or 0))
                  * (1 + 0.1 * math.min(streak, 5))
    local coinVal = math.floor(5 * mult)
    local cd  = math.max(1, 30 - ((data.upgrades and data.upgrades.touchSpeed) or 0))
    if gp.autoFarm then cd = math.max(1, math.floor(cd/2)) end
    -- Plot income: each owned plot ticks every cd seconds
    local plotIncome = plotCount > 0 and math.floor(plotCount * coinVal * (60/cd)) or 0

    local stats = {
        {"💰 Total Earned",      fmt(data.totalEarned or 0)},
        {"🔥 Prestige Level",    tostring(data.rebirths or 0)},
        {"🔁 Prestige Streak",   streak > 0 and ("×"..streak.." (+"..(streak*10).."%%)") or "None"},
        {"🌾 Plots Owned",       plotCount .. " / 20"},
        {"⏱  Play Time",        timeStr},
        {"📈 Plot Income/min",   plotCount>0 and "~"..fmt(plotIncome) or "Buy plots!"},
        {"💎 Coin Value",        fmt(coinVal).." ea"},
    }
    if gp.autoFarm then table.insert(stats, {"🤖 Auto Farm", "2× plot speed"}) end

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

    -- Live server ranking
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
makeBtn("🛒", Color3.fromRGB(25,110,50),  openShop)
makeBtn("🎁", Color3.fromRGB(120,40,140), openDaily)
makeBtn("🔥", Color3.fromRGB(160,55,0),   openPrestige)
makeBtn("💎", Color3.fromRGB(18,75,170),  openRobuxShop)
makeBtn("📊", Color3.fromRGB(0,90,160),   openStats)

-- ── ShowShop remote → opens upgrade shop ─────────────────
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
    -- Plot countdown bar
    local plotCount = 0
    if data.ownedPlots then
        for _, v in pairs(data.ownedPlots) do if v then plotCount += 1 end end
    end
    plotHasPlots = plotCount > 0
    plotBar.Visible = plotHasPlots
    if plotHasPlots and plotTickRemaining <= 0 then
        local tsLvl = (data.upgrades and data.upgrades.touchSpeed) or 0
        plotTickCd        = math.max(1, 30 - tsLvl)
        plotTickRemaining = plotTickCd
    end
    -- Rank badge + overtake notification
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
            -- "You overtook X!" when rank improves
            if prevRank and myRank < prevRank then
                local bumped = ranking[myRank + 1]
                showToast("📈 You overtook "..(bumped and bumped.name or "someone").."!",
                    "You're now #"..myRank.." on the server!", "green")
            end
            -- "Closing in" warning — within 10% of the leader above you
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

-- ── Welcome toast (fires once on join) ───────────────────
task.delay(2, function()
    showToast("Welcome to Money Island!", "Grab geyser coins — no cap, collect as many as you can!", "gold")
    task.delay(3.5, function()
        showToast("⚔️ Any plot is buyable!", "Walk up to any machine and click to buy it.", "green")
    end)
    task.delay(7, function()
        showToast("🦹 PVP is live!", "Raid enemies' machines by standing on them. Defend yours!", "red")
    end)
    task.delay(11, function()
        showToast("💸 Hot zone danger!", "Carrying coins in the geyser zone? Other players can pickpocket you!", "blue")
    end)
    task.delay(15, function()
        showToast("🎁 Daily Reward!", "Tap 🎁 on the right to claim it!", "blue")
    end)
end)

print("[MoneyIsland] ✅ ClientUI loaded!")

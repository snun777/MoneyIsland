-- GunTycoon ClientUI v2
-- Redesigned HUD: centered coin widget, populated arsenal shop, clean layout

local Players            = game:GetService("Players")
local RS                 = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local function waitRemote(name)
    return RS:WaitForChild(name, 30)
end

local RE = {
    UpdateStats        = waitRemote("UpdateStats"),
    Notify             = waitRemote("Notify"),
    PlayerHit          = waitRemote("PlayerHit"),
    PlayerKilled       = waitRemote("PlayerKilled"),
    KillFeed           = waitRemote("KillFeed"),
    RandomEvent        = waitRemote("RandomEvent"),
    IncomeUpdate       = waitRemote("IncomeUpdate"),
    WeaponEquipped     = waitRemote("WeaponEquipped"),
    VIPPrompt          = waitRemote("VIPPrompt"),
    WeaponFire         = waitRemote("WeaponFire"),
    DropperPing        = waitRemote("DropperPing"),
    EquipWeaponRequest = waitRemote("EquipWeaponRequest"),
}

-- ============================================================
-- Inline config
-- ============================================================

local WEAPONS = {
    [1]={
        {id=1011, name="Pistol",           damage=12,  range=65,  cooldown=0.75, cost=600    },
        {id=1012, name="Revolver",         damage=22,  range=75,  cooldown=1.2,  cost=2500   },
        {id=1013, name="Shotgun",          damage=36,  range=30,  cooldown=1.6,  cost=5000   },
    },
    [2]={
        {id=1021, name="SMG",              damage=18,  range=85,  cooldown=0.35, cost=15000  },
        {id=1022, name="Assault Rifle",    damage=32,  range=110, cooldown=0.55, cost=35000  },
        {id=1023, name="Combat Shotgun",   damage=48,  range=40,  cooldown=1.0,  cost=75000  },
    },
    [3]={
        {id=1031, name="Sniper Rifle",     damage=110, range=250, cooldown=2.2,  cost=250000 },
        {id=1032, name="LMG",              damage=42,  range=130, cooldown=0.22, cost=600000 },
        {id=1033, name="Grenade Launcher", damage=90,  range=90,  cooldown=2.8,  cost=1200000},
    },
    [4]={
        {id=1041, name="Minigun",          damage=38,  range=110, cooldown=0.12, cost=5000000 },
        {id=1042, name="Rocket Launcher",  damage=180, range=160, cooldown=3.5,  cost=14000000},
        {id=1043, name="Railgun",          damage=320, range=350, cooldown=4.5,  cost=30000000},
    },
}

local FLOOR_NAMES  = {"Armory", "Barracks", "War Room", "Black Ops"}
local FLOOR_COSTS  = {[1]=0, [2]=5000, [3]=120000, [4]=2500000}
local FLOOR_COLORS = {
    Color3.fromRGB(255,210,60),
    Color3.fromRGB(80,160,255),
    Color3.fromRGB(255,100,50),
    Color3.fromRGB(180,60,255),
}
local FACTIONS = {
    {name="Red Militia",       primary=Color3.fromRGB(195,40,40),   accent=Color3.fromRGB(255,90,90)  },
    {name="Blue Spec Ops",     primary=Color3.fromRGB(35,75,195),   accent=Color3.fromRGB(75,130,255) },
    {name="Green Rangers",     primary=Color3.fromRGB(45,155,55),   accent=Color3.fromRGB(90,215,105) },
    {name="Gold Mercs",        primary=Color3.fromRGB(195,160,18),  accent=Color3.fromRGB(255,210,50) },
    {name="Purple Shadow Ops", primary=Color3.fromRGB(115,35,175),  accent=Color3.fromRGB(175,85,255) },
    {name="Orange Frontline",  primary=Color3.fromRGB(205,95,25),   accent=Color3.fromRGB(255,145,55) },
    {name="Cyan Navy SEALs",   primary=Color3.fromRGB(28,165,185),  accent=Color3.fromRGB(65,215,235) },
    {name="White Ghost Div",   primary=Color3.fromRGB(200,200,210), accent=Color3.fromRGB(235,235,245)},
}
local COIN_PACKS = {
    {id=3586040050, name="Small Pack",  label="10,000 coins — 99 R$" },
    {id=3586040263, name="Medium Pack", label="80,000 coins — 299 R$"},
    {id=3586040422, name="Large Pack",  label="300,000 coins — 699 R$"},
}
local PRESTIGE_COSTS = {6000000,30000000,120000000,500000000,2000000000}
local MAX_HP         = 150
local VIP_PASS_ID    = 1821720069

local T = {
    bg       = Color3.fromRGB(10, 10, 16),
    panel    = Color3.fromRGB(18, 18, 26),
    panelAlt = Color3.fromRGB(26, 26, 36),
    accent   = Color3.fromRGB(255,200,50),
    text     = Color3.fromRGB(235,235,240),
    textDim  = Color3.fromRGB(150,150,165),
    btnBuy   = Color3.fromRGB(40, 165, 70),
    btnOwned = Color3.fromRGB(45, 110, 200),
    btnLocked= Color3.fromRGB(60, 60, 78),
    danger   = Color3.fromRGB(215,50,50),
    vip      = Color3.fromRGB(255,215,0),
}

-- ============================================================
-- UI helpers
-- ============================================================

local function tween(obj, props, t, style, dir)
    TweenService:Create(obj, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
end

local function corner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 10)
    return c
end

local function stroke(p, col, thick)
    local s = Instance.new("UIStroke", p)
    s.Color = col or Color3.fromRGB(60,60,80)
    s.Thickness = thick or 1.5
    return s
end

local function makeFrame(parent, name, size, pos, bg, bgTrans)
    local f = Instance.new("Frame", parent)
    f.Name = name; f.Size = size; f.Position = pos
    f.BackgroundColor3 = bg or T.panel
    f.BackgroundTransparency = bgTrans or 0
    f.BorderSizePixel = 0
    return f
end

local function makeLabel(parent, text, size, pos, col, font, scaled)
    local l = Instance.new("TextLabel", parent)
    l.Size = size; l.Position = pos; l.Text = text
    l.TextColor3 = col or T.text
    l.Font = font or Enum.Font.GothamBold
    l.BackgroundTransparency = 1
    l.TextScaled = scaled ~= false
    l.BorderSizePixel = 0
    return l
end

local function makeButton(parent, text, size, pos, bg, textCol)
    local b = Instance.new("TextButton", parent)
    b.Size = size; b.Position = pos; b.Text = text
    b.BackgroundColor3 = bg or T.btnBuy
    b.TextColor3 = textCol or T.text
    b.Font = Enum.Font.GothamBold
    b.TextScaled = true
    b.BorderSizePixel = 0
    corner(b, 8)
    local baseBg = bg or T.btnBuy
    b.MouseEnter:Connect(function() tween(b, {BackgroundColor3=baseBg:Lerp(Color3.new(1,1,1),0.18)}, 0.1) end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundColor3=baseBg}, 0.15) end)
    return b
end

local function formatCoins(n)
    if n >= 1e9 then return string.format("%.2fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

-- ============================================================
-- ScreenGui
-- ============================================================

local screen = Instance.new("ScreenGui", gui)
screen.Name           = "GunTycoonUI"
screen.ResetOnSpawn   = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.IgnoreGuiInset = false  -- Roblox handles top safe area; y=0 is below chrome

-- ============================================================
-- Coin widget (top center floating pill)
-- ============================================================

local coinWidget = makeFrame(screen, "CoinWidget", UDim2.new(0,340,0,54), UDim2.new(0.5,-170,0,6), T.panel)
corner(coinWidget, 14)
stroke(coinWidget, Color3.fromRGB(80,62,18), 2)

-- Left accent bar
local coinStrip = makeFrame(coinWidget, "Strip", UDim2.new(0,4,1,-10), UDim2.new(0,4,0,5), T.accent)
corner(coinStrip, 3)

local coinAmountLabel = makeLabel(coinWidget, "$0", UDim2.new(1,-100,0,28), UDim2.new(0,16,0,5), T.accent, Enum.Font.GothamBold)
coinAmountLabel.Name = "CoinAmountLabel"
coinAmountLabel.TextXAlignment = Enum.TextXAlignment.Left

local coinIncomeLabel = makeLabel(coinWidget, "+0/s", UDim2.new(1,-100,0,18), UDim2.new(0,16,0,32), T.textDim, Enum.Font.Gotham)
coinIncomeLabel.Name = "CoinIncomeLabel"
coinIncomeLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Floor progress dots (4, right side of widget)
local dotsHolder = makeFrame(coinWidget, "Dots", UDim2.new(0,74,1,-14), UDim2.new(1,-80,0,7), T.bg, 0)
local floorDots = {}
for i = 1, 4 do
    local dot = makeFrame(dotsHolder, "D"..i, UDim2.new(0,14,0,14), UDim2.new(0,(i-1)*18,0.5,-7), T.btnLocked)
    corner(dot, 4)
    floorDots[i] = dot
end

-- ============================================================
-- Left panel (prestige badge + faction badge)
-- ============================================================

local leftPanel = makeFrame(screen, "LeftPanel", UDim2.new(0,180,0,54), UDim2.new(0,6,0,6), T.panel)
corner(leftPanel, 12)
stroke(leftPanel, Color3.fromRGB(50,50,70), 1.5)

local prestigeBadge = makeFrame(leftPanel, "PrestigeBadge", UDim2.new(0,70,1,-10), UDim2.new(0,5,0,5), Color3.fromRGB(65,42,120))
corner(prestigeBadge, 8)
local prestigeLabel = makeLabel(prestigeBadge, "P0", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(185,145,255), Enum.Font.GothamBold)
prestigeLabel.Name = "PrestigeLabel"

local factionBadge = makeFrame(leftPanel, "FactionBadge", UDim2.new(0,100,1,-10), UDim2.new(0,78,0,5), T.panelAlt)
corner(factionBadge, 8)
local factionBadgeStroke = stroke(factionBadge, T.accent, 1.5)
local factionLabel = makeLabel(factionBadge, "---", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), T.textDim, Enum.Font.GothamBold)
factionLabel.Name = "FactionLabel"

-- ============================================================
-- Right panel (HP + weapon info)
-- ============================================================

local rightPanel = makeFrame(screen, "RightPanel", UDim2.new(0,204,0,172), UDim2.new(1,-210,0,6), T.panel)
corner(rightPanel, 12)
stroke(rightPanel, Color3.fromRGB(50,50,70), 1.5)

-- HP
makeLabel(rightPanel, "HP", UDim2.new(0,24,0,16), UDim2.new(0,6,0,7), T.textDim, Enum.Font.Gotham)
local hpBg = makeFrame(rightPanel, "HPBg", UDim2.new(1,-40,0,16), UDim2.new(0,34,0,8), Color3.fromRGB(28,10,10))
corner(hpBg, 5)
local hpBar = makeFrame(hpBg, "HPBar", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(200,44,44))
corner(hpBar, 5); hpBar.Name = "HPBar"
local hpNumLabel = makeLabel(hpBg, "150/150", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.new(1,1,1), Enum.Font.GothamBold)

makeFrame(rightPanel, "Div1", UDim2.new(1,-12,0,1), UDim2.new(0,6,0,31), Color3.fromRGB(42,42,58))

-- Weapon
local equippedLabel = makeLabel(rightPanel, "Pistol", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,37), T.text, Enum.Font.GothamBold)
equippedLabel.Name = "EquippedLabel"
equippedLabel.TextXAlignment = Enum.TextXAlignment.Left

local weaponStatLabel = makeLabel(rightPanel, "DMG 12 | RNG 65", UDim2.new(1,-8,0,16), UDim2.new(0,4,0,59), T.textDim, Enum.Font.Gotham)
weaponStatLabel.Name = "WeaponStatLabel"
weaponStatLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Cooldown bar
makeLabel(rightPanel, "COOLDOWN", UDim2.new(1,-8,0,12), UDim2.new(0,4,0,80), T.textDim, Enum.Font.Gotham)
local cdBg = makeFrame(rightPanel, "CDBg", UDim2.new(1,-8,0,14), UDim2.new(0,4,0,94), Color3.fromRGB(20,20,32))
corner(cdBg, 5)
local cdBar = makeFrame(cdBg, "CDBar", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(65,145,255))
cdBar.Name = "CooldownBar"; corner(cdBar, 5)

-- Killstreak
local killstreakLabel = makeLabel(rightPanel, "", UDim2.new(1,-8,0,18), UDim2.new(0,4,0,114), T.danger, Enum.Font.GothamBold)
killstreakLabel.Name = "KillstreakLabel"

makeFrame(rightPanel, "Div2", UDim2.new(1,-12,0,1), UDim2.new(0,6,0,137), Color3.fromRGB(42,42,58))

local floorStatusLabel = makeLabel(rightPanel, "Floor 1 — Armory", UDim2.new(1,-8,0,26), UDim2.new(0,4,0,142), FLOOR_COLORS[1], Enum.Font.GothamBold)
floorStatusLabel.Name = "FloorStatusLabel"
floorStatusLabel.TextXAlignment = Enum.TextXAlignment.Left

-- ============================================================
-- Kill feed (below right panel)
-- ============================================================

local killFeedFrame = makeFrame(screen, "KillFeed", UDim2.new(0,284,0,180), UDim2.new(1,-290,0,184), T.bg, 1)
local killFeedLayout = Instance.new("UIListLayout", killFeedFrame)
killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
killFeedLayout.Padding = UDim.new(0,3)

local function addKillFeedEntry(text, color)
    local entry = Instance.new("TextLabel", killFeedFrame)
    entry.Size = UDim2.new(1,0,0,24)
    entry.BackgroundColor3 = Color3.fromRGB(8,8,14)
    entry.BackgroundTransparency = 0.22
    entry.TextColor3 = color or T.danger
    entry.Font = Enum.Font.GothamBold
    entry.Text = text
    entry.TextScaled = true
    entry.BorderSizePixel = 0
    corner(entry, 5)
    task.delay(6, function()
        tween(entry, {BackgroundTransparency=1, TextTransparency=1}, 0.5)
        task.wait(0.55); entry:Destroy()
    end)
end

-- ============================================================
-- Event banner (below coin widget, slides in)
-- ============================================================

local eventBanner = makeFrame(screen, "EventBanner", UDim2.new(0,400,0,40), UDim2.new(0.5,-200,-0.12,0), Color3.fromRGB(28,20,4))
corner(eventBanner, 12)
stroke(eventBanner, T.accent, 2)
local eventLabel = makeLabel(eventBanner, "", UDim2.new(1,-12,1,0), UDim2.new(0,6,0,0), T.accent, Enum.Font.GothamBold)
eventLabel.Name = "EventLabel"

-- ============================================================
-- Bottom action bar (above backpack)
-- ============================================================

local bottomBar = makeFrame(screen, "BottomBar", UDim2.new(0,388,0,48), UDim2.new(0.5,-194,1,-104), Color3.fromRGB(12,12,18))
corner(bottomBar, 14)
stroke(bottomBar, Color3.fromRGB(50,50,70), 1.5)

local prestigeBtn = makeButton(bottomBar, "PRESTIGE", UDim2.new(0,122,0,36), UDim2.new(0,6,0,6), Color3.fromRGB(85,48,165))
prestigeBtn.Name = "PrestigeBtn"

local shopBtn = makeButton(bottomBar, "ARSENAL", UDim2.new(0,118,0,36), UDim2.new(0,134,0,6), Color3.fromRGB(28,110,195))
shopBtn.Name = "ShopBtn"

local coinsBtn = makeButton(bottomBar, "COIN PACKS", UDim2.new(0,120,0,36), UDim2.new(0,258,0,6), Color3.fromRGB(170,122,16))

-- ============================================================
-- Arsenal shop panel (slides up from bottom)
-- ============================================================

local shopPanel = makeFrame(screen, "ShopPanel", UDim2.new(0,450,0,560), UDim2.new(0.5,-225,1,10), T.bg)
corner(shopPanel, 16)
stroke(shopPanel, Color3.fromRGB(30,90,175), 2)
shopPanel.ZIndex = 10

-- Header
local shopHeaderBg = makeFrame(shopPanel, "ShopHdr", UDim2.new(1,0,0,50), UDim2.new(0,0,0,0), Color3.fromRGB(14,14,22))
shopHeaderBg.ZIndex = 11
corner(shopHeaderBg, 16)
-- flatten bottom corners
makeFrame(shopHeaderBg, "Fix", UDim2.new(1,0,0,18), UDim2.new(0,0,1,-18), Color3.fromRGB(14,14,22)).ZIndex = 11
makeLabel(shopHeaderBg, "ARSENAL", UDim2.new(1,-52,1,0), UDim2.new(0,12,0,0), Color3.fromRGB(75,155,255), Enum.Font.GothamBold).ZIndex = 12

local closeShop = makeButton(shopPanel, "✕", UDim2.new(0,34,0,34), UDim2.new(1,-40,0,8), T.danger)
closeShop.ZIndex = 12; corner(closeShop, 8)

local shopScroll = Instance.new("ScrollingFrame", shopPanel)
shopScroll.Name = "ShopScroll"
shopScroll.Size = UDim2.new(1,-10,1,-56)
shopScroll.Position = UDim2.new(0,5,0,52)
shopScroll.BackgroundTransparency = 1
shopScroll.ScrollBarThickness = 4
shopScroll.ZIndex = 11
shopScroll.CanvasSize = UDim2.new(1,0,0,0)
shopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local shopLayout = Instance.new("UIListLayout", shopScroll)
shopLayout.Padding = UDim.new(0,5)
local shopPad = Instance.new("UIPadding", shopScroll)
shopPad.PaddingLeft = UDim.new(0,3)
shopPad.PaddingRight = UDim.new(0,3)

local shopOpen = false
local function toggleShop()
    shopOpen = not shopOpen
    if shopOpen then
        shopScroll.CanvasPosition = Vector2.new(0,0)
    end
    tween(shopPanel, {Position = shopOpen and UDim2.new(0.5,-225,1,-570) or UDim2.new(0.5,-225,1,10)},
        0.3, Enum.EasingStyle.Back, shopOpen and Enum.EasingDirection.Out or Enum.EasingDirection.In)
end
shopBtn.MouseButton1Click:Connect(toggleShop)
closeShop.MouseButton1Click:Connect(toggleShop)

-- ============================================================
-- Coin packs panel
-- ============================================================

local packsPanel = makeFrame(screen, "PacksPanel", UDim2.new(0,340,0,300), UDim2.new(0.5,-170,1,10), T.bg)
corner(packsPanel, 16)
stroke(packsPanel, Color3.fromRGB(180,138,16), 2)
packsPanel.ZIndex = 10

makeLabel(packsPanel, "COIN PACKS", UDim2.new(1,-50,0,38), UDim2.new(0,8,0,6), T.vip, Enum.Font.GothamBold).ZIndex = 11
local closePacksBtn = makeButton(packsPanel, "✕", UDim2.new(0,34,0,34), UDim2.new(1,-40,0,8), T.danger)
closePacksBtn.ZIndex = 11

for i, pack in ipairs(COIN_PACKS) do
    local pb = makeButton(packsPanel, pack.name.."\n"..pack.label, UDim2.new(1,-16,0,62), UDim2.new(0,8,0,48+(i-1)*72), Color3.fromRGB(140,105,14))
    pb.ZIndex = 11
    local packId = pack.id
    pb.MouseButton1Click:Connect(function()
        MarketplaceService:PromptProductPurchase(player, packId)
    end)
end

local packsOpen = false
local function togglePacks()
    packsOpen = not packsOpen
    tween(packsPanel, {Position = packsOpen and UDim2.new(0.5,-170,1,-310) or UDim2.new(0.5,-170,1,10)},
        0.3, Enum.EasingStyle.Back, packsOpen and Enum.EasingDirection.Out or Enum.EasingDirection.In)
end
coinsBtn.MouseButton1Click:Connect(togglePacks)
closePacksBtn.MouseButton1Click:Connect(togglePacks)

-- ============================================================
-- Prestige panel
-- ============================================================

local prestPanel = makeFrame(screen, "PrestigePanel", UDim2.new(0,380,0,215), UDim2.new(0.5,-190,0.5,-107), T.bg)
prestPanel.Visible = false
corner(prestPanel, 16)
stroke(prestPanel, Color3.fromRGB(145,65,255), 2.5)
prestPanel.ZIndex = 20

makeLabel(prestPanel, "PRESTIGE", UDim2.new(1,0,0,40), UDim2.new(0,0,0,6), Color3.fromRGB(190,145,255), Enum.Font.GothamBold).ZIndex = 21
local prestDesc = makeLabel(prestPanel, "Reset tycoon for a permanent income boost.\nAll droppers and floor unlocks will reset.", UDim2.new(1,-16,0,46), UDim2.new(0,8,0,48), T.textDim, Enum.Font.Gotham)
prestDesc.ZIndex = 21
local prestCostLabel = makeLabel(prestPanel, "Cost: calculating...", UDim2.new(1,-16,0,26), UDim2.new(0,8,0,102), T.accent, Enum.Font.GothamBold)
prestCostLabel.Name = "PrestCostLabel"; prestCostLabel.ZIndex = 21
local confirmBtn     = makeButton(prestPanel, "PRESTIGE NOW", UDim2.new(0,168,0,40), UDim2.new(0,8,0,152), Color3.fromRGB(88,42,178))
confirmBtn.ZIndex = 21
local cancelPrestBtn = makeButton(prestPanel, "Cancel", UDim2.new(0,132,0,40), UDim2.new(1,-140,0,152), Color3.fromRGB(50,50,65))
cancelPrestBtn.ZIndex = 21

cancelPrestBtn.MouseButton1Click:Connect(function() prestPanel.Visible = false end)
prestigeBtn.MouseButton1Click:Connect(function() prestPanel.Visible = true end)

-- ============================================================
-- Death screen
-- ============================================================

local deathScreen = makeFrame(screen, "DeathScreen", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(155,14,14), 0.55)
deathScreen.Visible = false
deathScreen.ZIndex = 50
makeLabel(deathScreen, "ELIMINATED", UDim2.new(0,440,0,80), UDim2.new(0.5,-220,0.38,-40), Color3.new(1,1,1), Enum.Font.GothamBold).ZIndex = 51
local deathSubLabel = makeLabel(deathScreen, "", UDim2.new(0,440,0,36), UDim2.new(0.5,-220,0.38,50), Color3.fromRGB(255,190,190), Enum.Font.Gotham)
deathSubLabel.ZIndex = 51

-- ============================================================
-- VIP popup
-- ============================================================

local vipPopup = makeFrame(screen, "VIPPopup", UDim2.new(0,380,0,228), UDim2.new(0.5,-190,0.5,-114), Color3.fromRGB(32,22,4))
vipPopup.Visible = false
corner(vipPopup, 16)
stroke(vipPopup, Color3.fromRGB(255,215,0), 2.5)
vipPopup.ZIndex = 40

makeLabel(vipPopup, "VIP — 499 Robux", UDim2.new(1,-8,0,44), UDim2.new(0,4,0,6), T.vip, Enum.Font.GothamBold).ZIndex = 41
makeLabel(vipPopup, "2x all income\nExclusive VIP lounge access\nGolden crown cosmetic\nVIP badge in leaderboard", UDim2.new(1,-16,0,100), UDim2.new(0,8,0,54), T.textDim, Enum.Font.Gotham).ZIndex = 41
local buyVIPBtn   = makeButton(vipPopup, "BUY VIP (499 R)", UDim2.new(0,200,0,42), UDim2.new(0,8,0,168), Color3.fromRGB(185,140,14))
buyVIPBtn.ZIndex = 41
local closeVIPBtn = makeButton(vipPopup, "No thanks", UDim2.new(0,120,0,42), UDim2.new(1,-130,0,168), Color3.fromRGB(44,44,60))
closeVIPBtn.ZIndex = 41

buyVIPBtn.MouseButton1Click:Connect(function()
    MarketplaceService:PromptGamePassPurchase(player, VIP_PASS_ID)
    vipPopup.Visible = false
end)
closeVIPBtn.MouseButton1Click:Connect(function() vipPopup.Visible = false end)

-- ============================================================
-- Toast notification system
-- ============================================================

local toastQueue  = {}
local toastActive = false

local function showToast(msg, color, duration)
    table.insert(toastQueue, {msg=msg, color=color or T.accent, dur=duration or 3})
    if toastActive then return end
    toastActive = true
    task.spawn(function()
        while #toastQueue > 0 do
            local t = table.remove(toastQueue, 1)
            -- Slide in from below, above the bottom action bar (which sits at 1,-104)
            local toast = makeFrame(screen, "Toast", UDim2.new(0,440,0,52), UDim2.new(0.5,-220,1,62), t.color:Lerp(Color3.fromRGB(7,7,13),0.72))
            corner(toast, 14)
            stroke(toast, t.color, 2)
            toast.ZIndex = 30
            local tl = makeLabel(toast, t.msg, UDim2.new(1,-16,1,-8), UDim2.new(0,8,0,4), Color3.new(1,1,1), Enum.Font.GothamBold)
            tl.ZIndex = 31
            tween(toast, {Position=UDim2.new(0.5,-220,1,-166)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            task.wait(t.dur)
            tween(toast, {Position=UDim2.new(0.5,-220,1,62)}, 0.22)
            task.wait(0.28); toast:Destroy()
        end
        toastActive = false
    end)
end

-- ============================================================
-- Floating +coins popup
-- ============================================================

local function showFloatingText(text, position2D, color)
    local ft = Instance.new("TextLabel", screen)
    ft.Size = UDim2.new(0,130,0,30)
    ft.Position = UDim2.new(0, position2D.X-65, 0, position2D.Y-20)
    ft.BackgroundTransparency = 1
    ft.TextColor3 = color or T.accent
    ft.Font = Enum.Font.GothamBold
    ft.Text = text
    ft.TextScaled = true
    ft.BorderSizePixel = 0
    ft.ZIndex = 25
    tween(ft, {Position=UDim2.new(0,position2D.X-65,0,position2D.Y-72), TextTransparency=1}, 1.2, Enum.EasingStyle.Quad)
    task.delay(1.3, function() ft:Destroy() end)
end

-- ============================================================
-- State
-- ============================================================

local localStats = {
    coins=0, totalEarned=0, prestige=0, income=0,
    slot=nil, floors={true,false,false,false},
    droppers={}, weapons={}, eqFloor=1, eqWeapon=1,
}
local currentHP  = MAX_HP
local killStreak = 0

-- ============================================================
-- Arsenal shop population (rebuilt on every UpdateStats)
-- ============================================================

local function populateShop()
    for _, child in ipairs(shopScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    for floor = 1, 4 do
        local floorUnlocked = localStats.floors and localStats.floors[floor]

        -- Section header
        local hdr = Instance.new("TextLabel", shopScroll)
        hdr.Size = UDim2.new(1,-6,0,28)
        hdr.BackgroundColor3 = FLOOR_COLORS[floor]:Lerp(Color3.fromRGB(10,10,16), 0.76)
        hdr.TextColor3 = FLOOR_COLORS[floor]
        hdr.Font = Enum.Font.GothamBold
        hdr.TextScaled = true
        hdr.Text = "FLOOR " .. floor .. "  —  " .. FLOOR_NAMES[floor]:upper()
        hdr.BorderSizePixel = 0
        hdr.ZIndex = 12
        corner(hdr, 7)

        if not floorUnlocked and floor > 1 then
            local lockNote = makeLabel(shopScroll, "Unlock for " .. formatCoins(FLOOR_COSTS[floor]) .. " coins (use elevator pad)", UDim2.new(1,-6,0,20), UDim2.new(0,3,0,0), T.textDim, Enum.Font.Gotham)
            lockNote.ZIndex = 12
        end

        for wi, wd in ipairs(WEAPONS[floor]) do
            local owned      = localStats.weapons and localStats.weapons[floor] and localStats.weapons[floor][wi]
            local isEquipped = localStats.eqFloor == floor and localStats.eqWeapon == wi

            local row = makeFrame(shopScroll, "Row_F"..floor.."W"..wi, UDim2.new(1,-6,0,62), UDim2.new(0,3,0,0), T.panel)
            row.ZIndex = 12
            corner(row, 9)
            stroke(row, isEquipped and FLOOR_COLORS[floor] or Color3.fromRGB(32,32,48), isEquipped and 2 or 1.5)

            -- Colour strip on left
            local strip = makeFrame(row, "Strip", UDim2.new(0,3,1,-10), UDim2.new(0,3,0,5), FLOOR_COLORS[floor])
            corner(strip, 2); strip.ZIndex = 13

            local nameL = makeLabel(row, wd.name, UDim2.new(1,-130,0,24), UDim2.new(0,14,0,7), isEquipped and FLOOR_COLORS[floor] or T.text, Enum.Font.GothamBold)
            nameL.ZIndex = 13; nameL.TextXAlignment = Enum.TextXAlignment.Left

            local statL = makeLabel(row, "DMG "..wd.damage.."  RNG "..wd.range.."  CD "..wd.cooldown.."s", UDim2.new(1,-130,0,16), UDim2.new(0,14,0,31), T.textDim, Enum.Font.Gotham)
            statL.ZIndex = 13; statL.TextXAlignment = Enum.TextXAlignment.Left

            local costText = owned and (isEquipped and "equipped" or "owned") or formatCoins(wd.cost).." coins"
            local costL = makeLabel(row, costText, UDim2.new(1,-130,0,14), UDim2.new(0,14,0,46), owned and T.textDim or T.accent, Enum.Font.Gotham)
            costL.ZIndex = 13; costL.TextXAlignment = Enum.TextXAlignment.Left

            -- Action button
            local btnText, btnBg
            if not floorUnlocked then
                btnText = "LOCKED"; btnBg = T.btnLocked
            elseif isEquipped then
                btnText = "✓ ACTIVE"; btnBg = FLOOR_COLORS[floor]:Lerp(Color3.fromRGB(0,0,0), 0.35)
            elseif owned then
                btnText = "EQUIP"; btnBg = T.btnOwned
            else
                btnText = "BUY"; btnBg = T.btnBuy
            end

            local btn = makeButton(row, btnText, UDim2.new(0,108,0,48), UDim2.new(1,-114,0,7), btnBg)
            btn.ZIndex = 13

            if floorUnlocked and not isEquipped then
                local f, w = floor, wi
                btn.MouseButton1Click:Connect(function()
                    RE.EquipWeaponRequest:FireServer(f, w)
                    if not owned then
                        showToast("Purchasing " .. WEAPONS[f][w].name .. "...", T.btnBuy, 1.5)
                    end
                end)
            end
        end
    end
end

-- ============================================================
-- Stats update from server
-- ============================================================

RE.UpdateStats.OnClientEvent:Connect(function(data)
    localStats = data

    coinAmountLabel.Text = "$" .. formatCoins(data.coins)
    coinIncomeLabel.Text = "+" .. formatCoins(data.income) .. "/s"

    -- Floor dots
    for i = 1, 4 do
        local unlocked = data.floors and data.floors[i]
        floorDots[i].BackgroundColor3 = unlocked and FLOOR_COLORS[i] or T.btnLocked
    end

    -- Prestige badge
    local p = data.prestige or 0
    prestigeLabel.Text = "P" .. p
    prestigeBadge.BackgroundColor3 = p > 0 and Color3.fromRGB(96,52,185) or Color3.fromRGB(60,38,110)

    -- Faction badge
    if data.slot then
        local fac = FACTIONS[data.slot]
        factionLabel.Text = fac.name
        factionBadge.BackgroundColor3 = fac.primary
        factionLabel.TextColor3 = fac.accent
        factionBadgeStroke.Color = fac.accent
    else
        factionLabel.Text = "No Tycoon"
        factionBadge.BackgroundColor3 = T.panelAlt
        factionLabel.TextColor3 = T.textDim
        factionBadgeStroke.Color = Color3.fromRGB(60,60,80)
    end

    -- Floor status
    local fl = data.eqFloor or 1
    floorStatusLabel.Text = "Floor " .. fl .. " — " .. FLOOR_NAMES[fl]
    floorStatusLabel.TextColor3 = FLOOR_COLORS[fl]

    -- Prestige panel cost
    local pIdx  = math.min(p + 1, #PRESTIGE_COSTS)
    local pCost = PRESTIGE_COSTS[pIdx]
    prestCostLabel.Text = "Cost: " .. formatCoins(pCost) .. "  →  +" .. (p * 50) .. "% income"

    populateShop()
end)

-- ============================================================
-- Income tick (flash coin widget)
-- ============================================================

RE.IncomeUpdate.OnClientEvent:Connect(function()
    tween(coinAmountLabel, {TextColor3=T.vip}, 0.07)
    task.delay(0.09, function() tween(coinAmountLabel, {TextColor3=T.accent}, 0.22) end)
end)

RE.DropperPing.OnClientEvent:Connect(function() end)

-- ============================================================
-- HP bar
-- ============================================================

local function updateHPBar(hp)
    currentHP = hp
    local pct = math.max(0, hp / MAX_HP)
    tween(hpBar, {Size=UDim2.new(pct,0,1,0)}, 0.12)
    hpBar.BackgroundColor3 = pct > 0.5 and Color3.fromRGB(195,42,42) or pct > 0.25 and Color3.fromRGB(235,125,18) or Color3.fromRGB(255,48,48)
    hpNumLabel.Text = math.floor(hp) .. "/" .. MAX_HP
end

RE.PlayerHit.OnClientEvent:Connect(function(attackerName, damage, newHP)
    updateHPBar(newHP)
    local flash = makeFrame(screen, "HitFlash", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(175,0,0), 0.75)
    flash.ZIndex = 45
    tween(flash, {BackgroundTransparency=1}, 0.4)
    task.delay(0.5, function() flash:Destroy() end)
    showToast(attackerName .. " hit you for " .. damage, Color3.fromRGB(205,42,42), 2)
end)

RE.PlayerKilled.OnClientEvent:Connect(function(killerName, coinsLost)
    killStreak = 0
    killstreakLabel.Text = ""
    deathSubLabel.Text = "Killed by " .. killerName .. " — Lost " .. formatCoins(coinsLost or 0) .. " coins"
    deathScreen.Visible = true
    task.delay(4.5, function()
        deathScreen.Visible = false
        updateHPBar(MAX_HP)
    end)
end)

RE.KillFeed.OnClientEvent:Connect(function(killerName, victimName)
    if killerName == player.DisplayName then
        killStreak = killStreak + 1
        killstreakLabel.Text = killStreak > 1 and (killStreak .. "x STREAK!") or ""
        addKillFeedEntry(killerName .. " ▶ " .. victimName, T.danger)
    else
        addKillFeedEntry(killerName .. " ▶ " .. victimName, T.textDim)
    end
end)

-- ============================================================
-- Random event banner
-- ============================================================

RE.RandomEvent.OnClientEvent:Connect(function(name, color, duration, isStart)
    if isStart then
        eventLabel.Text = name .. " (" .. duration .. "s)"
        eventBanner.BackgroundColor3 = color:Lerp(Color3.fromRGB(8,8,8), 0.74)
        stroke(eventBanner, color, 2)
        tween(eventBanner, {Position=UDim2.new(0.5,-200,0,64)}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        showToast("EVENT: " .. name, color, 5)
    else
        tween(eventBanner, {Position=UDim2.new(0.5,-200,-0.12,0)}, 0.22)
    end
end)

-- ============================================================
-- Weapon equipped
-- ============================================================

RE.WeaponEquipped.OnClientEvent:Connect(function(floor, wi, wData)
    equippedLabel.Text = wData.name
    weaponStatLabel.Text = "DMG " .. wData.damage .. " | RNG " .. wData.range
    equippedLabel.TextColor3 = FLOOR_COLORS[floor] or T.text
    floorStatusLabel.Text = "Floor " .. floor .. " — " .. FLOOR_NAMES[floor]
    floorStatusLabel.TextColor3 = FLOOR_COLORS[floor]
end)

-- ============================================================
-- VIP prompt
-- ============================================================

RE.VIPPrompt.OnClientEvent:Connect(function()
    vipPopup.Visible = true
end)

-- ============================================================
-- Notifications
-- ============================================================

RE.Notify.OnClientEvent:Connect(function(msg, color, duration)
    showToast(msg, color, duration)
end)

-- ============================================================
-- Prestige confirm
-- ============================================================

confirmBtn.MouseButton1Click:Connect(function()
    prestPanel.Visible = false
    local pr = RS:FindFirstChild("PrestigeRequest")
    if pr then pr:FireServer() end
end)

-- ============================================================
-- Cooldown bar (called by WeaponHandler via _G)
-- ============================================================

local function setCooldown(pct)
    tween(cdBar, {Size=UDim2.new(pct,0,1,0)}, 0.05)
    cdBar.BackgroundColor3 = pct > 0.6 and Color3.fromRGB(65,145,255) or Color3.fromRGB(255,125,22)
end

_G.GunTycoon_SetCooldown   = setCooldown
_G.GunTycoon_ShowFloat     = showFloatingText
_G.GunTycoon_ShowToast     = showToast
_G.GunTycoon_GetLocalStats = function() return localStats end

print("[ClientUI] GunTycoon UI v2 ready")

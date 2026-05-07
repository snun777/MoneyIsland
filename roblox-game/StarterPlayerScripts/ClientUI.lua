-- ============================================================
-- MONEY ISLAND TYCOON — ClientUI.lua  (LocalScript)
-- Place in: StarterPlayerScripts
-- ============================================================

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
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

-- ── state ────────────────────────────────────────────────
local currentData  = nil
local upgradesDef  = nil
local shopOpen     = false

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
rebirthLbl.Name="RebirthLbl"; rebirthLbl.Size=UDim2.new(0.38,0,1,0)
rebirthLbl.Position=UDim2.new(0.62,0,0,0); rebirthLbl.BackgroundTransparency=1
rebirthLbl.Text="🔥 x0"; rebirthLbl.TextColor3=Color3.fromRGB(255,120,0)
rebirthLbl.Font=Enum.Font.GothamBold; rebirthLbl.TextSize=18
rebirthLbl.TextXAlignment=Enum.TextXAlignment.Right

-- ── SIDE BUTTONS ─────────────────────────────────────────
local btnFrame = Instance.new("Frame",sg)
btnFrame.Size=UDim2.new(0,60,0,280); btnFrame.AnchorPoint=Vector2.new(1,0.5); btnFrame.Position=UDim2.new(1,-8,0.5,0)
btnFrame.BackgroundTransparency=1
local btnLayout=Instance.new("UIListLayout",btnFrame)
btnLayout.FillDirection=Enum.FillDirection.Vertical; btnLayout.Padding=UDim.new(0,8)
btnLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center

local function makeBtn(emoji, bgColor, onClick)
    local b = Instance.new("TextButton",btnFrame)
    b.Size=UDim2.new(0,52,0,52); b.BackgroundColor3=bgColor
    b.Text=emoji; b.TextScaled=true; b.Font=Enum.Font.GothamBold
    b.TextColor3=Color3.white; b.AutoButtonColor=false; b.BorderSizePixel=0
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
spClose.TextColor3=Color3.white; spClose.Font=Enum.Font.GothamBold; spClose.TextSize=16
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
toastTitle.Text=""; toastTitle.TextColor3=Color3.white
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

local function updateHUD(data)
    coinLbl.Text   = "💰 "..fmt(data.coins or 0)
    rebirthLbl.Text= "🔥 x"..(data.rebirths or 0)
end

-- ============================================================
-- UPGRADE SHOP
-- ============================================================
local function buildShop(data,upgrades)
    for _,c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local total=0
    for i,upg in ipairs(upgrades) do
        local level=data.upgrades and data.upgrades[upg.key] or 0
        local maxed=level>=upg.maxLevel
        local cost=not maxed and math.floor(upg.baseCost*(upg.costMult^level)) or 0
        local canBuy=not maxed and (data.coins or 0)>=cost

        local card=Instance.new("Frame",scroll)
        card.Name="Card"..i; card.Size=UDim2.new(1,0,0,78)
        card.BackgroundColor3=Color3.fromRGB(18,18,36); card.BorderSizePixel=0
        card.LayoutOrder=i
        Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
        local cs=Instance.new("UIStroke",card)
        cs.Color=canBuy and Color3.fromRGB(0,190,70) or Color3.fromRGB(50,50,80); cs.Thickness=1.5

        -- icon
        local ico=Instance.new("TextLabel",card); ico.Size=UDim2.new(0,46,1,0)
        ico.BackgroundTransparency=1; ico.Text=upg.icon; ico.TextScaled=true

        -- name
        local nm=Instance.new("TextLabel",card); nm.Size=UDim2.new(0,178,0,26)
        nm.Position=UDim2.new(0,50,0,8); nm.BackgroundTransparency=1
        nm.Text=upg.name; nm.TextColor3=Color3.fromRGB(230,230,250)
        nm.Font=Enum.Font.GothamBold; nm.TextSize=15; nm.TextXAlignment=Enum.TextXAlignment.Left

        -- desc
        local dc=Instance.new("TextLabel",card); dc.Size=UDim2.new(0,195,0,20)
        dc.Position=UDim2.new(0,50,0,34); dc.BackgroundTransparency=1
        dc.Text=upg.desc; dc.TextColor3=Color3.fromRGB(120,120,150)
        dc.Font=Enum.Font.Gotham; dc.TextSize=12; dc.TextXAlignment=Enum.TextXAlignment.Left

        -- level bar
        local bg=Instance.new("Frame",card); bg.Size=UDim2.new(0,185,0,5)
        bg.Position=UDim2.new(0,50,0,58); bg.BackgroundColor3=Color3.fromRGB(35,35,55); bg.BorderSizePixel=0
        Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)
        local fill=Instance.new("Frame",bg); fill.Size=UDim2.new(level/upg.maxLevel,0,1,0)
        fill.BackgroundColor3=Color3.fromRGB(255,200,0); fill.BorderSizePixel=0
        Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

        -- buy btn
        local btn=Instance.new("TextButton",card); btn.Size=UDim2.new(0,96,0,38)
        btn.Position=UDim2.new(1,-104,0.5,-19)
        btn.BackgroundColor3=maxed and Color3.fromRGB(35,75,35)
            or canBuy and Color3.fromRGB(18,130,55)
            or Color3.fromRGB(55,35,35)
        btn.Text=maxed and "MAX ✓" or "💰 "..fmt(cost)
        btn.TextColor3=Color3.white; btn.Font=Enum.Font.GothamBold; btn.TextSize=13
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
        if not maxed then
            btn.MouseButton1Click:Connect(function()
                RE_BuyUpgrade:FireServer(upg.key)
            end)
        end
        total=total+86
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

-- ── ROBUX SHOP ───────────────────────────────────────────
local PRODUCTS={
    {id=3586040050,label="💰 500 Coins",   price="R$50"},
    {id=3586040263,label="💰 2,500 Coins", price="R$199"},
    {id=3586040422,label="💰 10,000 Coins",price="R$699"},
}
local PASSES={
    {id=1821720069,label="⭐ Ultimate VIP",  price="R$499"},
    {id=1822515059,label="🤖 Auto Farm",     price="R$349"},
    {id=1821659972,label="🔥 Rebirth Pass",  price="R$199"},
}

local function openRobuxShop()
    local old2=sg:FindFirstChild("RobuxShop")
    if old2 then old2:Destroy() return end

    local panel=Instance.new("Frame",sg); panel.Name="RobuxShop"
    panel.BackgroundColor3=Color3.fromRGB(8,8,22); panel.BorderSizePixel=0
    Instance.new("UICorner",panel).CornerRadius=UDim.new(0,14)
    local rs=Instance.new("UIStroke",panel); rs.Color=Color3.fromRGB(55,140,255); rs.Thickness=2

    local y=56
    local function row(lbl,price,cb,col)
        local r=Instance.new("TextButton",panel); r.Size=UDim2.new(1,-20,0,50)
        r.Position=UDim2.new(0,10,0,y); r.BackgroundColor3=col; r.Text=""; r.BorderSizePixel=0
        Instance.new("UICorner",r).CornerRadius=UDim.new(0,10)
        local l=Instance.new("TextLabel",r); l.Size=UDim2.new(0.62,0,1,0)
        l.Position=UDim2.new(0,10,0,0); l.BackgroundTransparency=1; l.Text=lbl
        l.TextColor3=Color3.white; l.Font=Enum.Font.GothamBold; l.TextSize=14
        l.TextXAlignment=Enum.TextXAlignment.Left
        local p=Instance.new("TextLabel",r); p.Size=UDim2.new(0.35,0,1,0)
        p.Position=UDim2.new(0.64,0,0,0); p.BackgroundTransparency=1; p.Text=price
        p.TextColor3=Color3.fromRGB(255,215,0); p.Font=Enum.Font.GothamBold; p.TextSize=15
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
        row(p.label,p.price,function() MarketplaceService:PromptProductPurchase(player,pid) end,
            Color3.fromRGB(16,48,16))
    end
    sec("GAMEPASSES")
    for _,gp in ipairs(PASSES) do
        local gpid=gp.id
        row(gp.label,gp.price,function() MarketplaceService:PromptGamePassPurchase(player,gpid) end,
            Color3.fromRGB(16,16,52))
    end

    panel.Size=UDim2.new(0,370,0,y+12); panel.Position=UDim2.new(0.5,-185,0.5,-(y+12)/2)

    local cl=Instance.new("TextButton",panel); cl.Size=UDim2.new(0,32,0,32)
    cl.Position=UDim2.new(1,-40,0,8); cl.BackgroundColor3=Color3.fromRGB(160,25,25)
    cl.Text="✕"; cl.TextColor3=Color3.white; cl.Font=Enum.Font.GothamBold; cl.TextSize=15
    Instance.new("UICorner",cl).CornerRadius=UDim.new(0,8)
    cl.MouseButton1Click:Connect(function() panel:Destroy() end)

    local t2=Instance.new("TextLabel",panel); t2.Size=UDim2.new(1,-50,0,44)
    t2.Position=UDim2.new(0,12,0,4); t2.BackgroundTransparency=1
    t2.Text="💎 ROBUX SHOP"; t2.TextColor3=Color3.fromRGB(90,170,255)
    t2.Font=Enum.Font.GothamBold; t2.TextSize=22; t2.TextXAlignment=Enum.TextXAlignment.Left
end

-- ── WIRE BUTTONS ─────────────────────────────────────────
makeBtn("🛒", Color3.fromRGB(25,110,50),  openShop)
makeBtn("🎁", Color3.fromRGB(110,35,170), function() RE_ClaimDaily:FireServer() end)
makeBtn("🔥", Color3.fromRGB(190,55,15),  function() RE_Rebirth:FireServer() end)
makeBtn("💎", Color3.fromRGB(18,75,170),  openRobuxShop)

-- ── ShowShop remote → opens upgrade shop ─────────────────
RE_ShowShop.OnClientEvent:Connect(function()
    shopOpen = true
    shopPanel.Visible = true
    if currentData and upgradesDef then
        buildShop(currentData, upgradesDef)
    end
end)

-- ── Stat updates from server ──────────────────────────────
RE_UpdateStats.OnClientEvent:Connect(function(data, upgrades)
    currentData = data
    upgradesDef = upgrades
    updateHUD(data)
    if shopOpen then buildShop(data, upgrades) end
end)

-- ── Welcome toast ─────────────────────────────────────────
task.delay(2, function()
    showToast("🎁 Daily Reward!", "Tap 🎁 to claim your bonus!", "gold")
end)

print("[MoneyIsland] ✅ ClientUI loaded!")

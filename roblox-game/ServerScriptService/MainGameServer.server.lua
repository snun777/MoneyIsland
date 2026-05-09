-- GunTycoon MainGameServer v3
-- Rebalanced progression, multi-tier machine visuals updated on upgrade

local OWNER_ID = 0

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RS                 = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local Workspace          = game:GetService("Workspace")
local RunService         = game:GetService("RunService")

local Theme = {
    FACTIONS = {
        {name="Red Militia",       primary=Color3.fromRGB(195,40,40),   accent=Color3.fromRGB(255,90,90)  },
        {name="Blue Spec Ops",     primary=Color3.fromRGB(35,75,195),   accent=Color3.fromRGB(75,130,255) },
        {name="Green Rangers",     primary=Color3.fromRGB(45,155,55),   accent=Color3.fromRGB(90,215,105) },
        {name="Gold Mercs",        primary=Color3.fromRGB(195,160,18),  accent=Color3.fromRGB(255,210,50) },
        {name="Purple Shadow Ops", primary=Color3.fromRGB(115,35,175),  accent=Color3.fromRGB(175,85,255) },
        {name="Orange Frontline",  primary=Color3.fromRGB(205,95,25),   accent=Color3.fromRGB(255,145,55) },
        {name="Cyan Navy SEALs",   primary=Color3.fromRGB(28,165,185),  accent=Color3.fromRGB(65,215,235) },
        {name="White Ghost Div",   primary=Color3.fromRGB(200,200,210), accent=Color3.fromRGB(235,235,245)},
    },
    FLOORS = {
        [1]={name="Armory"},   [2]={name="Barracks"},
        [3]={name="War Room"}, [4]={name="Black Ops"},
    },
    VIP = { glowColor=Color3.fromRGB(255,240,100) },
}

local GC = {
    MAX_PLAYERS       = 8,
    DROPPER_TICK      = 1,
    RESPAWN_TIME      = 4,
    PLAYER_MAX_HP     = 150,
    KILL_STEAL        = 0.18,
    HIT_STEAL         = 0.01,
    AWAY_INCOME_RATE  = 0.6,
    DATASTORE_VERSION = "GT_v2",
    SAVE_INTERVAL     = 60,
    EVENT_MIN_INTERVAL= 180,
    EVENT_MAX_INTERVAL= 360,
    PRESTIGE_MULTIPLIER= 1.5,
    FLOOR_COSTS       = {[1]=0,[2]=60000,[3]=4000000,[4]=250000000},
    PRESTIGE_COSTS    = {10000000000,100000000000,1000000000000,10000000000000,100000000000000},
    COIN_PACKS = {
        {id=3586040050, coins=10000,  label="Small Pack" },
        {id=3586040263, coins=80000,  label="Medium Pack"},
        {id=3586040422, coins=300000, label="Large Pack" },
    },
    RESET_PRODUCT_ID = 3586040561,
    PASSES = {
        vip=1821720069, autoFarm=1823064828, autoCollect=1822515059,
        prestigeBoost=1822649609, luckyCharm=1821659972, speedDemon=1822655551,
    },
    EVENTS = {
        {name="Double Income", duration=30, incomeBoost=2,   damageBoost=1,   color=Color3.fromRGB(255,210,40)},
        {name="Triple Income", duration=20, incomeBoost=3,   damageBoost=1,   color=Color3.fromRGB(255,140,0) },
        {name="Arms Frenzy",   duration=30, incomeBoost=1,   damageBoost=2.5, color=Color3.fromRGB(220,40,40) },
        {name="Supply Drop",   duration=20, incomeBoost=1.5, damageBoost=1,   color=Color3.fromRGB(80,200,255)},
        {name="Black Market",  duration=25, shopDiscount=0.3,incomeBoost=1,   color=Color3.fromRGB(140,80,255)},
    },
    DROPPERS = {
        [1]={
            {name="Pistol Range",  baseRate=5,       baseCost=100,       maxLevel=8, costMult=1.9},
            {name="Rifle Station", baseRate=18,      baseCost=1500,      maxLevel=8, costMult=1.9},
            {name="Shotgun Rack",  baseRate=55,      baseCost=8500,      maxLevel=8, costMult=1.9},
            {name="Ammo Press",    baseRate=150,     baseCost=32000,     maxLevel=8, costMult=1.9},
        },
        [2]={
            {name="SMG Assembly",  baseRate=500,     baseCost=150000,    maxLevel=8, costMult=2.0},
            {name="AR Workshop",   baseRate=1600,    baseCost=500000,    maxLevel=8, costMult=2.0},
            {name="Heavy Forge",   baseRate=5000,    baseCost=1800000,   maxLevel=8, costMult=2.0},
        },
        [3]={
            {name="Sniper Lab",    baseRate=20000,   baseCost=8000000,   maxLevel=8, costMult=2.1},
            {name="LMG Factory",   baseRate=70000,   baseCost=32000000,  maxLevel=8, costMult=2.1},
            {name="Launcher Bay",  baseRate=250000,  baseCost=130000000, maxLevel=8, costMult=2.1},
        },
        [4]={
            {name="Minigun Core",  baseRate=1000000,  baseCost=750000000,   maxLevel=8, costMult=2.2},
            {name="Rocket Depot",  baseRate=4500000,  baseCost=3500000000,  maxLevel=8, costMult=2.2},
            {name="Railgun Lab",   baseRate=20000000, baseCost=16000000000, maxLevel=8, costMult=2.2},
        },
    },
    WEAPONS = {
        [1]={
            {name="Pistol",          damage=12,  range=65,  cooldown=0.75,cost=600,    speed=250,isAoe=false},
            {name="Revolver",        damage=22,  range=75,  cooldown=1.2, cost=2500,   speed=280,isAoe=false},
            {name="Shotgun",         damage=36,  range=30,  cooldown=1.6, cost=5000,   speed=200,isAoe=false},
        },
        [2]={
            {name="SMG",             damage=18,  range=85,  cooldown=0.35,cost=15000,  speed=320,isAoe=false},
            {name="Assault Rifle",   damage=32,  range=110, cooldown=0.55,cost=35000,  speed=350,isAoe=false},
            {name="Combat Shotgun",  damage=48,  range=40,  cooldown=1.0, cost=75000,  speed=220,isAoe=false},
        },
        [3]={
            {name="Sniper Rifle",    damage=110, range=250, cooldown=2.2, cost=250000, speed=600,isAoe=false},
            {name="LMG",             damage=42,  range=130, cooldown=0.22,cost=600000, speed=380,isAoe=false},
            {name="Grenade Launcher",damage=90,  range=90,  cooldown=2.8, cost=1200000,speed=180,isAoe=true },
        },
        [4]={
            {name="Minigun",         damage=38,  range=110, cooldown=0.12,cost=5000000, speed=400,isAoe=false},
            {name="Rocket Launcher", damage=180, range=160, cooldown=3.5, cost=14000000,speed=150,isAoe=true },
            {name="Railgun",         damage=320, range=350, cooldown=4.5, cost=30000000,speed=800,isAoe=false},
        },
    },
}

local DS = DataStoreService:GetDataStore(GC.DATASTORE_VERSION)

-- ============================================================
-- Remote setup
-- ============================================================

local function makeRemote(name, class)
    local r=Instance.new(class or "RemoteEvent"); r.Name=name; r.Parent=RS; return r
end

local RE = {
    UpdateStats     = makeRemote("UpdateStats"),
    Notify          = makeRemote("Notify"),
    TycoonUpdate    = makeRemote("TycoonUpdate"),
    PlayerHit       = makeRemote("PlayerHit"),
    PlayerKilled    = makeRemote("PlayerKilled"),
    KillFeed        = makeRemote("KillFeed"),
    RandomEvent     = makeRemote("RandomEvent"),
    DropperPing     = makeRemote("DropperPing"),
    IncomeUpdate    = makeRemote("IncomeUpdate"),
    WeaponEquipped  = makeRemote("WeaponEquipped"),
    VIPPrompt       = makeRemote("VIPPrompt"),
    WeaponFire          = makeRemote("WeaponFire"),
    PrestigeRequest     = makeRemote("PrestigeRequest"),
    EquipWeaponRequest  = makeRemote("EquipWeaponRequest"),
}
local RF = {
    GetTycoonData = makeRemote("GetTycoonData","RemoteFunction"),
}

-- ============================================================
-- Player data
-- ============================================================

local function defaultData()
    return {
        coins         = 0,
        totalEarned   = 0,
        prestige      = 0,
        tycoonSlot    = nil,
        floorsUnlocked = {true,false,false,false},
        dropperLevels  = {{0,0,0,0},{0,0,0},{0,0,0},{0,0,0}},
        weaponsOwned   = {{false,false,false},{false,false,false},{false,false,false},{false,false,false}},
        equippedFloor  = 1,
        equippedWeapon = 1,
        boostExpiry    = 0,
    }
end

local playerData   = {}
local dirtyPlayers = {}
local slotOwners   = {}

-- ============================================================
-- Persistence
-- ============================================================

local function loadData(player)
    local ok,saved=pcall(function() return DS:GetAsync("P_"..player.UserId) end)
    if ok and saved then
        local d=defaultData()
        for k,v in pairs(saved) do d[k]=v end
        return d
    end
    return defaultData()
end

local function saveData(player)
    local d=playerData[player.UserId]
    if not d then return end
    pcall(function() DS:SetAsync("P_"..player.UserId,d) end)
    dirtyPlayers[player.UserId]=nil
end

-- ============================================================
-- Helpers
-- ============================================================

local function getMultiplier(data)
    local base=1+(data.prestige*(GC.PRESTIGE_MULTIPLIER-1))
    local hasVIP=data._gp and data._gp[GC.PASSES.vip]
    return base*(hasVIP and 2 or 1)*(tick()<(data.boostExpiry or 0) and 2 or 1)
end

local function formatCoins(n)
    if n>=1e12 then return string.format("%.2fT",n/1e12)
    elseif n>=1e9 then return string.format("%.2fB",n/1e9)
    elseif n>=1e6 then return string.format("%.2fM",n/1e6)
    elseif n>=1e3 then return string.format("%.1fK",n/1e3)
    else return tostring(math.floor(n)) end
end

local function incomePerSec(data, eventBoost)
    local total=0
    for floor=1,4 do
        if data.floorsUnlocked[floor] then
            local dlist=GC.DROPPERS[floor]
            for di,dd in ipairs(dlist) do
                local lv=(data.dropperLevels[floor] or {})[di] or 0
                if lv>0 then total=total+dd.baseRate*(dd.costMult^(lv-1)) end
            end
        end
    end
    return math.floor(total*getMultiplier(data)*(eventBoost or 1))
end

local function sendStats(player)
    local d=playerData[player.UserId]
    if not d then return end
    RE.UpdateStats:FireClient(player,{
        coins=d.coins, totalEarned=d.totalEarned, prestige=d.prestige,
        income=incomePerSec(d,activeEventBoost), slot=d.tycoonSlot,
        floors=d.floorsUnlocked, droppers=d.dropperLevels, weapons=d.weaponsOwned,
        eqFloor=d.equippedFloor, eqWeapon=d.equippedWeapon, boostExpiry=d.boostExpiry,
    })
end

local function notify(player, msg, color, duration)
    RE.Notify:FireClient(player, msg, color or Color3.fromRGB(255,200,50), duration or 3)
end

-- ============================================================
-- Gamepass cache
-- ============================================================

local function hasPass(player, passId)
    local d=playerData[player.UserId]
    if not d then return false end
    if d._gp and d._gp[passId]~=nil then return d._gp[passId] end
    local ok,result=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId,passId) end)
    if not d._gp then d._gp={} end
    d._gp[passId]=ok and result or false
    return d._gp[passId]
end

local function refreshPasses(player)
    local d=playerData[player.UserId]
    if not d then return end
    if not d._gp then d._gp={} end
    for name,id in pairs(GC.PASSES) do
        local ok,res=pcall(MarketplaceService.UserOwnsGamePassAsync,MarketplaceService,player.UserId,id)
        d._gp[id]=ok and res or false
    end
    if d._gp[GC.PASSES.speedDemon] then
        local char=player.Character
        if char then
            local hum=char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed=32+16 end
        end
    end
end

-- ============================================================
-- Tycoon utilities
-- ============================================================

local function getTycoonFolder(slotId)
    return Workspace:FindFirstChild("Tycoons") and Workspace.Tycoons:FindFirstChild("Tycoon_"..slotId)
end

-- Glow colors per floor per visual tier (tier 1=active, 2=enhanced, 3=max)
local FLOOR_GLOW = {
    [1]={Color3.fromRGB(120,150,255), Color3.fromRGB(170,200,255), Color3.fromRGB(210,230,255)},
    [2]={Color3.fromRGB(80,200,80),   Color3.fromRGB(130,255,130), Color3.fromRGB(200,255,200)},
    [3]={Color3.fromRGB(220,105,40),  Color3.fromRGB(255,155,65),  Color3.fromRGB(255,210,110)},
    [4]={Color3.fromRGB(120,45,220),  Color3.fromRGB(165,75,255),  Color3.fromRGB(215,140,255)},
}
local GLOW_LIGHT = {
    {range=9,  brightness=1.4},
    {range=17, brightness=2.8},
    {range=28, brightness=4.5},
}

local function getGlowTier(level)
    if level>=6 then return 3
    elseif level>=3 then return 2
    else return 1 end
end

-- Called after every dropper upgrade, floor reveal, and prestige reset.
-- Updates glow color/intensity and reveals tier-2/3 machine parts.
local function updateDropperVisual(slotId, floor, di, level)
    local t=getTycoonFolder(slotId)
    if not t then return end
    local machF=t:FindFirstChild("DMach_F"..floor.."_"..di,true)
    if not machF then return end

    local tier       = getGlowTier(level)
    local glowColor  = FLOOR_GLOW[floor][tier]
    local lightData  = GLOW_LIGHT[tier]

    for _,desc in ipairs(machF:GetDescendants()) do
        if desc:IsA("BasePart") then
            local partTier=desc:GetAttribute("UpgradeTier")
            if partTier then
                -- Reveal or hide tier parts based on current tier
                if partTier<=tier then
                    local baseTrans=desc:GetAttribute("BaseTrans") or 0
                    desc.Transparency=baseTrans
                else
                    desc.Transparency=1
                end
                desc.CanCollide=false
            end
            -- Update glow part color and light
            if desc:GetAttribute("IsGlow") then
                desc.Color=glowColor
                local lt=desc:FindFirstChildOfClass("PointLight")
                if lt then lt.Color=glowColor; lt.Range=lightData.range; lt.Brightness=lightData.brightness end
            end
        end
    end
end

local function updateDropperLabel(slotId, floor, di, level)
    local t=getTycoonFolder(slotId)
    if not t then return end
    local btn=t:FindFirstChild("UpBtn_F"..floor.."_"..di,true)
    if not btn then return end
    local bb=btn:FindFirstChild("BillboardGui")
    local lbl=bb and bb:FindFirstChild("Label")
    if not lbl then return end
    local dd=GC.DROPPERS[floor][di]
    if level>=dd.maxLevel then
        lbl.Text=dd.name.."\nMAXED"
    else
        local upgradeCost=math.floor(dd.baseCost*(dd.costMult^level))
        lbl.Text=dd.name.."\nLv"..level.."  |  "..formatCoins(upgradeCost).." coins"
    end
end

local function showFloorBarrier(slotId,floor,visible)
    local t=getTycoonFolder(slotId)
    if not t then return end
    local barrier=t:FindFirstChild("Barrier_F"..floor,true)
    if barrier then
        barrier.Transparency=visible and 0.45 or 1
        barrier.CanCollide=visible
    end
end

local function revealFloor(slotId,floor)
    local t=getTycoonFolder(slotId)
    if not t then return end
    local floorFolder=t:FindFirstChild("Floor_"..floor)
    if not floorFolder then return end
    for _,desc in ipairs(floorFolder:GetDescendants()) do
        if desc:IsA("BasePart") then
            local ot=desc:GetAttribute("OrigTrans")
            local oc=desc:GetAttribute("OrigCollide")
            desc.Transparency=ot~=nil and ot or 0
            desc.CanCollide  =oc~=nil and oc or true
        elseif desc:IsA("ProximityPrompt") then
            desc.Enabled=true
        end
    end
    -- Apply correct visual tier to all droppers on this floor
    local player=nil
    for _,p in ipairs(Players:GetPlayers()) do
        local d=playerData[p.UserId]
        if d and d.tycoonSlot==slotId then player=p; break end
    end
    if player then
        local d=playerData[player.UserId]
        if d then
            local dlist=GC.DROPPERS[floor]
            for di=1,#dlist do
                local lv=(d.dropperLevels[floor] or {})[di] or 0
                if lv>0 then
                    updateDropperVisual(slotId,floor,di,lv)
                end
            end
        end
    end
end

local function hideFloor(slotId,floor)
    local t=getTycoonFolder(slotId)
    if not t then return end
    local floorFolder=t:FindFirstChild("Floor_"..floor)
    if not floorFolder then return end
    for _,desc in ipairs(floorFolder:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Transparency=1; desc.CanCollide=false
        elseif desc:IsA("ProximityPrompt") then
            desc.Enabled=false
        end
    end
end

local function updateTycoonForPlayer(player)
    local d=playerData[player.UserId]
    if not d or not d.tycoonSlot then return end
    local slotId=d.tycoonSlot
    for floor=1,4 do
        if d.floorsUnlocked[floor] then
            showFloorBarrier(slotId,floor,false)
            local dlist=GC.DROPPERS[floor]
            for di=1,#dlist do
                local lv=(d.dropperLevels[floor] or {})[di] or 0
                updateDropperLabel(slotId,floor,di,lv)
                if lv>0 then updateDropperVisual(slotId,floor,di,lv) end
            end
        else
            showFloorBarrier(slotId,floor,true)
        end
    end
end

-- ============================================================
-- Tycoon claiming
-- ============================================================

local function releaseTycoon(player)
    local d=playerData[player.UserId]
    if not d or not d.tycoonSlot then return end
    local slot=d.tycoonSlot
    slotOwners[slot]=nil; d.tycoonSlot=nil
    local t=getTycoonFolder(slot)
    if t then
        local btn=t:FindFirstChild("ClaimButton",true)
        if btn then
            local bb=btn:FindFirstChildOfClass("BillboardGui")
            if bb and bb:FindFirstChild("Label") then
                local faction=Theme.FACTIONS[slot]
                bb.Label.Text="CLAIM\n"..faction.name
            end
        end
    end
    sendStats(player)
end

local function claimTycoon(player,slotId)
    local d=playerData[player.UserId]
    if not d then return false,"Not loaded" end
    if d.tycoonSlot then return false,"Already have a tycoon" end
    if slotOwners[slotId] then return false,"Already claimed" end
    slotOwners[slotId]=player.UserId; d.tycoonSlot=slotId
    if not d.dropperLevels[1] then d.dropperLevels[1]={} end
    if (d.dropperLevels[1][1] or 0)==0 then d.dropperLevels[1][1]=1 end
    local t=getTycoonFolder(slotId)
    if t then
        local btn=t:FindFirstChild("ClaimButton",true)
        if btn then
            local bb=btn:FindFirstChildOfClass("BillboardGui")
            if bb and bb:FindFirstChild("Label") then
                bb.Label.Text=player.DisplayName.."\nowner"
            end
        end
    end
    updateTycoonForPlayer(player)
    revealFloor(slotId,1)
    sendStats(player)
    dirtyPlayers[player.UserId]=true
    notify(player,"Tycoon claimed! Build up your arsenal.",Color3.fromRGB(80,255,100))
    return true
end

-- ============================================================
-- Dropper upgrades
-- ============================================================

local function upgradeDropper(player,floor,di)
    local d=playerData[player.UserId]
    if not d then return false,"Not loaded" end
    if not d.tycoonSlot then return false,"No tycoon" end
    if not d.floorsUnlocked[floor] then return false,"Floor locked" end
    if not GC.DROPPERS[floor] or not GC.DROPPERS[floor][di] then return false,"Invalid" end
    local dd=GC.DROPPERS[floor][di]
    if not d.dropperLevels[floor] then d.dropperLevels[floor]={} end
    local lv=d.dropperLevels[floor][di] or 0
    if lv>=dd.maxLevel then return false,"Already maxed" end
    local cost=lv==0 and dd.baseCost or math.floor(dd.baseCost*(dd.costMult^lv))
    if activeEventDiscount then cost=math.floor(cost*(1-activeEventDiscount)) end
    if d.coins<cost then return false,"Not enough coins (need "..formatCoins(cost)..")" end
    d.coins=d.coins-cost
    d.dropperLevels[floor][di]=lv+1
    local newLevel=lv+1
    updateDropperLabel(d.tycoonSlot,floor,di,newLevel)
    updateDropperVisual(d.tycoonSlot,floor,di,newLevel)
    -- Flash glow to white on upgrade, then tween back to tier color
    local t=getTycoonFolder(d.tycoonSlot)
    local glowPart=t and t:FindFirstChild("DGlow_F"..floor.."_"..di,true)
    if glowPart and glowPart:IsA("BasePart") then
        local prevColor=glowPart.Color
        glowPart.Color=Color3.fromRGB(255,255,255)
        TweenService:Create(glowPart,TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Color=FLOOR_GLOW[floor][getGlowTier(newLevel)]}):Play()
    end
    dirtyPlayers[player.UserId]=true
    sendStats(player)
    notify(player,dd.name.." upgraded to Lv"..newLevel,Color3.fromRGB(80,200,255))
    RE.DropperPing:FireClient(player,floor,di)
    return true
end

-- ============================================================
-- Floor unlock
-- ============================================================

local function unlockFloor(player,floor)
    local d=playerData[player.UserId]
    if not d then return false,"Not loaded" end
    if not d.tycoonSlot then return false,"No tycoon" end
    if d.floorsUnlocked[floor] then return false,"Already unlocked" end
    if floor>1 and not d.floorsUnlocked[floor-1] then return false,"Unlock previous floor first" end
    local cost=GC.FLOOR_COSTS[floor]
    if activeEventDiscount then cost=math.floor(cost*(1-activeEventDiscount)) end
    if d.coins<cost then return false,"Need "..formatCoins(cost).." coins" end
    d.coins=d.coins-cost
    d.floorsUnlocked[floor]=true
    showFloorBarrier(d.tycoonSlot,floor,false)
    revealFloor(d.tycoonSlot,floor)
    dirtyPlayers[player.UserId]=true
    sendStats(player)
    notify(player,"Floor "..floor.." unlocked: "..Theme.FLOORS[floor].name.."!",Color3.fromRGB(255,200,50))
    return true
end

-- ============================================================
-- Weapon purchase & equip
-- ============================================================

local function buyWeapon(player,floor,wi)
    local d=playerData[player.UserId]
    if not d then return false end
    if not d.tycoonSlot then return false,"No tycoon" end
    if not d.floorsUnlocked[floor] then return false,"Floor locked" end
    local wData=GC.WEAPONS[floor] and GC.WEAPONS[floor][wi]
    if not wData then return false,"Invalid weapon" end
    if not d.weaponsOwned[floor] then d.weaponsOwned[floor]={} end
    if d.weaponsOwned[floor][wi] then return false,"Already owned" end
    local cost=wData.cost
    if activeEventDiscount then cost=math.floor(cost*(1-activeEventDiscount)) end
    if d.coins<cost then return false,"Need "..formatCoins(cost) end
    d.coins=d.coins-cost
    d.weaponsOwned[floor][wi]=true
    dirtyPlayers[player.UserId]=true
    sendStats(player)
    notify(player,wData.name.." purchased!",Color3.fromRGB(255,160,50))
    return true
end

local function equipWeapon(player,floor,wi)
    local d=playerData[player.UserId]
    if not d then return end
    if not (d.weaponsOwned[floor] and d.weaponsOwned[floor][wi]) then return end
    d.equippedFloor=floor; d.equippedWeapon=wi
    local wData=GC.WEAPONS[floor][wi]
    RE.WeaponEquipped:FireClient(player,floor,wi,wData)
    sendStats(player)
end

-- ============================================================
-- Prestige
-- ============================================================

local function prestige(player)
    local d=playerData[player.UserId]
    if not d then return false end
    local prestigeIndex=math.min(d.prestige+1,#GC.PRESTIGE_COSTS)
    local cost=GC.PRESTIGE_COSTS[prestigeIndex]
    if hasPass(player,GC.PASSES.prestigeBoost) then cost=math.floor(cost*0.8) end
    if d.coins<cost then return false,"Need "..formatCoins(cost).." coins to prestige" end
    d.coins=d.coins-cost
    d.prestige=d.prestige+1
    d.floorsUnlocked={true,false,false,false}
    d.dropperLevels={{1,0,0,0},{0,0,0},{0,0,0},{0,0,0}}
    d.weaponsOwned={{false,false,false},{false,false,false},{false,false,false},{false,false,false}}
    d.equippedFloor=1; d.equippedWeapon=1
    if d.tycoonSlot then
        for fl=2,4 do hideFloor(d.tycoonSlot,fl) end
        revealFloor(d.tycoonSlot,1)
        updateTycoonForPlayer(player)
        for fl=2,4 do showFloorBarrier(d.tycoonSlot,fl,true) end
        -- Reset all dropper visuals to tier 1
        for fl=1,4 do
            for di=1,#GC.DROPPERS[fl] do
                local lv=(d.dropperLevels[fl] or {})[di] or 0
                if lv>0 then
                    updateDropperVisual(d.tycoonSlot,fl,di,lv)
                    updateDropperLabel(d.tycoonSlot,fl,di,lv)
                else
                    updateDropperLabel(d.tycoonSlot,fl,di,0)
                end
            end
        end
    end
    dirtyPlayers[player.UserId]=true
    sendStats(player)
    notify(player,"PRESTIGE "..d.prestige.."! You now earn "..string.format("%.0f%%",getMultiplier(d)*100).." of base income.",Color3.fromRGB(255,215,0),6)
    return true
end

-- ============================================================
-- Combat
-- ============================================================

local activeEventBoost    = 1
local activeEventDiscount = nil
local activeEventDamage   = 1
local playerHP = {}

local function getHP(userId)
    if not playerHP[userId] then playerHP[userId]=GC.PLAYER_MAX_HP end
    return playerHP[userId]
end

local function getWeaponData(player)
    local d=playerData[player.UserId]
    if not d then return nil end
    return GC.WEAPONS[d.equippedFloor] and GC.WEAPONS[d.equippedFloor][d.equippedWeapon]
end

RE.WeaponFire.OnServerEvent:Connect(function(shooter,targetPlayer)
    if not targetPlayer or not targetPlayer:IsA("Player") then return end
    if targetPlayer==shooter then return end
    local attackerData=playerData[shooter.UserId]
    local wData=getWeaponData(shooter)
    if not wData then return end
    local aChar=shooter.Character; local tChar=targetPlayer.Character
    if not aChar or not tChar then return end
    local aRoot=aChar:FindFirstChild("HumanoidRootPart")
    local tRoot=tChar:FindFirstChild("HumanoidRootPart")
    if not aRoot or not tRoot then return end
    local dist=(aRoot.Position-tRoot.Position).Magnitude
    if dist>wData.range+15 then return end
    local damage=math.floor(wData.damage*activeEventDamage)
    local curHP=getHP(targetPlayer.UserId)
    curHP=math.max(0,curHP-damage)
    playerHP[targetPlayer.UserId]=curHP
    RE.PlayerHit:FireClient(targetPlayer,shooter.DisplayName,damage,curHP)
    local targetData=playerData[targetPlayer.UserId]
    if targetData and targetData.coins>0 then
        local stolen=math.floor(targetData.coins*GC.HIT_STEAL)
        if stolen>0 then
            targetData.coins=targetData.coins-stolen
            attackerData.coins=attackerData.coins+stolen
            dirtyPlayers[targetPlayer.UserId]=true
            dirtyPlayers[shooter.UserId]=true
        end
    end
    if curHP<=0 then
        playerHP[targetPlayer.UserId]=GC.PLAYER_MAX_HP
        local stolen=math.floor((targetData and targetData.coins or 0)*GC.KILL_STEAL)
        if stolen>0 and targetData then
            targetData.coins=targetData.coins-stolen
            attackerData.coins=attackerData.coins+stolen
            dirtyPlayers[targetPlayer.UserId]=true
            dirtyPlayers[shooter.UserId]=true
            notify(shooter,"KILL! Stole "..formatCoins(stolen).." coins from "..targetPlayer.DisplayName,Color3.fromRGB(255,80,80),4)
        end
        RE.PlayerKilled:FireClient(targetPlayer,shooter.DisplayName,stolen)
        RE.KillFeed:FireAllClients(shooter.DisplayName,targetPlayer.DisplayName)
        task.delay(GC.RESPAWN_TIME,function()
            if targetPlayer and targetPlayer.Parent then targetPlayer:LoadCharacter() end
        end)
        sendStats(shooter); sendStats(targetPlayer)
    end
end)

-- ============================================================
-- Dropper income tick
-- ============================================================

task.spawn(function()
    while true do
        task.wait(GC.DROPPER_TICK)
        for _,player in ipairs(Players:GetPlayers()) do
            local d=playerData[player.UserId]
            if not d then continue end
            local mult=1
            if hasPass(player,GC.PASSES.luckyCharm) and math.random()<0.06 then
                mult=8
                notify(player,"Lucky Jackpot! 8x income this tick!",Color3.fromRGB(255,215,0),2)
            end
            local income=incomePerSec(d,activeEventBoost)*mult
            local isOnTycoon=false
            if d.tycoonSlot then
                local tFolder=getTycoonFolder(d.tycoonSlot)
                local char=player.Character
                if tFolder and char then
                    local root=char:FindFirstChild("HumanoidRootPart")
                    local pad=tFolder:FindFirstChild("Pad")
                    if root and pad then
                        local rel=pad.CFrame:PointToObjectSpace(root.Position)
                        isOnTycoon=math.abs(rel.X)<40 and math.abs(rel.Z)<35
                    end
                end
            end
            if not isOnTycoon and not hasPass(player,GC.PASSES.autoFarm) then
                income=math.floor(income*GC.AWAY_INCOME_RATE)
            end
            if income>0 then
                d.coins=d.coins+income; d.totalEarned=d.totalEarned+income
                dirtyPlayers[player.UserId]=true
                RE.IncomeUpdate:FireClient(player,income)
            end
        end
    end
end)

-- ============================================================
-- Random events
-- ============================================================

task.spawn(function()
    while true do
        task.wait(math.random(GC.EVENT_MIN_INTERVAL,GC.EVENT_MAX_INTERVAL))
        local evData=GC.EVENTS[math.random(#GC.EVENTS)]
        activeEventBoost   =evData.incomeBoost  or 1
        activeEventDamage  =evData.damageBoost  or 1
        activeEventDiscount=evData.shopDiscount or nil
        RE.RandomEvent:FireAllClients(evData.name,evData.color,evData.duration,true)
        task.wait(evData.duration)
        activeEventBoost=1; activeEventDamage=1; activeEventDiscount=nil
        RE.RandomEvent:FireAllClients(evData.name,evData.color,0,false)
    end
end)

-- ============================================================
-- ProximityPrompt connections
-- ============================================================

task.delay(5,function()
    local tycoons=Workspace:WaitForChild("Tycoons",30)
    if not tycoons then return end

    for _,tFolder in ipairs(tycoons:GetChildren()) do
        for _,desc in ipairs(tFolder:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                local parent=desc.Parent
                if not parent then continue end

                if parent:GetAttribute("IsClaimBtn") then
                    local slotId=parent:GetAttribute("TycoonId")
                    desc.Triggered:Connect(function(player)
                        if slotOwners[slotId] then
                            notify(player,"This tycoon is already claimed!",Color3.fromRGB(255,80,80)); return
                        end
                        claimTycoon(player,slotId)
                    end)

                elseif parent:GetAttribute("IsUpgradeBtn") then
                    local slotId=parent:GetAttribute("TycoonId")
                    local floor =parent:GetAttribute("FloorId")
                    local di    =parent:GetAttribute("DropperId")
                    desc.Triggered:Connect(function(player)
                        local d=playerData[player.UserId]
                        if not d or d.tycoonSlot~=slotId then
                            notify(player,"This is not your tycoon!",Color3.fromRGB(255,80,80)); return
                        end
                        if not d.floorsUnlocked[floor] then
                            local ok,msg=unlockFloor(player,floor)
                            if not ok then notify(player,msg,Color3.fromRGB(255,80,80)) end
                            return
                        end
                        local ok,msg=upgradeDropper(player,floor,di)
                        if not ok then notify(player,msg,Color3.fromRGB(255,80,80)) end
                    end)

                elseif parent:GetAttribute("IsWeaponBtn") then
                    local slotId=parent:GetAttribute("TycoonId")
                    local floor =parent:GetAttribute("FloorId")
                    local wi    =parent:GetAttribute("WeaponId")
                    desc.Triggered:Connect(function(player)
                        local d=playerData[player.UserId]
                        if not d or d.tycoonSlot~=slotId then
                            notify(player,"This is not your tycoon!",Color3.fromRGB(255,80,80)); return
                        end
                        if d.weaponsOwned[floor] and d.weaponsOwned[floor][wi] then
                            equipWeapon(player,floor,wi)
                            notify(player,GC.WEAPONS[floor][wi].name.." equipped!",Color3.fromRGB(80,180,255))
                        else
                            local ok,msg=buyWeapon(player,floor,wi)
                            if ok then equipWeapon(player,floor,wi)
                            else notify(player,msg or "Cannot buy",Color3.fromRGB(255,80,80)) end
                        end
                    end)

                elseif parent:GetAttribute("IsElevUp") then
                    local slotId =parent:GetAttribute("TycoonId")
                    local floorId=parent:GetAttribute("FloorId")
                    desc.Triggered:Connect(function(plr)
                        local d=playerData[plr.UserId]
                        if not d or d.tycoonSlot~=slotId then
                            notify(plr,"This is not your tycoon!",Color3.fromRGB(255,80,80)); return
                        end
                        local nextFloor=floorId+1
                        if nextFloor>4 then return end
                        if not d.floorsUnlocked[nextFloor] then
                            local ok,msg=unlockFloor(plr,nextFloor)
                            if not ok then notify(plr,msg or "Cannot unlock floor",Color3.fromRGB(255,80,80)) end
                            return
                        end
                        local tf=getTycoonFolder(slotId)
                        local pad=tf and tf:FindFirstChild("Pad")
                        if not pad then return end
                        local baseYs={2,18,36,58}
                        local root=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if root then root.CFrame=pad.CFrame*CFrame.new(0,baseYs[nextFloor]+5,10) end
                    end)

                elseif parent:GetAttribute("IsElevDn") then
                    local slotId =parent:GetAttribute("TycoonId")
                    local floorId=parent:GetAttribute("FloorId")
                    desc.Triggered:Connect(function(plr)
                        local d=playerData[plr.UserId]
                        if not d or d.tycoonSlot~=slotId then
                            notify(plr,"This is not your tycoon!",Color3.fromRGB(255,80,80)); return
                        end
                        local prevFloor=floorId-1
                        if prevFloor<1 then return end
                        local tf=getTycoonFolder(slotId)
                        local pad=tf and tf:FindFirstChild("Pad")
                        if not pad then return end
                        local baseYs={2,18,36,58}
                        local root=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if root then root.CFrame=pad.CFrame*CFrame.new(0,baseYs[prevFloor]+5,10) end
                    end)
                end
            end
        end
    end

    -- Owner room
    local ownerRoom=Workspace:FindFirstChild("OwnerRoom")
    if ownerRoom then
        local keypad=ownerRoom:FindFirstChild("OwnerKeypad")
        if keypad then
            local kpp=keypad:FindFirstChildOfClass("ProximityPrompt")
            if kpp then
                kpp.Triggered:Connect(function(player)
                    if player.UserId~=OWNER_ID then notify(player,"Access denied.",Color3.fromRGB(255,60,60)); return end
                    local char=player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
                    if root then root.CFrame=CFrame.new(0,10,320+12+10) end
                end)
            end
        end
        local exitPad=ownerRoom:FindFirstChild("OwnerExitPad")
        if exitPad then
            local epp=exitPad:FindFirstChildOfClass("ProximityPrompt")
            if epp then
                epp.Triggered:Connect(function(player)
                    if player.UserId~=OWNER_ID then return end
                    local char=player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
                    if root then root.CFrame=CFrame.new(0,5,260) end
                end)
            end
        end
    end

    -- VIP
    local vipZone=Workspace:FindFirstChild("VIPZone")
    if vipZone then
        local vPad=vipZone:FindFirstChild("VIPPurchasePad")
        if vPad then
            local pp=vPad:FindFirstChildOfClass("ProximityPrompt")
            if pp then
                pp.Triggered:Connect(function(player)
                    if hasPass(player,GC.PASSES.vip) then
                        notify(player,"You already have VIP! Enjoy the lounge.",Theme.VIP.glowColor)
                    else
                        MarketplaceService:PromptGamePassPurchase(player,GC.PASSES.vip)
                    end
                end)
            end
        end
        local gate=vipZone:FindFirstChild("VIPGate")
        if gate then
            gate.Touched:Connect(function(hit)
                local char=hit.Parent; local player=Players:GetPlayerFromCharacter(char)
                if not player then return end
                if not hasPass(player,GC.PASSES.vip) then
                    RE.VIPPrompt:FireClient(player)
                    local root=char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local away=(root.Position-gate.Position).Unit
                        root.CFrame=root.CFrame+away*8
                    end
                end
            end)
        end
    end
end)

-- ============================================================
-- Remote handlers
-- ============================================================

RE.PrestigeRequest.OnServerEvent:Connect(function(player)
    local ok,msg=prestige(player)
    if not ok and msg then notify(player,msg,Color3.fromRGB(255,80,80)) end
end)

RE.EquipWeaponRequest.OnServerEvent:Connect(function(player,floor,wi)
    floor=tonumber(floor); wi=tonumber(wi)
    if not floor or not wi then return end
    local d=playerData[player.UserId]
    if not d or not d.tycoonSlot then return end
    if not GC.WEAPONS[floor] or not GC.WEAPONS[floor][wi] then return end
    if not d.floorsUnlocked[floor] then
        notify(player,"Unlock floor "..floor.." first!",Color3.fromRGB(255,80,80)); return
    end
    if not (d.weaponsOwned[floor] and d.weaponsOwned[floor][wi]) then
        local ok,msg=buyWeapon(player,floor,wi)
        if not ok then notify(player,msg or "Cannot purchase",Color3.fromRGB(255,80,80)); return end
    end
    equipWeapon(player,floor,wi)
end)

RF.GetTycoonData.OnServerInvoke=function(player)
    local d=playerData[player.UserId]
    return d and {slot=d.tycoonSlot,floors=d.floorsUnlocked,droppers=d.dropperLevels,weapons=d.weaponsOwned} or nil
end

-- ============================================================
-- Marketplace
-- ============================================================

MarketplaceService.ProcessReceipt=function(info)
    local player=Players:GetPlayerByUserId(info.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
    local d=playerData[info.PlayerId]
    if not d then return Enum.ProductPurchaseDecision.NotProcessedYet end
    for _,pack in ipairs(GC.COIN_PACKS) do
        if info.ProductId==pack.id then
            d.coins=d.coins+pack.coins; d.totalEarned=d.totalEarned+pack.coins
            notify(player,"+"..formatCoins(pack.coins).." coins added!",Color3.fromRGB(255,215,0),5)
            sendStats(player); dirtyPlayers[info.PlayerId]=true
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    if info.ProductId==GC.RESET_PRODUCT_ID then
        local refund=0
        for floor=1,4 do
            local dlist=GC.DROPPERS[floor]
            for di,dd in ipairs(dlist) do
                local lv=(d.dropperLevels[floor] or {})[di] or 0
                for lvl=1,lv do refund=refund+math.floor(dd.baseCost*(dd.costMult^(lvl-1))*0.4) end
            end
        end
        d.dropperLevels={{1,0,0,0},{0,0,0},{0,0,0},{0,0,0}}
        d.coins=d.coins+refund
        if d.tycoonSlot then updateTycoonForPlayer(player) end
        notify(player,"Droppers reset! +"..formatCoins(refund).." coins refunded.",Color3.fromRGB(200,150,255),5)
        sendStats(player); dirtyPlayers[info.PlayerId]=true
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player,passId,wasPurchased)
    if not wasPurchased then return end
    local d=playerData[player.UserId]
    if not d then return end
    if not d._gp then d._gp={} end
    d._gp[passId]=true
    refreshPasses(player); sendStats(player)
    notify(player,"Gamepass activated! Enjoy your perks.",Color3.fromRGB(255,215,0),5)
end)

-- ============================================================
-- Player join / leave
-- ============================================================

Players.PlayerAdded:Connect(function(player)
    local data=loadData(player)
    playerData[player.UserId]=data
    playerHP[player.UserId]=GC.PLAYER_MAX_HP
    task.spawn(refreshPasses,player)
    player.CharacterAdded:Connect(function(char)
        local hum=char:WaitForChild("Humanoid",8)
        if hum then hum.MaxHealth=GC.PLAYER_MAX_HP; hum.Health=GC.PLAYER_MAX_HP end
        if hasPass(player,GC.PASSES.speedDemon) then
            if hum then hum.WalkSpeed=32+16 end
        end
        task.wait(1); sendStats(player)
        if data.tycoonSlot then updateTycoonForPlayer(player) end
    end)
    task.wait(3); sendStats(player)
end)

Players.PlayerRemoving:Connect(function(player)
    releaseTycoon(player); saveData(player)
    playerData[player.UserId]=nil; playerHP[player.UserId]=nil
end)

-- ============================================================
-- Auto-save
-- ============================================================

task.spawn(function()
    while true do
        task.wait(GC.SAVE_INTERVAL)
        for uid,_ in pairs(dirtyPlayers) do
            local player=Players:GetPlayerByUserId(uid)
            if player then saveData(player) end
        end
    end
end)

game:BindToClose(function()
    for _,player in ipairs(Players:GetPlayers()) do saveData(player) end
end)

print("[MainGameServer] GunTycoon v3 server ready")

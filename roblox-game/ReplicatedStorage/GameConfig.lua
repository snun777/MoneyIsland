-- GunTycoon - Central game balance config
-- Tweak numbers here without touching game logic

local GameConfig = {}

GameConfig.MAX_PLAYERS = 8
GameConfig.DROPPER_TICK = 1        -- seconds between income ticks
GameConfig.RESPAWN_TIME = 4
GameConfig.PLAYER_MAX_HP = 150
GameConfig.KILL_STEAL = 0.18       -- fraction of victim coins stolen on kill
GameConfig.HIT_STEAL = 0.01        -- fraction stolen per hit (small, keeps it fair)
GameConfig.AWAY_INCOME_RATE = 0.6  -- income rate when not on your tycoon (60%)

GameConfig.FLOOR_COSTS = {
    [1] = 0,
    [2] = 5000,
    [3] = 120000,
    [4] = 2500000,
}

-- {name, baseRate (coins/tick), baseCost, maxLevel, costMult}
GameConfig.DROPPERS = {
    [1] = {
        { name = "Pistol Range",   baseRate = 3,      baseCost = 0,        maxLevel = 8, costMult = 2.1 },
        { name = "Rifle Station",  baseRate = 10,     baseCost = 200,      maxLevel = 8, costMult = 2.1 },
        { name = "Shotgun Rack",   baseRate = 28,     baseCost = 700,      maxLevel = 8, costMult = 2.1 },
        { name = "Ammo Press",     baseRate = 70,     baseCost = 2500,     maxLevel = 8, costMult = 2.1 },
    },
    [2] = {
        { name = "SMG Assembly",   baseRate = 180,    baseCost = 9000,     maxLevel = 8, costMult = 2.15 },
        { name = "AR Workshop",    baseRate = 480,    baseCost = 25000,    maxLevel = 8, costMult = 2.15 },
        { name = "Heavy Forge",    baseRate = 1200,   baseCost = 65000,    maxLevel = 8, costMult = 2.15 },
    },
    [3] = {
        { name = "Sniper Lab",     baseRate = 3000,   baseCost = 200000,   maxLevel = 8, costMult = 2.2 },
        { name = "LMG Factory",    baseRate = 8000,   baseCost = 550000,   maxLevel = 8, costMult = 2.2 },
        { name = "Launcher Bay",   baseRate = 22000,  baseCost = 1500000,  maxLevel = 8, costMult = 2.2 },
    },
    [4] = {
        { name = "Minigun Core",   baseRate = 55000,  baseCost = 4000000,  maxLevel = 8, costMult = 2.3 },
        { name = "Rocket Depot",   baseRate = 160000, baseCost = 12000000, maxLevel = 8, costMult = 2.3 },
        { name = "Railgun Lab",    baseRate = 500000, baseCost = 35000000, maxLevel = 8, costMult = 2.3 },
    },
}

-- {name, damage, range (studs), cooldown (s), cost, projectileSpeed, isAoe}
GameConfig.WEAPONS = {
    [1] = {
        { name = "Pistol",          damage = 12,  range = 65,  cooldown = 0.75, cost = 600,     speed = 250, isAoe = false },
        { name = "Revolver",        damage = 22,  range = 75,  cooldown = 1.2,  cost = 2500,    speed = 280, isAoe = false },
        { name = "Shotgun",         damage = 36,  range = 30,  cooldown = 1.6,  cost = 5000,    speed = 200, isAoe = false },
    },
    [2] = {
        { name = "SMG",             damage = 18,  range = 85,  cooldown = 0.35, cost = 15000,   speed = 320, isAoe = false },
        { name = "Assault Rifle",   damage = 32,  range = 110, cooldown = 0.55, cost = 35000,   speed = 350, isAoe = false },
        { name = "Combat Shotgun",  damage = 48,  range = 40,  cooldown = 1.0,  cost = 75000,   speed = 220, isAoe = false },
    },
    [3] = {
        { name = "Sniper Rifle",    damage = 110, range = 250, cooldown = 2.2,  cost = 250000,  speed = 600, isAoe = false },
        { name = "LMG",             damage = 42,  range = 130, cooldown = 0.22, cost = 600000,  speed = 380, isAoe = false },
        { name = "Grenade Launcher",damage = 90,  range = 90,  cooldown = 2.8,  cost = 1200000, speed = 180, isAoe = true  },
    },
    [4] = {
        { name = "Minigun",         damage = 38,  range = 110, cooldown = 0.12, cost = 5000000, speed = 400, isAoe = false },
        { name = "Rocket Launcher", damage = 180, range = 160, cooldown = 3.5,  cost = 14000000,speed = 150, isAoe = true  },
        { name = "Railgun",         damage = 320, range = 350, cooldown = 4.5,  cost = 30000000,speed = 800, isAoe = false },
    },
}

-- Prestige costs (indexed by prestige number 1,2,3... use last entry for beyond)
GameConfig.PRESTIGE_COSTS = { 6000000, 30000000, 120000000, 500000000, 2000000000 }
GameConfig.PRESTIGE_MULTIPLIER = 1.5  -- each prestige adds 50% permanent income

-- Coin packs (existing product IDs)
GameConfig.COIN_PACKS = {
    { id = 3586040050, coins = 10000,   label = "Small Pack"  },
    { id = 3586040263, coins = 80000,   label = "Medium Pack" },
    { id = 3586040422, coins = 300000,  label = "Large Pack"  },
    -- NEW products (create in dashboard, add IDs here):
    -- Mega Pack: ~1,500,000 coins @ 1,499 R$
    -- Floor Boost: instant floor unlock @ 149 R$
    -- 2x Earnings 1hr: @ 99 R$
}

GameConfig.RESET_PRODUCT_ID = 3586040561  -- 49 R$: reset dropper upgrades, refund 40%

-- Gamepass IDs
GameConfig.PASSES = {
    vip           = 1821720069,  -- 2x all income + VIP area access + crown
    autoFarm      = 1823064828,  -- 100% income rate even when away
    autoCollect   = 1822515059,  -- auto-collects pending coins every 3s
    prestigeBoost = 1822649609,  -- -20% prestige cost
    luckyCharm    = 1821659972,  -- 6% chance for 8x tick bonus
    speedDemon    = 1822655551,  -- +32 walkspeed
}

-- Random events
GameConfig.EVENTS = {
    { name = "Double Income",  duration = 30, incomeBoost = 2,   damageBoost = 1,   color = Color3.fromRGB(255,210,40) },
    { name = "Triple Income",  duration = 20, incomeBoost = 3,   damageBoost = 1,   color = Color3.fromRGB(255,140,0)  },
    { name = "Arms Frenzy",    duration = 30, incomeBoost = 1,   damageBoost = 2.5, color = Color3.fromRGB(220,40,40)  },
    { name = "Supply Drop",    duration = 20, incomeBoost = 1.5, damageBoost = 1,   color = Color3.fromRGB(80,200,255) },
    { name = "Black Market",   duration = 25, shopDiscount = 0.3, incomeBoost = 1,  color = Color3.fromRGB(140,80,255) },
}
GameConfig.EVENT_MIN_INTERVAL = 180
GameConfig.EVENT_MAX_INTERVAL = 360

GameConfig.DATASTORE_VERSION = "GT_v1"
GameConfig.SAVE_INTERVAL = 60  -- auto-save every 60s

return GameConfig

-- GunTycoon - Central game balance config
-- Rebalanced: slower, more satisfying progression curve

local GameConfig = {}

GameConfig.MAX_PLAYERS = 8
GameConfig.DROPPER_TICK = 1
GameConfig.RESPAWN_TIME = 4
GameConfig.PLAYER_MAX_HP = 150
GameConfig.KILL_STEAL    = 0.18
GameConfig.HIT_STEAL     = 0.01
GameConfig.AWAY_INCOME_RATE = 0.6

-- Floor 2: ~25-35 min | Floor 3: ~60-90 min | Floor 4: ~2-3 hours
GameConfig.FLOOR_COSTS = {
    [1] = 0,
    [2] = 60000,
    [3] = 4000000,
    [4] = 250000000,
}

-- Item IDs: dropper = floor*100+index, weapon = 1000+floor*10+index
-- {id, name, baseRate (coins/tick at lv1), baseCost, maxLevel, costMult}
GameConfig.DROPPERS = {
    [1] = {
        { id = 101, name = "Pistol Range",   baseRate = 5,       baseCost = 100,       maxLevel = 8, costMult = 1.9 },
        { id = 102, name = "Rifle Station",  baseRate = 18,      baseCost = 1500,      maxLevel = 8, costMult = 1.9 },
        { id = 103, name = "Shotgun Rack",   baseRate = 55,      baseCost = 8500,      maxLevel = 8, costMult = 1.9 },
        { id = 104, name = "Ammo Press",     baseRate = 150,     baseCost = 32000,     maxLevel = 8, costMult = 1.9 },
    },
    [2] = {
        { id = 201, name = "SMG Assembly",   baseRate = 500,     baseCost = 150000,    maxLevel = 8, costMult = 2.0 },
        { id = 202, name = "AR Workshop",    baseRate = 1600,    baseCost = 500000,    maxLevel = 8, costMult = 2.0 },
        { id = 203, name = "Heavy Forge",    baseRate = 5000,    baseCost = 1800000,   maxLevel = 8, costMult = 2.0 },
    },
    [3] = {
        { id = 301, name = "Sniper Lab",     baseRate = 20000,   baseCost = 8000000,   maxLevel = 8, costMult = 2.1 },
        { id = 302, name = "LMG Factory",    baseRate = 70000,   baseCost = 32000000,  maxLevel = 8, costMult = 2.1 },
        { id = 303, name = "Launcher Bay",   baseRate = 250000,  baseCost = 130000000, maxLevel = 8, costMult = 2.1 },
    },
    [4] = {
        { id = 401, name = "Minigun Core",   baseRate = 1000000,  baseCost = 750000000,   maxLevel = 8, costMult = 2.2 },
        { id = 402, name = "Rocket Depot",   baseRate = 4500000,  baseCost = 3500000000,  maxLevel = 8, costMult = 2.2 },
        { id = 403, name = "Railgun Lab",    baseRate = 20000000, baseCost = 16000000000, maxLevel = 8, costMult = 2.2 },
    },
}

-- {id, name, damage, range (studs), cooldown (s), cost, projectileSpeed, isAoe}
GameConfig.WEAPONS = {
    [1] = {
        { id = 1011, name = "Pistol",           damage = 12,  range = 65,  cooldown = 0.75, cost = 600,      speed = 250, isAoe = false },
        { id = 1012, name = "Revolver",         damage = 22,  range = 75,  cooldown = 1.2,  cost = 2500,     speed = 280, isAoe = false },
        { id = 1013, name = "Shotgun",          damage = 36,  range = 30,  cooldown = 1.6,  cost = 5000,     speed = 200, isAoe = false },
    },
    [2] = {
        { id = 1021, name = "SMG",              damage = 18,  range = 85,  cooldown = 0.35, cost = 15000,    speed = 320, isAoe = false },
        { id = 1022, name = "Assault Rifle",    damage = 32,  range = 110, cooldown = 0.55, cost = 35000,    speed = 350, isAoe = false },
        { id = 1023, name = "Combat Shotgun",   damage = 48,  range = 40,  cooldown = 1.0,  cost = 75000,    speed = 220, isAoe = false },
    },
    [3] = {
        { id = 1031, name = "Sniper Rifle",     damage = 110, range = 250, cooldown = 2.2,  cost = 250000,   speed = 600, isAoe = false },
        { id = 1032, name = "LMG",              damage = 42,  range = 130, cooldown = 0.22, cost = 600000,   speed = 380, isAoe = false },
        { id = 1033, name = "Grenade Launcher", damage = 90,  range = 90,  cooldown = 2.8,  cost = 1200000,  speed = 180, isAoe = true  },
    },
    [4] = {
        { id = 1041, name = "Minigun",          damage = 38,  range = 110, cooldown = 0.12, cost = 5000000,  speed = 400, isAoe = false },
        { id = 1042, name = "Rocket Launcher",  damage = 180, range = 160, cooldown = 3.5,  cost = 14000000, speed = 150, isAoe = true  },
        { id = 1043, name = "Railgun",          damage = 320, range = 350, cooldown = 4.5,  cost = 30000000, speed = 800, isAoe = false },
    },
}

-- Prestige: meaningful cost at every tier, still achievable
GameConfig.PRESTIGE_COSTS = {
    10000000000,     -- 10B  (P1)
    100000000000,    -- 100B (P2)
    1000000000000,   -- 1T   (P3)
    10000000000000,  -- 10T  (P4)
    100000000000000, -- 100T (P5+)
}
GameConfig.PRESTIGE_MULTIPLIER = 1.5

GameConfig.COIN_PACKS = {
    { id = 3586040050, coins = 10000,   label = "Small Pack"  },
    { id = 3586040263, coins = 80000,   label = "Medium Pack" },
    { id = 3586040422, coins = 300000,  label = "Large Pack"  },
}
GameConfig.RESET_PRODUCT_ID = 3586040561

GameConfig.PASSES = {
    vip           = 1821720069,
    autoFarm      = 1823064828,
    autoCollect   = 1822515059,
    prestigeBoost = 1822649609,
    luckyCharm    = 1821659972,
    speedDemon    = 1822655551,
}

GameConfig.EVENTS = {
    { name = "Double Income",  duration = 30, incomeBoost = 2,   damageBoost = 1,   color = Color3.fromRGB(255,210,40) },
    { name = "Triple Income",  duration = 20, incomeBoost = 3,   damageBoost = 1,   color = Color3.fromRGB(255,140,0)  },
    { name = "Arms Frenzy",    duration = 30, incomeBoost = 1,   damageBoost = 2.5, color = Color3.fromRGB(220,40,40)  },
    { name = "Supply Drop",    duration = 20, incomeBoost = 1.5, damageBoost = 1,   color = Color3.fromRGB(80,200,255) },
    { name = "Black Market",   duration = 25, shopDiscount = 0.3, incomeBoost = 1,  color = Color3.fromRGB(140,80,255) },
}
GameConfig.EVENT_MIN_INTERVAL = 180
GameConfig.EVENT_MAX_INTERVAL = 360

GameConfig.DATASTORE_VERSION = "GT_v2"
GameConfig.SAVE_INTERVAL = 60

return GameConfig

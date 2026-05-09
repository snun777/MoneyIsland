-- GunTycoon - Visual theme config
-- Change these to reskin the entire game without touching logic

local ThemeConfig = {}

-- Platform
ThemeConfig.PLATFORM = {
    size        = Vector3.new(640, 6, 640),
    color       = Color3.fromRGB(42, 42, 48),
    material    = Enum.Material.SmoothPlastic,
    wallHeight  = 90,
    wallThick   = 14,
    wallColor   = Color3.fromRGB(32, 32, 38),
    wallMat     = Enum.Material.SmoothPlastic,
}

-- 8 faction tycoons - order matches tycoon slot 1-8
ThemeConfig.FACTIONS = {
    { name = "Red Militia",       primary = Color3.fromRGB(195, 40,  40),  accent = Color3.fromRGB(255, 90,  90)  },
    { name = "Blue Spec Ops",     primary = Color3.fromRGB(35,  75,  195), accent = Color3.fromRGB(75,  130, 255) },
    { name = "Green Rangers",     primary = Color3.fromRGB(45,  155, 55),  accent = Color3.fromRGB(90,  215, 105) },
    { name = "Gold Mercs",        primary = Color3.fromRGB(195, 160, 18),  accent = Color3.fromRGB(255, 210, 50)  },
    { name = "Purple Shadow Ops", primary = Color3.fromRGB(115, 35,  175), accent = Color3.fromRGB(175, 85,  255) },
    { name = "Orange Frontline",  primary = Color3.fromRGB(205, 95,  25),  accent = Color3.fromRGB(255, 145, 55)  },
    { name = "Cyan Navy SEALs",   primary = Color3.fromRGB(28,  165, 185), accent = Color3.fromRGB(65,  215, 235) },
    { name = "White Ghost Div",   primary = Color3.fromRGB(200, 200, 210), accent = Color3.fromRGB(235, 235, 245) },
}

-- Per-floor visual theme
ThemeConfig.FLOORS = {
    [1] = { name = "Armory",     wall = Color3.fromRGB(70,  70,  80),  trim = Color3.fromRGB(110, 110, 125), light = Color3.fromRGB(180, 200, 255) },
    [2] = { name = "Barracks",   wall = Color3.fromRGB(55,  70,  55),  trim = Color3.fromRGB(90,  115, 90),  light = Color3.fromRGB(150, 255, 150) },
    [3] = { name = "War Room",   wall = Color3.fromRGB(65,  50,  30),  trim = Color3.fromRGB(115, 90,  55),  light = Color3.fromRGB(255, 150, 80)  },
    [4] = { name = "Black Ops",  wall = Color3.fromRGB(20,  20,  28),  trim = Color3.fromRGB(70,  50,  110), light = Color3.fromRGB(160, 80,  255)  },
}

-- UI palette
ThemeConfig.UI = {
    bg         = Color3.fromRGB(12,  12,  18),
    panel      = Color3.fromRGB(22,  22,  30),
    panelAlt   = Color3.fromRGB(30,  30,  40),
    accent     = Color3.fromRGB(255, 200, 50),
    text       = Color3.fromRGB(235, 235, 235),
    textDim    = Color3.fromRGB(160, 160, 170),
    btnBuy     = Color3.fromRGB(45,  175, 75),
    btnOwned   = Color3.fromRGB(50,  120, 200),
    btnLocked  = Color3.fromRGB(80,  80,  90),
    danger     = Color3.fromRGB(215, 55,  55),
    warning    = Color3.fromRGB(255, 155, 35),
    vip        = Color3.fromRGB(255, 215, 0),
}

-- VIP zone
ThemeConfig.VIP = {
    color      = Color3.fromRGB(180, 145, 20),
    trim       = Color3.fromRGB(255, 215, 0),
    glowColor  = Color3.fromRGB(255, 240, 100),
    platform   = Color3.fromRGB(50,  45,  15),
}

-- Weapon colors (for bullet projectiles)
ThemeConfig.BULLET_COLORS = {
    [1] = Color3.fromRGB(255, 240, 160),  -- basic: warm yellow
    [2] = Color3.fromRGB(160, 220, 255),  -- heavy: blue tracer
    [3] = Color3.fromRGB(255, 100, 50),   -- elite: orange
    [4] = Color3.fromRGB(200, 80,  255),  -- legendary: purple energy
}

-- Cover objects on the PvP field
ThemeConfig.COVER_COLOR   = Color3.fromRGB(85, 75, 60)
ThemeConfig.CRATE_COLOR   = Color3.fromRGB(100, 85, 50)

return ThemeConfig

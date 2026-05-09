-- GunAssets.lua
-- Reference config for external 3D gun model asset IDs.
-- This file is NOT synced by Rojo - it is a reference only.
--
-- HOW TO USE:
--   1. Find a gun model on the Roblox toolbox / catalog.
--   2. Get its asset ID (the number in the URL).
--   3. Fill in the modelId below.
--   4. In WeaponHandler (CoinSpin.client.lua), load the model via:
--        local InsertService = game:GetService("InsertService")
--        local model = InsertService:LoadAsset(assetId)
--        model.Parent = workspace
--      or insert it as a Tool in the character for first-person view.
--
-- FIELDS:
--   modelId     -- Roblox asset ID for the gun Model/Tool (required)
--   viewModelId -- First-person viewmodel asset ID (optional, 0 = none)
--   holdAnimId  -- AnimationId for idle hold pose (optional)
--   fireAnimId  -- AnimationId for fire animation (optional)
--   reloadAnimId-- AnimationId for reload animation (optional)
--   scale       -- Size multiplier if the model is too large/small (default 1)

local GunAssets = {

    -- ========================================================
    -- FLOOR 1: Armory
    -- ========================================================
    Pistol = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
    Revolver = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
    Shotgun = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },

    -- ========================================================
    -- FLOOR 2: Barracks
    -- ========================================================
    SMG = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
    ["Assault Rifle"] = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
    ["Combat Shotgun"] = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },

    -- ========================================================
    -- FLOOR 3: War Room
    -- ========================================================
    ["Sniper Rifle"] = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
    LMG = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
    ["Grenade Launcher"] = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },

    -- ========================================================
    -- FLOOR 4: Black Ops
    -- ========================================================
    Minigun = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
    ["Rocket Launcher"] = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
    Railgun = {
        modelId      = 0,
        viewModelId  = 0,
        holdAnimId   = 0,
        fireAnimId   = 0,
        reloadAnimId = 0,
        scale        = 1,
    },
}

return GunAssets

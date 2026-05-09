-- GunTycoon GamepassEnforcer v1
-- Fires confirmation notifications when a gamepass is purchased mid-session
-- MainGameServer handles the actual perk application via refreshPasses()

local MarketplaceService = game:GetService("MarketplaceService")
local RS                 = game:GetService("ReplicatedStorage")

local MESSAGES = {
    [1821720069] = "VIP activated! 2x income, VIP lounge access, and golden crown are yours.",
    [1823064828] = "Auto Farm activated! Full income even when away from your tycoon.",
    [1822515059] = "Auto Collect activated! Dropper income auto-collected every few seconds.",
    [1822649609] = "Prestige Boost activated! Prestige costs reduced by 20%.",
    [1821659972] = "Lucky Charm activated! 6% chance for 8x income jackpot each tick.",
    [1822655551] = "Speed Demon activated! You are now 50% faster.",
}

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gpId, purchased)
    if not purchased then return end
    local notify = RS:FindFirstChild("Notify")
    if not notify then return end
    local msg = MESSAGES[gpId] or "Gamepass activated!"
    notify:FireClient(player, msg, Color3.fromRGB(255,215,0), 5)
end)

print("[GamepassEnforcer] GunTycoon pass enforcer ready")

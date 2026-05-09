-- GamepassEnforcer.server.lua
-- Sends purchase confirmation toasts and refreshes the GP cache when a
-- player buys a pass mid-session. Perk application (speed, auto-farm, etc.)
-- is handled entirely by MainGameServer via its own checkGamepasses().

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local GP = {
	VIP           = 1821720069,
	AUTO_FARM     = 1823064828,
	AUTO_COLLECT  = 1822515059,
	PRESTIGE_BOOST= 1822649609,
	LUCKY_CHARM   = 1821659972,
	SPEED_DEMON   = 1822655551,
}

local NOTIFICATIONS = {
	[GP.VIP]           = {"⭐ VIP ACTIVATED!",     "2× coins on everything!",              "gold" },
	[GP.AUTO_FARM]     = {"🤖 Auto Farm ON!",       "Your machines tick at 2× speed!",      "green"},
	[GP.AUTO_COLLECT]  = {"💰 Auto Collect ON!",    "Geyser coins fly straight to you!",    "green"},
	[GP.PRESTIGE_BOOST]= {"🔥 Prestige Boost ON!",  "Rebirth costs 20% less every run!",    "gold" },
	[GP.LUCKY_CHARM]   = {"🍀 Lucky Charm ON!",     "3× jackpot chance + 20× multiplier!",  "green"},
	[GP.SPEED_DEMON]   = {"⚡ Speed Demon ON!",     "You're now faster than everyone else!", "blue" },
}

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gpId, purchased)
	if not purchased then return end
	if not player or not player.Parent then return end

	local notify = ReplicatedStorage:FindFirstChild("NotifyPlayer")
	if not notify then return end

	local n = NOTIFICATIONS[gpId]
	if n then
		notify:FireClient(player, n[1], n[2], n[3])
	end
end)

print("[MoneyIsland] ✅ Gamepass enforcer loaded!")

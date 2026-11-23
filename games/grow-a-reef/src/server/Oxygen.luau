--!nonstrict
-- Air (ReefConfig.Oxygen). Four times a second: anyone in deep water (DeepWater) uses up air,
-- everyone else refills. Capacity grows with the Oxygen Tank (Equipment Station). Run out and
-- you're whisked back to the plaza with full air. The server decides; each player's air is
-- published as the attributes Oxygen and OxygenMax for the client's air bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local DeepWater = require(ReplicatedStorage.Shared.DeepWater)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Oxygen = {}

local TICK = 0.25
local air: { [Player]: number } = {}
local warned: { [Player]: boolean } = {}

local function plaza(): CFrame
	local center = ReefConfig.Lagoon.center
	return CFrame.lookAt(center + Vector3.new(0, 4, 10), center + Vector3.new(0, 4, 30))
end

local function step(player: Player)
	local profile = PlayerData.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end
	local capacity = ReefConfig.oxygenCapacity(profile.data.gear.oxygen or 0)
	local left = air[player] or capacity
	if DeepWater.isDeep(root.Position) then
		left -= TICK
	else
		left = math.min(capacity, left + ReefConfig.Oxygen.refillPerSecond * TICK)
		warned[player] = nil
	end
	if left <= capacity * 0.25 and not warned[player] then
		warned[player] = true
		Remotes.Notify:FireClient(player, "Your air is running low! Swim back up and out to breathe.", "bad")
	end
	if left <= 0 then
		left = capacity
		warned[player] = nil
		character:PivotTo(plaza())
		Remotes.Notify:FireClient(player, "You ran out of air! A friendly whirlpool carried you back to the plaza. A bigger Oxygen Tank lets you stay down longer.", "bad")
	end
	air[player] = left
	local shown = math.floor(left * 10 + 0.5) / 10
	if player:GetAttribute("Oxygen") ~= shown then
		player:SetAttribute("Oxygen", shown)
	end
	if player:GetAttribute("OxygenMax") ~= capacity then
		player:SetAttribute("OxygenMax", capacity)
	end
end

function Oxygen.start()
	Players.PlayerRemoving:Connect(function(player)
		air[player] = nil
		warned[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				step(player)
			end
		end
	end)
end

return Oxygen

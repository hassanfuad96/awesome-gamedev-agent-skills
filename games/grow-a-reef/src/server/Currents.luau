--!nonstrict
-- Ocean currents: every few minutes a current flows along the row of reefs. While it
-- flows, a fully grown mutated coral can pass its mutation to an un-mutated coral on the
-- next occupied reef downstream (the last reef wraps around to the first).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local World = require(script.Parent.World)
local Plots = require(script.Parent.Plots)

local Currents = {}

local rng = Random.new()

local function occupiedOwners(): { Player }
	local owners: { Player } = {}
	for index = 1, Plots.count() do
		local owner = Plots.ownerOf(index)
		if owner then
			table.insert(owners, owner)
		end
	end
	return owners
end

local function spreadOnce()
	local owners = occupiedOwners()
	if #owners < 2 then
		return
	end
	for i, source in owners do
		if rng:NextNumber() < ReefConfig.Current.spreadChance then
			local mutated = {}
			for _, coral in Plots.readyCorals(source) do
				if coral.mutation ~= "None" then
					table.insert(mutated, coral)
				end
			end
			local target = owners[i % #owners + 1]
			local candidates = Plots.unmutatedPlants(target)
			if #mutated > 0 and #candidates > 0 then
				local from = mutated[rng:NextInteger(1, #mutated)]
				local plantId = candidates[rng:NextInteger(1, #candidates)]
				if Plots.setMutation(target, plantId, from.mutation) then
					Plots.notify(target, `The current carried a {from.mutation} mutation from {source.DisplayName}'s reef onto your coral!`, "rare")
					Plots.notify(source, `Your {from.mutation} coral drifted onto {target.DisplayName}'s reef.`)
				end
			end
		end
	end
end

function Currents.start(worldParts: World.WorldParts)
	local stream = worldParts.currentStream
	Workspace:SetAttribute("NextCurrentAt", Workspace:GetServerTimeNow() + ReefConfig.Current.interval)

	task.spawn(function()
		while true do
			task.wait(ReefConfig.Current.interval)
			local endsAt = Workspace:GetServerTimeNow() + ReefConfig.Current.duration
			Workspace:SetAttribute("CurrentEndsAt", endsAt)
			stream.Enabled = true
			for _, player in Players:GetPlayers() do
				Plots.notify(player, "An ocean current is flowing! Mutations can drift between reefs.", "rare")
			end

			local ticks = math.max(1, math.floor(ReefConfig.Current.duration / ReefConfig.Current.tick))
			for _ = 1, ticks do
				task.wait(ReefConfig.Current.tick)
				spreadOnce()
			end

			stream.Enabled = false
			Workspace:SetAttribute("CurrentEndsAt", nil)
			Workspace:SetAttribute("NextCurrentAt", Workspace:GetServerTimeNow() + ReefConfig.Current.interval)
		end
	end)
end

return Currents

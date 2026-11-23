--!nonstrict
-- Ocean currents, one of the sea events (Events schedules it and shows the stream). While a
-- current flows, a fully grown mutated coral can pass its mutation to an un-mutated coral on
-- the next occupied reef downstream (the last reef wraps around to the first).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
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

-- One spread attempt per reef; Events calls this every ReefConfig.Current.tick seconds.
function Currents.spreadOnce()
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

return Currents

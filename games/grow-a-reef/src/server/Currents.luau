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
			-- One mutation at a time drifts across, onto a coral that can still take it, so
			-- a neighbour's Golden can stack onto your Glowing.
			local target = owners[i % #owners + 1]
			local offers = {}
			for _, coral in Plots.readyCorals(source) do
				for _, mutationId in ReefConfig.mutationParts(coral.mutation) do
					local takers = Plots.plantsAccepting(target, mutationId)
					if #takers > 0 then
						table.insert(offers, { mutationId = mutationId, takers = takers })
					end
				end
			end
			if #offers > 0 then
				local offer = offers[rng:NextInteger(1, #offers)]
				local plantId = offer.takers[rng:NextInteger(1, #offer.takers)]
				local key = Plots.addMutation(target, plantId, offer.mutationId)
				if key then
					local label = table.concat(ReefConfig.mutationParts(key), " + ")
					local multiplier = ReefConfig.mutationMultiplier(key)
					Plots.notify(target, `The current carried {offer.mutationId} from {source.DisplayName}'s reef onto your coral! It's now {label} (x{multiplier}).`, "rare")
					Plots.notify(source, `Your {offer.mutationId} drifted onto {target.DisplayName}'s reef.`)
				end
			end
		end
	end
end

return Currents

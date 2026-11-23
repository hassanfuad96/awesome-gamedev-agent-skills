--!nonstrict
-- Which sea event is running, and the modifiers it applies to other systems. Events sets
-- `active`; Plots and Fish read the modifiers. (A separate module so Plots and Fish don't
-- have to require Events, which requires them.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local EventState = {
	active = nil :: string?, -- an id from ReefConfig.Events.list
}

-- Bioluminescent Night: the same mutation table with Glowing made more likely.
local nightMutations = {}
for i, mutation in ReefConfig.Mutations do
	if mutation.id == "Glowing" then
		local boosted = table.clone(mutation)
		boosted.weight *= ReefConfig.Events.glowingMultiplier
		nightMutations[i] = boosted
	else
		nightMutations[i] = mutation
	end
end

-- The weights a newly planted coral rolls its mutation from.
function EventState.mutationWeights(): { ReefConfig.MutationDef }
	return if EventState.active == "Night" then nightMutations else ReefConfig.Mutations
end

-- How fast the fish spawn clock runs (Feeding Frenzy speeds it up).
function EventState.fishSpawnMultiplier(): number
	return if EventState.active == "Frenzy" then ReefConfig.Events.fishSpawnMultiplier else 1
end

return EventState

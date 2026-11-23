--!nonstrict
-- Where the water is deep enough that divers use up air (ReefConfig.Oxygen): inside the Main
-- Reef's caves and the Grand Reef Rock's grotto, inside the Sunken Ruins' cave, and down in
-- the Abyss below y = -15, except in its air pockets. Everywhere else you breathe freely.
-- Shared so the server (Oxygen) and the client's air bar agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ReefConfig = require(Shared.ReefConfig)
local RuinsConfig = require(Shared.RuinsConfig)
local AbyssConfig = require(Shared.AbyssConfig)

local DeepWater = {}

local ABYSS_DEPTH = -15 -- the Abyss pit counts as deep below this height (its ramp doesn't)
local CAVE_WIDTH, CAVE_HEIGHT = 7, 11 -- half width and height of a Main Reef cave's inside

-- Each Main Reef cave as (frame at the mouth, -Z pointing in; depth), as MainReef builds them.
local caves: { { frame: CFrame, depth: number } } = {}
for _, cave in ReefConfig.MainReef.caves do
	table.insert(caves, { frame = CFrame.lookAt(cave.mouth, cave.mouth + cave.into), depth = 24 })
end
do
	local rock = ReefConfig.MainReef.grandRock
	table.insert(caves, { frame = CFrame.lookAt(rock + Vector3.new(26, 0, 0), rock), depth = 14 })
end

local function inMainReefCave(point: Vector3): boolean
	for _, cave in caves do
		local p = cave.frame:PointToObjectSpace(point)
		if math.abs(p.X) < CAVE_WIDTH and p.Y < CAVE_HEIGHT and p.Z < -2 and p.Z > -(cave.depth + 3) then
			return true
		end
	end
	return false
end

local function inAbyssDeep(point: Vector3): boolean
	if not (AbyssConfig.inPit and AbyssConfig.inPit(point)) or point.Y >= ABYSS_DEPTH then
		return false
	end
	return not (AbyssConfig.inAirPocket and AbyssConfig.inAirPocket(point))
end

-- Whether a diver at `point` is using up air.
function DeepWater.isDeep(point: Vector3): boolean
	return inMainReefCave(point) or (RuinsConfig.inCave ~= nil and RuinsConfig.inCave(point)) or inAbyssDeep(point)
end

return DeepWater

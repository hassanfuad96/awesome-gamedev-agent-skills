--!nonstrict
-- Volcano Vent, one of the sea events: a volcano rises out past the lagoon and throws lava
-- rocks in arcs onto every reef's fully grown coral. A rock that hits can turn its coral
-- Molten (ReefConfig.Volcano.moltenChance), if the coral has room for another mutation.
-- When the event ends the volcano sinks back into the seabed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Plots = require(script.Parent.Plots)
local EventVisuals = require(script.Parent.EventVisuals)

local Volcano = {}

local SETTINGS = ReefConfig.Volcano
local MOLTEN = ReefConfig.MutationById.Molten.color or Color3.new(1, 0.5, 0.2)

local rng = Random.new()
local folder: Folder? = nil
local crater: BasePart? = nil
local runId = 0

-- Moves the volcano's pivot from `from` to `to` over `seconds`.
local function slide(model: Model, from: CFrame, to: CFrame, seconds: number, myRun: number)
	local started = os.clock()
	while model.Parent and runId == myRun do
		local t = math.min(1, (os.clock() - started) / seconds)
		model:PivotTo(from:Lerp(to, t * t * (3 - 2 * t)))
		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- Throws one lava rock from the crater to `target` along a high arc; onLand runs where it hits.
local function throw(target: Vector3, onLand: (() -> ())?)
	local from = crater and crater.Position
	if not from or not folder then
		return
	end
	local rock = EventVisuals.lavaRock()
	rock.Position = from
	rock.Parent = folder
	local distance = (target - from).Magnitude
	local seconds = math.max(2, distance / SETTINGS.rockSpeed)
	local peak = (from + target) / 2 + Vector3.new(0, math.max(from.Y, target.Y) + distance * 0.3, 0)
	task.spawn(function()
		local started = os.clock()
		while rock.Parent do
			local t = math.min(1, (os.clock() - started) / seconds)
			-- A quadratic Bezier curve: up out of the crater, over, and down onto the target.
			local a = from:Lerp(peak, t)
			local b = peak:Lerp(target, t)
			rock.Position = a:Lerp(b, t)
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		rock:Destroy()
		EventVisuals.burst(target + Vector3.new(0, 1, 0), MOLTEN, 30)
		EventVisuals.sound(target, "lava")
		if onLand then
			onLand()
		end
	end)
end

-- One volley: a rock at a random grown coral on every reef, plus one into the plaza for show.
function Volcano.volley()
	for _, player in Players:GetPlayers() do
		local ready = Plots.readyCorals(player)
		if #ready > 0 then
			local coral = ready[rng:NextInteger(1, #ready)]
			throw(coral.position, function()
				if rng:NextNumber() >= SETTINGS.moltenChance or not player.Parent then
					return
				end
				local key = Plots.addMutation(player, coral.plantId, "Molten")
				if key then
					Plots.notify(player, `A lava rock hit your coral: {ReefConfig.displayName(coral.seed, key)} (x{ReefConfig.mutationMultiplier(key)})!`, "rare")
				end
			end)
		end
	end
	local lagoon = ReefConfig.Lagoon
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(lagoon.plazaRadius * 0.6, lagoon.plazaRadius * 1.8)
	throw(lagoon.center + Vector3.new(math.cos(angle) * distance, 0.5, math.sin(angle) * distance), nil)
end

function Volcano.start()
	runId += 1
	local myRun = runId
	local newFolder = Instance.new("Folder")
	newFolder.Name = "VolcanoVent"
	newFolder.Parent = Workspace
	folder = newFolder
	local rest = CFrame.new(SETTINGS.vent)
	local model, newCrater = EventVisuals.volcano(rest, SETTINGS.height)
	crater = newCrater
	local sunk = rest * CFrame.new(0, -SETTINGS.height - 4, 0)
	model:PivotTo(sunk)
	model.Parent = newFolder
	task.spawn(slide, model, sunk, rest, SETTINGS.riseSeconds, myRun)
end

function Volcano.stop()
	runId += 1
	local myRun = runId
	local oldFolder = folder
	folder = nil
	crater = nil
	if not oldFolder then
		return
	end
	local model = oldFolder:FindFirstChild("Volcano") :: Model?
	task.spawn(function()
		if model then
			local at = model:GetPivot()
			slide(model, at, at * CFrame.new(0, -SETTINGS.height - 4, 0), SETTINGS.riseSeconds, myRun)
		end
		task.wait(3) -- let rocks still in the air land
		oldFolder:Destroy()
	end)
end

return Volcano

--!nonstrict
-- Giant Octopus, one of the sea events: a huge octopus hovers over the plaza and everyone taps
-- it (a ClickDetector, so mouse and touch both work; the server counts the hits and limits how
-- fast each player can land them). Its health grows with the number of players. Beat it
-- before the event ends and everyone who landed at least ReefConfig.Octopus.minHits hits wins
-- shells and seeds. The HUD line and the on-screen bar (EventBars) read the OctopusHealth /
-- OctopusMaxHealth Workspace attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local EventVisuals = require(script.Parent.EventVisuals)

local GiantOctopus = {}

local SETTINGS = ReefConfig.Octopus
local INK = Color3.fromRGB(60, 30, 70)

local rng = Random.new()
local model: Model? = nil
local hits: { [Player]: number } = {}
local lastHit: { [Player]: number } = {}
local health = 0
local defeated = false
local runId = 0

local function notifyAll(text: string, tone: string)
	for _, player in Players:GetPlayers() do
		Plots.notify(player, text, tone)
	end
end

local function setHealthAttributes(current: number?, maximum: number?)
	Workspace:SetAttribute("OctopusHealth", current)
	Workspace:SetAttribute("OctopusMaxHealth", maximum)
end

local function reward(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local data = profile.data
	local shells = math.floor(SETTINGS.shells * math.max(1, data.unlocked / 10))
	PlayerData.addShells(player, shells)
	local parts = { `{EconomyMath.formatNumber(shells)} shells` }
	local seeds = table.clone(SETTINGS.seeds)
	if rng:NextNumber() < SETTINGS.starChance then
		table.insert(seeds, { id = "star", count = 1 })
	end
	for _, gift in seeds do
		local seed = ReefConfig.Seeds[gift.id]
		if seed then
			data.seeds[gift.id] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, (data.seeds[gift.id] or 0) + gift.count)
			table.insert(parts, `{gift.count} {seed.name}`)
		end
	end
	Plots.notify(player, `You helped beat the Giant Octopus! +{table.concat(parts, ", ")}`, "rare")
	PlayerData.sync(player)
end

-- The octopus floats away upwards and is removed.
local function leave(octopus: Model)
	task.spawn(function()
		local from = octopus:GetPivot()
		local started = os.clock()
		while octopus.Parent and os.clock() - started < 4 do
			local t = (os.clock() - started) / 4
			octopus:PivotTo(from * CFrame.new(0, t * t * 60, 0))
			RunService.Heartbeat:Wait()
		end
		octopus:Destroy()
	end)
end

-- onDefeated is called once if the players win, so the event can end early.
function GiantOctopus.start(onDefeated: (() -> ())?)
	runId += 1
	local myRun = runId
	hits = {}
	lastHit = {}
	defeated = false
	local maximum = SETTINGS.baseHealth + SETTINGS.healthPerPlayer * #Players:GetPlayers()
	health = maximum
	local home = CFrame.new(ReefConfig.Lagoon.center + SETTINGS.hover)
	local octopus, body = EventVisuals.octopus(home * CFrame.new(0, 60, 0))
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = SETTINGS.clickRange
	click.Parent = octopus
	for _, part in octopus:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			part.CanQuery = true -- clickable
		end
	end
	octopus.Parent = Workspace
	model = octopus
	setHealthAttributes(health, maximum)

	click.MouseClick:Connect(function(player)
		if defeated or runId ~= myRun then
			return
		end
		local now = os.clock()
		if now - (lastHit[player] or 0) < 1 / SETTINGS.hitsPerSecond then
			return
		end
		lastHit[player] = now
		hits[player] = (hits[player] or 0) + 1
		health -= 1
		setHealthAttributes(math.max(0, health), maximum)
		if rng:NextNumber() < 0.3 then
			EventVisuals.burst(body.Position + Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-4, 4), -7), INK, 8)
		end
		if health <= 0 then
			defeated = true
			EventVisuals.burst(body.Position, INK, 80)
			local winners = 0
			for helper, count in hits do
				if count >= SETTINGS.minHits and helper.Parent then
					winners += 1
					reward(helper)
				end
			end
			notifyAll(`The Giant Octopus fled in a cloud of ink! {winners} diver{if winners == 1 then "" else "s"} won prizes.`, "rare")
			leave(octopus)
			model = nil
			if onDefeated then
				task.delay(3, onDefeated)
			end
		end
	end)

	-- Drop in from above, then bob and sway until the event ends.
	task.spawn(function()
		local started = os.clock()
		while octopus.Parent and model == octopus and runId == myRun do
			local t = os.clock() - started
			local drop = math.max(0, 1 - t / 3)
			local bob = math.sin(t * 1.3) * 2
			local sway = math.sin(t * 0.6) * 0.25
			octopus:PivotTo(home * CFrame.new(0, 60 * drop * drop + bob, 0) * CFrame.Angles(0, sway, math.sin(t * 0.9) * 0.05))
			RunService.Heartbeat:Wait()
		end
	end)
end

function GiantOctopus.stop()
	runId += 1
	if model and not defeated then
		notifyAll("The Giant Octopus got away! Tap it faster next time.", "bad")
		leave(model)
	end
	model = nil
	setHealthAttributes(nil, nil)
end

return GiantOctopus

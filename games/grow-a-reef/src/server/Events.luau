--!nonstrict
-- Sea events: every few minutes one event runs, picked at random by weight and never the
-- same twice in a row (ReefConfig.Events). Clients follow along through Workspace
-- attributes: NextEventAt while waiting; EventId, EventStartedAt and EventEndsAt while one
-- runs. The HUD shows the timer, SeaLife draws the Whale Pass whale and OceanEffects turns
-- the specks into glowing plankton at night; everything that changes the game runs here.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local Plots = require(script.Parent.Plots)
local EventState = require(script.Parent.EventState)
local Currents = require(script.Parent.Currents)
local TreasureStorm = require(script.Parent.TreasureStorm)

type Handler = {
	start: (() -> ())?,
	stop: (() -> ())?,
	every: number?, -- seconds between ticks while the event runs
	tick: (() -> ())?,
}

local Events = {}

local SETTINGS = ReefConfig.Events
local FADE = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local rng = Random.new()
local forced: string? = nil

local function notifyAll(text: string, tone: string)
	for _, player in Players:GetPlayers() do
		Plots.notify(player, text, tone)
	end
end

-- Bioluminescent Night darkens the sea so glowing coral, jellyfish and chests stand out.
-- Each Instance's day values are read when night falls and put back at dawn.
local function nightLighting(worldParts: World.WorldParts): Handler
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local tint = Lighting:FindFirstChild("UnderwaterTint")
	local bloom = Lighting:FindFirstChild("CoralGlow")
	local night = {
		{ Lighting, { Brightness = 0.4, Ambient = Color3.fromRGB(12, 22, 45), OutdoorAmbient = Color3.fromRGB(18, 32, 65) } },
		{ atmosphere, { Color = Color3.fromRGB(15, 40, 80), Decay = Color3.fromRGB(5, 15, 40) } },
		{ tint, { TintColor = Color3.fromRGB(150, 190, 255) } },
		{ bloom, { Intensity = 1.2, Threshold = 0.9 } },
		{ worldParts.surface, { Color = Color3.fromRGB(25, 55, 95) } },
	}
	for _, shaft in worldParts.lightShafts do
		table.insert(night, { shaft, { Transparency = 1 } })
	end
	local day = {}
	return {
		start = function()
			for i, entry in night do
				local instance, goal = entry[1], entry[2]
				if instance then
					day[i] = {}
					for property in goal do
						day[i][property] = (instance :: any)[property]
					end
					TweenService:Create(instance, FADE, goal):Play()
				end
			end
		end,
		stop = function()
			for i, entry in night do
				if entry[1] and day[i] then
					TweenService:Create(entry[1], FADE, day[i]):Play()
				end
			end
		end,
	}
end

local function pick(lastId: string?): ReefConfig.EventDef
	local choices = {}
	for _, event in SETTINGS.list do
		if event.id ~= lastId then
			table.insert(choices, event)
		end
	end
	local id = EconomyMath.pickWeighted(choices, rng:NextNumber())
	return ReefConfig.EventById[id]
end

local function run(event: ReefConfig.EventDef, handler: Handler)
	local now = Workspace:GetServerTimeNow()
	EventState.active = event.id
	Workspace:SetAttribute("NextEventAt", nil)
	Workspace:SetAttribute("EventId", event.id)
	Workspace:SetAttribute("EventStartedAt", now)
	Workspace:SetAttribute("EventEndsAt", now + event.duration)
	notifyAll(event.message, "rare")
	if handler.start then
		handler.start()
	end

	local elapsed = 0
	while elapsed < event.duration do
		local step = math.min(handler.every or event.duration, event.duration - elapsed)
		task.wait(step)
		elapsed += step
		if handler.tick then
			handler.tick()
		end
	end

	if handler.stop then
		handler.stop()
	end
	EventState.active = nil
	Workspace:SetAttribute("EventId", nil)
	Workspace:SetAttribute("EventStartedAt", nil)
	Workspace:SetAttribute("EventEndsAt", nil)
	notifyAll(`{event.name} is over.`, "info")
end

function Events.start(worldParts: World.WorldParts)
	TreasureStorm.start()
	local stream = worldParts.currentStream
	local streamColor = stream.Color
	-- Night darkens the sea and, while it lasts, grown coral can turn Shadow.
	local night = nightLighting(worldParts)
	night.every = SETTINGS.mutationTick
	night.tick = function()
		Plots.mutateAll("Shadow", SETTINGS.shadowChance)
	end
	local handlers: { [string]: Handler } = {
		Current = {
			start = function()
				stream.Enabled = true
			end,
			stop = function()
				stream.Enabled = false
			end,
			every = ReefConfig.Current.tick,
			tick = Currents.spreadOnce,
		},
		Cold = {
			start = function()
				stream.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
				stream.Enabled = true
			end,
			stop = function()
				stream.Enabled = false
				stream.Color = streamColor
			end,
			every = SETTINGS.mutationTick,
			tick = function()
				Plots.mutateAll("Frosted", SETTINGS.frostChance)
			end,
		},
		Night = night,
		Frenzy = {}, -- Fish reads EventState.fishSpawnMultiplier()
		Treasure = { every = SETTINGS.treasure.every, tick = TreasureStorm.dropChest },
		Whale = {
			every = 1,
			tick = function()
				-- Each second of the pass counts as growthMultiplier seconds of growth.
				Plots.boostGrowth(SETTINGS.growthMultiplier - 1)
			end,
		},
	}

	-- In Studio, set Workspace's DebugSeaEvent attribute to an event id (from the Command
	-- Bar, in the server view) to start that event now instead of waiting.
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("DebugSeaEvent"):Connect(function()
			local id = Workspace:GetAttribute("DebugSeaEvent")
			if type(id) == "string" and ReefConfig.EventById[id] then
				forced = id
				Workspace:SetAttribute("DebugSeaEvent", nil)
			end
		end)
	end

	task.spawn(function()
		local lastId: string? = nil
		while true do
			local nextAt = Workspace:GetServerTimeNow() + SETTINGS.interval
			Workspace:SetAttribute("NextEventAt", nextAt)
			while not forced and Workspace:GetServerTimeNow() < nextAt do
				task.wait(0.5)
			end
			local event = if forced then ReefConfig.EventById[forced] else pick(lastId)
			forced = nil
			run(event, handlers[event.id] or {})
			lastId = event.id
		end
	end)
end

return Events

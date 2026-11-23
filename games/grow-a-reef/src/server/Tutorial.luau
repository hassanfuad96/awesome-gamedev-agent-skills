--!nonstrict
-- The Starter Lagoon tutorial (ReefConfig.Tutorial). Every new player starts on step 1 and
-- Inky, the octopus by the spawn, walks them through: collect a seed, plant it, earn shells,
-- catch a fish, and find the Upgrade Station. The step is saved in data.tutorial; one past
-- the last step means done.
--   Tutorial.progress(player, action)  other systems report what the player did (Quests
--                                      forwards everything it is told)
--   Tutorial.isOn(player, action)      whether that action is the player's current step

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Tutorial = {}

local SETTINGS = ReefConfig.Tutorial
local rng = Random.new()

local function guideSays(player: Player, text: string)
	Remotes.GuideLine:FireClient(player, text)
end

local function currentStep(player: Player): (PlayerData.Profile?, ReefConfig.TutorialStep?)
	local profile = PlayerData.get(player)
	if not profile then
		return nil, nil
	end
	return profile, ReefConfig.tutorialStep(profile.data.tutorial)
end

function Tutorial.isOn(player: Player, action: string): boolean
	local _, step = currentStep(player)
	return step ~= nil and step.action == action
end

-- Moves the player on when `action` is their current step. The caller syncs afterwards,
-- except for the guide and Upgrade Station, which sync here.
function Tutorial.progress(player: Player, action: string)
	local profile, step = currentStep(player)
	if not profile or not step or step.action ~= action then
		return
	end
	local data = profile.data
	data.tutorial += 1
	local nextStep = ReefConfig.tutorialStep(data.tutorial)
	if nextStep then
		Remotes.Notify:FireClient(player, `Done: {step.title}! Next: {nextStep.title}.`, "good")
		guideSays(player, nextStep.inky)
	else
		PlayerData.addShells(player, SETTINGS.reward)
		Remotes.Notify:FireClient(player, `Starter Lagoon complete! +{EconomyMath.formatNumber(SETTINGS.reward)} shells`, "rare")
		guideSays(player, "You did it! You know everything you need. Go grow the best reef in the sea!")
	end
end

-- Talking to Inky: the first step hands over the starter seeds; after that Inky repeats
-- what to do next, or shares a tip once the tutorial is done.
local function talkToGuide(player: Player)
	local profile, step = currentStep(player)
	if not profile then
		return
	end
	if step and step.action == "guide" then
		local data = profile.data
		for seedId, count in SETTINGS.firstSeeds do
			data.seeds[seedId] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, (data.seeds[seedId] or 0) + count)
			profile.selected = profile.selected or seedId
		end
		guideSays(player, step.inky)
		Tutorial.progress(player, "guide")
		PlayerData.sync(player)
	elseif step then
		guideSays(player, step.inky)
	else
		guideSays(player, SETTINGS.doneLines[rng:NextInteger(1, #SETTINGS.doneLines)])
	end
end

function Tutorial.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local kind = prompt:GetAttribute("Kind")
		if kind == "Guide" then
			if RateLimit.consume(player) then
				talkToGuide(player)
			end
		elseif kind == "Supplies" and Tutorial.isOn(player, "upgrade") then
			Tutorial.progress(player, "upgrade")
			PlayerData.sync(player)
		end
	end)
end

return Tutorial

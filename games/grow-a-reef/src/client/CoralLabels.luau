--!nonstrict
-- Floating labels over planted coral: name, mutation, growth stage and countdown, all read from
-- Attributes the server sets on each coral model (tagged ReefConfig.CORAL_TAG). Built on the
-- client only, and tolerant of instance streaming (coral comes and goes as the player moves).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Ui = require(script.Parent.Ui)

local CoralLabels = {}

type Label = { gui: BillboardGui, title: TextLabel, status: TextLabel }

local labels: { [Model]: Label } = {}

local function makeLabel(root: BasePart, playerGui: PlayerGui): Label
	local gui = Ui.new("BillboardGui", {
		Name = "CoralLabel",
		Adornee = root,
		-- Narrower than the 5-stud coral spacing, so neighbouring labels don't overlap.
		Size = UDim2.new(4.6, 0, 1.5, 0),
		StudsOffset = Vector3.new(0, 7, 0),
		MaxDistance = 70,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local title = Ui.label({
		Name = "Title",
		Font = Ui.TitleFont,
		Size = UDim2.fromScale(1, 0.55),
		TextStrokeTransparency = 0.3,
		MaxTextSize = 40,
		Text = "",
		Parent = gui,
	})
	local status = Ui.label({
		Name = "Status",
		Position = UDim2.fromScale(0, 0.55),
		Size = UDim2.fromScale(1, 0.45),
		TextStrokeTransparency = 0.3,
		MaxTextSize = 32,
		Text = "",
		Parent = gui,
	})
	return { gui = gui, title = title, status = status }
end

local function refresh(coral: Model, label: Label, now: number)
	local seed = ReefConfig.Seeds[coral:GetAttribute("Seed")]
	if not seed then
		label.gui.Enabled = false
		return
	end
	local plot = coral.Parent
	local mine = plot ~= nil and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
	local mutationKey = coral:GetAttribute("Mutation")
	if not ReefConfig.isMutationKey(mutationKey) then
		mutationKey = "None"
	end
	local first = ReefConfig.MutationById[ReefConfig.mutationParts(mutationKey)[1]]
	local readyAt = coral:GetAttribute("ReadyAt")
	label.gui.Enabled = true
	label.title.Text = ReefConfig.displayName(coral:GetAttribute("Seed"), mutationKey)
	label.title.TextColor3 = if first then first.color or Ui.Colors.rare else Ui.Colors.text
	if type(readyAt) == "number" and readyAt > now then
		-- The growth stage (Seedling, Growing) and how long until it's ready.
		local stage = ReefConfig.STAGE_NAMES[coral:GetAttribute("Stage") or 0]
		label.status.Text = if stage then `{stage} · {Ui.formatTime(readyAt - now)}` else Ui.formatTime(readyAt - now)
		label.status.TextColor3 = Ui.Colors.muted
	else
		label.status.Text = if mine then "Ready! Click to harvest" else "Ready!"
		label.status.TextColor3 = Ui.Colors.good
	end
end

function CoralLabels.start(playerGui: PlayerGui)
	local function track(instance: Instance)
		if not instance:IsA("Model") or labels[instance] then
			return
		end
		-- A newly planted coral's tag reaches the client before its parts do.
		task.spawn(function()
			local root = instance:WaitForChild("Root", 10)
			if root and root:IsA("BasePart") and instance:HasTag(ReefConfig.CORAL_TAG) and not labels[instance] then
				labels[instance] = makeLabel(root, playerGui)
			end
		end)
	end
	local function untrack(instance: Instance)
		local label = labels[instance :: Model]
		if label then
			label.gui:Destroy()
			labels[instance :: Model] = nil
		end
	end
	for _, coral in CollectionService:GetTagged(ReefConfig.CORAL_TAG) do
		track(coral)
	end
	CollectionService:GetInstanceAddedSignal(ReefConfig.CORAL_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(ReefConfig.CORAL_TAG):Connect(untrack)

	task.spawn(function()
		while true do
			local now = Workspace:GetServerTimeNow()
			for coral, label in labels do
				refresh(coral, label, now)
			end
			task.wait(0.25)
		end
	end)
end

return CoralLabels

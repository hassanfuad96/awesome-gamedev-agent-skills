--!nonstrict
-- Floating labels over reef tiles: coral name, mutation and a growth countdown, all read
-- from Attributes the server sets on each tile. Built on the client only, and tolerant of
-- instance streaming (tiles can appear and disappear as the player moves).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Ui = require(script.Parent.Ui)

local TileLabels = {}

type Label = { gui: BillboardGui, title: TextLabel, status: TextLabel }

local labels: { [BasePart]: Label } = {}

local function makeLabel(tile: BasePart, playerGui: PlayerGui): Label
	local gui = Ui.new("BillboardGui", {
		Name = "TileLabel",
		Adornee = tile,
		Size = UDim2.new(7, 0, 2, 0),
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

local function isTile(instance: Instance): boolean
	return instance:IsA("BasePart") and instance:GetAttribute("TileIndex") ~= nil
end

local function refresh(tile: BasePart, label: Label, now: number)
	local seedId = tile:GetAttribute("Seed")
	local plot = tile.Parent
	local mine = plot ~= nil and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId

	if type(seedId) == "string" and ReefConfig.Seeds[seedId] then
		local seed = ReefConfig.Seeds[seedId]
		local mutationId = tile:GetAttribute("Mutation")
		local mutation = if type(mutationId) == "string" then ReefConfig.MutationById[mutationId] else nil
		local readyAt = tile:GetAttribute("ReadyAt")
		label.gui.Enabled = true
		if mutation and mutation.id ~= "None" then
			label.title.Text = `{mutation.id} {seed.name}`
			label.title.TextColor3 = mutation.color or Ui.Colors.rare
		else
			label.title.Text = seed.name
			label.title.TextColor3 = Ui.Colors.text
		end
		if type(readyAt) == "number" and readyAt > now then
			label.status.Text = Ui.formatTime(readyAt - now)
			label.status.TextColor3 = Ui.Colors.muted
		else
			label.status.Text = if mine then "Ready! Click to harvest" else "Ready!"
			label.status.TextColor3 = Ui.Colors.good
		end
	elseif mine and tile:GetAttribute("Locked") == true then
		label.gui.Enabled = true
		label.title.Text = "Locked"
		label.title.TextColor3 = Ui.Colors.muted
		label.status.Text = "Expand at the Seed Shop"
		label.status.TextColor3 = Ui.Colors.muted
	else
		label.gui.Enabled = false
	end
end

function TileLabels.start(playerGui: PlayerGui)
	local reef = Workspace:WaitForChild("Reef")
	local plotsFolder = reef:WaitForChild("Plots")

	local function track(instance: Instance)
		if isTile(instance) and not labels[instance :: BasePart] then
			labels[instance :: BasePart] = makeLabel(instance :: BasePart, playerGui)
		end
	end
	for _, descendant in plotsFolder:GetDescendants() do
		track(descendant)
	end
	plotsFolder.DescendantAdded:Connect(track)
	plotsFolder.DescendantRemoving:Connect(function(instance)
		local label = labels[instance :: any]
		if label then
			label.gui:Destroy()
			labels[instance :: any] = nil
		end
	end)

	task.spawn(function()
		while true do
			local now = Workspace:GetServerTimeNow()
			for tile, label in labels do
				refresh(tile, label, now)
			end
			task.wait(0.25)
		end
	end)
end

return TileLabels

--!nonstrict
-- The Starter Lagoon tutorial tracker: a card under the top bar with the current step, and
-- a glowing beam plus a marker over the place to go next (Inky, your reef, the Coral Shop or
-- the Upgrade Station). Only shows what the server synced (data.tutorial); the server
-- decides when a step is done (Tutorial).
-- Landmark positions come from attributes on Workspace.Reef, which reach every client even
-- when the buildings themselves haven't streamed in yet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Ui = require(script.Parent.Ui)

local TutorialPanel = {}

local GLOW = Color3.fromRGB(255, 214, 90)
local ARRIVED = 16 -- studs: close enough that the marker and beam step aside
local ON_REEF = ReefConfig.moundRadius() -- for "your reef": anywhere on the mound counts
local player = Players.LocalPlayer

local card: Frame
local stepLabel: TextLabel
local titleLabel: TextLabel
local hintLabel: TextLabel
local anchor: Part -- invisible, sits where the player should go
local marker: BillboardGui
local markerText: TextLabel
local beam: Beam
local rootAttachment: Attachment?
local data: any = nil

-- Where the current step wants the player, what to call it, and how close counts as there.
local function target(): (Vector3?, string?, number)
	local step = data and ReefConfig.tutorialStep(data.tutorial)
	local reef = Workspace:FindFirstChild("Reef")
	if not step or not reef then
		return nil, nil, ARRIVED
	end
	local function home(): Vector3?
		local index = player:GetAttribute("PlotIndex")
		return index and reef:GetAttribute(`PlotHome_{index}`)
	end
	if step.action == "guide" then
		return reef:GetAttribute("Landmark_Guide"), "Inky", ARRIVED
	elseif step.action == "plant" or step.action == "fish" then
		return home(), "Your reef", ON_REEF
	elseif step.action == "sell" then
		-- Harvest first; once the bag has coral in it, head to Pinch.
		if (data.bagCount or 0) > 0 then
			return reef:GetAttribute("Landmark_Sell"), "Sell here", ARRIVED
		end
		return home(), "Your reef", ON_REEF
	elseif step.action == "upgrade" then
		return reef:GetAttribute("Landmark_Upgrade"), "Upgrade Station", ARRIVED
	end
	return nil, nil, ARRIVED
end

local function attachToCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialBeam"
	attachment.Position = Vector3.new(0, -1.5, 0)
	attachment.Parent = root
	rootAttachment = attachment
	beam.Attachment0 = attachment
end

local function build(playerGui: PlayerGui)
	local gui = Ui.new("ScreenGui", {
		Name = "TutorialGui",
		ResetOnSpawn = false,
		DisplayOrder = -1, -- under the shop windows and toasts
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	-- Top right, beside the shells bar: the left side has the side buttons, and on a phone
	-- they reach up to the top bar. The teleport buttons on the right sit lower down.
	card = Ui.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(290, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.Colors.panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.stroke(GLOW, 2),
		Ui.padding(10),
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	})
	stepLabel = Ui.label({
		Name = "Step",
		LayoutOrder = 1,
		Text = "",
		Font = Ui.TitleFont,
		MaxTextSize = 14,
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GLOW,
		Parent = card,
	})
	titleLabel = Ui.label({
		Name = "Title",
		LayoutOrder = 2,
		Text = "",
		Font = Ui.TitleFont,
		MaxTextSize = 20,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	hintLabel = Ui.new("TextLabel", {
		Name = "Hint",
		LayoutOrder = 3,
		Text = "",
		Font = Ui.BodyFont,
		TextSize = 14,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = card,
	})
	Ui.autoScale({ card })

	anchor = Instance.new("Part")
	anchor.Name = "TutorialTarget"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Parent = Workspace

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchor
	beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(GLOW)
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Segments = 1
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.15, 0.35),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	beam.Enabled = false
	beam.Parent = anchor

	marker = Ui.new("BillboardGui", {
		Name = "TutorialMarker",
		Adornee = anchor,
		Size = UDim2.fromOffset(160, 56),
		StudsOffset = Vector3.new(0, 9, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	markerText = Ui.label({
		Name = "Text",
		Text = "",
		Font = Ui.TitleFont,
		MaxTextSize = 18,
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = GLOW,
		TextStrokeTransparency = 0.3,
		Parent = marker,
	})
	-- A diamond pointing down at the spot.
	Ui.new("Frame", {
		Name = "Pin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 45,
		BackgroundColor3 = GLOW,
		Parent = marker,
	}, { Ui.corner(3), Ui.stroke(Color3.fromRGB(80, 50, 0), 2) })
end

function TutorialPanel.setData(newData: any)
	data = newData
	local step = data and ReefConfig.tutorialStep(data.tutorial)
	card.Visible = step ~= nil
	if step then
		stepLabel.Text = `STARTER LAGOON  ·  STEP {data.tutorial} OF {#ReefConfig.Tutorial.steps}`
		titleLabel.Text = step.title
		hintLabel.Text = step.hint
	end
end

function TutorialPanel.start(playerGui: PlayerGui)
	build(playerGui)
	player.CharacterAdded:Connect(attachToCharacter)
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.15 then
			return
		end
		elapsed = 0
		local position, name, arrived = target()
		local root = rootAttachment and rootAttachment.Parent :: BasePart?
		-- Flat distance, so swimming overhead doesn't count as arriving.
		local distance = if position and root then ((root.Position - position) * Vector3.new(1, 0, 1)).Magnitude else 0
		local show = position ~= nil and root ~= nil and distance > arrived
		beam.Enabled = show
		marker.Enabled = show
		if show then
			anchor.Position = position + Vector3.new(0, 1, 0)
			markerText.Text = `{name}  ·  {math.round(distance)}m`
		end
	end)
end

return TutorialPanel

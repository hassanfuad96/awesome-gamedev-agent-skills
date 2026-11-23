--!nonstrict
-- The Research Laboratory's window, opened at the Lab counter. Three tabs:
--   Species  research each coral species in turn (ResearchSpecies); researched species can
--            be bought in the Coral Market
--   Reef     unlock the next planter (ExpandReef: shells and pearls) and research faster
--            coral growth (the Fertilizer gear: UpgradeGear)
--   Health   how your reef is doing right now: planters in use, coral ready to harvest,
--            species variety and mutated coral, read from your reef's coral
-- Buttons send ids only; the server checks everything (Research, Supplies).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local LabPanel = {}
LabPanel.__index = LabPanel

type SpeciesRow = { detail: TextLabel, button: TextButton, mark: TextLabel }
type Meter = { fill: Frame, value: TextLabel }

export type LabPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		status: TextLabel,
		tabs: { [string]: TextButton },
		lists: { [string]: ScrollingFrame },
		tab: string,
		species: { [string]: SpeciesRow },
		planter: { detail: TextLabel, button: TextButton },
		growth: { detail: TextLabel, button: TextButton },
		meters: { [string]: Meter },
		verdict: TextLabel,
		data: any,
		stand: BasePart?,
	},
	LabPanel
))

local TABS = { { id = "species", text = "Species" }, { id = "reef", text = "Reef" }, { id = "health", text = "Reef Health" } }
local TEAL = Color3.fromRGB(80, 170, 200)
local METERS = {
	{ id = "planters", text = "Planters in use" },
	{ id = "ready", text = "Fully grown, ready to harvest" },
	{ id = "variety", text = "Species variety" },
	{ id = "mutated", text = "Mutated coral" },
}

local function row(parent: Instance, order: number, height: number): Frame
	return Ui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Ui.Colors.panelLight,
		Parent = parent,
	}, { Ui.corner(10) })
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	props.Parent = parent
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return Ui.label(props)
end

local function actionButton(parent: Instance, onClick: () -> ()): TextButton
	local button = Ui.button({
		Name = "Action",
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 52),
		BackgroundColor3 = TEAL,
		MaxTextSize = 15,
		Parent = parent,
	})
	button.Activated:Connect(onClick)
	return button
end

function LabPanel.new(playerGui: PlayerGui): LabPanel
	local gui = Ui.new("ScreenGui", { Name = "ResearchLabGui", ResetOnSpawn = false, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
	local root = Ui.new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Ui.Colors.panel,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(TEAL, 2), Ui.padding(12) })
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(600, 580))
	text(root, { Name = "Title", Text = "Research Laboratory", Font = Ui.TitleFont, MaxTextSize = 28, Size = UDim2.new(0.6, 0, 0, 34) })
	local status = text(root, {
		Name = "Status",
		Text = "",
		MaxTextSize = 16,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -50, 0, 6),
		Size = UDim2.new(0.4, -50, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Ui.Colors.rare,
	})
	local close = Ui.button({ Name = "Close", Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 36), BackgroundColor3 = Ui.Colors.bad, Parent = root })
	local tabBar = Ui.new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })

	local self = setmetatable({
		gui = gui,
		status = status,
		tabs = {},
		lists = {},
		tab = "species",
		species = {},
		planter = nil,
		growth = nil,
		meters = {},
		verdict = nil,
		data = nil,
		stand = nil,
	}, LabPanel)

	for order, tab in TABS do
		local button = Ui.button({ Name = tab.id, LayoutOrder = order, Text = tab.text, Size = UDim2.new(1 / #TABS, -6, 1, 0), BackgroundColor3 = Ui.Colors.panelLight, MaxTextSize = 18, Parent = tabBar })
		button.Activated:Connect(function()
			self.tab = tab.id
			self:render()
		end)
		self.tabs[tab.id] = button
		self.lists[tab.id] = Ui.new("ScrollingFrame", {
			Name = tab.text,
			Position = UDim2.fromOffset(0, 90),
			Size = UDim2.new(1, 0, 1, -90),
			BackgroundTransparency = 1,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 6,
			Visible = false,
			Parent = root,
		}, { Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })
	end

	-- Species: one row per researchable coral, in research order.
	for order, seedId in ReefConfig.Research.order do
		local seed = ReefConfig.Seeds[seedId]
		local frame = row(self.lists.species, order, 70)
		Ui.new("Frame", { Name = "Swatch", Position = UDim2.fromOffset(10, 17), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = seed.color, Parent = frame }, { Ui.corner(18) })
		local mark = text(frame, { Name = "Mark", Text = "", Font = Ui.TitleFont, MaxTextSize = 20, Position = UDim2.fromOffset(10, 17), Size = UDim2.fromOffset(36, 36), TextXAlignment = Enum.TextXAlignment.Center })
		text(frame, { Name = "SeedName", Text = seed.name, Font = Ui.TitleFont, MaxTextSize = 19, Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -230, 0, 24) })
		local info = text(frame, { Name = "Detail", Text = "", MaxTextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(56, 32), Size = UDim2.new(1, -230, 0, 34), TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Ui.Colors.muted })
		local button = actionButton(frame, function()
			Remotes.ResearchSpecies:FireServer(seedId)
		end)
		self.species[seedId] = { detail = info, button = button, mark = mark }
	end

	-- Reef: unlocking planters and researching coral growth.
	do
		local frame = row(self.lists.reef, 1, 96)
		text(frame, { Name = "PlanterTitle", Text = "Unlock a planter", Font = Ui.TitleFont, MaxTextSize = 19, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -182, 0, 24) })
		local info = text(frame, { Name = "Detail", Text = "", MaxTextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -182, 0, 58), TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Ui.Colors.muted })
		self.planter = { detail = info, button = actionButton(frame, function()
			Remotes.ExpandReef:FireServer()
		end) }
	end
	do
		local frame = row(self.lists.reef, 2, 80)
		text(frame, { Name = "GrowthTitle", Text = "Coral growth research", Font = Ui.TitleFont, MaxTextSize = 19, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -182, 0, 24) })
		local info = text(frame, { Name = "Detail", Text = "", MaxTextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -182, 0, 42), TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Ui.Colors.muted })
		self.growth = { detail = info, button = actionButton(frame, function()
			Remotes.UpgradeGear:FireServer("fertilizer")
		end) }
	end

	-- Health: a meter per measure, and a one-line verdict.
	self.verdict = text(row(self.lists.health, 0, 44), { Name = "Verdict", Text = "", Font = Ui.TitleFont, MaxTextSize = 20, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0) })
	for order, meter in METERS do
		local frame = row(self.lists.health, order, 58)
		text(frame, { Name = "MeterName", Text = meter.text, MaxTextSize = 16, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.65, -12, 0, 20) })
		local value = text(frame, { Name = "Value", Text = "", MaxTextSize = 16, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.new(0.35, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Ui.Colors.rare })
		local track = Ui.new("Frame", { Name = "Track", Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -24, 0, 14), BackgroundColor3 = Ui.Colors.panel, Parent = frame }, { Ui.corner(7) })
		local fill = Ui.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.Colors.good, Parent = track }, { Ui.corner(7) })
		self.meters[meter.id] = { fill = fill, value = value }
	end

	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

function LabPanel.setOpen(self: LabPanel, open: boolean, stand: BasePart?)
	self.gui.Enabled = open
	self.stand = if open then stand else nil
	if open then
		self:render()
	end
end

function LabPanel.setData(self: LabPanel, data: any)
	self.data = data
	self:render()
end

-- Your reef's coral right now, read from the coral models on your plot.
local function reefCoral(): { Model }
	local index = Players.LocalPlayer:GetAttribute("PlotIndex")
	local plots = Workspace:FindFirstChild("Reef") and Workspace.Reef:FindFirstChild("Plots")
	local plot = plots and index and plots:FindFirstChild(`Plot_{index}`)
	local result = {}
	for _, coral in CollectionService:GetTagged(ReefConfig.CORAL_TAG) do
		if plot and coral.Parent == plot then
			table.insert(result, coral)
		end
	end
	return result
end

local function setMeter(meter: Meter, value: number, max: number, label: string)
	local fraction = if max > 0 then math.clamp(value / max, 0, 1) else 0
	meter.fill.Size = UDim2.fromScale(fraction, 1)
	meter.fill.BackgroundColor3 = if fraction >= 0.66 then Ui.Colors.good elseif fraction >= 0.33 then Ui.Colors.rare else Ui.Colors.bad
	meter.value.Text = label
end

function LabPanel.render(self: LabPanel)
	if not self.gui.Enabled then
		return
	end
	for id, button in self.tabs do
		button.BackgroundColor3 = if id == self.tab then Ui.Colors.button else Ui.Colors.panelLight
		self.lists[id].Visible = id == self.tab
	end
	local data = self.data
	if not data then
		return
	end
	local shells = data.shells
	self.status.Text = `{EconomyMath.formatNumber(shells)} shells · {data.pearls or 0} pearls`

	-- Species.
	for _, seedId in ReefConfig.Research.order do
		local r = self.species[seedId]
		local known = ReefConfig.speciesUnlocked(data, seedId)
		local cost = ReefConfig.Research.costs[seedId]
		r.mark.Text = if known then "✓" else ""
		if known then
			r.detail.Text = "Researched: buy its seeds in the Coral Market."
			r.button.Text = "Known"
			r.button.BackgroundColor3 = Ui.Colors.buttonDisabled
		else
			local problem = ReefConfig.researchProblem(data, seedId)
			r.detail.Text = problem or `Ready to research: {EconomyMath.formatNumber(cost)} shells.`
			r.button.Text = `Research · {EconomyMath.formatNumber(cost)}`
			r.button.BackgroundColor3 = if problem == nil and shells >= cost then TEAL else Ui.Colors.buttonDisabled
		end
	end

	-- Reef.
	local planterCost, pearls = data.expandCost, data.expandPearls or 0
	if planterCost then
		self.planter.detail.Text = `{data.unlocked} of {ReefConfig.MAX_SLOTS} planters unlocked. The next costs {EconomyMath.formatNumber(planterCost)} shells and {pearls} pearl{if pearls == 1 then "" else "s"}. Pearls hide in the Main Reef's caves, on its bridges and in the Kelp Forest's glades.`
		self.planter.button.Text = `Unlock · {EconomyMath.formatNumber(planterCost)} + {pearls}◆`
		self.planter.button.BackgroundColor3 = if shells >= planterCost and (data.pearls or 0) >= pearls then TEAL else Ui.Colors.buttonDisabled
	else
		self.planter.detail.Text = `Every planter is unlocked: {ReefConfig.MAX_SLOTS} of {ReefConfig.MAX_SLOTS}.`
		self.planter.button.Text = "All unlocked"
		self.planter.button.BackgroundColor3 = Ui.Colors.buttonDisabled
	end
	local fertilizer = ReefConfig.Gear.fertilizer
	local level = data.gear.fertilizer or 0
	local percent = function(l: number): string
		return `{math.round(l * fertilizer.perLevel * 100)}%`
	end
	if level < #fertilizer.costs then
		local cost = fertilizer.costs[level + 1]
		self.growth.detail.Text = `All your coral grows {percent(level)} faster now; the next level makes it {percent(level + 1)}. Level {level}/{#fertilizer.costs}.`
		self.growth.button.Text = `Research · {EconomyMath.formatNumber(cost)}`
		self.growth.button.BackgroundColor3 = if shells >= cost then TEAL else Ui.Colors.buttonDisabled
	else
		self.growth.detail.Text = `All your coral grows {percent(level)} faster. Fully researched!`
		self.growth.button.Text = "Maxed"
		self.growth.button.BackgroundColor3 = Ui.Colors.buttonDisabled
	end

	-- Health.
	local coral = reefCoral()
	local ready, mutated, kinds, kindCount = 0, 0, {}, 0
	for _, model in coral do
		if model:GetAttribute("Stage") == 3 then
			ready += 1
		end
		local mutation = model:GetAttribute("Mutation")
		if mutation and mutation ~= "None" then
			mutated += 1
		end
		local seedId = model:GetAttribute("Seed")
		if seedId and not kinds[seedId] then
			kinds[seedId] = true
			kindCount += 1
		end
	end
	local known = 0
	for _, seedId in ReefConfig.Research.order do
		if ReefConfig.speciesUnlocked(data, seedId) then
			known += 1
		end
	end
	setMeter(self.meters.planters, #coral, data.unlocked, `{#coral}/{data.unlocked}`)
	-- Ready coral is good, but a reef full of unharvested coral is waiting on you.
	setMeter(self.meters.ready, ready, math.max(#coral, 1), `{ready}/{#coral}`)
	setMeter(self.meters.variety, kindCount, math.max(known, 1), `{kindCount} of {known} known`)
	setMeter(self.meters.mutated, mutated, math.max(#coral, 1), `{mutated}`)
	local fill = #coral / math.max(data.unlocked, 1)
	self.verdict.Text = if #coral == 0 then "Your reef is bare. Plant some coral!"
		elseif fill >= 0.8 and kindCount >= 3 then "Thriving! A full, varied reef."
		elseif fill >= 0.5 then "Healthy. Plant more species for variety."
		else "Needs care: plenty of empty planters."
	self.verdict.TextColor3 = if fill >= 0.8 then Ui.Colors.good elseif fill >= 0.5 then Ui.Colors.rare else Ui.Colors.bad
end

-- A few times a second: keeps Reef Health live, closes when you walk off.
function LabPanel.update(self: LabPanel)
	if not self.gui.Enabled then
		return
	end
	if self.tab == "health" then
		self:render()
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if self.stand and root and (root.Position - self.stand.Position).Magnitude > ReefConfig.INTERACT_DISTANCE + 4 then
		self:setOpen(false)
	end
end

return LabPanel

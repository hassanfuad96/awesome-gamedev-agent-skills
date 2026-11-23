--!nonstrict
-- The Reef Index window: one tab per set (each seed, then fish). Every entry is a 3D model
-- in a ViewportFrame; ones not found yet are black silhouettes named "???". The server
-- records finds and pays set rewards (ReefIndex); this only shows them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)
local Ui = require(script.Parent.Ui)

local IndexPanel = {}
IndexPanel.__index = IndexPanel

export type IndexPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		summary: TextLabel,
		setLine: TextLabel,
		tabs: { [string]: TextButton },
		grid: ScrollingFrame,
		tab: string,
		book: any,
		shown: string, -- what the grid currently shows, to skip needless rebuilds
	},
	IndexPanel
))

local SILHOUETTE = Color3.fromRGB(12, 16, 26)

local function silhouette(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Transparency < 1 then
				d.Color = SILHOUETTE
				d.Material = Enum.Material.SmoothPlastic
				d.Transparency = 0
			end
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Sparkles") then
			d:Destroy()
		end
	end
end

local function fishModel(kind: ReefConfig.FishDef): Model
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(0.9, 1.1, 2)
	body.Color = kind.color
	body.Parent = model
	local tail = Instance.new("WedgePart")
	tail.Size = Vector3.new(0.2, 1, 0.8)
	tail.Color = kind.color:Lerp(Color3.new(0, 0, 0), 0.25)
	tail.CFrame = CFrame.new(0, 0, 1.3) * CFrame.Angles(0, math.rad(180), 0)
	tail.Parent = model
	model.PrimaryPart = body
	return model
end

function IndexPanel.new(playerGui: PlayerGui): IndexPanel
	local gui = Ui.new("ScreenGui", {
		Name = "ReefIndexGui",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local root = Ui.new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Ui.Colors.panel,
		Parent = gui,
	}, {
		Ui.corner(16),
		Ui.stroke(Ui.Colors.accent, 2),
		Ui.padding(12),
	})
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(660, 600))
	Ui.label({
		Name = "Title",
		Text = "Reef Index",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(0.5, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	local summary = Ui.label({
		Name = "Summary",
		Text = "",
		MaxTextSize = 18,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -50, 0, 4),
		Size = UDim2.new(0.5, -50, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Ui.Colors.rare,
		Parent = root,
	})
	local close = Ui.button({
		Name = "Close",
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(44, 36),
		BackgroundColor3 = Ui.Colors.bad,
		Parent = root,
	})

	local tabBar = Ui.new("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		Parent = root,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	local setLine = Ui.label({
		Name = "SetLine",
		Text = "",
		MaxTextSize = 16,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = root,
	})
	local grid = Ui.new("ScrollingFrame", {
		Name = "Entries",
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 1, -120),
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = root,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 132),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local self = setmetatable({
		gui = gui,
		summary = summary,
		setLine = setLine,
		tabs = {},
		grid = grid,
		tab = ReefConfig.IndexSets[1].id,
		book = nil,
		shown = "",
	}, IndexPanel)

	for order, set in ReefConfig.IndexSets do
		local button = Ui.button({
			Name = set.id,
			LayoutOrder = order,
			Text = set.name,
			Size = UDim2.fromOffset(124, 38),
			BackgroundColor3 = Ui.Colors.panelLight,
			MaxTextSize = 16,
			Parent = tabBar,
		})
		button.Activated:Connect(function()
			self.tab = set.id
			self:render()
		end)
		self.tabs[set.id] = button
	end
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

function IndexPanel.setOpen(self: IndexPanel, open: boolean)
	self.gui.Enabled = open
	if open then
		self:render()
	end
end

function IndexPanel.setData(self: IndexPanel, data: any)
	if type(data.index) == "table" then
		self.book = data.index
		self:render()
	end
end

local function count(t: { [any]: any }?): number
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

function IndexPanel.render(self: IndexPanel)
	local book = self.book or { coral = {}, fish = {}, sets = {} }
	local total = 0
	for _, set in ReefConfig.IndexSets do
		total += #set.entries
	end
	local found = count(book.coral) + count(book.fish)
	self.summary.Text = `{found} / {total} found`
	if not self.gui.Enabled then
		return
	end

	local set
	for _, candidate in ReefConfig.IndexSets do
		if candidate.id == self.tab then
			set = candidate
		end
	end
	for id, button in self.tabs do
		button.BackgroundColor3 = if id == self.tab then Ui.Colors.button else Ui.Colors.panelLight
	end
	local foundHere = 0
	for _, entry in set.entries do
		if book[set.kind][entry] then
			foundHere += 1
		end
	end
	local reward = EconomyMath.formatNumber(set.reward)
	self.setLine.Text = if book.sets[set.id]
		then `{set.name} set complete! ({foundHere}/{#set.entries}, paid {reward} shells)`
		else `{set.name} set: {foundHere}/{#set.entries} found. Complete it for {reward} shells`

	-- Viewports are costly to rebuild, so only redraw the grid when what it shows changed.
	local shown = `{set.id}:{foundHere}`
	if shown == self.shown then
		return
	end
	self.shown = shown
	for _, child in self.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for order, entry in set.entries do
		local discovered = book[set.kind][entry] == true
		local model, name, detail
		if set.kind == "coral" then
			local seedId, mutationKey = ReefConfig.splitInventoryKey(entry)
			model = CoralVisuals.build(seedId, mutationKey, CFrame.identity)
			name = ReefConfig.displayName(seedId, mutationKey)
			detail = `x{ReefConfig.mutationMultiplier(mutationKey)}`
		else
			for _, kind in ReefConfig.Fish.kinds do
				if kind.id == entry then
					model = fishModel(kind)
					detail = `x{kind.multiplier}`
				end
			end
			name = entry
		end
		if not discovered then
			silhouette(model)
		end
		local cell = Ui.new("Frame", {
			Name = entry,
			LayoutOrder = order,
			BackgroundColor3 = if discovered then Ui.Colors.panelLight else Color3.fromRGB(20, 30, 45),
			Parent = self.grid,
		}, { Ui.corner(10) })
		Ui.viewport({ Name = "Model", Size = UDim2.new(1, 0, 0, 84) }, model).Parent = cell
		Ui.label({
			Name = "EntryName",
			Text = if discovered then name else "???",
			MaxTextSize = 13,
			TextWrapped = true,
			Position = UDim2.fromOffset(4, 84),
			Size = UDim2.new(1, -8, 0, 30),
			TextColor3 = if discovered then Ui.Colors.text else Ui.Colors.muted,
			Parent = cell,
		})
		Ui.label({
			Name = "Multiplier",
			Text = if discovered then detail else "",
			Font = Ui.TitleFont,
			MaxTextSize = 13,
			Position = UDim2.new(0, 4, 1, -18),
			Size = UDim2.new(1, -8, 0, 16),
			TextColor3 = Ui.Colors.rare,
			Parent = cell,
		})
	end
end

return IndexPanel

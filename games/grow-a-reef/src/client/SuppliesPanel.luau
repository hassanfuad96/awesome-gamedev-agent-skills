--!nonstrict
-- Two of the hub's windows, by the counter that opens it (its prompt's Mode attribute):
--   market     the Coral Market's Decor & Fences counter, two tabs:
--                Fences  buy a fence style, or switch to one you own
--                Decor   buy decorations, then Place them on your reef (Planter places them)
--   equipment  the Equipment Station: diving gear (Bubble Wand, Bigger Bag, Oxygen Tank,
--              Swim Fins), one level at a time
-- (Planters, species and coral growth are at the Research Laboratory: LabPanel.)
-- Buttons send ids only; the server checks prices, ownership and distance (Supplies).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local DecorVisuals = require(ReplicatedStorage.Shared.DecorVisuals)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SuppliesPanel = {}
SuppliesPanel.__index = SuppliesPanel

type FenceRow = { detail: TextLabel, button: TextButton }
type DecorRow = { owned: TextLabel, buy: TextButton, place: TextButton }
type GearRow = { effect: TextLabel, level: TextLabel, button: TextButton }

export type SuppliesPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		status: TextLabel,
		tabs: { [string]: TextButton },
		lists: { [string]: ScrollingFrame },
		tab: string,
		fenceRows: { [string]: FenceRow },
		decorRows: { [string]: DecorRow },
		gearRows: { [string]: GearRow },
		title: TextLabel,
		mode: string,
		data: any,
		stand: BasePart?,
	},
	SuppliesPanel
))

local TABS = { { id = "fences", text = "Fences" }, { id = "decor", text = "Decor" }, { id = "gear", text = "Gear" } }
-- Which tabs each building's window shows, and its title.
local MODES = {
	market = { title = "Decor & Fences", tabs = { fences = true, decor = true }, first = "fences" },
	equipment = { title = "Equipment Station", tabs = { gear = true }, first = "gear" },
}
local BLUE = Color3.fromRGB(60, 120, 200)

-- The Reef Index set whose reward is this fence, for fences you can't buy.
local function rewardSetName(fenceId: string): string?
	for _, set in ReefConfig.IndexSets do
		local reward = ReefConfig.IndexRewards[set.id]
		if reward and reward.fence == fenceId then
			return set.name
		end
	end
	return nil
end

-- What a gear upgrade does at `level`.
local function gearEffect(gearId: string, level: number): string
	if gearId == "fertilizer" then
		return if level == 0 then "Makes all your coral grow faster" else `Coral grows {math.round(level * ReefConfig.Gear.fertilizer.perLevel * 100)}% faster`
	elseif gearId == "wand" then
		local wand = ReefConfig.Gear.wand
		return if level == 0
			then "Tap a growing coral to speed it up"
			else `Each tap: +{level * wand.boostSeconds}s and {math.round(level * wand.boostFraction * 100)}% of its grow time, every {wand.cooldown}s`
	end
	if gearId == "oxygen" then
		return `{ReefConfig.oxygenCapacity(level)} seconds of air in deep water`
	elseif gearId == "fins" then
		return if level == 0 then "Swim faster" else `Swim {math.round((ReefConfig.swimSpeedMultiplier(level) - 1) * 100)}% faster`
	end
	return `Holds {ReefConfig.bagCapacity(level)} coral`
end

local function row(parent: Instance, name: string, order: number, height: number): Frame
	return Ui.new("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Ui.Colors.panelLight,
		Parent = parent,
	}, { Ui.corner(10) })
end

local function title(parent: Instance, text: string, x: number, width: UDim): TextLabel
	return Ui.label({
		Name = "ItemName",
		Text = text,
		Font = Ui.TitleFont,
		MaxTextSize = 19,
		Position = UDim2.fromOffset(x, 6),
		Size = UDim2.new(width.Scale, width.Offset - x, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local function detail(parent: Instance, x: number, y: number, width: UDim, height: number): TextLabel
	return Ui.label({
		Name = "Detail",
		Text = "",
		MaxTextSize = 14,
		TextWrapped = true,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.new(width.Scale, width.Offset - x, 0, height),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Ui.Colors.muted,
		Parent = parent,
	})
end

-- onPlace(itemId) is called when the player presses Place on a decoration.
function SuppliesPanel.new(playerGui: PlayerGui, onPlace: (string) -> ()): SuppliesPanel
	local gui = Ui.new("ScreenGui", {
		Name = "SuppliesGui",
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
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(600, 580))
	local titleLabel = Ui.label({
		Name = "Title",
		Text = "Equipment Station",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(0.5, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	local status = Ui.label({
		Name = "Status",
		Text = "",
		MaxTextSize = 18,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -50, 0, 6),
		Size = UDim2.new(0.5, -50, 0, 24),
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
	local tabBar = Ui.new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})

	local self = setmetatable({
		gui = gui,
		status = status,
		tabs = {},
		lists = {},
		tab = "gear",
		title = titleLabel,
		mode = "equipment",
		fenceRows = {},
		decorRows = {},
		gearRows = {},
		data = nil,
		stand = nil,
	}, SuppliesPanel)

	for order, tab in TABS do
		local button = Ui.button({
			Name = tab.id,
			LayoutOrder = order,
			Text = tab.text,
			Size = UDim2.new(1 / #TABS, -6, 1, 0),
			BackgroundColor3 = Ui.Colors.panelLight,
			MaxTextSize = 18,
			Parent = tabBar,
		})
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
		}, {
			Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		})
	end

	-- Fences: a strip of the style's colours, its name and price, and Buy / Use.
	for order, fence in ReefConfig.Fences do
		local frame = row(self.lists.fences, fence.id, order, 66)
		local swatches = Ui.new("Frame", {
			Name = "Colours",
			Position = UDim2.fromOffset(10, 13),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = fence.postColor,
			Parent = frame,
		}, { Ui.corner(8) })
		for i, color in fence.plankColors do
			if i <= 3 then
				Ui.new("Frame", {
					Position = UDim2.new(0, 4, 0, 4 + (i - 1) * 11),
					Size = UDim2.new(1, -8, 0, 8),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					Parent = swatches,
				}, { Ui.corner(3) })
			end
		end
		title(frame, fence.name, 60, UDim.new(1, -130))
		local info = detail(frame, 60, 32, UDim.new(1, -130), 30)
		local button = Ui.button({
			Name = "Action",
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 44),
			MaxTextSize = 16,
			Parent = frame,
		})
		button.Activated:Connect(function()
			local data = self.data
			if not data then
				return
			end
			if data.fences[fence.id] then
				Remotes.EquipFence:FireServer(fence.id)
			elseif fence.shop ~= false then
				Remotes.BuyFence:FireServer(fence.id)
			end
		end)
		self.fenceRows[fence.id] = { detail = info, button = button }
	end

	-- Decorations: a 3D preview, what it is, how many you have, Buy and Place.
	for order, item in ReefConfig.Decor.items do
		local frame = row(self.lists.decor, item.id, order, 96)
		local view = Ui.viewport({ Name = "Preview", Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(80, 80) }, DecorVisuals.build(item.id, CFrame.identity))
		view.Parent = frame
		title(frame, item.name, 94, UDim.new(1, -124))
		detail(frame, 94, 30, UDim.new(1, -124), 32).Text = item.description
		local owned = Ui.label({
			Name = "Owned",
			Text = "",
			MaxTextSize = 14,
			Position = UDim2.fromOffset(94, 66),
			Size = UDim2.new(1, -218, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.rare,
			Parent = frame,
		})
		local buy = Ui.button({
			Name = "Buy",
			Text = `Buy {EconomyMath.formatNumber(item.price)}`,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.fromOffset(110, 38),
			MaxTextSize = 15,
			Parent = frame,
		})
		local place = Ui.button({
			Name = "Place",
			Text = "Place",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -8),
			Size = UDim2.fromOffset(110, 38),
			BackgroundColor3 = BLUE,
			MaxTextSize = 15,
			Parent = frame,
		})
		buy.Activated:Connect(function()
			Remotes.BuyDecor:FireServer(item.id)
		end)
		place.Activated:Connect(function()
			if self.data and (self.data.decorStorage[item.id] or 0) > 0 then
				self:setOpen(false)
				onPlace(item.id)
			end
		end)
		self.decorRows[item.id] = { owned = owned, buy = buy, place = place }
	end

	-- Gear: what the next level does and what it costs.
	for order, gearId in ReefConfig.GEAR_ORDER do
		if ReefConfig.GearStation[gearId] ~= "equipment" then
			continue -- coral growth research is at the Lab
		end
		local gear = ReefConfig.Gear[gearId]
		local frame = row(self.lists.gear, gearId, order, 80)
		title(frame, gear.name, 12, UDim.new(1, -140))
		local effect = detail(frame, 12, 32, UDim.new(1, -140), 22)
		local level = Ui.label({
			Name = "Level",
			Text = "",
			MaxTextSize = 14,
			Position = UDim2.fromOffset(12, 54),
			Size = UDim2.new(1, -152, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.rare,
			Parent = frame,
		})
		local button = Ui.button({
			Name = "Upgrade",
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 48),
			MaxTextSize = 15,
			Parent = frame,
		})
		button.Activated:Connect(function()
			Remotes.UpgradeGear:FireServer(gearId)
		end)
		self.gearRows[gearId] = { effect = effect, level = level, button = button }
	end

	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

-- `mode` is "market" or "equipment": which counter opened it.
function SuppliesPanel.setOpen(self: SuppliesPanel, open: boolean, stand: BasePart?, mode: string?)
	self.gui.Enabled = open
	self.stand = if open then stand else nil
	if open then
		local chosen = if mode and MODES[mode] then mode else "equipment"
		if chosen ~= self.mode or not MODES[chosen].tabs[self.tab] then
			self.tab = MODES[chosen].first
		end
		self.mode = chosen
		self.title.Text = MODES[chosen].title
		self:render()
	end
end

function SuppliesPanel.setData(self: SuppliesPanel, data: any)
	self.data = data
	self:render()
end

function SuppliesPanel.render(self: SuppliesPanel)
	if not self.gui.Enabled then
		return
	end
	local shown = MODES[self.mode].tabs
	local count = 0
	for _ in shown do
		count += 1
	end
	for id, button in self.tabs do
		button.Visible = shown[id] == true
		button.Size = UDim2.new(1 / count, -6, 1, 0)
		button.BackgroundColor3 = if id == self.tab then Ui.Colors.button else Ui.Colors.panelLight
		self.lists[id].Visible = id == self.tab
	end
	local data = self.data
	if not data then
		return
	end
	local shells = data.shells
	self.status.Text = `{EconomyMath.formatNumber(shells)} shells`

	for _, fence in ReefConfig.Fences do
		local r = self.fenceRows[fence.id]
		local owned = data.fences[fence.id] == true
		if data.fence == fence.id then
			r.detail.Text = "On your reef now"
			r.button.Text = "In use"
			r.button.BackgroundColor3 = Ui.Colors.buttonDisabled
		elseif owned then
			r.detail.Text = "Owned"
			r.button.Text = "Use"
			r.button.BackgroundColor3 = BLUE
		elseif fence.shop == false then
			r.detail.Text = `Reef Index reward: complete the {rewardSetName(fence.id) or "?"} set`
			r.button.Text = "Locked"
			r.button.BackgroundColor3 = Ui.Colors.buttonDisabled
		else
			r.detail.Text = `{EconomyMath.formatNumber(fence.price)} shells`
			r.button.Text = "Buy"
			r.button.BackgroundColor3 = if shells >= fence.price then Ui.Colors.button else Ui.Colors.buttonDisabled
		end
	end

	for _, item in ReefConfig.Decor.items do
		local r = self.decorRows[item.id]
		local stored = data.decorStorage[item.id] or 0
		local placed = data.decorPlaced[item.id] or 0
		r.owned.Text = if stored + placed == 0 then "" else `{stored} to place · {placed} on your reef`
		r.buy.BackgroundColor3 = if shells >= item.price then Ui.Colors.button else Ui.Colors.buttonDisabled
		r.place.BackgroundColor3 = if stored > 0 then BLUE else Ui.Colors.buttonDisabled
	end

	for _, gearId in ReefConfig.GEAR_ORDER do
		local gear = ReefConfig.Gear[gearId]
		local r = self.gearRows[gearId]
		if not r then
			continue -- sold at another building
		end
		local level = data.gear[gearId] or 0
		local maxLevel = #gear.costs
		r.effect.Text = if level < maxLevel then `{gearEffect(gearId, level)} → {gearEffect(gearId, level + 1)}` else gearEffect(gearId, level)
		r.level.Text = `Level {level}/{maxLevel}`
		if level >= maxLevel then
			r.button.Text = "Maxed"
			r.button.BackgroundColor3 = Ui.Colors.buttonDisabled
		else
			local cost = gear.costs[level + 1]
			r.button.Text = `{if level == 0 then "Buy" else "Upgrade"} {EconomyMath.formatNumber(cost)}`
			r.button.BackgroundColor3 = if shells >= cost then Ui.Colors.button else Ui.Colors.buttonDisabled
		end
	end
end

-- Called a few times a second: closes the window when the player walks off.
function SuppliesPanel.update(self: SuppliesPanel)
	if not self.gui.Enabled then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if self.stand and root and (root.Position - self.stand.Position).Magnitude > ReefConfig.INTERACT_DISTANCE + 4 then
		self:setOpen(false)
	end
end

return SuppliesPanel

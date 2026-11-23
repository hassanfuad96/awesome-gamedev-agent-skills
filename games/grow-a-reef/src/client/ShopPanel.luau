--!nonstrict
-- Seed shop window. Opens from the Seed Shop's ProximityPrompt and closes when the player
-- walks away. Buttons send seed ids only; the server checks price, stock and distance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ShopPanel = {}
ShopPanel.__index = ShopPanel

type Row = { button: TextButton, stock: TextLabel, price: TextLabel }

export type ShopPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		root: Frame,
		restock: TextLabel,
		expand: TextButton,
		close: TextButton,
		rows: { [string]: Row },
		stock: { [string]: number },
		restockAt: number,
		data: any,
		stand: BasePart?,
	},
	ShopPanel
))

function ShopPanel.new(playerGui: PlayerGui): ShopPanel
	local gui = Ui.new("ScreenGui", {
		Name = "SeedShopGui",
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
	-- Nearly full height: a landscape phone is ~330 px tall below the top bar.
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(540, 560))

	Ui.label({
		Name = "Title",
		Text = "Seed Shop",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(1, -50, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	local close = Ui.button({
		Name = "Close",
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(40, 34),
		BackgroundColor3 = Ui.Colors.bad,
		Parent = root,
	})
	local restock = Ui.label({
		Name = "Restock",
		Text = "",
		MaxTextSize = 16,
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = root,
	})

	local list = Ui.new("ScrollingFrame", {
		Name = "Seeds",
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, -124),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = root,
	}, {
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})

	local rows: { [string]: Row } = {}
	for order, seedId in ReefConfig.SEED_ORDER do
		local seed = ReefConfig.Seeds[seedId]
		if seed.shop == false then
			continue -- event-only seeds are never sold
		end
		local row = Ui.new("Frame", {
			Name = seedId,
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = Ui.Colors.panelLight,
			Parent = list,
		}, { Ui.corner(10) })
		Ui.new("Frame", {
			Name = "Swatch",
			Position = UDim2.fromOffset(10, 14),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = seed.color,
			Parent = row,
		}, { Ui.corner(18) })
		Ui.label({
			Name = "SeedName",
			Text = seed.name,
			Font = Ui.TitleFont,
			MaxTextSize = 20,
			Position = UDim2.fromOffset(56, 6),
			Size = UDim2.new(0.55, -56, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Ui.label({
			Name = "Details",
			Text = `Grows {Ui.formatTime(seed.growSeconds)} · sells {EconomyMath.formatNumber(seed.sellValue)}`,
			MaxTextSize = 14,
			Position = UDim2.fromOffset(56, 34),
			Size = UDim2.new(0.55, -56, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.muted,
			Parent = row,
		})
		local stock = Ui.label({
			Name = "Stock",
			Text = "",
			MaxTextSize = 14,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -110, 0, 8),
			Size = UDim2.new(0.25, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Ui.Colors.muted,
			Parent = row,
		})
		local price = Ui.label({
			Name = "Price",
			Text = `{EconomyMath.formatNumber(seed.price)} shells`,
			MaxTextSize = 16,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -110, 0, 32),
			Size = UDim2.new(0.25, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Ui.Colors.rare,
			Parent = row,
		})
		local button = Ui.button({
			Name = "Buy",
			Text = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(90, 44),
			Parent = row,
		})
		button.Activated:Connect(function()
			Remotes.BuySeed:FireServer(seedId)
		end)
		rows[seedId] = { button = button, stock = stock, price = price }
	end

	local expand = Ui.button({
		Name = "Expand",
		Text = "Grow your reef",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Color3.fromRGB(60, 120, 200),
		Parent = root,
	})
	expand.Activated:Connect(function()
		Remotes.ExpandReef:FireServer()
	end)

	local self = setmetatable({
		gui = gui,
		root = root,
		restock = restock,
		expand = expand,
		close = close,
		rows = rows,
		stock = {},
		restockAt = 0,
		data = nil,
		stand = nil,
	}, ShopPanel)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

function ShopPanel.setOpen(self: ShopPanel, open: boolean, stand: BasePart?)
	self.gui.Enabled = open
	self.stand = if open then stand else nil
	if open then
		self:render()
		-- Give gamepad players a focused button straight away. Mouse and touch players
		-- don't need it, and the selection box reads as a stuck highlight to them.
		if string.find(UserInputService:GetLastInputType().Name, "^Gamepad") then
			local first = self.rows[ReefConfig.SEED_ORDER[1]]
			GuiService.SelectedObject = if first then first.button else nil
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.gui) then
		GuiService.SelectedObject = nil
	end
end

function ShopPanel.setStock(self: ShopPanel, stock: { [string]: number }, restockAt: number)
	self.stock = stock
	self.restockAt = restockAt
	self:render()
end

function ShopPanel.setData(self: ShopPanel, data: any)
	self.data = data
	self:render()
end

function ShopPanel.render(self: ShopPanel)
	if not self.gui.Enabled then
		return
	end
	local shells = if self.data then self.data.shells else 0
	for seedId, row in self.rows do
		local seed = ReefConfig.Seeds[seedId]
		local left = self.stock[seedId] or 0
		local owned = if self.data then (self.data.seeds[seedId] or 0) else 0
		row.stock.Text = if left > 0 then `{left} in stock · own {owned}` else `Sold out · own {owned}`
		local canBuy = left > 0 and shells >= seed.price
		row.button.BackgroundColor3 = if canBuy then Ui.Colors.button else Ui.Colors.buttonDisabled
		row.button.Text = if left > 0 then "Buy" else "Sold out"
		row.price.TextColor3 = if shells >= seed.price then Ui.Colors.rare else Ui.Colors.bad
	end

	local cost = self.data and self.data.expandCost
	if cost then
		self.expand.Text = `Grow your reef to {self.data.unlocked + 1} coral slots - {EconomyMath.formatNumber(cost)} shells`
		self.expand.BackgroundColor3 = if shells >= cost then Color3.fromRGB(60, 120, 200) else Ui.Colors.buttonDisabled
	else
		self.expand.Text = "Reef fully grown"
		self.expand.BackgroundColor3 = Ui.Colors.buttonDisabled
	end
end

-- Called every frame-ish: restock countdown and auto-close when the player walks off.
function ShopPanel.update(self: ShopPanel)
	if not self.gui.Enabled then
		return
	end
	self.restock.Text = `New stock in {Ui.formatTime(self.restockAt - Workspace:GetServerTimeNow())}`
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if self.stand and root and (root.Position - self.stand.Position).Magnitude > ReefConfig.INTERACT_DISTANCE + 4 then
		self:setOpen(false)
	end
end

return ShopPanel

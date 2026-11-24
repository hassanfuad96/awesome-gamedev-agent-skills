--!nonstrict
-- The Store: Robux game passes and developer products (ReefConfig.Store), opened from the gold
-- Store button under the Music button. Buttons only open Roblox's own purchase prompt; the
-- server (Monetization) checks ownership and gives what was bought. Prices shown are the live
-- ones from Roblox when it answers, else the configured ones.
-- The Starter Pack shows at the top while it's on offer. Gifts first ask who they're for
-- (someone else in the server), tell the server (SetGiftTarget), then open the prompt.
-- Also applies the Speed Fins pass to swimming, which runs on this client.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local MenuButtons = require(script.Parent.MenuButtons)
local Swimming = require(script.Parent.Swimming)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local StorePanel = {}
StorePanel.__index = StorePanel

type Card = { buy: TextButton, price: TextLabel }

export type StorePanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		passCards: { [string]: Card },
		productCards: { [number]: Card },
		owned: { [string]: true },
		prices: { [number]: number },
		starterSection: { GuiObject },
		starterTimer: TextLabel,
		starterEndsAt: number?,
		picker: Frame,
		pickerList: ScrollingFrame,
		pickerTitle: TextLabel,
	},
	StorePanel
))

local GOLD = Color3.fromRGB(255, 200, 70)
local ROBUX = "R$ "

local function card(parent: Instance, order: number, name: string, icon: number, description: string): (Frame, TextLabel, TextButton)
	local frame = Ui.new("Frame", {
		Name = name,
		LayoutOrder = order,
		BackgroundColor3 = Ui.Colors.panelLight,
		Parent = parent,
	}, { Ui.corner(12) })
	Ui.new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{icon}`,
		Parent = frame,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Ui.label({
		Name = "ItemName",
		Text = name,
		Font = Ui.TitleFont,
		MaxTextSize = 17,
		Position = UDim2.fromOffset(6, 96),
		Size = UDim2.new(1, -12, 0, 22),
		Parent = frame,
	})
	Ui.label({
		Name = "Description",
		Text = description,
		MaxTextSize = 13,
		TextWrapped = true,
		Position = UDim2.fromOffset(8, 118),
		Size = UDim2.new(1, -16, 0, 44),
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Ui.Colors.muted,
		Parent = frame,
	})
	local price = Ui.label({
		Name = "Price",
		Text = "",
		Font = Ui.TitleFont,
		MaxTextSize = 15,
		Position = UDim2.fromOffset(6, 162),
		Size = UDim2.new(1, -12, 0, 20),
		TextColor3 = GOLD,
		Parent = frame,
	})
	local buy = Ui.button({
		Name = "Buy",
		Text = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 36),
		BackgroundColor3 = Color3.fromRGB(0, 170, 90),
		MaxTextSize = 16,
		Parent = frame,
	})
	return frame, price, buy
end

local function section(parent: Instance, order: number, title: string, subtitle: string): Frame
	Ui.label({
		Name = title,
		LayoutOrder = order,
		Text = title,
		Font = Ui.TitleFont,
		MaxTextSize = 20,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Parent = parent,
	})
	Ui.label({
		Name = title .. "Note",
		LayoutOrder = order + 1,
		Text = subtitle,
		MaxTextSize = 13,
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = parent,
	})
	return Ui.new("Frame", {
		Name = title .. "Grid",
		LayoutOrder = order + 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 232),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- "2d 5h", "5h 12m" or "12m" until a time.
local function timeLeft(seconds: number): string
	local s = math.max(0, seconds)
	if s >= 86400 then
		return `{s // 86400}d {(s % 86400) // 3600}h`
	elseif s >= 3600 then
		return `{s // 3600}h {(s % 3600) // 60}m`
	end
	return `{math.max(1, math.ceil(s / 60))}m`
end

-- The overlay that asks who a gift is for.
local function giftPicker(root: Frame): (Frame, TextLabel, ScrollingFrame, TextButton)
	local picker = Ui.new("Frame", {
		Name = "GiftPicker",
		Active = true,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.Colors.panel,
		ZIndex = 10,
		Parent = root,
	}, { Ui.corner(12) })
	local title = Ui.label({
		Name = "Title",
		Text = "Who is this gift for?",
		Font = Ui.TitleFont,
		MaxTextSize = 24,
		Size = UDim2.new(1, -60, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		ZIndex = 10,
		Parent = picker,
	})
	local back = Ui.button({
		Name = "Back",
		Text = "Back",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(70, 34),
		BackgroundColor3 = Ui.Colors.bad,
		ZIndex = 10,
		Parent = picker,
	})
	local list = Ui.new("ScrollingFrame", {
		Name = "Players",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ZIndex = 10,
		Parent = picker,
	}, {
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
	return picker, title, list, back
end

function StorePanel.new(playerGui: PlayerGui): StorePanel
	local gui = Ui.new("ScreenGui", {
		Name = "StoreGui",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 3,
		Parent = playerGui,
	})
	local root = Ui.new("Frame", {
		Name = "Root",
		Active = true, -- taps on the window don't reach the world behind it
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Ui.Colors.panel,
		Parent = gui,
	}, {
		Ui.corner(16),
		Ui.stroke(GOLD, 2),
		Ui.padding(12),
	})
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(700, 620))
	Ui.label({
		Name = "Title",
		Text = "Store",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(1, -50, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
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
	local body = Ui.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = root,
	}, {
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})

	local picker, pickerTitle, pickerList, pickerBack = giftPicker(root)
	local self = setmetatable({
		gui = gui,
		passCards = {},
		productCards = {},
		owned = {},
		prices = {},
		starterSection = {},
		starterTimer = nil :: any,
		starterEndsAt = nil,
		picker = picker,
		pickerList = pickerList,
		pickerTitle = pickerTitle,
	}, StorePanel)
	pickerBack.Activated:Connect(function()
		picker.Visible = false
	end)

	local player = Players.LocalPlayer
	-- The Starter Pack, while it's on offer.
	local starterGrid = section(body, -10, "Starter Pack", "A one-time welcome deal for new divers.")
	for _, product in ReefConfig.Store.products do
		if product.starter then
			local frame, price, buy = card(starterGrid, 1, product.name, product.icon, product.description)
			Ui.stroke(GOLD, 3).Parent = frame
			buy.Activated:Connect(function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
			self.productCards[product.id] = { buy = buy, price = price }
		end
	end
	-- The section's note line shows how long the offer has left.
	self.starterTimer = body:FindFirstChild("Starter PackNote") :: TextLabel
	self.starterTimer.TextColor3 = GOLD
	self.starterSection = { body:FindFirstChild("Starter Pack") :: GuiObject, body:FindFirstChild("Starter PackNote") :: GuiObject, starterGrid }

	local passGrid = section(body, 1, "Game Passes", "Buy once, keep forever.")
	for order, pass in ReefConfig.Store.passes do
		local _, price, buy = card(passGrid, order, pass.name, pass.icon, pass.description)
		buy.Activated:Connect(function()
			if not self.owned[pass.key] then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		end)
		self.passCards[pass.key] = { buy = buy, price = price }
	end
	local productGrid = section(body, 10, "Boosts and Shells", "Buy as many times as you like.")
	local giftGrid = section(body, 20, "Gifts", "Buy something for a friend in this server. They keep it.")
	for order, product in ReefConfig.Store.products do
		if product.starter then
			continue
		end
		local _, price, buy = card(if product.gift then giftGrid else productGrid, order, product.name, product.icon, product.description)
		if product.gift then
			buy.Text = "Gift"
		end
		buy.Activated:Connect(function()
			if product.gift then
				self:pickFriend(product)
			else
				MarketplaceService:PromptProductPurchase(player, product.id)
			end
		end)
		self.productCards[product.id] = { buy = buy, price = price }
	end

	-- Live prices from Roblox, in case they've been changed on the Creator Dashboard.
	task.spawn(function()
		for _, pass in ReefConfig.Store.passes do
			local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, pass.id, Enum.InfoType.GamePass)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				self.prices[pass.id] = info.PriceInRobux
			end
		end
		for _, product in ReefConfig.Store.products do
			local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, product.id, Enum.InfoType.Product)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				self.prices[product.id] = info.PriceInRobux
			end
		end
		self:render()
	end)

	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	MenuButtons.add("Store", "Store", Color3.fromRGB(230, 160, 30), 1, function()
		self:setOpen(not self.gui.Enabled)
	end)
	self:render()
	return self
end

-- Lists everyone else here for a gift; picking one tells the server, then opens the prompt.
function StorePanel.pickFriend(self: StorePanel, product: ReefConfig.StoreProduct)
	for _, child in self.pickerList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.pickerTitle.Text = `Who is {(string.gsub(product.name, "^Gift: ", ""))} for?`
	local me = Players.LocalPlayer
	local others = 0
	for order, other in Players:GetPlayers() do
		if other == me then
			continue
		end
		others += 1
		local passes = string.split(tostring(other:GetAttribute("Passes") or ""), ",")
		local hasIt = product.pass ~= nil and table.find(passes, product.pass) ~= nil
		local row = Ui.button({
			Name = other.Name,
			LayoutOrder = order,
			Text = if hasIt then `{other.DisplayName} (already has it)` else other.DisplayName,
			Size = UDim2.new(1, -10, 0, 44),
			BackgroundColor3 = if hasIt then Ui.Colors.buttonDisabled else Ui.Colors.panelLight,
			AutoButtonColor = not hasIt,
			MaxTextSize = 18,
			ZIndex = 10,
			Parent = self.pickerList,
		})
		if not hasIt then
			row.Activated:Connect(function()
				self.picker.Visible = false
				Remotes.SetGiftTarget:FireServer(other.UserId)
				MarketplaceService:PromptProductPurchase(me, product.id)
			end)
		end
	end
	if others == 0 then
		Ui.label({
			Name = "Nobody",
			Text = "Nobody else is here yet. Invite friends from the Rewards window, then gift them something!",
			TextWrapped = true,
			MaxTextSize = 18,
			Size = UDim2.new(1, -10, 0, 60),
			TextColor3 = Ui.Colors.muted,
			ZIndex = 10,
			Parent = self.pickerList,
		})
	end
	self.picker.Visible = true
end

-- Counts down the Starter Pack's offer while the window is open.
function StorePanel.update(self: StorePanel)
	if self.gui.Enabled and self.starterEndsAt then
		local left = self.starterEndsAt - os.time()
		self.starterTimer.Text = if left > 0 then `A one-time welcome deal for new divers. Ends in {timeLeft(left)}!` else "Offer ended"
	end
end

function StorePanel.setOpen(self: StorePanel, open: boolean)
	self.gui.Enabled = open
	self.picker.Visible = false
	if open then
		self:render()
	end
end

function StorePanel.setData(self: StorePanel, data: any)
	self.owned = if type(data.ownedPasses) == "table" then data.ownedPasses else {}
	self.starterEndsAt = if type(data.starterEndsAt) == "number" then data.starterEndsAt else nil
	Swimming.setSpeedMultiplier(if self.owned.speedFins then ReefConfig.Store.speedFinsMultiplier else 1)
	self:render()
end

function StorePanel.render(self: StorePanel)
	for _, pass in ReefConfig.Store.passes do
		local c = self.passCards[pass.key]
		local owned = self.owned[pass.key] == true
		c.price.Text = if owned then "Owned" else ROBUX .. (self.prices[pass.id] or pass.price)
		c.buy.Text = if owned then "Owned" else "Buy"
		c.buy.BackgroundColor3 = if owned then Ui.Colors.buttonDisabled else Color3.fromRGB(0, 170, 90)
		c.buy.AutoButtonColor = not owned
	end
	for _, product in ReefConfig.Store.products do
		local c = self.productCards[product.id]
		c.price.Text = ROBUX .. (self.prices[product.id] or product.price)
	end
	for _, item in self.starterSection do
		item.Visible = self.starterEndsAt ~= nil
	end
	self:update()
end

return StorePanel

--!nonstrict
-- Marina the Mermaid Merchant's window, opened at her stall during the Mermaid Merchant event.
-- The offers come from the MerchantOffers Workspace attribute and what you've bought from
-- your MerchantBought attribute. Buttons send an offer id only; the server checks the rest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MerchantPanel = {}
MerchantPanel.__index = MerchantPanel

export type MerchantPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		list: ScrollingFrame,
		status: TextLabel,
		stand: BasePart?,
		shells: number,
	},
	MerchantPanel
))

local TEAL = Color3.fromRGB(80, 210, 190)

local function split(value: unknown): { string }
	return if type(value) == "string" and value ~= "" then string.split(value, ",") else {}
end

function MerchantPanel.new(playerGui: PlayerGui): MerchantPanel
	local gui = Ui.new("ScreenGui", {
		Name = "MerchantGui",
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
		Ui.stroke(TEAL, 2),
		Ui.padding(12),
	})
	Ui.scaleWindow(root, Vector2.new(0.86, 0.86), Vector2.new(520, 420))
	Ui.label({
		Name = "Title",
		Text = "Marina's Rare Seeds",
		Font = Ui.TitleFont,
		MaxTextSize = 28,
		Size = UDim2.new(1, -50, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = TEAL,
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
	local status = Ui.label({
		Name = "Status",
		Text = "",
		MaxTextSize = 15,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = root,
	})
	local list = Ui.new("ScrollingFrame", {
		Name = "Offers",
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = root,
	}, {
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})

	local self = setmetatable({ gui = gui, list = list, status = status, stand = nil, shells = 0 }, MerchantPanel)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	Workspace:GetAttributeChangedSignal("MerchantOffers"):Connect(function()
		if Workspace:GetAttribute("MerchantOffers") == nil then
			self:setOpen(false) -- she has left
		else
			self:render()
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("MerchantBought"):Connect(function()
		self:render()
	end)
	return self
end

function MerchantPanel.setOpen(self: MerchantPanel, open: boolean, stand: BasePart?)
	self.gui.Enabled = open and Workspace:GetAttribute("MerchantOffers") ~= nil
	self.stand = if self.gui.Enabled then stand else nil
	self:render()
end

function MerchantPanel.setData(self: MerchantPanel, data: any)
	self.shells = data.shells or 0
	self:render()
end

function MerchantPanel.render(self: MerchantPanel)
	if not self.gui.Enabled then
		return
	end
	for _, child in self.list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local bought = {}
	for _, id in split(Players.LocalPlayer:GetAttribute("MerchantBought")) do
		bought[id] = true
	end
	self.status.Text = `One of each per diver, only while she's here. You have {EconomyMath.formatNumber(self.shells)} shells.`
	for order, id in split(Workspace:GetAttribute("MerchantOffers")) do
		local offer = ReefConfig.MerchantOfferById[id]
		local seed = offer and ReefConfig.Seeds[offer.seed]
		if seed then
			local row = Ui.new("Frame", {
				Name = id,
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 64),
				BackgroundColor3 = Ui.Colors.panelLight,
				Parent = self.list,
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
				Text = `{offer.count} x {seed.name}` .. (if seed.rarity then ` ({seed.rarity})` else ""),
				Font = Ui.TitleFont,
				MaxTextSize = 18,
				Position = UDim2.fromOffset(56, 6),
				Size = UDim2.new(1, -186, 0, 26),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			Ui.label({
				Name = "Price",
				Text = `{EconomyMath.formatNumber(offer.price)} shells`,
				MaxTextSize = 15,
				Position = UDim2.fromOffset(56, 34),
				Size = UDim2.new(1, -186, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if self.shells >= offer.price then Ui.Colors.rare else Ui.Colors.bad,
				Parent = row,
			})
			local done = bought[id] == true
			local button = Ui.button({
				Name = "Buy",
				Text = if done then "Bought" else "Buy",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(110, 44),
				BackgroundColor3 = if done or self.shells < offer.price then Ui.Colors.buttonDisabled else Ui.Colors.button,
				Parent = row,
			})
			button.Activated:Connect(function()
				if not done then
					Remotes.BuyMerchant:FireServer(id)
				end
			end)
		end
	end
end

-- Called a few times a second: closes the window when the player swims away.
function MerchantPanel.update(self: MerchantPanel)
	if not self.gui.Enabled then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not self.stand or not self.stand.Parent or (root and (root.Position - self.stand.Position).Magnitude > ReefConfig.INTERACT_DISTANCE + 4) then
		self:setOpen(false)
	end
end

return MerchantPanel

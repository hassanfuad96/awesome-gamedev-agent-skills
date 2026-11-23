--!nonstrict
-- Lumi's Deep Seeds: the window for the Abyss's seed stall (the AbyssShop prompt). Shows the
-- high-value abyssal coral with how long each grows and what it sells for; Buy sends only the
-- seed id (BuyAbyssSeed) and the server checks the price, the unlock and the distance.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local AbyssConfig = require(ReplicatedStorage.Shared.AbyssConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local CoralVisuals = require(ReplicatedStorage.Shared.CoralVisuals)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local AbyssPanel = {}
AbyssPanel.__index = AbyssPanel

local GLOW = Color3.fromRGB(140, 255, 220)

type Row = { button: TextButton, owned: TextLabel, price: number }

export type AbyssPanel = typeof(setmetatable(
	{} :: { gui: ScreenGui, rows: { [string]: Row }, stand: BasePart?, data: any },
	AbyssPanel
))

local function minutes(seconds: number): string
	return if seconds >= 3600 then `{seconds / 3600} h` else `{seconds // 60} min`
end

function AbyssPanel.new(playerGui: PlayerGui): AbyssPanel
	local gui = Ui.new("ScreenGui", {
		Name = "AbyssShopGui",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local root = Ui.new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(12, 16, 40),
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(GLOW, 2), Ui.padding(12) })
	Ui.scaleWindow(root, Vector2.new(0.9, 0.8), Vector2.new(560, 430))
	Ui.label({ Name = "Title", Text = "Lumi's Deep Seeds", Font = Ui.TitleFont, MaxTextSize = 28, Size = UDim2.new(1, -50, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GLOW, Parent = root })
	Ui.label({ Name = "Subtitle", Text = "Abyssal coral grows nowhere else. Plant it on your reef like any seed.", MaxTextSize = 14, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Ui.Colors.muted, Parent = root })
	local close = Ui.button({ Name = "Close", Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 36), BackgroundColor3 = Ui.Colors.bad, Parent = root })
	local list = Ui.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = root,
	}, { Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }), Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8) }) })

	local rows: { [string]: Row } = {}
	for order, seedId in AbyssConfig.SHOP_SEEDS do
		local seed = ReefConfig.Seeds[seedId]
		local frame = Ui.new("Frame", { Name = seedId, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = Color3.fromRGB(24, 30, 70), Parent = list }, { Ui.corner(10), Ui.stroke(seed.color, 1.5) })
		local model = CoralVisuals.build(seedId, "None", CFrame.new())
		local view = Ui.viewport({ Name = "Coral", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(88, 88), BackgroundColor3 = Color3.fromRGB(8, 10, 28), BackgroundTransparency = 0, Ambient = Color3.fromRGB(120, 130, 200) }, model)
		Ui.corner(8).Parent = view
		view.Parent = frame
		Ui.label({ Name = "Name", Text = `{seed.name}`, Font = Ui.TitleFont, MaxTextSize = 20, Position = UDim2.fromOffset(104, 8), Size = UDim2.new(1, -250, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = seed.color, Parent = frame })
		Ui.label({ Name = "Rarity", Text = `{seed.rarity or "Abyssal"} coral`, MaxTextSize = 13, Position = UDim2.fromOffset(104, 32), Size = UDim2.new(1, -250, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GLOW, Parent = frame })
		Ui.label({ Name = "Info", Text = `Grows in {minutes(seed.growSeconds)} · sells for {EconomyMath.formatNumber(seed.sellValue)}`, MaxTextSize = 14, Position = UDim2.fromOffset(104, 52), Size = UDim2.new(1, -250, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Ui.Colors.text, Parent = frame })
		local owned = Ui.label({ Name = "Owned", Text = "", MaxTextSize = 13, Position = UDim2.fromOffset(104, 74), Size = UDim2.new(1, -250, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Ui.Colors.muted, Parent = frame })
		local button = Ui.button({ Name = "Buy", Text = `Buy {EconomyMath.formatNumber(seed.price)}`, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 46), MaxTextSize = 18, Parent = frame })
		button.Activated:Connect(function()
			Remotes.BuyAbyssSeed:FireServer(seedId)
		end)
		rows[seedId] = { button = button, owned = owned, price = seed.price }
	end

	local self = setmetatable({ gui = gui, rows = rows, stand = nil, data = nil }, AbyssPanel)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

function AbyssPanel.setOpen(self: AbyssPanel, open: boolean, stand: BasePart?)
	self.gui.Enabled = open
	self.stand = if open then stand else nil
	if open then
		self:render()
		if string.find(UserInputService:GetLastInputType().Name, "^Gamepad") then
			GuiService.SelectedObject = self.rows[AbyssConfig.SHOP_SEEDS[1]].button
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.gui) then
		GuiService.SelectedObject = nil
	end
end

function AbyssPanel.render(self: AbyssPanel)
	local data = self.data
	if not data then
		return
	end
	for seedId, row in self.rows do
		local affordable = (data.shells or 0) >= row.price
		row.button.BackgroundColor3 = if affordable then Ui.Colors.button else Ui.Colors.buttonDisabled
		row.button.AutoButtonColor = affordable
		row.owned.Text = `You have {data.seeds[seedId] or 0}`
	end
end

function AbyssPanel.setData(self: AbyssPanel, data: any)
	self.data = data
	if self.gui.Enabled then
		self:render()
	end
end

-- Closes the window when you swim away from the stall.
function AbyssPanel.update(self: AbyssPanel)
	if not self.gui.Enabled then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if self.stand and root and (root.Position - self.stand.Position).Magnitude > AbyssConfig.REACH + 8 then
		self:setOpen(false)
	end
end

return AbyssPanel

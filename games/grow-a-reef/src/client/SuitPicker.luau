--!nonstrict
-- The diving suit picker: a card for each suit in ReefConfig.Suits with a 3D preview (the
-- server's dressed mannequins in ReplicatedStorage.SuitPreviews) and a Wear button, which
-- sends only the suit id (ChooseSuit). It opens by itself the first time a player hasn't
-- chosen yet, and from Captain Mako's prompt (Kind "SuitPicker") at the Equipment Station.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SuitPicker = {}
SuitPicker.__index = SuitPicker

export type SuitPicker = typeof(setmetatable(
	{} :: { gui: ScreenGui, buttons: { [string]: TextButton }, offered: boolean, current: string },
	SuitPicker
))

function SuitPicker.new(playerGui: PlayerGui): SuitPicker
	local gui = Ui.new("ScreenGui", {
		Name = "SuitPickerGui",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local root = Ui.new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Ui.Colors.panel,
		Active = true, -- taps on the window stop here, not on the octopus or fish behind it
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(Ui.Colors.accent, 2), Ui.padding(14) })
	Ui.scaleWindow(root, Vector2.new(0.9, 0.86), Vector2.new(560, 440))
	Ui.label({ Name = "Title", Text = "Choose your diving suit", Font = Ui.TitleFont, MaxTextSize = 28, Size = UDim2.new(1, -50, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, Parent = root })
	Ui.label({ Name = "Subtitle", Text = "You can change it any time with Captain Mako at the Equipment Station.", MaxTextSize = 14, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Ui.Colors.muted, Parent = root })
	local close = Ui.button({ Name = "Close", Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 36), BackgroundColor3 = Ui.Colors.bad, Parent = root })
	local cards = Ui.new("Frame", {
		Name = "Cards",
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local self = setmetatable({ gui = gui, buttons = {}, offered = false, current = "" }, SuitPicker)
	local previews = ReplicatedStorage:WaitForChild("SuitPreviews", 10)
	for order, id in ReefConfig.Suits.order do
		local suit = ReefConfig.Suits.byId[id]
		local card = Ui.new("Frame", { Name = id, LayoutOrder = order, Size = UDim2.fromScale(0.46, 1), BackgroundColor3 = Ui.Colors.panelLight, Active = true, Parent = cards }, { Ui.corner(12), Ui.stroke(suit.color, 2) })
		local mannequin = previews and previews:FindFirstChild(id)
		if mannequin then
			local model = mannequin:Clone()
			local view = Ui.viewport({ Name = "Preview", Position = UDim2.fromScale(0.05, 0.03), Size = UDim2.fromScale(0.9, 0.66), Ambient = Color3.fromRGB(180, 190, 210) }, model)
			-- Face the camera, a little turned, like the concept art.
			model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, math.rad(200), 0))
			view.Parent = card
		end
		Ui.label({ Name = "Name", Text = suit.name, Font = Ui.TitleFont, MaxTextSize = 20, Position = UDim2.fromScale(0.05, 0.7), Size = UDim2.new(0.9, 0, 0, 24), TextColor3 = suit.color, Parent = card })
		local button = Ui.button({ Name = "Wear", Text = "Wear this", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(0.8, 0, 0, 40), BackgroundColor3 = suit.color, MaxTextSize = 18, Parent = card })
		button.Activated:Connect(function()
			Remotes.ChooseSuit:FireServer(id)
			self:setOpen(false)
		end)
		self.buttons[id] = button
	end
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

function SuitPicker.setOpen(self: SuitPicker, open: boolean)
	self.gui.Enabled = open
end

function SuitPicker.setData(self: SuitPicker, data: any)
	self.current = if type(data.suit) == "string" then data.suit else ""
	for id, button in self.buttons do
		button.Text = if id == self.current then "Wearing ✓" else "Wear this"
	end
	-- First visit with no suit yet: offer the choice once.
	if self.current == "" and not self.offered then
		self.offered = true
		self:setOpen(true)
	end
end

return SuitPicker

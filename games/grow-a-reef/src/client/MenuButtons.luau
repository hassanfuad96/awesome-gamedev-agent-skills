--!nonstrict
-- The column of small buttons under the Music button (which sits under the teleports on the
-- right): Store, Rewards, Friends. Each window adds its own button with MenuButtons.add.

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)

local MenuButtons = {}

local WIDTH = 64
local HEIGHT = 30
local GAP = 8

local column: Frame? = nil

local function getColumn(): Frame
	if column then
		return column
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Ui.new("ScreenGui", {
		Name = "MenuButtons",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2,
		Parent = playerGui,
	})
	local frame = Ui.new("Frame", {
		Name = "Column",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(1, -46, 0.5, 140),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
	})
	column = frame
	local currentScale = 1
	local music: GuiObject? = nil
	local function place()
		if music then
			local offset = music.AbsolutePosition - gui.AbsolutePosition
			frame.Position = UDim2.fromOffset(offset.X + music.AbsoluteSize.X / 2, offset.Y + music.AbsoluteSize.Y + GAP * currentScale)
		end
	end
	Ui.autoScale({ frame }, function(scale)
		currentScale = scale
		task.defer(place)
	end)
	-- Audio makes the Music button a moment later; follow it once it's there.
	task.spawn(function()
		local toggle = playerGui:WaitForChild("AudioToggle", 15)
		music = toggle and toggle:WaitForChild("Music", 5) :: GuiObject?
		if music then
			music:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
			music:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
			place()
		end
	end)
	return frame
end

-- Adds a button to the column (lower `order` is higher up) and returns it.
function MenuButtons.add(name: string, text: string, color: Color3, order: number, onPress: () -> ()): TextButton
	local button = Ui.button({
		Name = name,
		Text = text,
		LayoutOrder = order,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = color,
		MaxTextSize = 14,
		Parent = getColumn(),
	})
	Ui.stroke(Color3.new(1, 1, 1), 1.5).Parent = button
	button.Activated:Connect(onPress)
	return button
end

-- A small red dot on a button, for something waiting (a trade request, a daily reward).
function MenuButtons.badge(button: GuiObject): Frame
	return Ui.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Ui.Colors.bad,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

return MenuButtons

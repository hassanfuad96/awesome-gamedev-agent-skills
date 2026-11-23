--!nonstrict
-- An on-screen health bar for the Giant Octopus while it's attacking, read from the
-- OctopusHealth / OctopusMaxHealth Workspace attributes the server sets (GiantOctopus). A bar
-- in the world gets lost in the underwater haze, so this one is part of the screen.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ui = require(script.Parent.Ui)

local EventBars = {}

local PINK = Color3.fromRGB(255, 90, 160)

function EventBars.start(playerGui: PlayerGui)
	local gui = Ui.new("ScreenGui", {
		Name = "EventBars",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})
	local frame = Ui.new("Frame", {
		Name = "OctopusHealth",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.fromOffset(340, 52),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.label({
		Name = "Title",
		Text = "Giant Octopus",
		Font = Ui.TitleFont,
		MaxTextSize = 20,
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = PINK,
		TextStrokeTransparency = 0.4,
		Parent = frame,
	})
	local back = Ui.new("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Ui.Colors.panel,
		Parent = frame,
	}, { Ui.corner(11), Ui.stroke(PINK, 2) })
	local fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PINK,
		Parent = back,
	}, { Ui.corner(11) })
	local count = Ui.label({
		Name = "Count",
		Text = "",
		Font = Ui.TitleFont,
		MaxTextSize = 15,
		ZIndex = 2,
		TextStrokeTransparency = 0.4,
		Parent = back,
	})
	Ui.autoScale({ frame })

	local function update()
		local health = Workspace:GetAttribute("OctopusHealth")
		local maximum = Workspace:GetAttribute("OctopusMaxHealth")
		local active = type(health) == "number" and type(maximum) == "number" and maximum > 0
		gui.Enabled = active
		if active then
			count.Text = `{health} / {maximum}`
			TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.clamp(health / maximum, 0, 1), 1) }):Play()
		end
	end
	Workspace:GetAttributeChangedSignal("OctopusHealth"):Connect(update)
	Workspace:GetAttributeChangedSignal("OctopusMaxHealth"):Connect(update)
	update()
end

return EventBars

--!nonstrict
-- The air bar: shows only while your air isn't full (diving in deep water, or refilling after),
-- above the hotbar. It reads the Oxygen and OxygenMax attributes the server keeps on your
-- player (Oxygen); the server decides when you run out.

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)

local OxygenBar = {}

local AIR = Color3.fromRGB(110, 220, 255)

function OxygenBar.start(playerGui: PlayerGui)
	local player = Players.LocalPlayer
	local gui = Ui.new("ScreenGui", { Name = "OxygenGui", ResetOnSpawn = false, Enabled = false, Parent = playerGui })
	local frame = Ui.new("Frame", {
		Name = "AirBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(280, 30),
		BackgroundColor3 = Ui.Colors.panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(AIR, 2), Ui.padding(5) })
	Ui.autoScale({ frame })
	local fill = Ui.new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = AIR, Parent = frame }, { Ui.corner(6) })
	local label = Ui.label({
		Name = "Air",
		Text = "",
		Font = Ui.TitleFont,
		MaxTextSize = 16,
		Size = UDim2.fromScale(1, 1),
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
		Parent = frame,
	})

	local function refresh()
		local air = player:GetAttribute("Oxygen")
		local max = player:GetAttribute("OxygenMax")
		if type(air) ~= "number" or type(max) ~= "number" or max <= 0 then
			gui.Enabled = false
			return
		end
		gui.Enabled = air < max - 0.05
		local fraction = math.clamp(air / max, 0, 1)
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.BackgroundColor3 = if fraction > 0.5 then AIR elseif fraction > 0.25 then Ui.Colors.rare else Ui.Colors.bad
		label.Text = `AIR  {math.ceil(air)}s`
	end
	player:GetAttributeChangedSignal("Oxygen"):Connect(refresh)
	player:GetAttributeChangedSignal("OxygenMax"):Connect(refresh)
	refresh()
end

return OxygenBar

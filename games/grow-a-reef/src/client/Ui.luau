--!nonstrict
-- Small helpers and the shared look for every Grow a Reef screen.

local Ui = {}

Ui.Colors = {
	panel = Color3.fromRGB(14, 42, 66),
	panelLight = Color3.fromRGB(24, 64, 96),
	accent = Color3.fromRGB(64, 214, 220),
	text = Color3.fromRGB(230, 246, 255),
	muted = Color3.fromRGB(150, 190, 210),
	good = Color3.fromRGB(110, 230, 140),
	rare = Color3.fromRGB(255, 205, 80),
	bad = Color3.fromRGB(255, 120, 110),
	button = Color3.fromRGB(46, 170, 120),
	buttonDisabled = Color3.fromRGB(70, 90, 100),
}

Ui.TitleFont = Enum.Font.FredokaOne
Ui.BodyFont = Enum.Font.GothamMedium

function Ui.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number?): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.stroke(color: Color3?, thickness: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = color or Color3.fromRGB(80, 160, 200),
		Thickness = thickness or 1.5,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(pixels: number): UIPadding
	local p = UDim.new(0, pixels)
	return Ui.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Ui.BodyFont,
		TextColor3 = Ui.Colors.text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = Ui.new("TextLabel", defaults)
	Ui.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 22, Parent = label })
	return label
end

function Ui.button(props: { [string]: any }): TextButton
	local defaults = {
		BackgroundColor3 = Ui.Colors.button,
		Font = Ui.TitleFont,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local button = Ui.new("TextButton", defaults, { Ui.corner(8) })
	Ui.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 20, Parent = button })
	return button
end

function Ui.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s >= 60 then
		return string.format("%d:%02d", s // 60, s % 60)
	end
	return `{s}s`
end

function Ui.reducedMotion(): boolean
	local ok, value = pcall(function()
		return (game:GetService("GuiService") :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

return Ui

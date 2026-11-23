--!nonstrict
-- Always-on HUD: shells, bag value, sea-event timer, toasts and the seed hotbar.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local Ui = require(script.Parent.Ui)

local Hud = {}
Hud.__index = Hud

local toastCounter = 0

export type Hud = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		shells: TextLabel,
		bag: TextLabel,
		event: TextLabel,
		toasts: Frame,
		hotbar: ScrollingFrame,
		hint: TextLabel,
		flashFrame: Frame,
		onSelect: (string?) -> (),
	},
	Hud
))

local TONE_COLORS = {
	info = Ui.Colors.text,
	good = Ui.Colors.good,
	rare = Ui.Colors.rare,
	bad = Ui.Colors.bad,
}

-- onOpen is called with "index" or "pets" when a side button is pressed, and onTeleport with
-- "shops" or "home" for the teleport buttons on the right.
function Hud.new(playerGui: PlayerGui, onSelect: (string?) -> (), onOpen: (string) -> (), onTeleport: (string) -> ()): Hud
	local gui = Ui.new("ScreenGui", {
		Name = "ReefHud",
		ResetOnSpawn = false,
		-- Draws over the Roblox top bar too, so the shells bar can sit in it (see placeStatus).
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	-- Top: currency and status. Placed in the top bar row by placeStatus below.
	local top = Ui.new("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(420, 84),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),
	})
	local shellsPill = Ui.new("Frame", {
		Name = "ShellsPill",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Ui.Colors.panel,
		BackgroundTransparency = 0.15,
		Parent = top,
	}, { Ui.corner(20), Ui.stroke(Ui.Colors.accent) })
	local shells = Ui.label({
		Name = "Shells",
		Text = "0 shells",
		Font = Ui.TitleFont,
		TextColor3 = Ui.Colors.rare,
		MaxTextSize = 28,
		Size = UDim2.new(0.5, -8, 1, -8),
		Position = UDim2.new(0, 8, 0, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = shellsPill,
	})
	local bag = Ui.label({
		Name = "Bag",
		Text = "Bag empty",
		MaxTextSize = 16,
		Size = UDim2.new(0.5, -12, 1, -12),
		Position = UDim2.new(0.5, 0, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Ui.Colors.muted,
		Parent = shellsPill,
	})
	local event = Ui.label({
		Name = "SeaEvent",
		LayoutOrder = 2,
		Text = "",
		MaxTextSize = 16,
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Ui.Colors.muted,
		TextStrokeTransparency = 0.6,
		Parent = top,
	})

	local toasts = Ui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.new(0.8, 0, 0, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(520, 200) }),
		Ui.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),
	})

	-- Left edge: the Reef Index and pets, above where the touch thumbstick sits.
	local side = Ui.new("Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, -30),
		Size = UDim2.fromOffset(72, 152),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }) })
	for order, panel in { { id = "index", text = "Index" }, { id = "pets", text = "Pets" } } do
		local button = Ui.button({
			Name = panel.text,
			LayoutOrder = order,
			Text = panel.text,
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = Ui.Colors.panel,
			Parent = side,
		})
		Ui.stroke(Ui.Colors.accent, 2).Parent = button
		button.Activated:Connect(function()
			onOpen(panel.id)
		end)
	end

	-- Right edge: teleports, above where the touch jump button sits.
	local teleports = Ui.new("Frame", {
		Name = "TeleportButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, -30),
		Size = UDim2.fromOffset(72, 152),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }) })
	for order, place in { { id = "shops", text = "Shop" }, { id = "home", text = "Home" } } do
		local button = Ui.button({
			Name = place.text,
			LayoutOrder = order,
			Text = place.text,
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = Ui.Colors.panel,
			Parent = teleports,
		})
		Ui.stroke(Ui.Colors.good, 2).Parent = button
		button.Activated:Connect(function()
			onTeleport(place.id)
		end)
	end

	-- A flash of light over the screen when you teleport.
	local flash = Ui.new("Frame", {
		Name = "TeleportFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(190, 245, 255),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	})

	-- Bottom: seed hotbar. Kept narrow so it sits between the touch thumbstick and jump button.
	local hotbarHolder = Ui.new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0.55, 0, 0, 96),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.new("UISizeConstraint", { MaxSize = Vector2.new(620, 96) }) })
	local hint = Ui.label({
		Name = "Hint",
		Text = "Buy seeds at the Seed Shop",
		MaxTextSize = 16,
		Size = UDim2.new(1, 0, 0, 20),
		TextStrokeTransparency = 0.5,
		Parent = hotbarHolder,
	})
	local hotbar = Ui.new("ScrollingFrame", {
		Name = "Slots",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundColor3 = Ui.Colors.panel,
		BackgroundTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		Parent = hotbarHolder,
	}, {
		Ui.corner(12),
		Ui.padding(6),
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	-- The shells bar sits in the Roblox top bar row, centred in the free space between the
	-- Roblox buttons (GuiService.TopbarInset). Where there is no top bar, it sits 8 px down.
	local currentScale = 1
	local function placeStatus()
		local scale = currentScale
		local bar = GuiService.TopbarInset
		local pillHeight = 40 * scale
		local y = if bar.Height >= pillHeight then (bar.Height - pillHeight) / 2 else 8
		local center = gui.AbsoluteSize.X / 2
		local room = if bar.Width > 0
			then 2 * math.min(center - bar.Min.X, bar.Max.X - center) - 16
			else gui.AbsoluteSize.X - 16
		top.Size = UDim2.fromOffset(math.clamp(room, 200, 420 * scale) / scale, 84)
		top.Position = UDim2.new(0.5, 0, 0, y)
		toasts.Position = UDim2.new(0.5, 0, 0, y + 92 * scale)
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeStatus)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeStatus)

	-- Smaller on phones. The hotbar keeps its share of the screen width so more seeds fit.
	Ui.autoScale({ top, toasts, side, teleports, hotbarHolder }, function(scale)
		currentScale = scale
		hotbarHolder.Size = UDim2.new(0.55 / scale, 0, 0, 96)
		placeStatus()
	end)

	local self = setmetatable({
		gui = gui,
		shells = shells,
		bag = bag,
		event = event,
		toasts = toasts,
		hotbar = hotbar,
		hint = hint,
		flashFrame = flash,
		onSelect = onSelect,
	}, Hud)
	return self
end

function Hud.setData(self: Hud, data: any)
	self.shells.Text = `{EconomyMath.formatNumber(data.shells)} shells`
	local count = 0
	for _, amount in data.inventory do
		count += amount
	end
	self.bag.Text = if count == 0
		then "Bag empty"
		else `Bag: {count} coral ({EconomyMath.formatNumber(data.inventoryValue)})`

	for _, child in self.hotbar:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local any = false
	for order, seedId in ReefConfig.SEED_ORDER do
		local amount = data.seeds[seedId]
		if amount and amount > 0 then
			any = true
			local seed = ReefConfig.Seeds[seedId]
			local selected = data.selected == seedId
			local slot = Ui.button({
				Name = seedId,
				LayoutOrder = order,
				Size = UDim2.new(0, 84, 1, 0),
				BackgroundColor3 = if selected then Ui.Colors.panelLight else Ui.Colors.panel,
				Text = "",
				Parent = self.hotbar,
			})
			Ui.new("UIStroke", {
				Color = if selected then Ui.Colors.accent else seed.color,
				Thickness = if selected then 3 else 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = slot,
			})
			Ui.new("Frame", {
				Name = "Swatch",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 6),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = seed.color,
				Parent = slot,
			}, { Ui.corner(9) })
			Ui.label({
				Name = "SeedName",
				Text = seed.name,
				MaxTextSize = 13,
				Position = UDim2.new(0, 4, 0, 26),
				Size = UDim2.new(1, -8, 0, 16),
				Parent = slot,
			})
			Ui.label({
				Name = "Count",
				Text = `x{amount}`,
				Font = Ui.TitleFont,
				MaxTextSize = 16,
				Position = UDim2.new(0, 4, 1, -20),
				Size = UDim2.new(1, -8, 0, 16),
				TextColor3 = Ui.Colors.rare,
				Parent = slot,
			})
			slot.Activated:Connect(function()
				self.onSelect(if selected then nil else seedId)
			end)
		end
	end

	local slots = `{data.planted or 0}/{data.unlocked} coral planted`
	if not any then
		self.hint.Text = `No seeds. Buy some at the Seed Shop! ({slots})`
	elseif (data.planted or 0) >= data.unlocked then
		self.hint.Text = `Reef full ({slots}). Harvest, or grow your reef at the Seed Shop`
	elseif data.selected then
		self.hint.Text = `Click your reef bed to plant {ReefConfig.Seeds[data.selected].name} ({slots})`
	else
		self.hint.Text = `Pick a seed, then click your reef bed to plant it ({slots})`
	end
end

function Hud.toast(self: Hud, text: string, tone: string?)
	local color = TONE_COLORS[tone or "info"] or Ui.Colors.text
	toastCounter += 1
	local toast = Ui.new("Frame", {
		Name = "Toast",
		LayoutOrder = toastCounter,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Ui.Colors.panel,
		BackgroundTransparency = 0.15,
		Parent = self.toasts,
	}, { Ui.corner(10), Ui.stroke(color) })
	local label = Ui.label({
		Text = text,
		TextColor3 = color,
		MaxTextSize = 17,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Parent = toast,
	})

	-- Keep at most four toasts on screen.
	local shown = {}
	for _, child in self.toasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(shown, child)
		end
	end
	table.sort(shown, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #shown - 4 do
		shown[i]:Destroy()
	end

	task.delay(3.5, function()
		if not toast.Parent then
			return
		end
		if Ui.reducedMotion() then
			toast:Destroy()
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		task.wait(0.45)
		toast:Destroy()
	end)
end

function Hud.flash(self: Hud)
	if Ui.reducedMotion() then
		return
	end
	self.flashFrame.BackgroundTransparency = 0.15
	TweenService:Create(self.flashFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

function Hud.updateTimers(self: Hud)
	local now = Workspace:GetServerTimeNow()
	local event = ReefConfig.EventById[Workspace:GetAttribute("EventId")]
	local endsAt = Workspace:GetAttribute("EventEndsAt")
	local nextAt = Workspace:GetAttribute("NextEventAt")
	if event and type(endsAt) == "number" and endsAt > now then
		self.event.Text = `{event.name}! {Ui.formatTime(endsAt - now)}`
		self.event.TextColor3 = event.color
	elseif type(nextAt) == "number" then
		self.event.Text = `Next sea event in {Ui.formatTime(nextAt - now)}`
		self.event.TextColor3 = Ui.Colors.muted
	else
		self.event.Text = ""
	end
end

return Hud

--!nonstrict
-- The Admin window, only offered to players the server marks IsAdmin. Every button just
-- sends a request through AdminAction; the server checks the sender is an admin and does
-- the work (Admin.luau), so this window grants nothing by itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local AdminPanel = {}
AdminPanel.__index = AdminPanel

export type AdminPanel = typeof(setmetatable({} :: { gui: ScreenGui }, AdminPanel))

local function send(action: string, arg1: any?, arg2: any?)
	Remotes.AdminAction:FireServer(action, arg1, arg2)
end

function AdminPanel.new(playerGui: PlayerGui): AdminPanel
	local gui = Ui.new("ScreenGui", {
		Name = "AdminGui",
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
		Ui.stroke(Ui.Colors.bad, 2),
		Ui.padding(12),
	})
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(620, 600))
	Ui.label({
		Name = "Title",
		Text = "Admin",
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
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})

	local order = 0
	local function heading(text: string)
		order += 1
		Ui.label({
			Name = "Heading",
			LayoutOrder = order,
			Text = text,
			Font = Ui.TitleFont,
			MaxTextSize = 20,
			Size = UDim2.new(1, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.rare,
			Parent = body,
		})
	end
	-- A wrapping grid of buttons; each entry is { text, color?, onPress }.
	local function buttonGrid(entries: { { any } })
		order += 1
		local grid = Ui.new("Frame", {
			Name = "Buttons",
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = body,
		}, {
			Ui.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(176, 40),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for index, entry in entries do
			local button = Ui.button({
				Name = entry[1],
				LayoutOrder = index,
				Text = entry[1],
				BackgroundColor3 = entry[2] or Ui.Colors.button,
				MaxTextSize = 16,
				Parent = grid,
			})
			button.Activated:Connect(entry[3])
		end
	end

	heading("Sea events")
	local eventButtons = {}
	for _, event in ReefConfig.Events.list do
		table.insert(eventButtons, { event.name, Color3.fromRGB(40, 110, 170), function()
			send("startEvent", event.id)
		end })
	end
	table.insert(eventButtons, { "Stop event", Ui.Colors.bad, function()
		send("stopEvent")
	end })
	buttonGrid(eventButtons)

	heading("Announcement")
	order += 1
	local message = Ui.new("TextBox", {
		Name = "Message",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Ui.Colors.panelLight,
		TextColor3 = Ui.Colors.text,
		PlaceholderText = `Message to players (up to {ReefConfig.Admin.announceMaxLength} letters)`,
		PlaceholderColor3 = Ui.Colors.muted,
		Text = "",
		Font = Ui.BodyFont,
		TextSize = 16,
		TextWrapped = true,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = body,
	}, { Ui.corner(8), Ui.padding(6) })
	local function announce(scope: string)
		if not string.match(message.Text, "^%s*$") then
			send("announce", message.Text, scope)
			message.Text = ""
		end
	end
	buttonGrid({
		{ "Send to this server", nil, function()
			announce("server")
		end },
		{ "Send to all servers", Color3.fromRGB(200, 120, 40), function()
			announce("global")
		end },
	})

	heading("Gifts for everyone in this server")
	local gifts = {}
	for _, seedId in ReefConfig.SEED_ORDER do
		local seed = ReefConfig.Seeds[seedId]
		table.insert(gifts, { `+{ReefConfig.Admin.giftSeedCount} {seed.name}`, if seed.rarity then Color3.fromRGB(150, 90, 220) else nil, function()
			send("giveSeeds", seedId)
		end })
	end
	for _, amount in ReefConfig.Admin.giftShells do
		table.insert(gifts, { `+{EconomyMath.formatNumber(amount)} shells`, Color3.fromRGB(190, 150, 40), function()
			send("giveShells", amount)
		end })
	end
	table.insert(gifts, { "Restock Coral Shop", Color3.fromRGB(60, 120, 200), function()
		send("restock")
	end })
	buttonGrid(gifts)

	local self = setmetatable({ gui = gui }, AdminPanel)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

function AdminPanel.setOpen(self: AdminPanel, open: boolean)
	self.gui.Enabled = open
end

return AdminPanel

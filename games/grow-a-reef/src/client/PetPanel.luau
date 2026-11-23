--!nonstrict
-- The Pets window: eggs (buyable at the Pet Hatchery, with every outcome's odds shown before
-- buying) and your pets, which you can take out (up to the limit), put away or release.
-- Buttons send ids only; the server rolls eggs and checks everything (Pets).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PetVisuals = require(script.Parent.PetVisuals)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PetPanel = {}
PetPanel.__index = PetPanel

type EggRow = { buy: TextButton, price: TextLabel }

export type PetPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		status: TextLabel,
		eggRows: { [string]: EggRow },
		grid: ScrollingFrame,
		data: any,
		stand: BasePart?,
		shown: string,
		confirming: string?, -- pet id whose Release button is waiting for a second press
	},
	PetPanel
))

local SETTINGS = ReefConfig.Pets

-- "Seahorse 50% · Pufferfish 35% · Octopus 15%": every outcome, from the list the server rolls.
local function oddsText(egg: ReefConfig.EggDef): string
	local odds = EconomyMath.oddsPercent(egg.odds)
	local parts = {}
	for _, outcome in egg.odds do
		table.insert(parts, `{SETTINGS.species[outcome.id].name} {math.round(odds[outcome.id] * 10) / 10}%`)
	end
	return table.concat(parts, " · ")
end

function PetPanel.new(playerGui: PlayerGui): PetPanel
	local gui = Ui.new("ScreenGui", {
		Name = "PetGui",
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
		Ui.stroke(Ui.Colors.accent, 2),
		Ui.padding(12),
	})
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(660, 600))
	Ui.label({
		Name = "Title",
		Text = "Pets",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(0.4, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	local status = Ui.label({
		Name = "Status",
		Text = "",
		MaxTextSize = 16,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -50, 0, 6),
		Size = UDim2.new(0.6, -50, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Ui.Colors.muted,
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

	local scroll = Ui.new("ScrollingFrame", {
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
	})

	local eggRows: { [string]: EggRow } = {}
	for order, egg in SETTINGS.eggs do
		local row = Ui.new("Frame", {
			Name = egg.id,
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 92),
			BackgroundColor3 = Ui.Colors.panelLight,
			Parent = scroll,
		}, { Ui.corner(10) })
		Ui.new("Frame", {
			Name = "Egg",
			Position = UDim2.fromOffset(10, 16),
			Size = UDim2.fromOffset(46, 60),
			BackgroundColor3 = egg.color,
			Parent = row,
		}, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		Ui.label({
			Name = "EggName",
			Text = egg.name,
			Font = Ui.TitleFont,
			MaxTextSize = 20,
			Position = UDim2.fromOffset(66, 6),
			Size = UDim2.new(1, -180, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		-- Every outcome and its chance, visible before buying.
		Ui.label({
			Name = "Odds",
			Text = `{oddsText(egg)}\nAny pet: {SETTINGS.goldenChance * 100}% chance to be Golden (double perk)`,
			MaxTextSize = 13,
			TextWrapped = true,
			Position = UDim2.fromOffset(66, 32),
			Size = UDim2.new(1, -180, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Ui.Colors.muted,
			Parent = row,
		})
		local price = Ui.label({
			Name = "Price",
			Text = `{EconomyMath.formatNumber(egg.price)} shells`,
			MaxTextSize = 15,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.fromOffset(100, 20),
			TextColor3 = Ui.Colors.rare,
			Parent = row,
		})
		local buy = Ui.button({
			Name = "Buy",
			Text = "Hatch",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -10),
			Size = UDim2.fromOffset(100, 44),
			Parent = row,
		})
		buy.Activated:Connect(function()
			Remotes.BuyEgg:FireServer(egg.id)
		end)
		eggRows[egg.id] = { buy = buy, price = price }
	end

	Ui.label({
		Name = "YourPets",
		LayoutOrder = 10,
		Text = "Your pets",
		Font = Ui.TitleFont,
		MaxTextSize = 20,
		Size = UDim2.new(1, -8, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = scroll,
	})
	local grid = Ui.new("Frame", {
		Name = "Owned",
		LayoutOrder = 11,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = scroll,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 190),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local self = setmetatable({
		gui = gui,
		status = status,
		eggRows = eggRows,
		grid = grid,
		data = nil,
		stand = nil,
		shown = "",
		confirming = nil,
	}, PetPanel)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

-- stand is the Pet Hatchery when opened from its prompt; eggs can only be bought there.
function PetPanel.setOpen(self: PetPanel, open: boolean, stand: BasePart?)
	self.gui.Enabled = open
	self.stand = if open then stand else nil
	if open then
		self.shown = ""
		self:render()
	end
end

function PetPanel.setData(self: PetPanel, data: any)
	self.data = data
	self:render()
end

-- Called often: closes the window when the player walks away from the Hatchery.
function PetPanel.update(self: PetPanel)
	if not self.gui.Enabled or not self.stand then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - self.stand.Position).Magnitude > ReefConfig.INTERACT_DISTANCE + 4 then
		self:setOpen(false)
	end
end

function PetPanel.render(self: PetPanel)
	if not self.gui.Enabled or not self.data then
		return
	end
	local data = self.data
	local pets = data.pets or {}
	local equipped = data.equipped or {}
	local owned = 0
	for _ in pets do
		owned += 1
	end
	self.status.Text = `{#equipped}/{SETTINGS.maxEquipped} out · {owned}/{SETTINGS.maxOwned} owned`

	for _, egg in SETTINGS.eggs do
		local row = self.eggRows[egg.id]
		local affordable = data.shells >= egg.price
		row.buy.Text = if self.stand then "Hatch" else "At Hatchery"
		row.buy.BackgroundColor3 = if self.stand and affordable then Ui.Colors.button else Ui.Colors.buttonDisabled
		row.price.TextColor3 = if affordable then Ui.Colors.rare else Ui.Colors.bad
	end

	-- Rebuild the pet cards only when the pets, what's out, or a pending release changed.
	local ids = {}
	for petId in pets do
		table.insert(ids, petId)
	end
	table.sort(ids, function(a, b)
		return tonumber(a) > tonumber(b) -- newest first
	end)
	local shown = `{table.concat(ids, ",")}|{table.concat(equipped, ",")}|{self.confirming or ""}`
	if shown == self.shown then
		return
	end
	self.shown = shown
	for _, child in self.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #ids == 0 then
		Ui.label({
			Name = "Empty",
			Text = "No pets yet. Hatch an egg at the Pet Hatchery!",
			MaxTextSize = 15,
			TextColor3 = Ui.Colors.muted,
			Parent = self.grid,
		})
		return
	end

	for order, petId in ids do
		local pet = pets[petId]
		local def = SETTINGS.species[pet.species]
		local out = table.find(equipped, petId) ~= nil
		local card = Ui.new("Frame", {
			Name = petId,
			LayoutOrder = order,
			BackgroundColor3 = Ui.Colors.panelLight,
			Parent = self.grid,
		}, { Ui.corner(10), Ui.stroke(if pet.golden then Ui.Colors.rare elseif out then Ui.Colors.good else Ui.Colors.panel, 2) })
		Ui.viewport({ Name = "Model", Size = UDim2.new(1, 0, 0, 70) }, PetVisuals.build(pet.species, pet.golden)).Parent = card
		Ui.label({
			Name = "PetName",
			Text = if pet.golden then `Golden {def.name}` else def.name,
			Font = Ui.TitleFont,
			MaxTextSize = 15,
			Position = UDim2.fromOffset(4, 70),
			Size = UDim2.new(1, -8, 0, 18),
			TextColor3 = if pet.golden then Ui.Colors.rare else Ui.Colors.text,
			Parent = card,
		})
		Ui.label({
			Name = "Perk",
			Text = if pet.golden then def.goldenPerk else def.perk,
			MaxTextSize = 12,
			TextWrapped = true,
			Position = UDim2.fromOffset(4, 88),
			Size = UDim2.new(1, -8, 0, 30),
			TextColor3 = Ui.Colors.muted,
			Parent = card,
		})
		local equip = Ui.button({
			Name = "Equip",
			Text = if out then "Put away" else "Take out",
			Position = UDim2.fromOffset(6, 120),
			Size = UDim2.new(1, -12, 0, 30),
			MaxTextSize = 15,
			BackgroundColor3 = if out then Ui.Colors.buttonDisabled else Ui.Colors.button,
			Parent = card,
		})
		equip.Activated:Connect(function()
			Remotes.EquipPet:FireServer(petId, not out)
		end)
		local refund = if pet.golden then SETTINGS.releaseShells.golden else SETTINGS.releaseShells.normal
		local sure = self.confirming == petId
		local release = Ui.button({
			Name = "Release",
			Text = if sure then `Sure? +{refund}` else "Release",
			Position = UDim2.fromOffset(6, 154),
			Size = UDim2.new(1, -12, 0, 28),
			MaxTextSize = 13,
			BackgroundColor3 = if sure then Ui.Colors.bad else Ui.Colors.panel,
			Parent = card,
		})
		release.Activated:Connect(function()
			if self.confirming == petId then
				self.confirming = nil
				Remotes.ReleasePet:FireServer(petId)
			else
				-- A second press within a few seconds releases it.
				self.confirming = petId
				self:render()
				task.delay(3, function()
					if self.confirming == petId then
						self.confirming = nil
						self:render()
					end
				end)
			end
		end)
	end
end

return PetPanel

--!nonstrict
-- The Quests window (side button): today's daily quests with Claim buttons, Rebirth, and the
-- title shown over your head. Buttons send requests only; the server checks progress, cost
-- and ownership (Quests, Rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local QuestsPanel = {}
QuestsPanel.__index = QuestsPanel

type QuestRow = { text: TextLabel, reward: TextLabel, fill: Frame, count: TextLabel, claim: TextButton }

export type QuestsPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		resetLine: TextLabel,
		questRows: { QuestRow },
		rebirthInfo: TextLabel,
		rebirthButton: TextButton,
		confirmUntil: number, -- the Rebirth button wants a second press until this time
		titleButtons: { [string]: TextButton },
		data: any,
	},
	QuestsPanel
))

local REBIRTH_COLOR = Color3.fromRGB(220, 110, 60)

function QuestsPanel.new(playerGui: PlayerGui): QuestsPanel
	local gui = Ui.new("ScreenGui", {
		Name = "QuestsGui",
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
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(600, 600))
	Ui.label({
		Name = "Title",
		Text = "Quests",
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
	local function nextOrder(): number
		order += 1
		return order
	end
	local function heading(text: string)
		Ui.label({
			Name = "Heading",
			LayoutOrder = nextOrder(),
			Text = text,
			Font = Ui.TitleFont,
			MaxTextSize = 20,
			Size = UDim2.new(1, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.rare,
			Parent = body,
		})
	end

	heading("Daily quests")
	local resetLine = Ui.label({
		Name = "Reset",
		LayoutOrder = nextOrder(),
		Text = "",
		MaxTextSize = 14,
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = body,
	})
	local questRows: { QuestRow } = {}
	for slot = 1, ReefConfig.Quests.perDay do
		local frame = Ui.new("Frame", {
			Name = "Quest" .. slot,
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundColor3 = Ui.Colors.panelLight,
			Parent = body,
		}, { Ui.corner(10) })
		local text = Ui.label({
			Name = "Text",
			Text = "",
			Font = Ui.TitleFont,
			MaxTextSize = 17,
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -140, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local reward = Ui.label({
			Name = "Reward",
			Text = "",
			MaxTextSize = 14,
			Position = UDim2.fromOffset(10, 28),
			Size = UDim2.new(1, -140, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.rare,
			Parent = frame,
		})
		local bar = Ui.new("Frame", {
			Name = "Bar",
			Position = UDim2.fromOffset(10, 50),
			Size = UDim2.new(1, -140, 0, 16),
			BackgroundColor3 = Ui.Colors.panel,
			Parent = frame,
		}, { Ui.corner(8) })
		local fill = Ui.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Ui.Colors.good,
			Parent = bar,
		}, { Ui.corner(8) })
		local count = Ui.label({
			Name = "Count",
			Text = "",
			MaxTextSize = 12,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			TextStrokeTransparency = 0.5,
			Parent = bar,
		})
		local claim = Ui.button({
			Name = "Claim",
			Text = "Claim",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 46),
			MaxTextSize = 17,
			Parent = frame,
		})
		claim.Activated:Connect(function()
			Remotes.ClaimQuest:FireServer(slot)
		end)
		questRows[slot] = { text = text, reward = reward, fill = fill, count = count, claim = claim }
	end

	heading("Rebirth")
	local rebirthInfo = Ui.label({
		Name = "RebirthInfo",
		LayoutOrder = nextOrder(),
		Text = "",
		MaxTextSize = 14,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 58),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Ui.Colors.text,
		Parent = body,
	})
	local rebirthButton = Ui.button({
		Name = "Rebirth",
		LayoutOrder = nextOrder(),
		Text = "Rebirth",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = REBIRTH_COLOR,
		MaxTextSize = 18,
		Parent = body,
	})

	heading("Your title")
	local titleGrid = Ui.new("Frame", {
		Name = "Titles",
		LayoutOrder = nextOrder(),
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(170, 38),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local titleButtons: { [string]: TextButton } = {}
	local titleChoices = { { id = "", text = "No title" } }
	for _, titleDef in ReefConfig.Titles do
		table.insert(titleChoices, { id = titleDef.id, text = titleDef.text })
	end
	for i, choice in titleChoices do
		local button = Ui.button({
			Name = if choice.id == "" then "None" else choice.id,
			LayoutOrder = i,
			Text = choice.text,
			BackgroundColor3 = Ui.Colors.panelLight,
			MaxTextSize = 15,
			Parent = titleGrid,
		})
		button.Activated:Connect(function()
			Remotes.EquipTitle:FireServer(choice.id)
		end)
		titleButtons[choice.id] = button
	end

	local self = setmetatable({
		gui = gui,
		resetLine = resetLine,
		questRows = questRows,
		rebirthInfo = rebirthInfo,
		rebirthButton = rebirthButton,
		confirmUntil = 0,
		titleButtons = titleButtons,
		data = nil,
	}, QuestsPanel)

	-- Rebirth resets a lot, so it takes a second press to confirm.
	rebirthButton.Activated:Connect(function()
		local data = self.data
		if not data or data.shells < data.rebirthCost then
			return
		end
		if os.clock() < self.confirmUntil then
			self.confirmUntil = 0
			Remotes.Rebirth:FireServer()
		else
			self.confirmUntil = os.clock() + 4
		end
		self:render()
	end)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

function QuestsPanel.setOpen(self: QuestsPanel, open: boolean)
	self.gui.Enabled = open
	if open then
		self:render()
	end
end

function QuestsPanel.setData(self: QuestsPanel, data: any)
	self.data = data
	self:render()
end

-- Whether a quest is done and waiting to be claimed (the HUD marks the Quests button).
function QuestsPanel.readyToClaim(data: any): boolean
	if not data or type(data.quests) ~= "table" then
		return false
	end
	for slot, id in ReefConfig.dailyQuests(data.quests.day) do
		local quest = ReefConfig.QuestById[id]
		if not data.quests.claimed[slot] and (data.quests.progress[slot] or 0) >= quest.goal then
			return true
		end
	end
	return false
end

function QuestsPanel.render(self: QuestsPanel)
	local data = self.data
	if not self.gui.Enabled or not data then
		return
	end
	local book = data.quests
	for slot, id in ReefConfig.dailyQuests(book.day) do
		local quest = ReefConfig.QuestById[id]
		local r = self.questRows[slot]
		local progress = math.min(book.progress[slot] or 0, quest.goal)
		local claimed = book.claimed[slot] == true
		r.text.Text = string.format(quest.text, quest.goal)
		local reward = `+{EconomyMath.formatNumber(ReefConfig.questShells(quest, data.unlocked))} shells`
		if quest.seed and ReefConfig.Seeds[quest.seed.id] then
			reward ..= `, {quest.seed.count} {ReefConfig.Seeds[quest.seed.id].name} seed`
		end
		r.reward.Text = reward
		r.fill.Size = UDim2.fromScale(progress / quest.goal, 1)
		r.count.Text = `{EconomyMath.formatNumber(progress)} / {EconomyMath.formatNumber(quest.goal)}`
		if claimed then
			r.claim.Text = "Claimed"
			r.claim.BackgroundColor3 = Ui.Colors.buttonDisabled
		else
			r.claim.Text = "Claim"
			r.claim.BackgroundColor3 = if progress >= quest.goal then Ui.Colors.button else Ui.Colors.buttonDisabled
		end
	end

	local bonus = math.round((ReefConfig.shellMultiplier(data.rebirths) - 1) * 100)
	local nextBonus = math.round(ReefConfig.Rebirth.shellBonus * 100)
	local maxed = data.rebirths >= ReefConfig.Rebirth.maxRebirths
	self.rebirthInfo.Text = `Rebirths: {data.rebirths}. Coral and fish pay +{bonus}% shells.\n`
		.. (if maxed
			then "You've reached the highest rebirth!"
			else `Rebirth for +{nextBonus}% more. You start over with {ReefConfig.STARTING_SHELLS} shells, starter seeds, an empty bag and a small reef. You keep pets, the Reef Index, fences, decorations, gear and titles.`)
	local canAfford = data.shells >= data.rebirthCost
	if maxed then
		self.rebirthButton.Text = "Max rebirth"
		self.rebirthButton.BackgroundColor3 = Ui.Colors.buttonDisabled
	elseif os.clock() < self.confirmUntil then
		self.rebirthButton.Text = "Press again to rebirth!"
		self.rebirthButton.BackgroundColor3 = Ui.Colors.bad
	else
		self.rebirthButton.Text = `Rebirth for {EconomyMath.formatNumber(data.rebirthCost)} shells`
		self.rebirthButton.BackgroundColor3 = if canAfford then REBIRTH_COLOR else Ui.Colors.buttonDisabled
	end

	for id, button in self.titleButtons do
		local earned = id == "" or data.titles[id] == true
		local titleDef = ReefConfig.TitleById[id]
		button.Text = if earned then (if titleDef then titleDef.text else "No title") else "Locked"
		button.TextColor3 = if earned and titleDef then titleDef.color else Color3.new(1, 1, 1)
		button.BackgroundColor3 = if data.title == id then Ui.Colors.button elseif earned then Ui.Colors.panelLight else Color3.fromRGB(20, 30, 45)
		button.AutoButtonColor = earned
	end
end

-- Called a few times a second: the reset countdown, and the Rebirth confirm running out.
function QuestsPanel.update(self: QuestsPanel)
	if not self.gui.Enabled then
		return
	end
	local now = os.time()
	local nextDay = (ReefConfig.dayNumber(now) + 1) * 86400
	local left = nextDay - now
	self.resetLine.Text = string.format("New quests in %d:%02d:%02d", left // 3600, left % 3600 // 60, left % 60)
	if self.confirmUntil > 0 and os.clock() >= self.confirmUntil then
		self.confirmUntil = 0
		self:render()
	end
end

return QuestsPanel

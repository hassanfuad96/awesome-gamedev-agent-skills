--!nonstrict
-- Otto's Ranger Journal: the Kelp Forest's challenges (KelpConfig.Challenges) with what's
-- done, how to do the rest and what each pays, plus how restored the two seagrass meadows
-- are right now. Opened by talking to Otto at the forest's entrance; closes when you walk
-- off. Reads only what the server synced (data.kelp) and the meadow patches' attributes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local KelpConfig = require(ReplicatedStorage.Shared.KelpConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local Ui = require(script.Parent.Ui)

local KelpPanel = {}
KelpPanel.__index = KelpPanel

type Row = { frame: Frame, mark: TextLabel, title: TextLabel, detail: TextLabel }

export type KelpPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		summary: TextLabel,
		rows: { [string]: Row },
		data: any,
		otto: BasePart?,
	},
	KelpPanel
))

local GREEN = Color3.fromRGB(150, 225, 90)

local function rewardText(reward: KelpConfig.Reward): string
	local parts = { `{EconomyMath.formatNumber(reward.shells)} shells` }
	for seedId, count in reward.seeds or {} do
		local seed = ReefConfig.Seeds[seedId]
		if seed then
			table.insert(parts, `{count} {seed.name}`)
		end
	end
	if reward.title and ReefConfig.TitleById[reward.title] then
		table.insert(parts, `"{ReefConfig.TitleById[reward.title].text}" title`)
	end
	return table.concat(parts, " + ")
end

-- How restored each meadow is now, from its patches' State attributes.
local function meadowLine(): string
	local lines = {}
	for _, meadow in KelpConfig.Meadows do
		local total, score = 0, 0
		for _, patch in CollectionService:GetTagged(KelpConfig.PATCH_TAG) do
			if patch:GetAttribute("Meadow") == meadow.id then
				total += 1
				local state = patch:GetAttribute("State")
				score += if state == "lush" then 1 elseif state == "growing" then 0.5 else 0
			end
		end
		if total > 0 then
			table.insert(lines, `{meadow.name} {math.round(score / total * 100)}%`)
		end
	end
	return if #lines > 0 then "Seagrass: " .. table.concat(lines, " · ") else ""
end

function KelpPanel.new(playerGui: PlayerGui): KelpPanel
	local gui = Ui.new("ScreenGui", {
		Name = "KelpJournalGui",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local root = Ui.new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(16, 48, 40),
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(GREEN, 2), Ui.padding(12) })
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(560, 580))
	Ui.label({
		Name = "Title",
		Text = "Otto's Ranger Journal",
		Font = Ui.TitleFont,
		MaxTextSize = 28,
		Size = UDim2.new(1, -50, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GREEN,
		Parent = root,
	})
	local close = Ui.button({
		Name = "Close",
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(40, 34),
		BackgroundColor3 = Ui.Colors.bad,
		Parent = root,
	})
	local summary = Ui.label({
		Name = "Summary",
		Text = "",
		MaxTextSize = 15,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = root,
	})
	local list = Ui.new("ScrollingFrame", {
		Name = "Challenges",
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -62),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = root,
	}, { Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })

	local rows: { [string]: Row } = {}
	for order, challenge in KelpConfig.Challenges do
		local frame = Ui.new("Frame", {
			Name = challenge.id,
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 70),
			BackgroundColor3 = Color3.fromRGB(26, 70, 58),
			Parent = list,
		}, { Ui.corner(10) })
		local mark = Ui.label({
			Name = "Mark",
			Text = "",
			Font = Ui.TitleFont,
			MaxTextSize = 26,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, 30, 1, 0),
			Parent = frame,
		})
		local title = Ui.label({
			Name = "ChallengeTitle",
			Text = challenge.title,
			Font = Ui.TitleFont,
			MaxTextSize = 19,
			Position = UDim2.fromOffset(44, 6),
			Size = UDim2.new(1, -52, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local detail = Ui.label({
			Name = "Detail",
			Text = "",
			MaxTextSize = 14,
			TextWrapped = true,
			Position = UDim2.fromOffset(44, 30),
			Size = UDim2.new(1, -52, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Ui.Colors.muted,
			Parent = frame,
		})
		rows[challenge.id] = { frame = frame, mark = mark, title = title, detail = detail }
	end

	local self = setmetatable({ gui = gui, summary = summary, rows = rows, data = nil, otto = nil }, KelpPanel)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	return self
end

function KelpPanel.setOpen(self: KelpPanel, open: boolean, otto: BasePart?)
	self.gui.Enabled = open
	self.otto = if open then otto else nil
	if open then
		self:render()
	end
end

function KelpPanel.setData(self: KelpPanel, data: any)
	self.data = data
	self:render()
end

function KelpPanel.render(self: KelpPanel)
	if not self.gui.Enabled then
		return
	end
	local state = self.data and self.data.kelp or KelpConfig.newState()
	local fish = self.data and self.data.index and self.data.index.fish or {}
	local done = 0
	for _, challenge in KelpConfig.Challenges do
		local row = self.rows[challenge.id]
		local finished = state.done[challenge.id] == true
		if finished then
			done += 1
		end
		-- Progress for the counting challenges.
		local progress = ""
		if challenge.id == "hatchlings" then
			progress = ` ({math.min(state.hatchlings, 3)}/3)`
		elseif challenge.id == "meadow" then
			progress = ` ({math.min(state.restored, 10)}/10)`
		elseif challenge.id == "glades" then
			progress = ` ({KelpConfig.count(state.glades)}/{#KelpConfig.Glades})`
		elseif challenge.id == "naturalist" then
			local caught = 0
			for _, id in KelpConfig.FISH_IDS do
				if fish[id] then
					caught += 1
				end
			end
			progress = ` ({caught}/{#KelpConfig.FISH_IDS})`
		end
		row.mark.Text = if finished then "✓" else "○"
		row.mark.TextColor3 = if finished then Ui.Colors.good else Ui.Colors.muted
		row.title.Text = challenge.title .. (if finished then "" else progress)
		row.title.TextColor3 = if finished then Ui.Colors.good else Ui.Colors.text
		row.detail.Text = if finished then `Done! Earned {rewardText(challenge.reward)}.` else `{challenge.hint} Reward: {rewardText(challenge.reward)}.`
		row.frame.BackgroundTransparency = if finished then 0.4 else 0
	end
	local meadows = meadowLine()
	self.summary.Text = `{done} of {#KelpConfig.Challenges} challenges done` .. (if meadows ~= "" then "   ·   " .. meadows else "")
end

-- Called a few times a second: refreshes the meadows, closes when you walk away from Otto.
function KelpPanel.update(self: KelpPanel)
	if not self.gui.Enabled then
		return
	end
	self:render()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if self.otto and root and (root.Position - self.otto.Position).Magnitude > 24 then
		self:setOpen(false)
	end
end

return KelpPanel

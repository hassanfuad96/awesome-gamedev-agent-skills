--!nonstrict
-- The Rewards window (the Rewards button under Store): the daily login streak, your shell
-- boost, inviting friends, codes, the group reward, notifications and the weekly board.
-- Also the welcome-back popup (Remotes.Welcome). Everything shown comes from the server
-- (DataSync, WeeklyBoard); buttons only ask (RedeemCode, ClaimGroup) or open Roblox prompts.

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local MenuButtons = require(script.Parent.MenuButtons)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RewardsPanel = {}
RewardsPanel.__index = RewardsPanel

export type RewardsPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		dayTiles: { Frame },
		streakText: TextLabel,
		boostText: TextLabel,
		boostDetail: TextLabel,
		inviteText: TextLabel,
		groupButton: TextButton?,
		groupText: TextLabel?,
		notifyButton: TextButton,
		weeklyList: Frame,
		weeklyMine: TextLabel,
		weeklyEnds: TextLabel,
		weeklyEndsAt: number?,
		data: any,
	},
	RewardsPanel
))

local REWARD = Color3.fromRGB(110, 230, 160)
local SETTINGS = ReefConfig.Rewards

local function heading(parent: Instance, order: number, text: string)
	Ui.label({
		Name = text,
		LayoutOrder = order,
		Text = text,
		Font = Ui.TitleFont,
		MaxTextSize = 20,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = REWARD,
		Parent = parent,
	})
end

local function note(parent: Instance, order: number, text: string, height: number?): TextLabel
	return Ui.label({
		Name = "Note" .. order,
		LayoutOrder = order,
		Text = text,
		TextWrapped = true,
		MaxTextSize = 15,
		Size = UDim2.new(1, 0, 0, height or 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = parent,
	})
end

-- A row holding a label on the left and a button on the right.
local function actionRow(parent: Instance, order: number, text: string, buttonText: string, color: Color3?): (TextLabel, TextButton)
	local row = Ui.new("Frame", {
		Name = "Row" .. order,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local label = Ui.label({
		Name = "Text",
		Text = text,
		TextWrapped = true,
		MaxTextSize = 15,
		Size = UDim2.new(1, -130, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local button = Ui.button({
		Name = "Button",
		Text = buttonText,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(120, 38),
		BackgroundColor3 = color or Ui.Colors.button,
		MaxTextSize = 17,
		Parent = row,
	})
	return label, button
end

local function formatDuration(seconds: number): string
	local minutes = math.floor(seconds / 60)
	if minutes >= 60 then
		return `{minutes // 60}h {minutes % 60}m`
	end
	return `{minutes}m`
end

local function shortReward(bundle: ReefConfig.RewardBundle): string
	local parts = {}
	if bundle.shells then
		table.insert(parts, EconomyMath.formatNumber(bundle.shells) .. " shells")
	end
	for _, seedId in ReefConfig.SEED_ORDER do
		local count = bundle.seeds and bundle.seeds[seedId]
		if count then
			table.insert(parts, `{count} {ReefConfig.Seeds[seedId].name}`)
		end
	end
	return table.concat(parts, " + ")
end

-- The welcome-back popup.
local function showWelcome(playerGui: PlayerGui, info: any)
	local old = playerGui:FindFirstChild("WelcomeBack")
	if old then
		old:Destroy()
	end
	local gui = Ui.new("ScreenGui", {
		Name = "WelcomeBack",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = playerGui,
	})
	local root = Ui.new("Frame", {
		Name = "Root",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 260),
		BackgroundColor3 = Ui.Colors.panel,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(REWARD, 2), Ui.padding(14) })
	Ui.autoScale({ root })
	Ui.label({
		Name = "Title",
		Text = "Welcome back!",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = REWARD,
		Parent = root,
	})
	local lines = {}
	if type(info.offlineShells) == "number" and info.offlineShells > 0 then
		table.insert(lines, `You were away {formatDuration(info.awaySeconds or 0)}. Your reef earned {EconomyMath.formatNumber(info.offlineShells)} shells!`)
	end
	if type(info.dailyText) == "string" then
		table.insert(lines, `Day {info.streak or 1} login reward: {info.dailyText}.`)
	end
	if type(info.readyCorals) == "number" and info.readyCorals > 0 then
		table.insert(lines, `{info.readyCorals} coral {if info.readyCorals == 1 then "is" else "are"} fully grown and ready to harvest.`)
	end
	Ui.label({
		Name = "Body",
		Text = table.concat(lines, "\n\n"),
		TextWrapped = true,
		MaxTextSize = 18,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -100),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = root,
	})
	local ok = Ui.button({
		Name = "Ok",
		Text = "Let's dive in!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(200, 44),
		Parent = root,
	})
	ok.Activated:Connect(function()
		gui:Destroy()
	end)
end

function RewardsPanel.new(playerGui: PlayerGui): RewardsPanel
	local gui = Ui.new("ScreenGui", {
		Name = "RewardsGui",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 3,
		Parent = playerGui,
	})
	local root = Ui.new("Frame", {
		Name = "Root",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Ui.Colors.panel,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(REWARD, 2), Ui.padding(12) })
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(640, 620))
	Ui.label({
		Name = "Title",
		Text = "Rewards",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(1, -50, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = REWARD,
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
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})

	-- Daily streak: seven tiles.
	heading(body, 1, "Daily Streak")
	local tiles = Ui.new("Frame", {
		Name = "Days",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	local dayTiles = {}
	local count = #SETTINGS.daily
	for day, bundle in SETTINGS.daily do
		local tile = Ui.new("Frame", {
			Name = "Day" .. day,
			LayoutOrder = day,
			Size = UDim2.new(1 / count, -6, 1, 0),
			BackgroundColor3 = Ui.Colors.panelLight,
			Parent = tiles,
		}, { Ui.corner(10), Ui.new("UIStroke", { Color = REWARD, Thickness = 2, Enabled = false }) })
		Ui.label({ Name = "Day", Text = `Day {day}`, Font = Ui.TitleFont, MaxTextSize = 15, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 18), Parent = tile })
		Ui.label({
			Name = "Reward",
			Text = shortReward(bundle),
			TextWrapped = true,
			MaxTextSize = 12,
			Position = UDim2.fromOffset(3, 24),
			Size = UDim2.new(1, -6, 1, -28),
			TextColor3 = Ui.Colors.rare,
			Parent = tile,
		})
		table.insert(dayTiles, tile)
	end
	local streakText = note(body, 3, "", 36)

	-- Shell boost.
	heading(body, 10, "Shell Boost")
	local boostText = note(body, 11, "", 22)
	boostText.TextColor3 = Ui.Colors.text
	local boostDetail = note(body, 12, "", 36)

	-- Invite friends.
	heading(body, 20, "Invite Friends")
	local inviteText, invite = actionRow(body, 21, "", "Invite", Color3.fromRGB(70, 140, 230))
	invite.Activated:Connect(function()
		local player = Players.LocalPlayer
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		end
	end)

	-- Codes.
	heading(body, 30, "Codes")
	local codeRow = Ui.new("Frame", { Name = "CodeRow", LayoutOrder = 31, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = body })
	local box = Ui.new("TextBox", {
		Name = "Code",
		PlaceholderText = "Type a code",
		Text = "",
		ClearTextOnFocus = false,
		Font = Ui.BodyFont,
		TextScaled = true,
		TextColor3 = Ui.Colors.text,
		PlaceholderColor3 = Ui.Colors.muted,
		BackgroundColor3 = Ui.Colors.panelLight,
		Size = UDim2.new(1, -130, 1, 0),
		Parent = codeRow,
	}, { Ui.corner(8), Ui.padding(8), Ui.new("UITextSizeConstraint", { MaxTextSize = 18 }) })
	local redeem = Ui.button({
		Name = "Redeem",
		Text = "Redeem",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(120, 38),
		MaxTextSize = 17,
		Parent = codeRow,
	})
	redeem.Activated:Connect(function()
		if box.Text ~= "" then
			Remotes.RedeemCode:FireServer(box.Text)
			box.Text = ""
		end
	end)
	note(body, 32, "Find codes on the game page and in our updates.")

	-- Group (only once the game has one).
	local groupText, groupButton = nil, nil
	if SETTINGS.group.id ~= 0 then
		heading(body, 40, "Join the Group")
		groupText, groupButton = actionRow(body, 41, `Join the Grow a Reef group for {EconomyMath.formatNumber(SETTINGS.group.shells)} shells and the Reef Crew title.`, "Check")
		groupButton.Activated:Connect(function()
			Remotes.ClaimGroup:FireServer()
		end)
	end

	-- Notifications.
	heading(body, 50, "Notifications")
	local _, notifyButton = actionRow(body, 51, "Get a heads-up from Roblox when something big happens on the reef.", "Notify me", Color3.fromRGB(150, 110, 230))
	notifyButton.Activated:Connect(function()
		local ok, can = pcall(ExperienceNotificationService.CanPromptOptInAsync, ExperienceNotificationService)
		if ok and can then
			pcall(ExperienceNotificationService.PromptOptIn, ExperienceNotificationService)
		else
			notifyButton.Text = "All set"
			notifyButton.AutoButtonColor = false
			notifyButton.BackgroundColor3 = Ui.Colors.buttonDisabled
		end
	end)

	-- Weekly board.
	heading(body, 60, "This Week's Top Divers")
	local weeklyEnds = note(body, 61, "")
	local prizes = SETTINGS.weekly.prizes
	note(body, 62, `Prizes: 1st {EconomyMath.formatNumber(prizes[1])} shells and the Weekly Champion title, 2nd {EconomyMath.formatNumber(prizes[2])}, 3rd {EconomyMath.formatNumber(prizes[3])}, 4th to 10th {EconomyMath.formatNumber(prizes[4])}.`, 36)
	local weeklyList = Ui.new("Frame", {
		Name = "Weekly",
		LayoutOrder = 63,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	}, { Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })
	local weeklyMine = note(body, 64, "", 22)
	weeklyMine.TextColor3 = Ui.Colors.rare

	local self = setmetatable({
		gui = gui,
		dayTiles = dayTiles,
		streakText = streakText,
		boostText = boostText,
		boostDetail = boostDetail,
		inviteText = inviteText,
		groupButton = groupButton,
		groupText = groupText,
		notifyButton = notifyButton,
		weeklyList = weeklyList,
		weeklyMine = weeklyMine,
		weeklyEnds = weeklyEnds,
		weeklyEndsAt = nil,
		data = {},
	}, RewardsPanel)

	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	MenuButtons.add("Rewards", "Rewards", Color3.fromRGB(40, 160, 110), 2, function()
		self:setOpen(not self.gui.Enabled)
	end)
	Remotes.WeeklyBoard.OnClientEvent:Connect(function(board)
		if type(board) == "table" then
			self:setWeekly(board)
		end
	end)
	Remotes.Welcome.OnClientEvent:Connect(function(info)
		if type(info) == "table" then
			showWelcome(playerGui, info)
		end
	end)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("FriendsHere"):Connect(function()
		self:render()
	end)
	self:render()
	return self
end

function RewardsPanel.setOpen(self: RewardsPanel, open: boolean)
	self.gui.Enabled = open
	if open then
		self:render()
	end
end

function RewardsPanel.setData(self: RewardsPanel, data: any)
	self.data = data
	self:render()
end

function RewardsPanel.setWeekly(self: RewardsPanel, board: any)
	for _, child in self.weeklyList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local me = Players.LocalPlayer.UserId
	local rows = if type(board.rows) == "table" then board.rows else {}
	if #rows == 0 then
		note(self.weeklyList, 1, "Nobody has earned shells this week yet. Be the first!")
	end
	for rank, row in rows do
		if type(row) ~= "table" or type(row.value) ~= "number" then
			continue
		end
		local label = note(self.weeklyList, rank, `{rank}. {tostring(row.name)}  -  {EconomyMath.formatNumber(row.value)} shells`, 20)
		label.TextColor3 = if row.userId == me then Ui.Colors.rare elseif rank == 1 then Color3.fromRGB(255, 220, 120) else Ui.Colors.text
	end
	self.weeklyEndsAt = if type(board.endsAt) == "number" then board.endsAt else nil
	self:update()
end

-- The weekly countdown, while the window is open.
function RewardsPanel.update(self: RewardsPanel)
	if not self.gui.Enabled or not self.weeklyEndsAt then
		return
	end
	local left = math.max(0, self.weeklyEndsAt - os.time())
	self.weeklyEnds.Text = `Shells earned since Monday. Resets in {left // 86400}d {(left % 86400) // 3600}h {(left % 3600) // 60}m (UTC).`
end

function RewardsPanel.render(self: RewardsPanel)
	local data = self.data
	local login = if type(data.login) == "table" then data.login else { day = 0, streak = 0 }
	local streak = if type(login.streak) == "number" then login.streak else 0
	local todayTile = if streak > 0 then (streak - 1) % #SETTINGS.daily + 1 else 0
	for day, tile in self.dayTiles do
		local stroke = tile:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = day == todayTile
		end
		tile.BackgroundColor3 = if day <= todayTile then Color3.fromRGB(30, 100, 80) else Ui.Colors.panelLight
	end
	local nextDay = todayTile % #SETTINGS.daily + 1
	self.streakText.Text = if streak > 0
		then `Streak: {streak} day{if streak == 1 then "" else "s"}. Today's reward is yours! Come back tomorrow for Day {nextDay}. Miss one day and your streak is safe.`
		else "Play each day for bigger rewards."

	local player = Players.LocalPlayer
	local boost = if type(data.boost) == "number" then data.boost else 0
	local friends = player:GetAttribute("FriendsHere") or 0
	local premium = player:GetAttribute("PremiumBoost") == true
	self.boostText.Text = if boost > 0 then `+{math.floor(boost * 100 + 0.5)}% shells on everything you sell` else "No boost right now"
	local parts = {
		`Roblox Premium: +{math.floor(SETTINGS.premiumBonus * 100)}%{if premium then " (you have it!)" else ""}`,
		`Each friend in this server: +{math.floor(SETTINGS.friendBonus * 100)}% (up to +{math.floor(SETTINGS.friendBonusMax * 100)}%). Friends here now: {friends}`,
	}
	self.boostDetail.Text = table.concat(parts, "\n")

	local referral = SETTINGS.referral
	local invited = if type(data.referrals) == "number" then data.referrals else 0
	self.inviteText.Text = `Each friend who joins from your invite earns you {EconomyMath.formatNumber(referral.shells)} shells, and they get {EconomyMath.formatNumber(referral.newcomerShells)}. Friends joined: {invited}`

	if self.groupButton and self.groupText then
		local claimed = data.groupRewarded == true
		self.groupButton.Text = if claimed then "Claimed" else "Check"
		self.groupButton.AutoButtonColor = not claimed
		self.groupButton.BackgroundColor3 = if claimed then Ui.Colors.buttonDisabled else Ui.Colors.button
	end

	local earned = if type(data.weeklyEarned) == "number" then data.weeklyEarned else 0
	self.weeklyMine.Text = `You: {EconomyMath.formatNumber(earned)} shells this week`
	self:update()
end

return RewardsPanel

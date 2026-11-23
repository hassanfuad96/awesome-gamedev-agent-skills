--!nonstrict
-- The Sunken Ruins on the client: shows only what the server synced (data.ruins), never
-- decides anything.
--   the Explorer's Journal  (the Journal side button, or talking to Marlo): missions, relics,
--                           rare creatures, hidden coral and chest timers, and a button to
--                           teleport to the ruins
--   the mission tracker     a card under the top bar with the current mission once the
--                           Starter Lagoon tutorial is done, and a marker over where to go
--   the spots               each player sees their own chests (looted ones show a refill
--                           timer), relics (found ones disappear) and hidden coral (cut today)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local RuinsConfig = require(ReplicatedStorage.Shared.RuinsConfig)
local AbyssConfig = require(ReplicatedStorage.Shared.AbyssConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RuinsPanel = {}
RuinsPanel.__index = RuinsPanel

local SAND = Color3.fromRGB(240, 200, 130)
local DONE = Ui.Colors.good
local player = Players.LocalPlayer

type Row = { frame: Frame, title: TextLabel, detail: TextLabel }

export type RuinsPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		body: ScrollingFrame,
		missionLine: TextLabel,
		rows: { [string]: Row }, -- "chest:gate", "coral:cave1", "creature:squid" ... for the timers
		card: Frame,
		cardTitle: TextLabel,
		cardHint: TextLabel,
		marker: BillboardGui,
		markerText: TextLabel,
		anchor: Part,
		labels: { [Model]: BillboardGui },
		data: any,
	},
	RuinsPanel
))

local function rewardText(reward: RuinsConfig.Reward): string
	local parts = { `{EconomyMath.formatNumber(reward.shells)} shells` }
	for _, seedId in ReefConfig.SEED_ORDER do
		local count = reward.seeds and reward.seeds[seedId]
		if count then
			table.insert(parts, `{count} {ReefConfig.Seeds[seedId].name} seed{if count > 1 then "s" else ""}`)
		end
	end
	local title = reward.title and ReefConfig.TitleById[reward.title]
	if title then
		table.insert(parts, `"{title.text}" title`)
	end
	return "Reward: " .. table.concat(parts, ", ")
end

-- "5h 12m" for long waits; Ui.formatTime ("4:05") for short ones.
local function longTime(seconds: number): string
	if seconds >= 3600 then
		return `{seconds // 3600}h {(seconds % 3600) // 60}m`
	end
	return Ui.formatTime(seconds)
end

local function state(self: RuinsPanel): RuinsConfig.State?
	return self.data and self.data.ruins
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

function RuinsPanel.new(playerGui: PlayerGui): RuinsPanel
	local gui = Ui.new("ScreenGui", {
		Name = "RuinsJournalGui",
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
	}, { Ui.corner(16), Ui.stroke(SAND, 2), Ui.padding(12) })
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(620, 620))
	Ui.label({
		Name = "Title",
		Text = "Explorer's Journal",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(1, -290, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = SAND,
		Parent = root,
	})
	local go = Ui.button({
		Name = "GoToRuins",
		Text = "Go to Ruins",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 0),
		Size = UDim2.fromOffset(110, 36),
		MaxTextSize = 16,
		Parent = root,
	})
	go.Activated:Connect(function()
		Remotes.Teleport:FireServer("ruins")
	end)
	-- The Abyss (zone 3); the server refuses, and says why, until it's unlocked.
	local goAbyss = Ui.button({
		Name = "GoToAbyss",
		Text = "Go to Abyss",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -168, 0, 0),
		Size = UDim2.fromOffset(110, 36),
		BackgroundColor3 = Color3.fromRGB(90, 70, 200),
		MaxTextSize = 16,
		Parent = root,
	})
	goAbyss.Activated:Connect(function()
		Remotes.Teleport:FireServer("abyss")
	end)
	local close = Ui.button({
		Name = "Close",
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(44, 36),
		BackgroundColor3 = Ui.Colors.bad,
		Parent = root,
	})
	local missionLine = Ui.label({
		Name = "Progress",
		Text = "",
		MaxTextSize = 14,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = root,
	})
	local body = Ui.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
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

	-- The tracker card, top right (where the tutorial card sits while the tutorial runs).
	local trackerGui = Ui.new("ScreenGui", {
		Name = "RuinsTrackerGui",
		ResetOnSpawn = false,
		DisplayOrder = -1,
		-- In Roblox's top bar row, like the tutorial card, clear of the teleport buttons.
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local card = Ui.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.Colors.panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = trackerGui,
	}, {
		Ui.corner(12),
		Ui.stroke(SAND, 2),
		Ui.padding(10),
		Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	})
	Ui.label({ Name = "Kicker", LayoutOrder = 1, Text = "SUNKEN RUINS MISSION", Font = Ui.TitleFont, MaxTextSize = 13, Size = UDim2.new(1, 0, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SAND, Parent = card })
	local cardTitle = Ui.label({ Name = "Title", LayoutOrder = 2, Text = "", Font = Ui.TitleFont, MaxTextSize = 18, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local cardHint = Ui.new("TextLabel", {
		Name = "Hint",
		LayoutOrder = 3,
		Text = "",
		Font = Ui.BodyFont,
		TextSize = 13,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.muted,
		Parent = card,
	})
	Ui.autoScale({ card })

	local anchor = Instance.new("Part")
	anchor.Name = "RuinsMissionTarget"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Parent = Workspace
	local marker = Ui.new("BillboardGui", {
		Name = "RuinsMissionMarker",
		Adornee = anchor,
		Size = UDim2.fromOffset(170, 50),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local markerText = Ui.label({ Name = "Text", Text = "", Font = Ui.TitleFont, MaxTextSize = 17, Size = UDim2.new(1, 0, 0, 24), TextColor3 = SAND, TextStrokeTransparency = 0.3, Parent = marker })
	Ui.new("Frame", {
		Name = "Pin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.fromOffset(14, 14),
		Rotation = 45,
		BackgroundColor3 = SAND,
		Parent = marker,
	}, { Ui.corner(3) })

	local self = setmetatable({
		gui = gui,
		body = body,
		missionLine = missionLine,
		rows = {},
		card = card,
		cardTitle = cardTitle,
		cardHint = cardHint,
		marker = marker,
		markerText = markerText,
		anchor = anchor,
		labels = {},
		data = nil,
	}, RuinsPanel)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)

	-- Spots stream in and out; style each one for this player as it arrives.
	for _, spot in CollectionService:GetTagged(RuinsConfig.SPOT_TAG) do
		self:styleSpot(spot)
	end
	CollectionService:GetInstanceAddedSignal(RuinsConfig.SPOT_TAG):Connect(function(spot)
		self:styleSpot(spot)
	end)
	CollectionService:GetInstanceRemovedSignal(RuinsConfig.SPOT_TAG):Connect(function(spot)
		local label = self.labels[spot]
		if label then
			label:Destroy()
			self.labels[spot] = nil
		end
	end)
	return self
end

function RuinsPanel.setOpen(self: RuinsPanel, open: boolean)
	self.gui.Enabled = open
	if open then
		self:rebuild()
		self:update()
	end
end

-- What Marlo says when you talk to him: the current mission, or a tip once all are done.
function RuinsPanel.marloLine(self: RuinsPanel): string
	local s = state(self)
	local mission = s and RuinsConfig.Missions[s.mission]
	if mission then
		return mission.marlo
	end
	return RuinsConfig.doneLines[math.random(1, #RuinsConfig.doneLines)]
end

local function section(self: RuinsPanel, order: number, text: string)
	Ui.label({
		Name = "Heading",
		LayoutOrder = order,
		Text = text,
		Font = Ui.TitleFont,
		MaxTextSize = 19,
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = SAND,
		Parent = self.body,
	})
end

local function row(self: RuinsPanel, order: number, key: string?, title: string, detail: string, color: Color3?, highlight: boolean?): Row
	local frame = Ui.new("Frame", {
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = if highlight then Color3.fromRGB(60, 74, 70) else Ui.Colors.panelLight,
		Parent = self.body,
	}, { Ui.corner(8), if highlight then Ui.stroke(SAND, 2) else nil })
	local titleLabel = Ui.label({ Name = "Title", Text = title, Font = Ui.TitleFont, MaxTextSize = 16, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or Ui.Colors.text, Parent = frame })
	local detailLabel = Ui.label({ Name = "Detail", Text = detail, MaxTextSize = 13, Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Ui.Colors.muted, Parent = frame })
	local r = { frame = frame, title = titleLabel, detail = detailLabel }
	if key then
		self.rows[key] = r
	end
	return r
end

-- Lays out the journal for the current data. Timers are filled in by update().
function RuinsPanel.rebuild(self: RuinsPanel)
	for _, child in self.body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.rows = {}
	local s = state(self)
	if not s then
		return
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local total = #RuinsConfig.Missions
	self.missionLine.Text = if s.mission > total
		then `All {total} exploration missions done!`
		else `Mission {s.mission} of {total}. Talk to Marlo at the ruins entrance for help.`

	section(self, nextOrder(), "Missions")
	for i, mission in RuinsConfig.Missions do
		if i < s.mission then
			row(self, nextOrder(), nil, `✓ {mission.title}`, rewardText(mission.reward), DONE)
		elseif i == s.mission then
			row(self, nextOrder(), nil, `▶ {mission.title}`, mission.hint, SAND, true)
			row(self, nextOrder(), nil, "", rewardText(mission.reward), nil, true).frame.Size = UDim2.new(1, 0, 0, 28)
		else
			row(self, nextOrder(), nil, mission.title, "Locked: finish the missions above first.", Ui.Colors.muted)
		end
	end

	section(self, nextOrder(), `Relics ({RuinsConfig.count(s.relics)}/{#RuinsConfig.Relics.list})`)
	for _, relic in RuinsConfig.Relics.list do
		if s.relics[relic.id] then
			row(self, nextOrder(), nil, `✓ {relic.name}`, "Found!", DONE)
		else
			row(self, nextOrder(), nil, relic.name, relic.hint)
		end
	end

	section(self, nextOrder(), `Rare creatures ({RuinsConfig.count(s.sighted)}/{#RuinsConfig.Creatures.list})`)
	for _, creature in RuinsConfig.Creatures.list do
		local seen = s.sighted[creature.id]
		row(self, nextOrder(), `creature:{creature.id}`, if seen then `✓ {creature.name}` else creature.name, if seen then "Spotted!" else creature.hint, if seen then DONE else nil)
	end

	section(self, nextOrder(), "Hidden coral (one cutting a day from each)")
	for _, spot in RuinsConfig.HiddenCoral do
		local seed = ReefConfig.Seeds[spot.seed]
		row(self, nextOrder(), `coral:{spot.id}`, `{seed.name} ({seed.rarity})`, "")
	end

	section(self, nextOrder(), "Treasure chests (refill every 20 minutes)")
	for _, chest in RuinsConfig.Chests.spots do
		row(self, nextOrder(), `chest:{chest.id}`, chest.name, "")
	end

	-- The Abyss: how to unlock it, then its deep-sea creatures.
	local abyss = self.data.abyss
	local ABYSS = Color3.fromRGB(170, 150, 255)
	section(self, nextOrder(), "The Abyss (south of the plaza)")
	if abyss and abyss.unlocked then
		row(self, nextOrder(), nil, "✓ Unlocked", "Press Go to Abyss, or follow the road south from the plaza. Lumi sells abyssal coral at the bottom.", DONE)
	else
		local exploration, health = AbyssConfig.levels(self.data)
		local u = AbyssConfig.Unlock
		row(self, nextOrder(), nil, `Exploration Level {exploration}/{u.exploration}`, "Sunken Ruins missions done. Reach it to unlock the Abyss...", ABYSS)
		row(self, nextOrder(), nil, `Reef Health {math.min(health, u.reefHealth)}/{u.reefHealth}`, "...or harvest this many coral, ever.", ABYSS)
	end
	local seen = 0
	for _, creature in AbyssConfig.Creatures.list do
		if abyss and abyss.sighted[creature.id] then
			seen += 1
		end
	end
	section(self, nextOrder(), `Deep-sea creatures ({seen}/{#AbyssConfig.Creatures.list})`)
	for _, creature in AbyssConfig.Creatures.list do
		local spotted = abyss and abyss.sighted[creature.id]
		row(self, nextOrder(), nil, if spotted then `✓ {creature.name}` else creature.name, if spotted then "Spotted!" else creature.hint, if spotted then DONE else nil)
	end
end

-- Refreshes the timers: chest refills, cuttings, and when the Giant Squid next rises.
function RuinsPanel.update(self: RuinsPanel)
	local s = state(self)
	if not s then
		return
	end
	local t = now()
	if self.gui.Enabled then
		for _, chest in RuinsConfig.Chests.spots do
			local r = self.rows[`chest:{chest.id}`]
			if r then
				local wait = RuinsConfig.chestWait(s, chest.id, t)
				r.detail.Text = if wait > 0 then `Refills in {Ui.formatTime(wait)}` else "Ready to open!"
				r.detail.TextColor3 = if wait > 0 then Ui.Colors.muted else DONE
			end
		end
		local day = ReefConfig.dayNumber(t)
		for _, spot in RuinsConfig.HiddenCoral do
			local r = self.rows[`coral:{spot.id}`]
			if r then
				local problem = RuinsConfig.cuttingProblem(s, spot, day)
				local where = if spot.seed == "ghost" then "In the cave." else "In the temple sanctum."
				local status = "Ready for a cutting!"
				if s.cuttings[spot.id] == day then
					status = "Regrows in " .. longTime((day + 1) * 86400 - t)
				elseif problem then
					status = problem
				end
				r.detail.Text = `{where} {status}`
				r.detail.TextColor3 = if problem then Ui.Colors.muted else DONE
			end
		end
		local squid = self.rows["creature:squid"]
		if squid and not s.sighted.squid then
			local c = RuinsConfig.Creatures
			local into = t % c.squidEvery
			squid.detail.Text = if into <= c.squidSeconds
				then `It's up right now! Over the Wreck Basin for {Ui.formatTime(c.squidSeconds - into)}.`
				else `Rises out of the Wreck Basin in {Ui.formatTime(c.squidEvery - into)}.`
		end
	end
	self:refreshSpots()
end

-- The tracker card and marker. Called often (every frame batch) by the client's main loop.
function RuinsPanel.track(self: RuinsPanel)
	local s = state(self)
	local data = self.data
	local mission = s and RuinsConfig.Missions[s.mission]
	local tutorialDone = data and ReefConfig.tutorialStep(data.tutorial) == nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local inRuins = root ~= nil and RuinsConfig.inRuins(root.Position)
	-- Show it once the tutorial is done: everywhere for the first mission (an invitation),
	-- then only inside the ruins.
	local show = mission ~= nil and tutorialDone and (s.mission == 1 or inRuins)
	self.card.Visible = show == true
	if show then
		self.cardTitle.Text = mission.title
		self.cardHint.Text = mission.hint
	end
	local target = show and inRuins and mission.target
	if target and root then
		local distance = ((root.Position - target) * Vector3.new(1, 0, 1)).Magnitude
		self.marker.Enabled = distance > 12
		self.anchor.Position = target + Vector3.new(0, 1, 0)
		self.markerText.Text = `{mission.title}  ·  {math.round(distance)}m`
	else
		self.marker.Enabled = false
	end
end

local function promptOf(spot: Instance): ProximityPrompt?
	return spot:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function setEffects(spot: Instance, on: boolean)
	for _, d in spot:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = on
		end
	end
end

-- A small floating line over a spot for this player ("Refills in 12:30").
local function spotLabel(self: RuinsPanel, spot: Model, text: string?)
	local label = self.labels[spot]
	if not text then
		if label then
			label.Enabled = false
		end
		return
	end
	if not label then
		local adornee = spot.PrimaryPart or spot:FindFirstChildWhichIsA("BasePart")
		if not adornee then
			return
		end
		label = Ui.new("BillboardGui", {
			Name = "RuinsSpotLabel",
			Adornee = adornee,
			Size = UDim2.fromOffset(170, 26),
			StudsOffset = Vector3.new(0, 3.5, 0),
			MaxDistance = 45,
			LightInfluence = 0,
			ResetOnSpawn = false,
			Parent = player:FindFirstChildOfClass("PlayerGui"),
		})
		Ui.label({ Name = "Text", Text = "", MaxTextSize = 15, TextColor3 = Ui.Colors.muted, TextStrokeTransparency = 0.4, Parent = label })
		self.labels[spot] = label
	end
	label.Enabled = true
	(label:FindFirstChild("Text") :: TextLabel).Text = text
end

function RuinsPanel.styleSpot(self: RuinsPanel, spot: Instance)
	local s = state(self)
	if not s or not spot:IsA("Model") then
		return
	end
	local kind, id = spot:GetAttribute("Kind"), spot:GetAttribute("Id")
	local p = promptOf(spot)
	if kind == "Chest" then
		local wait = RuinsConfig.chestWait(s, id, now())
		if p then
			p.Enabled = wait <= 0
		end
		setEffects(spot, wait <= 0)
		spotLabel(self, spot, if wait > 0 then `Looted · refills in {Ui.formatTime(wait)}` else nil)
	elseif kind == "Relic" then
		local found = s.relics[id] == true
		if p then
			p.Enabled = not found
		end
		setEffects(spot, not found)
		for _, d in spot:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if found then 1 else 0
			end
		end
	elseif kind == "Coral" then
		local day = ReefConfig.dayNumber(now())
		local cut = s.cuttings[id] == day
		if p then
			p.Enabled = not cut
		end
		setEffects(spot, not cut)
		spotLabel(self, spot, if cut then "Cutting taken · regrows tomorrow" else nil)
	end
end

function RuinsPanel.refreshSpots(self: RuinsPanel)
	for _, spot in CollectionService:GetTagged(RuinsConfig.SPOT_TAG) do
		self:styleSpot(spot)
	end
end

function RuinsPanel.setData(self: RuinsPanel, data: any)
	local before = self.data and self.data.ruins
	self.data = data
	if self.gui.Enabled then
		self:rebuild()
	end
	self:update()
	if not before then
		self:refreshSpots()
	end
end

return RuinsPanel

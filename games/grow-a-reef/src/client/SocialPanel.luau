--!nonstrict
-- The Friends window (the Friends button under Rewards): everyone else in the server, with
-- Visit (whirl to their reef) and Trade. Trade requests from others show here, with a dot
-- on the button. During a trade the window shows both offers: tap + and - on your seeds and
-- pets to change yours, then Accept, then Confirm. The server checks and does the swap
-- (Social.luau); this only shows what the server sends (TradeSync).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local MenuButtons = require(script.Parent.MenuButtons)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SocialPanel = {}
SocialPanel.__index = SocialPanel

export type SocialPanel = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		title: TextLabel,
		listView: ScrollingFrame,
		tradeView: Frame,
		mineList: ScrollingFrame,
		theirsList: ScrollingFrame,
		theirsTitle: TextLabel,
		status: TextLabel,
		goButton: TextButton,
		badge: Frame,
		requests: { [number]: { name: string, at: number } },
		trade: any?,
		data: any,
	},
	SocialPanel
))

local FRIENDS = Color3.fromRGB(90, 160, 255)
local REQUEST_SECONDS = ReefConfig.Rewards.trade.requestSeconds

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function petName(pet: any): string
	local species = ReefConfig.Pets.species[pet.species]
	local name = if species then species.name else "Pet"
	return if pet.golden then "Golden " .. name else name
end

local function row(parent: Instance, order: number, height: number?): Frame
	return Ui.new("Frame", {
		Name = "Row" .. order,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height or 44),
		BackgroundColor3 = Ui.Colors.panelLight,
		Parent = parent,
	}, { Ui.corner(8) })
end

local function rowText(parent: Instance, text: string, rightSpace: number): TextLabel
	return Ui.label({
		Name = "Text",
		Text = text,
		TextWrapped = true,
		MaxTextSize = 16,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -(rightSpace + 14), 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local function smallButton(parent: Instance, text: string, x: number, width: number, color: Color3?): TextButton
	return Ui.button({
		Name = text,
		Text = text,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -x, 0.5, 0),
		Size = UDim2.fromOffset(width, 34),
		BackgroundColor3 = color or Ui.Colors.button,
		MaxTextSize = 16,
		Parent = parent,
	})
end

local function scroller(parent: Instance, name: string, position: UDim2, size: UDim2): ScrollingFrame
	return Ui.new("ScrollingFrame", {
		Name = name,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = parent,
	}, { Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })
end

function SocialPanel.new(playerGui: PlayerGui, onToast: (string, string?) -> ()): SocialPanel
	local gui = Ui.new("ScreenGui", {
		Name = "SocialGui",
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
	}, { Ui.corner(16), Ui.stroke(FRIENDS, 2), Ui.padding(12) })
	Ui.scaleWindow(root, Vector2.new(0.92, 0.94), Vector2.new(640, 560))
	local title = Ui.label({
		Name = "Title",
		Text = "Friends",
		Font = Ui.TitleFont,
		MaxTextSize = 30,
		Size = UDim2.new(1, -50, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = FRIENDS,
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
	local listView = scroller(root, "Players", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 1, -42))

	-- The trade: your items on the left, their offer on the right, the buttons at the bottom.
	local tradeView = Ui.new("Frame", {
		Name = "Trade",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	Ui.label({
		Name = "MineTitle",
		Text = "Your items (tap + to offer)",
		Font = Ui.TitleFont,
		MaxTextSize = 17,
		Size = UDim2.new(0.56, -6, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.accent,
		Parent = tradeView,
	})
	local theirsTitle = Ui.label({
		Name = "TheirsTitle",
		Text = "Their offer",
		Font = Ui.TitleFont,
		MaxTextSize = 17,
		Position = UDim2.fromScale(0.56, 0),
		Size = UDim2.new(0.44, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.rare,
		Parent = tradeView,
	})
	local mineList = scroller(tradeView, "Mine", UDim2.fromOffset(0, 26), UDim2.new(0.56, -6, 1, -120))
	local theirsList = scroller(tradeView, "Theirs", UDim2.new(0.56, 0, 0, 26), UDim2.new(0.44, 0, 1, -120))
	local status = Ui.label({
		Name = "Status",
		Text = "",
		TextWrapped = true,
		MaxTextSize = 16,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -48),
		Size = UDim2.new(1, 0, 0, 40),
		TextColor3 = Ui.Colors.muted,
		Parent = tradeView,
	})
	local goButton = Ui.button({
		Name = "Go",
		Text = "Accept",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.5, -4, 0, 42),
		Parent = tradeView,
	})
	local cancel = Ui.button({
		Name = "Cancel",
		Text = "Cancel trade",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.5, -4, 0, 42),
		BackgroundColor3 = Ui.Colors.bad,
		Parent = tradeView,
	})

	local button = MenuButtons.add("Friends", "Friends", Color3.fromRGB(50, 110, 210), 3, function() end)
	local self = setmetatable({
		gui = gui,
		title = title,
		listView = listView,
		tradeView = tradeView,
		mineList = mineList,
		theirsList = theirsList,
		theirsTitle = theirsTitle,
		status = status,
		goButton = goButton,
		badge = MenuButtons.badge(button),
		requests = {},
		trade = nil,
		data = {},
	}, SocialPanel)

	button.Activated:Connect(function()
		self:setOpen(not self.gui.Enabled)
	end)
	close.Activated:Connect(function()
		self:setOpen(false)
	end)
	goButton.Activated:Connect(function()
		local trade = self.trade
		if not trade then
			return
		end
		if trade.stage == "confirm" and not trade.confirmed then
			Remotes.TradeAction:FireServer("confirm")
		elseif trade.stage == "offer" and not trade.accepted then
			Remotes.TradeAction:FireServer("accept")
		end
	end)
	cancel.Activated:Connect(function()
		Remotes.TradeAction:FireServer("cancel")
	end)
	Remotes.TradeSync.OnClientEvent:Connect(function(payload)
		if payload == nil then
			self.trade = nil
		elseif type(payload) == "table" and payload.kind == "request" and type(payload.from) == "number" then
			self.requests[payload.from] = { name = tostring(payload.fromName), at = os.clock() }
			onToast(`{payload.fromName} wants to trade! Open Friends to answer.`, "rare")
		elseif type(payload) == "table" and payload.kind == "trade" then
			local opening = self.trade == nil
			self.trade = payload
			self.requests[payload.with] = nil
			if opening then
				self:setOpen(true)
			end
		end
		self:render()
	end)
	Players.PlayerAdded:Connect(function()
		self:render()
	end)
	Players.PlayerRemoving:Connect(function(leaving)
		self.requests[leaving.UserId] = nil
		task.defer(function()
			self:render()
		end)
	end)
	self:render()
	return self
end

function SocialPanel.setOpen(self: SocialPanel, open: boolean)
	self.gui.Enabled = open
	if open then
		self:render()
	end
end

function SocialPanel.setData(self: SocialPanel, data: any)
	self.data = data
	if self.trade then
		self:render()
	end
end

-- Forgets requests that have run out; keeps the dot on the button in step.
function SocialPanel.update(self: SocialPanel)
	local any = false
	for userId, request in self.requests do
		if os.clock() - request.at > REQUEST_SECONDS then
			self.requests[userId] = nil
			if self.gui.Enabled and not self.trade then
				self:render()
			end
		else
			any = true
		end
	end
	self.badge.Visible = any or self.trade ~= nil
end

function SocialPanel.renderList(self: SocialPanel)
	local list = self.listView
	clear(list)
	local me = Players.LocalPlayer
	local order = 0
	for userId, request in self.requests do
		order += 1
		local r = row(list, order)
		r.BackgroundColor3 = Color3.fromRGB(60, 80, 40)
		rowText(r, `{request.name} wants to trade with you`, 200)
		smallButton(r, "Accept", 104, 90).Activated:Connect(function()
			Remotes.TradeRequest:FireServer(userId)
		end)
		smallButton(r, "No", 8, 90, Ui.Colors.bad).Activated:Connect(function()
			self.requests[userId] = nil
			Remotes.TradeAction:FireServer("decline", userId)
			self:render()
		end)
	end
	local others = 0
	for _, other in Players:GetPlayers() do
		if other == me then
			continue
		end
		others += 1
		order += 1
		local r = row(list, 100 + order)
		rowText(r, other.DisplayName, 200)
		smallButton(r, "Visit", 104, 90, Color3.fromRGB(60, 150, 200)).Activated:Connect(function()
			Remotes.VisitReef:FireServer(other.UserId)
			self:setOpen(false)
		end)
		local canTrade = me:GetAttribute("CanTrade") == true and other:GetAttribute("CanTrade") == true
		local trade = smallButton(r, "Trade", 8, 90, if canTrade then Ui.Colors.button else Ui.Colors.buttonDisabled)
		trade.AutoButtonColor = canTrade
		trade.Activated:Connect(function()
			if canTrade then
				Remotes.TradeRequest:FireServer(other.UserId)
			end
		end)
	end
	if others == 0 then
		local label = Ui.label({
			Name = "Nobody",
			LayoutOrder = 999,
			Text = "Nobody else is here yet. Invite friends from the Rewards window: you both earn shells, and each friend here boosts your sales by 10%!",
			TextWrapped = true,
			MaxTextSize = 17,
			Size = UDim2.new(1, -8, 0, 70),
			TextColor3 = Ui.Colors.muted,
			Parent = list,
		})
		label.LayoutOrder = 999
	end
end

function SocialPanel.renderTrade(self: SocialPanel)
	local trade = self.trade
	local data = self.data
	local mine = if type(trade.mine) == "table" then trade.mine else { seeds = {}, pets = {} }
	local offerSeeds = if type(mine.seeds) == "table" then mine.seeds else {}
	local offerPets = if type(mine.pets) == "table" then mine.pets else {}
	local function send(seeds: { [string]: number }, pets: { string })
		Remotes.TradeAction:FireServer("offer", { seeds = seeds, pets = pets })
	end

	-- Your seeds and pets, each with what's offered.
	clear(self.mineList)
	local order = 0
	local seeds = if type(data.seeds) == "table" then data.seeds else {}
	for _, seedId in ReefConfig.SEED_ORDER do
		local owned = seeds[seedId] or 0
		if owned <= 0 then
			continue
		end
		order += 1
		local offered = offerSeeds[seedId] or 0
		local r = row(self.mineList, order, 40)
		if offered > 0 then
			r.BackgroundColor3 = Color3.fromRGB(30, 100, 80)
		end
		rowText(r, `{ReefConfig.Seeds[seedId].name} seeds: {offered}/{owned}`, 96)
		smallButton(r, "+", 4, 42).Activated:Connect(function()
			if offered < owned then
				local copy = table.clone(offerSeeds)
				copy[seedId] = offered + 1
				send(copy, offerPets)
			end
		end)
		smallButton(r, "-", 50, 42, Ui.Colors.bad).Activated:Connect(function()
			if offered > 0 then
				local copy = table.clone(offerSeeds)
				copy[seedId] = if offered > 1 then offered - 1 else nil
				send(copy, offerPets)
			end
		end)
	end
	local pets = if type(data.pets) == "table" then data.pets else {}
	for petId, pet in pets do
		order += 1
		local offered = table.find(offerPets, petId) ~= nil
		local r = row(self.mineList, 1000 + order, 40)
		if offered then
			r.BackgroundColor3 = Color3.fromRGB(30, 100, 80)
		end
		rowText(r, petName(pet), 96)
		smallButton(r, if offered then "Take back" else "Offer", 4, 88, if offered then Ui.Colors.bad else Ui.Colors.button).Activated:Connect(function()
			local copy = table.clone(offerPets)
			local at = table.find(copy, petId)
			if at then
				table.remove(copy, at)
			else
				table.insert(copy, petId)
			end
			send(offerSeeds, copy)
		end)
	end
	if order == 0 then
		Ui.label({ Name = "Empty", Text = "You have no seeds or pets to trade.", TextWrapped = true, MaxTextSize = 15, Size = UDim2.new(1, -8, 0, 40), TextColor3 = Ui.Colors.muted, Parent = self.mineList })
	end

	-- Their offer.
	clear(self.theirsList)
	self.theirsTitle.Text = `{trade.withName}'s offer`
	local theirs = 0
	for _, seedId in ReefConfig.SEED_ORDER do
		local count = type(trade.theirSeeds) == "table" and trade.theirSeeds[seedId]
		if type(count) == "number" and count > 0 then
			theirs += 1
			rowText(row(self.theirsList, theirs, 34), `{count} {ReefConfig.Seeds[seedId].name} seed{if count == 1 then "" else "s"}`, 0)
		end
	end
	for _, pet in (if type(trade.theirPets) == "table" then trade.theirPets else {}) do
		theirs += 1
		rowText(row(self.theirsList, 100 + theirs, 34), petName(pet), 0)
	end
	if theirs == 0 then
		Ui.label({ Name = "Empty", Text = "Nothing yet.", MaxTextSize = 15, Size = UDim2.new(1, -8, 0, 30), TextColor3 = Ui.Colors.muted, Parent = self.theirsList })
	end

	-- Where the trade is.
	local go = self.goButton
	if trade.stage == "confirm" then
		go.Text = if trade.confirmed then "Waiting..." else "Confirm trade"
		go.BackgroundColor3 = if trade.confirmed then Ui.Colors.buttonDisabled else Ui.Colors.rare
		self.status.Text = if trade.theyConfirmed
			then `{trade.withName} confirmed. Check both offers, then Confirm to swap.`
			else "Both accepted. Check both offers one last time, then Confirm."
	else
		go.Text = if trade.accepted then "Accepted" else "Accept"
		go.BackgroundColor3 = if trade.accepted then Ui.Colors.buttonDisabled else Ui.Colors.button
		self.status.Text = if trade.theyAccepted
			then `{trade.withName} accepted. Accept too if you're happy.`
			else "Put in your offer, then Accept. Any change clears both Accepts."
	end
	go.AutoButtonColor = not (trade.accepted or trade.confirmed)
end

function SocialPanel.render(self: SocialPanel)
	local trading = self.trade ~= nil
	self.listView.Visible = not trading
	self.tradeView.Visible = trading
	self.title.Text = if trading then `Trading with {self.trade.withName}` else "Friends"
	if not self.gui.Enabled then
		return
	end
	if trading then
		self:renderTrade()
	else
		self:renderList()
	end
end

return SocialPanel

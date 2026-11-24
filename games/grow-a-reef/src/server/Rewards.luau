--!nonstrict
-- Rewards for coming back and bringing friends (ReefConfig.Rewards). Everything is decided
-- here on the server and recorded in the player's save, so each reward is given once.
--   Daily login streak: one reward a day (UTC), on joining or at midnight if you're playing.
--     Missing one day keeps the streak; missing two starts it again.
--   Offline earnings: shells for each minute away (capped), per unlocked planter; coral keeps
--     growing on its own. Shown in the welcome-back popup with the day's reward.
--   Boosts (not saved): Roblox Premium, and each friend in the same server, raise what coral
--     and fish sell for (PlayerData.setBoost).
--   Codes (RedeemCode): the list below, server-only so it can't be read from the game files.
--   Group: joining the game's group (ReefConfig.Rewards.group.id) gives shells and a title once.
--   Referrals: a first-time player who came from someone's invite (GetJoinData's
--     ReferredByPlayerId) gets a welcome bonus; after they've stayed a few minutes the inviter
--     is credited in a DataStore record, and paid (in any server) the next time it's checked.
--   Weekly board: shells earned since Monday (UTC), on an OrderedDataStore per week; last
--     week's top ten get prizes the next time they play.

local DataStoreService = game:GetService("DataStoreService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Rewards = {}

local SETTINGS = ReefConfig.Rewards

-- Codes players can redeem once each. Add one here (upper case, no spaces) and publish;
-- `expires` (os.time, optional) ends it.
local CODES: { [string]: { shells: number?, seeds: { [string]: number }?, expires: number? } } = {
	REEFLAUNCH = { shells = 5000 },
	BUBBLES = { seeds = { anemone = 2 } },
	SEAHORSE = { shells = 2500, seeds = { clam = 1 } },
}

local REFERRAL_STORE = "GrowAReef_Referrals_v1"
local MAX_REFERRALS = 200 -- friends one player can be paid for
local REFERRAL_CHECK_SECONDS = 300

local referralStore: DataStore? = nil
pcall(function()
	referralStore = DataStoreService:GetDataStore(REFERRAL_STORE)
end)

local friendCache: { [Player]: { [number]: boolean } } = {}
local claimingReferrals: { [Player]: boolean } = {}
local lastGroupCheck: { [Player]: number } = {}
local nameCache: { [number]: string } = {}

-- Gives shells and seeds. Returns what was given, as text.
local function grantBundle(player: Player, profile: PlayerData.Profile, bundle: ReefConfig.RewardBundle): string
	if bundle.shells and bundle.shells > 0 then
		PlayerData.addShells(player, bundle.shells)
	end
	for seedId, count in bundle.seeds or {} do
		if ReefConfig.Seeds[seedId] then
			profile.data.seeds[seedId] = math.min(ReefConfig.MAX_SEEDS_PER_TYPE, (profile.data.seeds[seedId] or 0) + count)
		end
	end
	return ReefConfig.bundleText(bundle)
end

local function giveTitle(profile: PlayerData.Profile, titleId: string)
	if ReefConfig.TitleById[titleId] then
		profile.data.titles[titleId] = true
		if profile.data.title == "" then
			profile.data.title = titleId
		end
	end
end

local function saveSoon(player: Player)
	task.spawn(PlayerData.save, player, false)
end

-- Today's login reward, if it hasn't been given. Returns its text, or nil.
local function checkDaily(player: Player, profile: PlayerData.Profile): (string?, number?)
	local today = ReefConfig.dayNumber(os.time())
	local login = profile.data.login
	if login.day == today then
		return nil
	end
	-- Yesterday, or the day before (one missed day is forgiven), keeps the streak going.
	login.streak = if login.day >= today - 2 and login.day > 0 then login.streak + 1 else 1
	login.day = today
	local bundle = SETTINGS.daily[(login.streak - 1) % #SETTINGS.daily + 1]
	return grantBundle(player, profile, bundle), login.streak
end

-- Shells for the time away. Returns (shells, seconds counted).
local function offlineEarnings(player: Player, profile: PlayerData.Profile): (number, number)
	local settings = SETTINGS.offline
	local away = math.min(profile.awaySeconds or 0, settings.maxSeconds)
	if away < settings.minSeconds then
		return 0, 0
	end
	local data = profile.data
	local shells = math.floor(away / 60 * data.unlocked * settings.shellsPerPlanterMinute * PlayerData.saleMultiplier(data))
	if shells > 0 then
		PlayerData.addShells(player, shells)
	end
	return shells, away
end

-- Friends: Player:IsFriendsWith is a web call, so each pair is asked once per server.
local function areFriends(a: Player, b: Player): boolean
	local cached = friendCache[a] and friendCache[a][b.UserId]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
	local friends = ok and result == true
	if ok then
		friendCache[a] = friendCache[a] or {}
		friendCache[a][b.UserId] = friends
		friendCache[b] = friendCache[b] or {}
		friendCache[b][a.UserId] = friends
	end
	return friends
end

-- Recomputes a player's Premium and friends boost.
local function refreshBoost(player: Player)
	if not PlayerData.get(player) then
		return
	end
	local friends = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Parent and areFriends(player, other) then
			friends += 1
		end
	end
	if not player.Parent then
		return
	end
	local premium = player.MembershipType == Enum.MembershipType.Premium
	local friendBoost = math.min(friends * SETTINGS.friendBonus, SETTINGS.friendBonusMax)
	PlayerData.setBoost(player, (if premium then SETTINGS.premiumBonus else 0) + friendBoost)
	-- For the Rewards window's breakdown.
	player:SetAttribute("FriendsHere", friends)
	player:SetAttribute("PremiumBoost", premium)
	PlayerData.sync(player)
end

local function refreshAllBoosts()
	for player in PlayerData.all() do
		task.spawn(refreshBoost, player)
	end
end

-- Group reward: once, if the player is in the game's group. quiet = no message when not.
local function checkGroup(player: Player, profile: PlayerData.Profile, quiet: boolean)
	local group = SETTINGS.group
	if group.id == 0 or profile.data.groupRewarded then
		return
	end
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok or type(groups) ~= "table" then
		if not quiet then
			Plots.notify(player, "Couldn't check the group right now. Try again in a minute.", "bad")
		end
		return
	end
	local member = false
	for _, info in groups do
		if type(info) == "table" and info.Id == group.id then
			member = true
		end
	end
	if not member then
		if not quiet then
			Plots.notify(player, "Join the Grow a Reef group, then press Check again.", "info")
		end
		return
	end
	if profile.data.groupRewarded or not player.Parent then
		return
	end
	profile.data.groupRewarded = true
	PlayerData.addShells(player, group.shells)
	giveTitle(profile, group.title)
	Plots.notify(player, `Thanks for joining the group! +{EconomyMath.formatNumber(group.shells)} shells and the Reef Crew title.`, "rare")
	PlayerData.sync(player)
	saveSoon(player)
end

-- Pays the inviter for friends credited to them since the last payment.
local function claimReferrals(player: Player)
	local profile = PlayerData.get(player)
	if not profile or not profile.persist or not referralStore or claimingReferrals[player] then
		return
	end
	claimingReferrals[player] = true
	local ok, record = pcall(function()
		return (referralStore :: DataStore):GetAsync(tostring(player.UserId))
	end)
	claimingReferrals[player] = nil
	if not ok or type(record) ~= "table" or type(record.total) ~= "number" or not player.Parent then
		return
	end
	local data = profile.data
	local total = math.min(math.floor(record.total), MAX_REFERRALS)
	local owed = total - data.referralsClaimed
	if owed <= 0 then
		return
	end
	data.referralsClaimed = total
	local shells = owed * SETTINGS.referral.shells
	PlayerData.addShells(player, shells)
	if total >= SETTINGS.referral.ambassadorAt then
		giveTitle(profile, SETTINGS.referral.title)
	end
	local friends = if owed == 1 then "A friend you invited" else `{owed} friends you invited`
	Plots.notify(player, `{friends} joined Grow a Reef! +{EconomyMath.formatNumber(shells)} shells.`, "rare")
	PlayerData.sync(player)
	saveSoon(player)
end

-- Records that newcomerId joined from inviterId's invite (each newcomer counts once).
local function creditInviter(inviterId: number, newcomerId: number)
	if not referralStore then
		return
	end
	local ok, err = pcall(function()
		(referralStore :: DataStore):UpdateAsync(tostring(inviterId), function(record)
			record = if type(record) == "table" then record else { total = 0, ids = {} }
			record.ids = if type(record.ids) == "table" then record.ids else {}
			record.total = if type(record.total) == "number" then record.total else 0
			local key = tostring(newcomerId)
			if record.ids[key] or record.total >= MAX_REFERRALS then
				return nil -- already counted, or full: no change
			end
			record.ids[key] = true
			record.total += 1
			return record
		end)
	end)
	if not ok then
		warn("[Rewards] couldn't credit a referral:", err)
		return
	end
	local inviter = Players:GetPlayerByUserId(inviterId)
	if inviter then
		claimReferrals(inviter)
	end
end

-- A first-time player who came from an invite.
local function checkReferral(player: Player, profile: PlayerData.Profile)
	if not profile.isNew or profile.data.referredBy ~= 0 then
		return
	end
	local ok, joinData = pcall(player.GetJoinData, player)
	local inviterId = ok and type(joinData) == "table" and joinData.ReferredByPlayerId
	if type(inviterId) ~= "number" or inviterId <= 0 or inviterId == player.UserId then
		return
	end
	profile.data.referredBy = inviterId
	local bonus = SETTINGS.referral.newcomerShells
	PlayerData.addShells(player, bonus)
	Plots.notify(player, `Welcome! A friend invited you: +{EconomyMath.formatNumber(bonus)} shells to start your reef.`, "rare")
	PlayerData.sync(player)
	-- The inviter is credited once the newcomer has stayed a little while.
	task.delay(SETTINGS.referral.stayMinutes * 60, function()
		if player.Parent then
			creditInviter(inviterId, player.UserId)
		end
	end)
end

-- Weekly board ------------------------------------------------------------------------------

local weeklyRows: { { userId: number, name: string, value: number } } = {}
local lastWeekRanks: { [number]: { [number]: number } } = {} -- week → userId → rank

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = player and player.DisplayName
	if not name then
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		name = if ok and type(result) == "string" then result else `Diver {userId}`
	end
	nameCache[userId] = name
	return name
end

local function weeklyStore(week: number): OrderedDataStore?
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, `GrowAReef_Weekly_{week}`)
	return if ok then store else nil
end

-- Starts a new week's count when the week has changed.
local function rollWeek(profile: PlayerData.Profile)
	local week = ReefConfig.weekNumber(os.time())
	local weekly = profile.data.weekly
	if weekly.week ~= week then
		weekly.week = week
		weekly.start = profile.data.totalEarned
	end
end

local function weeklyEarned(profile: PlayerData.Profile): number
	return math.max(0, profile.data.totalEarned - profile.data.weekly.start)
end

-- The ranks of a past week's top players, read once per server. nil if it couldn't be read.
local function ranksFor(week: number): { [number]: number }?
	if lastWeekRanks[week] then
		return lastWeekRanks[week]
	end
	local store = weeklyStore(week)
	if not store then
		return nil
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, SETTINGS.weekly.size)
	if not ok then
		return nil
	end
	local ranks = {}
	for rank, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId and entry.value > 0 then
			ranks[userId] = rank
		end
	end
	lastWeekRanks[week] = ranks
	return ranks
end

-- Last week's prize, once.
local function payWeeklyPrize(player: Player, profile: PlayerData.Profile)
	local lastWeek = ReefConfig.weekNumber(os.time()) - 1
	if not profile.persist or profile.data.weekly.prized >= lastWeek then
		return
	end
	local ranks = ranksFor(lastWeek)
	if not ranks or not player.Parent or profile.data.weekly.prized >= lastWeek then
		return
	end
	profile.data.weekly.prized = lastWeek
	local rank = ranks[player.UserId]
	local prize = rank and SETTINGS.weekly.prizes[rank]
	if not prize then
		return
	end
	PlayerData.addShells(player, prize)
	if rank == 1 then
		giveTitle(profile, SETTINGS.weekly.title)
	end
	Plots.notify(player, `You finished #{rank} on last week's board! +{EconomyMath.formatNumber(prize)} shells.`, "rare")
	PlayerData.sync(player)
	saveSoon(player)
end

local function weeklyPayload()
	local week = ReefConfig.weekNumber(os.time())
	local endsAt = (week + 1) * 7 * 86400 + 4 * 86400
	return { week = week, endsAt = endsAt, rows = weeklyRows, prizes = SETTINGS.weekly.prizes }
end

-- Pushes everyone's weekly total, reads the top of the board and sends it to every client.
-- When the board can't be read (Studio without data stores), it ranks the players here.
local function refreshWeekly()
	local week = ReefConfig.weekNumber(os.time())
	local store = weeklyStore(week)
	for player, profile in PlayerData.all() do
		rollWeek(profile)
		local earned = math.floor(weeklyEarned(profile))
		if store and profile.persist and earned > 0 then
			pcall(store.SetAsync, store, tostring(player.UserId), earned)
		end
	end
	local rows = {}
	local readOk, pages = false, nil
	if store then
		readOk, pages = pcall(store.GetSortedAsync, store, false, SETTINGS.weekly.size)
	end
	if readOk then
		for _, entry in (pages :: DataStorePages):GetCurrentPage() do
			local userId = tonumber(entry.key)
			if userId and entry.value > 0 then
				table.insert(rows, { userId = userId, name = nameFor(userId), value = entry.value })
			end
		end
	else
		for player, profile in PlayerData.all() do
			local earned = math.floor(weeklyEarned(profile))
			if earned > 0 then
				table.insert(rows, { userId = player.UserId, name = player.DisplayName, value = earned })
			end
		end
		table.sort(rows, function(a, b)
			return a.value > b.value
		end)
		for i = #rows, SETTINGS.weekly.size + 1, -1 do
			rows[i] = nil
		end
	end
	weeklyRows = rows
	Remotes.WeeklyBoard:FireAllClients(weeklyPayload())
end

-- Joining ---------------------------------------------------------------------------------

local function onLoaded(player: Player, profile: PlayerData.Profile)
	rollWeek(profile)
	-- The boost first, so offline earnings include it.
	refreshBoost(player)
	refreshAllBoosts()
	local offlineShells, awaySeconds = offlineEarnings(player, profile)
	local dailyText, streak = checkDaily(player, profile)
	checkReferral(player, profile)
	PlayerData.sync(player)
	if not profile.isNew and (offlineShells > 0 or dailyText) then
		local ready = #Plots.readyCorals(player)
		Remotes.Welcome:FireClient(player, {
			awaySeconds = awaySeconds,
			offlineShells = offlineShells,
			dailyText = dailyText,
			streak = streak,
			readyCorals = ready,
		})
	elseif dailyText then
		Plots.notify(player, `Daily reward: {dailyText}! Come back tomorrow for the next one.`, "good")
	end
	Remotes.WeeklyBoard:FireClient(player, weeklyPayload())
	checkGroup(player, profile, true)
	claimReferrals(player)
	payWeeklyPrize(player, profile)
	saveSoon(player)
end

local function onRedeemCode(player: Player, raw: unknown)
	if not RateLimit.consume(player, 3) or type(raw) ~= "string" or #raw > 40 then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	local reward = CODES[code]
	if code == "" or not reward or (reward.expires and os.time() > reward.expires) then
		Plots.notify(player, "That code doesn't work. Check the spelling, or it may have expired.", "bad")
		return
	end
	if profile.data.codes[code] then
		Plots.notify(player, "You've already used that code.", "bad")
		return
	end
	profile.data.codes[code] = true
	local text = grantBundle(player, profile, reward)
	Plots.notify(player, `Code {code}: {text}!`, "rare")
	PlayerData.sync(player)
	saveSoon(player)
end

local function onClaimGroup(player: Player)
	local profile = PlayerData.get(player)
	if not profile or os.clock() - (lastGroupCheck[player] or -math.huge) < 10 then
		return
	end
	lastGroupCheck[player] = os.clock()
	checkGroup(player, profile, false)
end

-- For Studio test scripts.
Rewards.checkDaily = checkDaily
Rewards.offlineEarnings = offlineEarnings

function Rewards.start()
	Remotes.RedeemCode.OnServerEvent:Connect(onRedeemCode)
	Remotes.ClaimGroup.OnServerEvent:Connect(onClaimGroup)
	PlayerData.onLoaded(onLoaded)
	Players.PlayerMembershipChanged:Connect(function(player)
		task.spawn(refreshBoost, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player] = nil
		claimingReferrals[player] = nil
		lastGroupCheck[player] = nil
		for _, cache in friendCache do
			cache[player.UserId] = nil
		end
		task.defer(refreshAllBoosts) -- after they've gone, so they no longer count
	end)

	-- Every minute: midnight's login rewards, the weekly board and last week's prizes.
	-- Every few minutes: referral payments for players whose friends joined elsewhere.
	task.spawn(function()
		local sinceReferrals = 0
		while true do
			task.wait(ReefConfig.LEADERBOARD_REFRESH)
			sinceReferrals += ReefConfig.LEADERBOARD_REFRESH
			for player, profile in PlayerData.all() do
				local text, streak = checkDaily(player, profile)
				if text then
					Plots.notify(player, `A new day! Day {streak} login reward: {text}.`, "rare")
					PlayerData.sync(player)
				end
				task.spawn(payWeeklyPrize, player, profile)
				if sinceReferrals >= REFERRAL_CHECK_SECONDS then
					task.spawn(claimReferrals, player)
				end
			end
			if sinceReferrals >= REFERRAL_CHECK_SECONDS then
				sinceReferrals = 0
			end
			refreshWeekly()
		end
	end)
	task.delay(5, refreshWeekly)
end

return Rewards

--!nonstrict
-- The Shipwreck event. A liner sinks onto the seabed in front of the stands; when the orcas
-- arrive they hunt everyone who was in the game at that moment and isn't hiding inside the
-- hull. Anyone caught is eaten (their character dies and respawns at home). Everyone still
-- uneaten when the hunt ends gets the reward seed. Clients follow along through Workspace
-- attributes: ShipwreckCFrame (the hull, for the HUD's hidden/exposed line), OrcasAt and
-- HuntEndsAt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local ShipwreckVisuals = require(script.Parent.ShipwreckVisuals)

local Shipwreck = {}

local SETTINGS = ReefConfig.Shipwreck
local TICK = 0.1

local rng = Random.new()
local runId = 0 -- bumped by stop(), which ends a running sequence
local folder: Folder?
local ship: Model?
local orcas: { ShipwreckVisuals.Orca } = {}

local function notifyAll(text: string, tone: string)
	for _, player in Players:GetPlayers() do
		Plots.notify(player, text, tone)
	end
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

-- Where the wreck comes to rest: listing a little, turned slightly off the stands' line.
local function restingCFrame(): CFrame
	return CFrame.new(SETTINGS.landing + Vector3.new(0, 0.4, 0)) * CFrame.Angles(math.rad(4), math.rad(8), math.rad(-2))
end

local function sink(myRun: number, rest: CFrame)
	local model = ShipwreckVisuals.buildShip()
	local from = CFrame.new(rest.Position + Vector3.new(0, 95, 0)) * CFrame.Angles(0, math.rad(8), math.rad(-22))
	model:PivotTo(from)
	model.Parent = folder
	ship = model
	local started = os.clock()
	while runId == myRun do
		local alpha = math.clamp((os.clock() - started) / SETTINGS.sinkSeconds, 0, 1)
		-- Slow at first, then faster as it plunges, settling bow-first.
		local eased = alpha * alpha * (3 - 2 * alpha)
		model:PivotTo(from:Lerp(rest, eased))
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if runId == myRun then
		ShipwreckVisuals.sandBurst(folder :: Folder, rest.Position)
		Workspace:SetAttribute("ShipwreckCFrame", rest)
	end
end

local function giveReward(player: Player)
	local profile = PlayerData.get(player)
	local seed = ReefConfig.Seeds[SETTINGS.reward.seed]
	if not profile or not seed then
		return
	end
	local owned = profile.data.seeds[seed.id] or 0
	local count = math.min(SETTINGS.reward.count, ReefConfig.MAX_SEEDS_PER_TYPE - owned)
	if count > 0 then
		profile.data.seeds[seed.id] = owned + count
		PlayerData.sync(player)
	end
	Plots.notify(player, `You survived the orca hunt! +{count} {seed.name} seed ({seed.rarity or "rare"})!`, "rare")
end

local function hunt(myRun: number, rest: CFrame)
	-- Only players here when the orcas arrive take part, so late joiners aren't hunted.
	local hunted: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		if rootOf(player) then
			hunted[player] = true
		end
	end
	local eaten: { [Player]: boolean } = {}

	for i = 1, SETTINGS.orcas do
		local angle = (i / SETTINGS.orcas) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local start = rest.Position + Vector3.new(math.cos(angle) * 260, rng:NextNumber(18, 32), math.sin(angle) * 260)
		local orca = ShipwreckVisuals.buildOrca(CFrame.lookAt(start, rest.Position + Vector3.new(0, 20, 0)))
		orca.model.Parent = folder
		orca.root:SetNetworkOwner(nil)
		table.insert(orcas, orca)
	end
	notifyAll("The orcas are here! Stay hidden inside the wreck!", "bad")

	local endsAt = os.clock() + SETTINGS.huntSeconds
	while runId == myRun and os.clock() < endsAt do
		-- Everyone taking part who is outside the hull.
		local exposed: { [Player]: BasePart } = {}
		for player in hunted do
			local root = if player.Parent and not eaten[player] then rootOf(player) else nil
			if root and not ReefConfig.insideShipwreck(rest, root.Position) then
				exposed[player] = root
			end
		end

		for index, orca in orcas do
			local position = orca.root.Position
			local target, best = nil, math.huge
			for player, root in exposed do
				local distance = (root.Position - position).Magnitude
				if distance < best then
					target, best = player, distance
				end
			end
			local goal
			if target then
				goal = exposed[target].Position
				if best < SETTINGS.catchRadius then
					eaten[target] = true
					exposed[target] = nil
					local _, humanoid = rootOf(target)
					if humanoid then
						humanoid.Health = 0
					end
					Plots.notify(target, "An orca got you! Hide inside the wreck next time.", "bad")
					for _, other in Players:GetPlayers() do
						if other ~= target then
							Plots.notify(other, `{target.DisplayName} was eaten by an orca!`, "bad")
						end
					end
				end
			else
				-- Nobody to chase: circle the wreck, waiting for someone to come out.
				local angle = os.clock() * 0.25 + index * (math.pi * 2 / SETTINGS.orcas)
				goal = rest.Position + Vector3.new(math.cos(angle) * 85, 24 + math.sin(os.clock() + index) * 4, math.sin(angle) * 85)
			end
			orca.mover.Position = goal
			local heading = goal - position
			if heading.Magnitude > 1 then
				orca.turner.CFrame = CFrame.lookAt(Vector3.zero, heading.Unit)
			end
		end
		task.wait(TICK)
	end
	if runId ~= myRun then
		return
	end

	-- The hunt is over: the orcas swim off, and everyone who made it gets the seed.
	local survivors = 0
	for player in hunted do
		if player.Parent and not eaten[player] then
			survivors += 1
			giveReward(player)
		end
	end
	notifyAll(`The orcas are leaving. {survivors} diver{if survivors == 1 then "" else "s"} survived!`, "good")
	for _, orca in orcas do
		local away = (orca.root.Position - rest.Position) * Vector3.new(1, 0, 1)
		local direction = if away.Magnitude > 1 then away.Unit else Vector3.xAxis
		orca.mover.Position = orca.root.Position + direction * 400 + Vector3.new(0, 30, 0)
		orca.turner.CFrame = CFrame.lookAt(Vector3.zero, direction)
	end
end

function Shipwreck.start()
	runId += 1
	local myRun = runId
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "ShipwreckEvent"
		newFolder.Parent = Workspace
		folder = newFolder
	end
	local now = Workspace:GetServerTimeNow()
	Workspace:SetAttribute("OrcasAt", now + SETTINGS.huntStartsAt)
	Workspace:SetAttribute("HuntEndsAt", now + SETTINGS.huntStartsAt + SETTINGS.huntSeconds)
	local rest = restingCFrame()
	task.spawn(function()
		local started = os.clock()
		sink(myRun, rest)
		local warned = false
		while runId == myRun and os.clock() - started < SETTINGS.huntStartsAt do
			if not warned and os.clock() - started > SETTINGS.huntStartsAt - 5 then
				warned = true
				notifyAll("Orcas in 5 seconds! Get inside the wreck!", "bad")
			end
			task.wait(0.1)
		end
		if runId == myRun then
			hunt(myRun, rest)
		end
	end)
end

function Shipwreck.stop()
	runId += 1
	for _, orca in orcas do
		orca.model:Destroy()
	end
	orcas = {}
	Workspace:SetAttribute("ShipwreckCFrame", nil)
	Workspace:SetAttribute("OrcasAt", nil)
	Workspace:SetAttribute("HuntEndsAt", nil)
	-- The wreck settles into the sand and is gone.
	local model = ship
	ship = nil
	if model then
		task.spawn(function()
			local from = model:GetPivot()
			for i = 1, 60 do
				model:PivotTo(from * CFrame.new(0, -i * 0.4, 0))
				task.wait(0.05)
			end
			model:Destroy()
		end)
	end
end

return Shipwreck

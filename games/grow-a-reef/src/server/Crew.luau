--!nonstrict
-- The human crew from the character roster (ReefConfig.Crew; outfits in Outfits): Coralie the
-- Shopkeeper, Kai the Guide, Captain Mako the Master Diver, Dr. Pearl the Research Scientist
-- and Marlo the Explorer. Each is a real R15 rig with Roblox's default idle, walk and wave
-- animations, run by a small server-side state machine:
--   post     stands at their counter facing customers, turning to face a player who's near
--   wander   now and then strolls (pathfinding) to a nearby point and back, within a leash
--   greet    a player walks up: stop, turn to them and wave (once per player per while)
--   serve    a customer is near the counter: go back to the post and stay there
-- The station prompts stay on the counters (and Inky's old rock), so serving never depends on
-- where the NPC is. Each NPC is tagged as a shopkeeper (Walker attribute set), so the client's
-- Shopkeepers module shows their greetings and lines (Kai's tutorial lines go through it)
-- without moving them; the Guide keeps the tutorial's Landmark_Guide attribute on him.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local RuinsConfig = require(ReplicatedStorage.Shared.RuinsConfig)
local Outfits = require(script.Parent.Outfits)

local Crew = {}

-- Roblox's own default R15 animations, which every game may use.
local ANIMATIONS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	wave = "rbxassetid://507770239",
	point = "rbxassetid://507770453",
}
local CUSTOMER_RADIUS = 14 -- a player this close to the post: go and serve
local GREET_RADIUS = 13 -- a player this close to the NPC: stop and wave
local GREET_AGAIN = 40 -- seconds before greeting the same player again
local STEP_TIMEOUT = 3 -- seconds to reach one path waypoint before giving up on the walk

type Npc = {
	kind: string,
	def: any,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	post: CFrame, -- where they stand, facing customers
	tracks: { [string]: AnimationTrack },
	greeted: { [Player]: number },
	interrupt: boolean, -- set when a customer or greeting should cut a walk short
}

local rng = Random.new()
local folder: Folder
local npcs: { Npc } = {}

-- The ground under a point, so NPCs stand on floors whatever their height.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function ground(position: Vector3): Vector3
	local hit = Workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), groundParams)
	return if hit then hit.Position else position
end

-- The part holding the station prompt of `kind` (and Mode, if given).
local function stationPart(kind: string, mode: string?): BasePart?
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Kind") == kind and (mode == nil or d:GetAttribute("Mode") == mode) then
			local holder = d.Parent
			if holder and holder:IsA("BasePart") then
				return holder
			end
		end
	end
	return nil
end

-- Where each crew member stands, facing their customers (+Z of a counter is the players' side).
local function findPost(kind: string, def: any): CFrame?
	if kind == "Guide" then
		-- Beside the old guide rock by the spawn, facing the plaza.
		local center = ReefConfig.Lagoon.center
		local at = ReefConfig.Lagoon.guide
		local toward = (Vector3.new(center.X, at.Y, center.Z) - at)
		local spot = at + (if toward.Magnitude > 0.1 then toward.Unit else Vector3.zAxis) * 3.6
		return CFrame.lookAt(ground(spot), ground(spot) + (if toward.Magnitude > 0.1 then toward.Unit else Vector3.zAxis))
	elseif kind == "Explorer" then
		local at = RuinsConfig.Places.explorer
		local face = RuinsConfig.at(150, 0, 0)
		local spot = at + (face - at).Unit * 3.6
		return CFrame.lookAt(ground(spot), ground(spot) + ((face - spot) * Vector3.new(1, 0, 1)).Unit)
	end
	local counter = stationPart(def.station or kind, def.mode)
	if not counter then
		return nil
	end
	local behind = counter.CFrame * CFrame.new(0, -counter.Size.Y / 2, -(counter.Size.Z / 2 + 2.2))
	local customers = -counter.CFrame.LookVector * Vector3.new(1, 0, 1)
	local spot = ground(behind.Position)
	return CFrame.lookAt(spot, spot + customers.Unit)
end

local function buildRig(def: any): Model
	local description = Instance.new("HumanoidDescription")
	-- Classic blocky Roblox proportions, like the art.
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	description.HeightScale = def.height or 1
	description.WidthScale = 1
	description.DepthScale = 1
	description.HeadScale = 1
	local skin = Outfits.SKIN[def.skin] or Color3.fromRGB(235, 190, 150)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = skin
	description.LeftLegColor = skin
	description.RightLegColor = skin
	local rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	rig.Name = def.name
	return rig
end

local function play(npc: Npc, name: string, fade: number?)
	local track = npc.tracks[name]
	if track and not track.IsPlaying then
		track:Play(fade or 0.2)
	end
end

local function stop(npc: Npc, name: string)
	local track = npc.tracks[name]
	if track and track.IsPlaying then
		track:Stop(0.2)
	end
end

local function spawnNpc(kind: string, def: any, post: CFrame): Npc
	local rig = buildRig(def)
	rig:PivotTo(post * CFrame.new(0, 3.2, 0))
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.WalkSpeed = def.walkSpeed or 8
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	-- Players walk through the crew instead of shoving them about; the Humanoid stands on
	-- the floor by itself.
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	Outfits.dress(rig, def.outfit)
	rig:SetAttribute("Shopkeeper", kind)
	rig:SetAttribute("Walker", true)
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	rig.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil) -- the server moves the crew
	end)
	rig:AddTag(ReefConfig.SHOPKEEPER_TAG)

	if def.prompt then
		-- A prompt on the NPC itself (Captain Mako: change your diving suit). F, so it never
		-- fights the counter's E prompt beside it.
		local p = Instance.new("ProximityPrompt")
		p.Name = "CrewPrompt"
		p.ActionText = def.prompt.action
		p.ObjectText = def.name
		p.KeyboardKeyCode = Enum.KeyCode.F
		p.GamepadKeyCode = Enum.KeyCode.ButtonY
		p.HoldDuration = 0
		p.MaxActivationDistance = 10
		p.RequiresLineOfSight = false
		p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		p.UIOffset = Vector2.new(0, 40)
		p:SetAttribute("Kind", def.prompt.kind)
		p.Parent = rig:FindFirstChild("UpperTorso") or root
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks = {}
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok then
			track.Priority = if name == "wave" or name == "point" then Enum.AnimationPriority.Action elseif name == "walk" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Idle
			track.Looped = name == "idle" or name == "walk"
			tracks[name] = track
		end
	end
	local npc: Npc = { kind = kind, def = def, model = rig, humanoid = humanoid, root = root, post = post, tracks = tracks, greeted = {}, interrupt = false }
	play(npc, "idle")
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			play(npc, "walk", 0.15)
			local walk = npc.tracks.walk
			if walk then
				walk:AdjustSpeed(speed / 10)
			end
		else
			stop(npc, "walk")
		end
	end)
	return npc
end

-- Players by distance to a point, nearest first within `radius`.
local function nearestPlayer(point: Vector3, radius: number): (Player?, BasePart?)
	local best, bestRoot, bestDistance = nil, nil, radius
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local d = (root.Position - point).Magnitude
			if d < bestDistance then
				best, bestRoot, bestDistance = player, root, d
			end
		end
	end
	return best, bestRoot
end

local function face(npc: Npc, point: Vector3)
	local from = npc.root.Position
	local flat = Vector3.new(point.X, from.Y, point.Z)
	if (flat - from).Magnitude > 0.5 then
		npc.humanoid.AutoRotate = false
		npc.root.CFrame = CFrame.lookAt(from, flat)
	end
end

-- Walks to `goal` along a path (straight there if no path is found). Returns false if it was
-- interrupted or got stuck.
local function walkTo(npc: Npc, goal: Vector3): boolean
	npc.humanoid.AutoRotate = true
	local path = PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 5.5, AgentCanJump = false, WaypointSpacing = 4 })
	local ok = pcall(path.ComputeAsync, path, npc.root.Position, goal)
	local waypoints = if ok and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else { { Position = goal } }
	for _, waypoint in waypoints do
		if npc.interrupt then
			npc.humanoid:MoveTo(npc.root.Position)
			return false
		end
		npc.humanoid:MoveTo(waypoint.Position)
		local reached = false
		local connection = npc.humanoid.MoveToFinished:Connect(function(r)
			reached = r
		end)
		local started = os.clock()
		while not reached and os.clock() - started < STEP_TIMEOUT and not npc.interrupt do
			task.wait(0.1)
		end
		connection:Disconnect()
		if not reached and not npc.interrupt then
			return false -- stuck; give up this walk
		end
	end
	return true
end

-- Greets a player who has walked up: stop, turn to them, wave. Returns true if it did.
local function greet(npc: Npc): boolean
	local player, root = nearestPlayer(npc.root.Position, GREET_RADIUS)
	if not player or not root or os.clock() - (npc.greeted[player] or -math.huge) < GREET_AGAIN then
		return false
	end
	npc.greeted[player] = os.clock()
	npc.humanoid:MoveTo(npc.root.Position)
	face(npc, root.Position)
	local wave = npc.tracks.wave
	if wave then
		wave:Play(0.15)
		task.wait(math.min(wave.Length > 0 and wave.Length or 2, 2.5))
	end
	return true
end

-- The guide carries the tutorial tracker's target with him.
local function trackGuide(npc: Npc, last: Vector3?): Vector3?
	if npc.kind ~= "Guide" then
		return last
	end
	local reef = Workspace:FindFirstChild("Reef")
	local here = npc.root.Position
	if reef and (not last or (here - last).Magnitude > 2) then
		reef:SetAttribute("Landmark_Guide", Vector3.new(here.X, ReefConfig.Lagoon.guide.Y, here.Z))
		return here
	end
	return last
end

local function brain(npc: Npc)
	local def = npc.def
	local postPosition = npc.post.Position
	local lastGuidePos: Vector3? = nil
	local nextWander = os.clock() + rng:NextNumber(4, 10)
	while npc.model.Parent do
		lastGuidePos = trackGuide(npc, lastGuidePos)
		local customer, customerRoot = nearestPlayer(postPosition, CUSTOMER_RADIUS)
		local atPost = (npc.root.Position * Vector3.new(1, 0, 1) - postPosition * Vector3.new(1, 0, 1)).Magnitude < 2
		if customer and customerRoot then
			-- serve: be at the counter, facing the customer.
			if not atPost then
				npc.interrupt = false
				walkTo(npc, postPosition)
			end
			if not greet(npc) then
				face(npc, customerRoot.Position)
			end
			task.wait(0.4)
		elseif greet(npc) then
			task.wait(0.3)
		elseif os.clock() >= nextWander and (def.wander or 0) > 0 then
			-- wander: a short stroll within the leash, a pause, and back to the post.
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(def.wander * 0.4, def.wander)
			local goal = ground(postPosition + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
			npc.interrupt = false
			local watcher = task.spawn(function()
				-- Cut the walk short when a customer turns up at the counter or someone's near.
				while npc.model.Parent and not npc.interrupt do
					task.wait(0.3)
					if nearestPlayer(postPosition, CUSTOMER_RADIUS) or nearestPlayer(npc.root.Position, GREET_RADIUS) then
						npc.interrupt = true
					end
				end
			end)
			local arrived = walkTo(npc, goal)
			if arrived then
				local pause = os.clock() + rng:NextNumber(2, 4)
				while os.clock() < pause and not npc.interrupt do
					lastGuidePos = trackGuide(npc, lastGuidePos)
					task.wait(0.2)
				end
			end
			-- Back to the post, whatever happened (a customer there wants serving anyway).
			task.cancel(watcher)
			npc.interrupt = false
			walkTo(npc, postPosition)
			face(npc, postPosition + npc.post.LookVector * 10)
			nextWander = os.clock() + rng:NextNumber(def.restMin or 8, def.restMax or 16)
		else
			if atPost then
				face(npc, postPosition + npc.post.LookVector * 10)
			end
			task.wait(0.5)
		end
	end
end

function Crew.start()
	folder = Instance.new("Folder")
	folder.Name = "Crew"
	folder.Parent = Workspace
	groundParams.FilterDescendantsInstances = { folder }
	for kind, def in ReefConfig.Crew do
		local post = findPost(kind, def)
		if post then
			local npc = spawnNpc(kind, def, post)
			table.insert(npcs, npc)
			-- Staggered, so the crew don't all think on the same frame.
			task.delay(rng:NextNumber(0.5, 2.5), brain, npc)
		else
			warn(`[Crew] no post found for {kind}; {def.name} wasn't spawned`)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, npc in npcs do
			npc.greeted[player] = nil
		end
	end)
end

return Crew

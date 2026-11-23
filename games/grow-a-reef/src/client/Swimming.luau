--!nonstrict
-- Swimming: jumping pushes off into a swim. While swimming the character floats, lies along
-- the way it is going, and moves faster than walking, up or down wherever the camera points.
-- Holding jump swims straight up; letting go of everything drifts down to the seabed, where
-- you walk again. Client-side, since each client moves its own character in Roblox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local Swimming = {}

local SETTINGS = ReefConfig.Swim
local HOLD_WINDOW = 0.25 -- jump counts as held if it was requested this recently
local MIN_SWIM = 0.5 -- seconds before touching the seabed ends a swim
-- The camera normally looks down at the character a little; only a steeper tilt than this
-- (as a share of straight down or up) swims down or up.
local TILT_DEADZONE = 0.45

local player = Players.LocalPlayer
local controls -- the PlayerModule's controls: the move input, camera-relative
local swimming = false
local startedAt = 0
local lastJumpAt = 0
local parts: { Instance } = {}
local tracks: { swim: AnimationTrack?, idle: AnimationTrack? } = {}
local mover: LinearVelocity?
local aligner: AlignOrientation?

local function characterParts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return character, humanoid, root
end

-- The default swim animations from the character's Animate script, if it has them.
local function loadTrack(character: Model, humanoid: Humanoid, folder: string, name: string): AnimationTrack?
	local animate = character:FindFirstChild("Animate")
	local animation = animate and animate:FindFirstChild(folder) and animate[folder]:FindFirstChild(name)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animation or not animator then
		return nil
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	return track
end

function Swimming.stop()
	if not swimming then
		return
	end
	swimming = false
	for _, track in tracks do
		track:Stop(0.2)
	end
	tracks = {}
	for _, instance in parts do
		instance:Destroy()
	end
	parts = {}
	mover, aligner = nil, nil
	local _, humanoid, root = characterParts()
	if humanoid and root then
		-- Stand back up, still facing the same way.
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.1 then
			look = root.CFrame.UpVector * Vector3.new(1, 0, 1)
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function start()
	local character, humanoid, root = characterParts()
	if swimming or not humanoid or not root or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	swimming = true
	startedAt = os.clock()
	-- PlatformStand hands the body over to the constraints below. A jump would end it, so
	-- jumping is off until the swim ends; jump presses still swim up.
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "SwimAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "SwimVelocity"
	velocity.Attachment0 = attachment
	velocity.MaxForce = 1e6
	velocity.VectorVelocity = Vector3.new(0, SETTINGS.rise, 0)
	velocity.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "SwimAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 1e6
	align.Responsiveness = 18
	align.CFrame = root.CFrame.Rotation
	align.Parent = root
	parts = { attachment, velocity, align }
	mover, aligner = velocity, align

	tracks = {
		swim = loadTrack(character :: Model, humanoid, "swim", "Swim"),
		idle = loadTrack(character :: Model, humanoid, "swimidle", "SwimIdle"),
	}
end

local function onSeabed(character: Model, humanoid: Humanoid, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local reach = humanoid.HipHeight + root.Size.Y / 2 + 0.6
	return Workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), params) ~= nil
end

local function step()
	if not swimming then
		return
	end
	local character, humanoid, root = characterParts()
	if not humanoid or not root or humanoid.Health <= 0 or not mover or not aligner then
		Swimming.stop()
		return
	end
	local camera = Workspace.CurrentCamera
	local input = if controls then controls:GetMoveVector() else Vector3.zero
	local moving = input.Magnitude > 0.1
	local holdingJump = os.clock() - lastJumpAt < HOLD_WINDOW

	if not humanoid.PlatformStand then
		humanoid.PlatformStand = true
	end

	-- The move input is camera-relative, so tilting the camera well down (or up) while moving
	-- forward swims down (or up); a gentle tilt stays level.
	local direction = Vector3.zero
	if moving then
		local raw = camera.CFrame:VectorToWorldSpace(input)
		local flatPart = raw * Vector3.new(1, 0, 1)
		local tilt = math.sign(raw.Y) * math.max(0, math.abs(raw.Y) - TILT_DEADZONE) / (1 - TILT_DEADZONE)
		local level = if flatPart.Magnitude > 0.01 then flatPart.Unit * input.Magnitude else Vector3.zero
		direction = level * math.sqrt(math.max(0, 1 - tilt * tilt)) + Vector3.new(0, tilt * input.Magnitude, 0)
	end
	local velocity = direction * SETTINGS.speed
	if holdingJump then
		velocity += Vector3.new(0, SETTINGS.rise, 0)
	elseif not moving then
		velocity = Vector3.new(0, -SETTINGS.sink, 0)
	end
	if root.Position.Y > SETTINGS.maxHeight and velocity.Y > 0 then
		velocity = velocity * Vector3.new(1, 0, 1)
	end
	mover.VectorVelocity = velocity

	-- Lie along the swim, head first; upright when treading water.
	local flat = (if moving then direction else camera.CFrame.LookVector) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.05 then
		flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	local facing = CFrame.lookAt(Vector3.zero, flat.Unit)
	local climb = if moving then math.asin(math.clamp(direction.Unit.Y, -1, 1)) else 0
	local pitch = if moving then -math.rad(75) + climb * 0.6 else -math.rad(8)
	aligner.CFrame = facing * CFrame.Angles(pitch, 0, 0)

	local swimTrack, idleTrack = tracks.swim, tracks.idle
	if swimTrack and moving and not swimTrack.IsPlaying then
		swimTrack:Play(0.2)
		if idleTrack then
			idleTrack:Stop(0.2)
		end
	elseif idleTrack and not moving and not idleTrack.IsPlaying then
		idleTrack:Play(0.2)
		if swimTrack then
			swimTrack:Stop(0.2)
		end
	end

	-- Only sinking or diving onto the seabed (or a rock) ends the swim, not gliding over it.
	if os.clock() - startedAt > MIN_SWIM and velocity.Y < 0 and onSeabed(character :: Model, humanoid, root) then
		Swimming.stop()
	end
end

function Swimming.isSwimming(): boolean
	return swimming
end

function Swimming.start()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	controls = if ok then playerModule:GetControls() else nil

	UserInputService.JumpRequest:Connect(function()
		lastJumpAt = os.clock()
		start()
	end)
	player.CharacterAdded:Connect(function()
		swimming = false
		parts, tracks = {}, {}
		mover, aligner = nil, nil
	end)
	RunService.Heartbeat:Connect(step)
end

return Swimming

--!nonstrict
-- Shopkeepers at the stands: a gentle idle bob, turning to face the local player, and a
-- speech bubble when the player walks up. Purely cosmetic and local to this client; the
-- server only builds and tags the models (ShopkeeperVisuals). Tolerant of streaming.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local Ui = require(script.Parent.Ui)

local Shopkeepers = {}

local MAX_TURN = math.rad(50)
local TURN_SPEED = 4
local BUBBLE_SECONDS = 4
local ANIMATE_DISTANCE = 150

type Keeper = {
	model: Model,
	head: BasePart,
	def: ReefConfig.ShopkeeperDef,
	home: CFrame,
	phase: number,
	yaw: number,
	near: boolean,
	lastGreet: number,
	lastLine: number,
	bubble: BillboardGui?,
}

local keepers: { [Model]: Keeper } = {}
local rng = Random.new()
local gui: PlayerGui

local function nextLine(keeper: Keeper): string
	local lines = keeper.def.greetings
	local index = rng:NextInteger(1, #lines)
	if #lines > 1 and index == keeper.lastLine then
		index = index % #lines + 1 -- never the same line twice in a row
	end
	keeper.lastLine = index
	return lines[index]
end

-- `long` is for something the player asked for (talking to Inky): a bigger bubble that
-- stays up longer.
local function showBubble(keeper: Keeper, playerGui: PlayerGui, text: string, long: boolean?)
	if keeper.bubble then
		keeper.bubble:Destroy()
	end
	local bubble = Ui.new("BillboardGui", {
		Name = "ShopkeeperBubble",
		Adornee = keeper.head,
		Size = if long then UDim2.fromOffset(300, 92) else UDim2.fromOffset(250, 66),
		-- Usually beside the head, not above it, where it would cover the stand's sign.
		-- SizeOffset keeps the bubble's edge next to the head at any distance. Long lines
		-- (Inky, who has no sign) go above the head, where they stay on screen up close.
		StudsOffset = if long then Vector3.new(0, keeper.head.Size.Y / 2 + 0.6, 0) else Vector3.new(keeper.head.Size.X / 2 + 0.4, 0.3, 0),
		SizeOffset = if long then Vector2.new(0, 0.5) else Vector2.new(0.5, 0),
		-- The Seed Shop roof is in front of the diver's head from most camera angles.
		AlwaysOnTop = true,
		MaxDistance = 60,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = playerGui,
	})
	local panel = Ui.new("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.Colors.panel,
		BackgroundTransparency = 0.1,
		Parent = bubble,
	}, { Ui.corner(12), Ui.stroke(Ui.Colors.accent), Ui.padding(6) })
	local speaker = Ui.label({
		Name = "Speaker",
		Text = keeper.def.name,
		Font = Ui.TitleFont,
		MaxTextSize = 16,
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.rare,
		Parent = panel,
	})
	local line = Ui.label({
		Name = "Line",
		Text = text,
		MaxTextSize = 15,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 1, -18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	keeper.bubble = bubble

	task.delay(if long then BUBBLE_SECONDS * 2 else BUBBLE_SECONDS, function()
		if keeper.bubble ~= bubble then
			return -- replaced by a newer greeting, which owns its own fade
		end
		keeper.bubble = nil
		if Ui.reducedMotion() then
			bubble:Destroy()
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(panel, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(speaker, info, { TextTransparency = 1 }):Play()
		TweenService:Create(line, info, { TextTransparency = 1 }):Play()
		task.wait(0.45)
		bubble:Destroy()
	end)
end

local function add(instance: Instance)
	if not instance:IsA("Model") or keepers[instance] then
		return
	end
	local def = ReefConfig.Shopkeepers[instance:GetAttribute("Shopkeeper")]
	local head = instance:FindFirstChild("Head")
	if not def or not (head and head:IsA("BasePart")) then
		warn(`Shopkeeper {instance:GetFullName()} needs a known Shopkeeper attribute and a Head part`)
		return
	end
	keepers[instance] = {
		model = instance,
		head = head,
		def = def,
		home = instance:GetPivot(),
		phase = rng:NextNumber(0, math.pi * 2),
		yaw = 0,
		near = false,
		lastGreet = -math.huge,
		lastLine = 0,
		bubble = nil,
	}
end

local function remove(instance: Instance)
	local keeper = keepers[instance :: Model]
	if keeper then
		if keeper.bubble then
			keeper.bubble:Destroy()
		end
		keepers[instance :: Model] = nil
	end
end

-- Shows a line from the shopkeeper of `kind` (a ReefConfig.Shopkeepers key), such as Inky's
-- tutorial lines from the server.
function Shopkeepers.say(kind: string, text: string)
	for model, keeper in keepers do
		if model:GetAttribute("Shopkeeper") == kind then
			keeper.lastGreet = os.clock()
			showBubble(keeper, gui, text, true)
		end
	end
end

function Shopkeepers.start(playerGui: PlayerGui)
	gui = playerGui
	for _, instance in CollectionService:GetTagged(ReefConfig.SHOPKEEPER_TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(ReefConfig.SHOPKEEPER_TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(ReefConfig.SHOPKEEPER_TAG):Connect(remove)

	RunService.Heartbeat:Connect(function(dt)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local now = os.clock()
		local still = Ui.reducedMotion()
		for model, keeper in keepers do
			local distance = (root.Position - keeper.home.Position).Magnitude
			if distance > ANIMATE_DISTANCE then
				continue
			end

			-- Greet once on the way in; the 4-stud margin stops it re-firing at the edge.
			if distance <= ReefConfig.SHOPKEEPER_GREET_DISTANCE then
				if not keeper.near and now - keeper.lastGreet >= ReefConfig.SHOPKEEPER_GREET_COOLDOWN then
					keeper.lastGreet = now
					showBubble(keeper, playerGui, nextLine(keeper))
				end
				keeper.near = true
			elseif distance > ReefConfig.SHOPKEEPER_GREET_DISTANCE + 4 then
				keeper.near = false
			end

			-- Turn toward the player (forward is -Z), within a limit so they never face the wall.
			local targetYaw = 0
			if distance <= ReefConfig.SHOPKEEPER_GREET_DISTANCE * 2 then
				local offset = keeper.home:PointToObjectSpace(root.Position)
				targetYaw = math.clamp(math.atan2(-offset.X, -offset.Z), -MAX_TURN, MAX_TURN)
			end
			keeper.yaw += (targetYaw - keeper.yaw) * math.min(1, dt * TURN_SPEED)
			local bob = if still then 0 else math.sin(now * 2 + keeper.phase) * keeper.def.bob
			model:PivotTo(keeper.home * CFrame.new(0, bob, 0) * CFrame.Angles(0, keeper.yaw, 0))
		end
	end)
end

return Shopkeepers

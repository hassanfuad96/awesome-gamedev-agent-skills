--!nonstrict
-- Reef ratings. Every reef's gate sign has a "Like this reef" prompt; a visitor can like
-- each reef once a day (UTC). The owner's likes are saved with their reef, shown on the sign
-- and ranked on the Best Reefs board (Leaderboard).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local RateLimit = require(script.Parent.RateLimit)

local Likes = {}

-- Hearts float up from the sign.
local function hearts(sign: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 120, 170))
	emitter.LightEmission = 0.7
	emitter.Size = NumberSequence.new(0.8, 0.2)
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Enabled = false
	emitter.Parent = sign
	emitter:Emit(30)
	task.delay(2, emitter.Destroy, emitter)
end

-- Forgets old likes once the list is long, keeping today's.
local function trim(liked: { [string]: number }, today: number)
	local count = 0
	for _ in liked do
		count += 1
	end
	if count < ReefConfig.Likes.maxRemembered then
		return
	end
	for ownerId, day in liked do
		if day ~= today then
			liked[ownerId] = nil
		end
	end
end

local function onLike(player: Player, plot: World.PlotParts)
	if not RateLimit.consume(player, 2) then
		return
	end
	local owner = Plots.ownerOf(plot.index)
	if not owner then
		Plots.notify(player, "Nobody owns this reef yet.")
		return
	end
	if owner == player then
		Plots.notify(player, "You can't like your own reef. Invite friends to visit it!")
		return
	end
	local liker = PlayerData.get(player)
	local ownerProfile = PlayerData.get(owner)
	if not liker or not ownerProfile then
		return
	end
	local today = ReefConfig.dayNumber(os.time())
	local key = tostring(owner.UserId)
	if liker.data.liked[key] == today then
		Plots.notify(player, `You already liked {owner.DisplayName}'s reef today. Come back tomorrow!`)
		return
	end
	trim(liker.data.liked, today)
	liker.data.liked[key] = today
	ownerProfile.data.likes += 1
	Plots.updateSign(owner)
	hearts(plot.signPart)
	Plots.notify(player, `You liked {owner.DisplayName}'s reef!`, "good")
	Plots.notify(owner, `{player.DisplayName} liked your reef!`, "rare")
	PlayerData.sync(owner)
end

function Likes.start(worldParts: World.WorldParts)
	for _, plot in worldParts.plots do
		local prompt = plot.signPart:FindFirstChild("LikePrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				onLike(player, plot)
			end)
		end
	end
end

return Likes

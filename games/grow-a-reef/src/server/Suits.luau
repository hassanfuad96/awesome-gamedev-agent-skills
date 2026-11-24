--!nonstrict
-- Players' diving suits (ReefConfig.Suits; outfits in Outfits): each player picks the Blue or
-- Pink Explorer suit (Roblox doesn't tell games a player's gender, so it's their choice). The
-- picker opens on a first visit (SuitPicker, on the client) and again from Captain Mako at the
-- Equipment Station. The choice is saved (data.suit, "" until chosen) and put on every time the
-- player's character spawns. ChooseSuit carries only the suit id, checked here.
-- Also builds a dressed preview of each suit in ReplicatedStorage.SuitPreviews for the picker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)
local Outfits = require(script.Parent.Outfits)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Suits = {}

local function dress(player: Player)
	local profile = PlayerData.get(player)
	local character = player.Character
	local suit = profile and ReefConfig.Suits.byId[profile.data.suit]
	if character and suit then
		Outfits.dress(character, suit.outfit)
	end
end

local function onChoose(player: Player, suitId: unknown)
	if not RateLimit.consume(player) or type(suitId) ~= "string" or not ReefConfig.Suits.byId[suitId] then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local changed = profile.data.suit ~= suitId
	profile.data.suit = suitId
	if changed then
		dress(player)
		Remotes.Notify:FireClient(player, `You're wearing the {ReefConfig.Suits.byId[suitId].name} suit! Change it any time with Captain Mako at the Equipment Station.`, "good")
	end
	PlayerData.sync(player)
end

-- A dressed, anchored mannequin of each suit for the picker's previews.
local function buildPreviews()
	local folder = Instance.new("Folder")
	folder.Name = "SuitPreviews"
	for _, id in ReefConfig.Suits.order do
		local suit = ReefConfig.Suits.byId[id]
		local description = Instance.new("HumanoidDescription")
		description.BodyTypeScale = 0
		description.ProportionScale = 0
		local skin = Color3.fromRGB(235, 190, 150)
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		local ok, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
		if ok and rig then
			rig.Name = id
			Outfits.dress(rig, suit.outfit)
			for _, d in rig:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			rig.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

function Suits.start()
	Remotes.ChooseSuit.OnServerEvent:Connect(onChoose)
	local function watch(player: Player)
		-- After the avatar has loaded, so its own clothes don't come back over the suit.
		player.CharacterAppearanceLoaded:Connect(function()
			dress(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- The save loads after the first spawn: dress them then.
	PlayerData.onLoaded(function(player)
		dress(player)
	end)
	task.spawn(buildPreviews)
end

return Suits

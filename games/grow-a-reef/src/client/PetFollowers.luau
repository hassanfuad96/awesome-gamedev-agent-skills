--!nonstrict
-- Draws every player's equipped pets swimming beside them. The server publishes them as the
-- "EquippedPets" player attribute ("seahorse,octopus:golden"); each client builds and moves
-- its own copies, so following stays smooth and nothing replicates.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetVisuals = require(script.Parent.PetVisuals)

local PetFollowers = {}

type Follower = { model: Model, at: CFrame }

local SIDES = { -3.2, 3.2 } -- first pet on the left, second on the right
local followers: { [Player]: { Follower } } = {}
local folder: Folder

local function clear(player: Player)
	for _, follower in followers[player] or {} do
		follower.model:Destroy()
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local shown = player:GetAttribute("EquippedPets")
	if type(shown) ~= "string" or shown == "" then
		return
	end
	local list = {}
	for _, entry in string.split(shown, ",") do
		local species, variant = table.unpack(string.split(entry, ":"))
		local model = PetVisuals.build(species, variant == "golden")
		model.Parent = folder
		table.insert(list, { model = model, at = CFrame.identity })
	end
	followers[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function PetFollowers.start()
	folder = Instance.new("Folder")
	folder.Name = "PetFollowers" -- client-only
	folder.Parent = Workspace

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)

	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for player, list in followers do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				for i, follower in list do
					local bob = math.sin(t * 2 + i) * 0.4
					local target = root.CFrame * CFrame.new(SIDES[i] or 0, 1.2 + bob, 2.2)
					-- Ease towards the spot instead of snapping; a big jump (a respawn) snaps.
					local far = (follower.at.Position - target.Position).Magnitude > 40
					follower.at = if far then target else follower.at:Lerp(target, math.min(1, dt * 6))
					follower.model:PivotTo(follower.at)
				end
			end
		end
	end)
end

return PetFollowers

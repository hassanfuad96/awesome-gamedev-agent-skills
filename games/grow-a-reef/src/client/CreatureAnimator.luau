--!nonstrict
-- Swims every mesh creature (tagged "Creature", see Creatures) in the world near this
-- client's camera: tails swing, fins paddle, bodies sway. It only changes the welds' C0 on
-- this client, so it works the same for the server's catchable fish and for this client's
-- own pets and aquarium fish. A model's optional "Pace" attribute sets how hard it swims.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Creatures = require(ReplicatedStorage.Shared.Creatures)

local CreatureAnimator = {}

local NEAR = 140 -- studs from the camera; farther creatures hold still

function CreatureAnimator.start()
	local active: { [Model]: true } = {}
	local function add(instance: Instance)
		if instance:IsA("Model") then
			active[instance] = true
		end
	end
	for _, instance in CollectionService:GetTagged(Creatures.TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Creatures.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Creatures.TAG):Connect(function(instance)
		active[instance] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local t = os.clock()
		for model in active do
			-- Templates and Reef Index/pet panel previews aren't in the world: leave them be.
			local root = model.PrimaryPart
			if root and model:IsDescendantOf(Workspace) and (root.Position - eye).Magnitude < NEAR then
				Creatures.animate(model, t, model:GetAttribute("Pace"))
			end
		end
	end)
end

return CreatureAnimator

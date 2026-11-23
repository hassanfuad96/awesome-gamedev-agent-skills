--!nonstrict
-- Species research at the Research Laboratory (ReefConfig.Research). ResearchSpecies <seedId>
-- unlocks that coral in the Coral Market for good, if the player is at the lab's counter, the
-- species before it is researched and grown (ReefConfig.researchProblem), and they have the
-- shells. The remote carries only the id; the server decides everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Research = {}

local labStand: BasePart

local function notify(player: Player, text: string, tone: string?)
	Remotes.Notify:FireClient(player, text, tone or "info")
end

local function onResearch(player: Player, seedId: unknown)
	if not RateLimit.consume(player, 2) or type(seedId) ~= "string" or not ReefConfig.Seeds[seedId] then
		return
	end
	local profile = PlayerData.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end
	if (root.Position - labStand.Position).Magnitude > ReefConfig.INTERACT_DISTANCE then
		notify(player, "Walk over to the Research Laboratory to research species.")
		return
	end
	local data = profile.data
	local problem = ReefConfig.researchProblem(data, seedId)
	if problem then
		notify(player, problem)
		return
	end
	local cost = ReefConfig.Research.costs[seedId]
	local wallet = { shells = data.shells }
	if not EconomyMath.trySpend(wallet, { shells = cost }) then
		notify(player, `Researching {ReefConfig.Seeds[seedId].name} costs {EconomyMath.formatNumber(cost)} shells.`)
		return
	end
	-- No yields between the checks above and these writes.
	data.shells = wallet.shells
	data.research[seedId] = true
	notify(player, `Research complete: {ReefConfig.Seeds[seedId].name} seeds are now in the Coral Market for you!`, "rare")
	PlayerData.sync(player)
end

function Research.start(worldParts: any)
	labStand = worldParts.labStand
	Remotes.ResearchSpecies.OnServerEvent:Connect(onResearch)
end

return Research

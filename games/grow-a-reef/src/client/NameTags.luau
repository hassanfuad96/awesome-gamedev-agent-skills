--!nonstrict
-- Titles over heads. The server publishes each player's chosen title and rebirth count as
-- the "Title" and "Rebirths" attributes (PlayerData.sync); this draws them above every
-- character, on this client only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)

local NameTags = {}

local TAG_NAME = "ReefTitleTag"

local function render(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild(TAG_NAME)
	if old then
		old:Destroy()
	end
	local title = ReefConfig.TitleById[player:GetAttribute("Title") or ""]
	local rebirths = player:GetAttribute("Rebirths") or 0
	if not title and rebirths <= 0 then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = TAG_NAME
	gui.Size = UDim2.fromOffset(200, 44)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	local function line(order: number, text: string, color: Color3, height: number)
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.35
		label.Text = text
		label.Parent = gui
	end
	if title then
		line(1, title.text, title.color, 24)
	end
	if rebirths > 0 then
		line(2, `Rebirth {rebirths}`, Color3.fromRGB(255, 170, 110), 16)
	end
	gui.Parent = head
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Title"):Connect(function()
		render(player)
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		render(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		render(player)
	end)
	render(player)
end

function NameTags.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return NameTags

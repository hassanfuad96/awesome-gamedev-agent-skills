--!nonstrict
-- Global boards (OrderedDataStore): "Top Reefs" ranked by lifetime shells earned and "Best
-- Reefs" ranked by likes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefConfig = require(ReplicatedStorage.Shared.ReefConfig)
local EconomyMath = require(ReplicatedStorage.Shared.EconomyMath)
local World = require(script.Parent.World)
local PlayerData = require(script.Parent.PlayerData)

local Leaderboard = {}

local SIZE = 10
local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else "Diver " .. userId
	nameCache[userId] = result
	return result
end

local function render(list: Frame, rows: { { name: string, value: number } })
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #rows == 0 then
		rows = { { name = "No reefs ranked yet", value = -1 } }
	end
	for rank, row in rows do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = rank
		label.Size = UDim2.fromScale(1, 1 / SIZE)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if rank == 1 then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(220, 240, 255)
		label.Text = if row.value < 0 then row.name else `{rank}. {row.name}  -  {EconomyMath.formatNumber(row.value)}`
		label.Parent = list
	end
end

-- One board: an OrderedDataStore of `value(data)` for every player, drawn into `list`.
local function runBoard(storeName: string, list: Frame, value: (PlayerData.Data) -> number)
	local ok, board = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName)
	end)
	if not ok then
		render(list, {})
		return
	end
	local ordered = board :: OrderedDataStore

	task.spawn(function()
		while true do
			-- Push the values of everyone here, then read the top of the board.
			for player, profile in PlayerData.all() do
				if profile.persist then
					local total = math.floor(value(profile.data))
					pcall(function()
						ordered:SetAsync(tostring(player.UserId), total)
					end)
				end
			end

			local readOk, pages = pcall(function()
				return ordered:GetSortedAsync(false, SIZE)
			end)
			local rows = {}
			if readOk then
				for _, entry in (pages :: DataStorePages):GetCurrentPage() do
					local userId = tonumber(entry.key)
					if userId and entry.value > 0 then
						table.insert(rows, { name = nameFor(userId), value = entry.value })
					end
				end
			end
			render(list, rows)
			task.wait(ReefConfig.LEADERBOARD_REFRESH)
		end
	end)
end

function Leaderboard.start(worldParts: World.WorldParts)
	runBoard("GrowAReef_TotalEarned_v1", worldParts.boardList, function(data)
		return data.totalEarned
	end)
	runBoard("GrowAReef_Likes_v1", worldParts.likesBoardList, function(data)
		return data.likes
	end)
end

return Leaderboard

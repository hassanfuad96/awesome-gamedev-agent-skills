--!nonstrict
-- Per-player token bucket. Every remote handler calls consume() before doing work.

local Players = game:GetService("Players")

type Bucket = { tokens: number, updatedAt: number }

local CAPACITY = 8
local REFILL_PER_SECOND = 4

local buckets: { [Player]: Bucket } = {}

local RateLimit = {}

function RateLimit.consume(player: Player, cost: number?): boolean
	local spend = cost or 1
	local now = os.clock()
	local bucket = buckets[player] or { tokens = CAPACITY, updatedAt = now }
	bucket.tokens = math.min(CAPACITY, bucket.tokens + (now - bucket.updatedAt) * REFILL_PER_SECOND)
	bucket.updatedAt = now
	buckets[player] = bucket
	if bucket.tokens < spend then
		return false
	end
	bucket.tokens -= spend
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimit

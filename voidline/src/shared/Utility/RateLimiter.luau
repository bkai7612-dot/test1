--!strict
--[[
	RateLimiter
	Token bucket keyed by any value (normally a Player).

	Each key starts with `capacity` tokens. Every Check consumes one token;
	tokens refill continuously at `refillPerSecond`. A burst of `capacity`
	calls is allowed, after which calls are limited to the refill rate.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { Tokens: number, Updated: number }
type RateLimiterData = {
	Capacity: number,
	RefillPerSecond: number,
	_buckets: { [any]: Bucket },
}
export type RateLimiter = typeof(setmetatable({} :: RateLimiterData, RateLimiter))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	assert(capacity >= 1, "RateLimiter capacity must be >= 1")
	assert(refillPerSecond > 0, "RateLimiter refill rate must be > 0")
	return setmetatable({
		Capacity = capacity,
		RefillPerSecond = refillPerSecond,
		_buckets = {},
	}, RateLimiter)
end

-- Returns true and consumes a token if `key` is within its limit.
function RateLimiter.Check(self: RateLimiter, key: any): boolean
	local now = os.clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { Tokens = self.Capacity, Updated = now }
		self._buckets[key] = bucket
	else
		local elapsed = now - bucket.Updated
		bucket.Tokens = math.min(self.Capacity, bucket.Tokens + elapsed * self.RefillPerSecond)
		bucket.Updated = now
	end

	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

-- Forget a key (call when a player leaves to avoid leaking memory).
function RateLimiter.Reset(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

function RateLimiter.Clear(self: RateLimiter)
	table.clear(self._buckets)
end

return RateLimiter

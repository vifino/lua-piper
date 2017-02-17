-- streams
-- Simple buffered streams.
-- Rather thin library. Uses a linked list to preserve order.
-- Can be used without piper, no problems.

local _M = {}

-- Localize some funcs.
local setmetatable = setmetatable
local rawget, rawset = rawget, rawset

-- Helper functions
local function getfirst(self)
	if self.len == 0 then
		return nil
	end
	local first = rawget(self, "buf")
	local val = first.val
	rawset(self, "buf", first.next)
	rawset(self, "len", rawget(self, "len") - 1)
	return val
end

local streammt = {
	__index = {
		--- Insert into the stream.
		send = function(self, obj)
			local new = {
				val = obj,
				next = nil,
			}
			
			if self.len == 0 then
				rawset(self, "last", new)
				rawset(self, "buf", new)
				rawset(self, "len", 1)
				return
			end

			rawget(self, "last").next = new
			rawset(self, "last", new)
			rawset(self, "len", rawget(self, "len") + 1)
		end,
		
		--- Fetch from the stream.
		recv = function(self)
			if self.len == 0 then
				local filler = self.fetch
				if filler then
					local ret = filler(self)
					if ret ~= nil then
						return ret
					end

					if self.len == 0 then
						return nil
					end

					return getfirst(self)
				end
			end
			return getfirst(self)
		end,

		-- Return an iterator for iterating over the bufffered elements.
		-- @param filler Invoke the filler when empty, disabled by default.
		iter = function(self, filler)
			if filler then
				local recv = self.recv
				return function()
					return recv(self)
				end
			end

			return function()
				return getfirst(self)
			end
		end,
	},
	__name = "stream",
}

--- Create a new stream.
function _M.new(fetcher)
	local ret = {
		len = 0,
		buf = {
			val = nil,
			prev = nil,
		},
		last = nil,
		fetch = fetcher,
	}
	setmetatable(ret, streammt)
	return ret
end

return _M

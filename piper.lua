-- lua-piper
-- A Lua pipeline processing library.
-- Enables easy, efficient, modular and reusable processing pipelines to be used.
--
-- Also contains a pipeline builder, which should make map and reduce fans squee.
--
-- Terminology:
--   * Filter:
--     A processing element. Can be a function or table.
--     Functions get called with the input, returning the result.
--   * Source:
--     The first filter in a Pipeline. Only filter with optional input, rather than the usual enforcement.
--     Returning nil as the result means end of input.
--   * Sink:
--     The last filter in a Pipeline. Can return nil.
--   * Pipeline:
--     A collection of sources, filters and sinks.
--     If a non-source or non-sink filter returns nil, the pipeline aborts.

local _M = {
	stepper = {},
	filters = {},
}

-- Localize functions for performance.
local sel = select
local rset, rget = rawset, rawget

-- Helpers.

local function run_filter(filter, ...)
	if type(filter) == "function" then
		return filter(...)
	else
		return filter[sel(1, ...)]
	end
end

-- Steppers.

--- Return a stepper that does a single pipeline run.
-- This method usually gets invoked via methods from the pipeline itself.
-- This stepper is basic, but not simple.
-- @param pipeline The pipeline to execute.
function _M.stepper.basic(pipeline)
	return function(value)
		local filters = pipeline.filters
		local elems = #filters
		if elems == 0 then
			return true, value
		elseif elems == 1 then
			return true, run_filter(filters[1], value)
		end

		local res = value
		for i=1, elems do
			res = run_filter(filters[i], res)

			if res == nil then
				if i == 1 then -- source, usually done processing input
					return true, nil
				elseif i ~= elems then -- not the end, which doesn't have to return anything.
					return false, "Filter no. "..tostring(i).. " returned nil."
				end
			end
		end

		return true, res
	end
end

--- Return a caching stepper that does a single pipeline run.
-- This method usually gets invoked via methods from the pipeline itself.
-- Unlike the basic stepper, this one requires input to the pipeline.
-- It caches the result, so it won't rerun the pipeline for the same input.
-- Do note that unless the pipeline is GC'd, a reference to each input will be kept.
-- @param pipeline The pipeline to execute.
function _M.stepper.caching(pipeline)
	local cache = {}
	return function(value)
		local filters = pipeline.filters
		local elems = #filters
		if elems == 0 then
			return true, value
		end

		local cached = rget(cache, value)
		if cached then return true, cached end

		if elems == 1 then
			local res = run_filter(filters[1], value)
			rset(cache, value, res)
			return true, res
		end

		local res = value
		for i=1, elems do
			res = run_filter(filters[i], res)

			if res == nil then
				if i == 1 then -- source, usually done processing input
					return true, nil
				elseif i ~= elems then -- not the end, which doesn't have to return anything.
					return false, "Filter no. "..tostring(i).. " returned nil."
				end
			end
		end

		rset(cache, value, res)
		return true, res
	end
end

-- Default stepper.
_M.stepper.default = _M.stepper.basic

-- Pipelines.
local pipemt = {
	__index = {
		-- Denotes which stepper runs the pipeline.
		stepper = _M.stepper.default,

		run = function(self, input)
			if not self.step then self.step = self:stepper() end
			local success, result = self.step(input)
			if not success then
				error(result, 2)
			end
			return result
		end,

		runner = function(self)
			return function(input)
				return self:run(input)
			end
		end,

		add = function(self, filter)
			assert(filter, "Need a filter.")
			rset(self.filters, #self.filters+1, filter)
		end,
	},
	__name = "pipeline",
}

-- Creation and management.

--- Create a new pipeline.
-- Returned pipeline has several methods:
--  * res = pipeline:run([input])
--    Runs the pipeline, returning the result. Optionally with input.
--  * runnerfn = pipeline:runner()
--    Returns a function that does the same as pipeline:run([input]), but called as runnerfn([input])
--    Useful to call a pipeline in another pipeline.
--  * pipeline:add(filter)
--    Adds a filter to the pipeline.
-- @param filters Table containing filters.
function _M.create(filters, dontcheck)
	assert(filters, "Need a table of filters.")
	if #filters == 0 and not dontcheck then error("No filters given, need at least one.", 2) end
	local pipeline = {
		["filters"] = filters,
	}
	setmetatable(pipeline, pipemt)
	return pipeline
end

local buildermt = {
	__index = function(self, fname)
		if fname == "run" then
			local runner = function(input)
				return self.pipeline:run(input)
			end
			rset(self, "run", runner)
			return runner
		elseif fname == "use" then
			local user = function(filter)
				self.pipeline:add(filter)
				return self
			end
			rset(self, "use", user)
			return user
		end

		local filter_creator = self.flist[fname]
		if not filter_creator then error("No such filter: "..tostring(fname), 2) end

		local fc = function(...)
			local filter = filter_creator(...)
			rset(self.pipeline.filters, #self.pipeline.filters+1, filter)
			return self
		end
		rset(self, fname, fc)
		return fc
	end,
	__name = "pipeline builder"
}

--- Pipeline builder.
-- Unlike normal pipeline creation, this is different interface, more akin to functional languages.
function _M.builder()
	local builder = {
		pipeline = _M.create({}, true),
		flist = _M.filters,
	}
	setmetatable(builder, buildermt)
	return builder
end

-- Builtin filters.
-- Not a huge amount, hopefully.
-- Should contain essentials.

--- A basic map implementation.
-- Call with a filter, it returns a filter,
-- which iterates over it's input, calling the input filter repeatedly.
function _M.filters.map(filter)
	return function(tmp)
		assert(tmp, "Expected table to map over.")

		for i=1, #tmp do
			tmp[i] = run_filter(filter, tmp[i])
		end
		return tmp
	end
end

--- A basic reduce implementation.
function _M.filters.reduce(filter, starter)
	return function(input)
		assert(input, "Expected a table to reduce.")

		local acc = starter
		for i=1, #input do
			acc = run_filter(filter, acc, input[i])
			input[i] = nil
		end
		return acc
	end
end

return _M

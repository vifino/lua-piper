describe("piper", function()
	local piper = require("piper")

	describe("pipelines", function()
		it("error when no filters given.", function()
			assert.has_error(function() piper.create({}) end, "No filters given, need at least one.")
		end)

		it("work for one filter", function()
			local function add10(num)
				return true, 10 + num
			end
			local pipeline = piper.create({add10})
			local res = pipeline:run(10)
			assert.is_equals(res, 20)
		end)
		it("work for two filters", function()
			local function add10(num)
				return true, 10 + num
			end
			local function sub5(num)
				return true, num - 5
			end
			local pipeline = piper.create({add10, sub5})
			local res = pipeline:run(10)
			assert.is_equals(res, 15)
		end)

		it("work for a table", function()
			local lookup = {
				2, 4, 8, 16, 32, 64,
			}
			local pipeline = piper.create({lookup})
			assert.is_equals(pipeline:run(2), 4)
		end)
	end)
end)

describe("piper", function()
	local piper = require("piper")

	describe("builder", function()
		it("can initiate", function()
			piper.builder()
		end)

		it("can run a basic pipeline", function()
			local function add10(num)
				return true, 10 + num
			end
			local res = piper.builder().use(add10).run(10)
			assert.is_equals(res, 20)
		end)
		it("can run a map pipeline (2 filters)", function()
			local function square(num)
				return true, num^2
			end
			local res = piper.builder().map(square).run({1, 2, 3, 4, 5})
			assert.are.same(res, {1, 4, 9, 16, 25})
		end)
		it("can run a map/reduce pipeline (3 filters)", function()
			local function sum(acc, new)
				return true, acc + new
			end
			local function square(num)
				return true, num^2
			end

			local res = piper.builder().map(square).reduce(sum, 0).run({1, 2, 3, 4, 5})
			assert.is_equals(res, 55)
		end)
	end)
end)

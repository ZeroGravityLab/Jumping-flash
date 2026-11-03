local ToyStats = require("../src/ReplicatedStorage/Shared/ToyStats")
local check = require("./check")

local jumps = {
	{ t = 10, perfect = true },
	{ t = 20, perfect = false },
	{ t = 200, perfect = true },
}

return {
	["구간별 퍼펙트율"] = function()
		check.equal(ToyStats.perfectRate(jumps, 0, 180), 0.5)
		check.equal(ToyStats.perfectRate(jumps, 180, math.huge), 1)
	end,

	["공중 점프가 없는 구간은 nil"] = function()
		check.equal(ToyStats.perfectRate(jumps, 500, 600), nil)
	end,
}

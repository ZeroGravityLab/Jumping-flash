local Rush = require("../src/ReplicatedStorage/Config/Rush")
local RushLogic = require("../src/ReplicatedStorage/Shared/RushLogic")
local check = require("./check")

return {
	["해일은 TideDelay까지 0이고 그 뒤로 점점 빨라진다"] = function()
		check.equal(RushLogic.tideHeight(Rush, 0), 0)
		check.equal(RushLogic.tideHeight(Rush, Rush.TideDelay), 0)
		local a = RushLogic.tideHeight(Rush, Rush.TideDelay + 10)
		local b = RushLogic.tideHeight(Rush, Rush.TideDelay + 20)
		local c = RushLogic.tideHeight(Rush, Rush.TideDelay + 30)
		check.truthy(a > 0 and b > a and c > b, "tide must rise")
		check.truthy(c - b > b - a, "tide must speed up")
	end,

	["라운드 끝 무렵 해일은 가장 낮은 탑의 절반을 넘는다"] = function()
		local lowest = Rush.ChunkCountMin * Rush.ChunkHeight
		check.truthy(RushLogic.tideHeight(Rush, Rush.MaxRoundSeconds) > lowest / 2)
	end,

	["순위: 종을 먼저 울린 사람, 그다음 최고 높이"] = function()
		local ranked = RushLogic.rank({
			{ id = "a", maxHeight = 900 },
			{ id = "b", maxHeight = 1200, rangAt = 80 },
			{ id = "c", maxHeight = 1200, rangAt = 70 },
			{ id = "d", maxHeight = 1000 },
		})
		check.equal(ranked[1].id, "c")
		check.equal(ranked[2].id, "b")
		check.equal(ranked[3].id, "d")
		check.equal(ranked[4].id, "a")
	end,

	["코인: 높이 + 순위 보너스 + 종 보너스"] = function()
		check.equal(RushLogic.coins(Rush, 0, 9, 9, false), 0)
		check.equal(RushLogic.coins(Rush, Rush.MetersPerCoin * 10 + 5, 9, 9, false), 10)
		check.equal(RushLogic.coins(Rush, 0, 1, 4, true), Rush.RankBonus[1] + Rush.BellBonus)
	end,

	["혼자 하면 순위 보너스가 없다"] = function()
		check.equal(RushLogic.coins(Rush, 0, 1, 1, false), 0)
		check.equal(RushLogic.coins(Rush, 0, 1, 1, true), Rush.BellBonus)
	end,
}

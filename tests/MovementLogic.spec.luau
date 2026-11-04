local Movement = require("../src/ReplicatedStorage/Config/Movement")
local MovementLogic = require("../src/ReplicatedStorage/Shared/MovementLogic")
local check = require("./check")

local function airJump(jumpsUsed: number, sinceGrounded: number, vy: number, arcLaunched: boolean)
	return MovementLogic.resolveAirJump(Movement, {
		jumpsUsed = jumpsUsed,
		sinceGrounded = sinceGrounded,
		vy = vy,
		arcLaunched = arcLaunched,
	})
end

return {
	["점프 높이는 v²/2g"] = function()
		check.near(MovementLogic.jumpHeight(70, 110), 22.27, 0.01)
	end,

	["단계마다 더 높이 뛴다"] = function()
		for index = 2, #Movement.JumpVelocity do
			check.truthy(Movement.JumpVelocity[index] > Movement.JumpVelocity[index - 1])
		end
	end,

	["3단 점프 총 높이: 일반 약 125, 퍼펙트 약 158 (GDD 5.6)"] = function()
		check.near(MovementLogic.chainHeight(Movement, false), 124.6, 1)
		check.near(MovementLogic.chainHeight(Movement, true), 157.6, 1)
	end,

	["놀이터의 150 탑은 퍼펙트로만 닿는다"] = function()
		check.truthy(MovementLogic.chainHeight(Movement, false) < 150)
		check.truthy(MovementLogic.chainHeight(Movement, true) > 150)
	end,

	["다이브 캠이 보일 만큼 하강이 길다 (1.5초 이상)"] = function()
		check.truthy(MovementLogic.chainFallTime(Movement, false) >= 1.5)
	end,

	["수평 도달 거리 약 115 (GDD 5.6)"] = function()
		check.near(MovementLogic.chainReach(Movement, false), 115, 5)
	end,

	["정점 ±판정창 안이면 퍼펙트"] = function()
		local edge = Movement.Gravity * Movement.PerfectWindow
		check.truthy(MovementLogic.isPerfect(Movement, 0))
		check.truthy(MovementLogic.isPerfect(Movement, edge))
		check.truthy(MovementLogic.isPerfect(Movement, -edge))
		check.truthy(not MovementLogic.isPerfect(Movement, edge + 0.5))
	end,

	["연속 퍼펙트 단계는 시작 횟수에서 오르고, 연속이 아니면 0"] = function()
		check.equal(MovementLogic.perfectTier(Movement, 0), 0)
		local previous = 0
		for index, step in Movement.PerfectStreakTiers do
			check.truthy(step.from > previous, "단계 시작 횟수는 오름차순")
			check.equal(MovementLogic.perfectTier(Movement, step.from), index)
			check.equal(MovementLogic.perfectTier(Movement, step.from - 1), index - 1)
			previous = step.from
		end
		check.equal(MovementLogic.perfectTier(Movement, 999), #Movement.PerfectStreakTiers)
	end,

	["코요테 타임 안에서는 1단 점프"] = function()
		local jump = airJump(0, Movement.CoyoteTime / 2, -1, false)
		check.equal(jump and jump.index, 1)
		check.equal(jump and jump.velocity, Movement.JumpVelocity[1])
	end,

	["걸어서 떨어지면 지면 점프는 쓴 것으로 보고, 퍼펙트도 없다"] = function()
		local jump = airJump(0, 1, 0, false)
		check.equal(jump and jump.index, 2)
		check.equal(jump and jump.perfect, false)
	end,

	["2단 점프를 정점에서 누르면 퍼펙트 배율"] = function()
		local jump = airJump(1, 1, 3, true)
		check.equal(jump and jump.perfect, true)
		check.near(jump and jump.velocity or 0, Movement.JumpVelocity[2] * Movement.PerfectMultiplier, 1e-6)
	end,

	["정점에서 먼 2단 점프는 기본 초속"] = function()
		local jump = airJump(1, 1, -60, true)
		check.equal(jump and jump.perfect, false)
		check.equal(jump and jump.velocity, Movement.JumpVelocity[2])
	end,

	["점프를 다 쓰면 nil"] = function()
		check.equal(airJump(#Movement.JumpVelocity, 1, 0, true), nil)
	end,

	["밟기 반동은 공중 점프 1회를 돌려준다"] = function()
		check.equal(MovementLogic.jumpsAfterBounce(Movement, 3), 2)
		check.equal(MovementLogic.jumpsAfterBounce(Movement, 1), 1)
		check.equal(MovementLogic.jumpsAfterBounce(Movement, 0), 1)
	end,

	["낙하 속도 상한 (스톰프는 더 빠르다)"] = function()
		check.equal(MovementLogic.clampFall(Movement, -500, false), -Movement.TerminalFall)
		check.equal(MovementLogic.clampFall(Movement, -500, true), -Movement.StompDive)
		check.equal(MovementLogic.clampFall(Movement, 20, false), 20)
	end,

	["탄도 위치"] = function()
		local x, y, z = MovementLogic.trajectoryPoint({ X = 0, Y = 0, Z = 0 }, { X = 10, Y = 110, Z = 0 }, 110, 1)
		check.near(x, 10, 1e-9)
		check.near(y, 55, 1e-9)
		check.near(z, 0, 1e-9)
	end,
}

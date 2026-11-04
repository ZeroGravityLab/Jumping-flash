local Movement = require("../src/ReplicatedStorage/Config/Movement")
local Rush = require("../src/ReplicatedStorage/Config/Rush")
local GuardLogic = require("../src/ReplicatedStorage/Shared/GuardLogic")
local check = require("./check")

local DT = Rush.ServerTick

-- 높이 함수 y(t)를 서버처럼 DT마다 보고, 처음 걸린 시각과 이유를 돌려준다
local function watch(y: (number) -> number, duration: number): (number?, string?)
	local state = GuardLogic.new(Rush, y(0))
	local t = 0
	while t < duration do
		t += DT
		local ok, reason = GuardLogic.step(Rush, state, y(t), DT)
		if not ok then
			return t, reason
		end
	end
	return nil, nil
end

-- 탄도: 시작 높이 y0, 초속 v에서 t초 뒤 높이
local function arc(y0: number, v: number, t: number): number
	return y0 + v * t - Movement.Gravity * t * t / 2
end

-- 바운스 패드 → 정점마다 퍼펙트 2단·3단 → 낙하 (가장 큰 한 번의 상승)
local function padChain(t: number): number
	local g = Movement.Gravity
	local v1 = Movement.BouncePadVelocity
	local v2 = Movement.JumpVelocity[2] * Movement.PerfectMultiplier
	local v3 = Movement.JumpVelocity[3] * Movement.PerfectMultiplier
	local t1, t2 = v1 / g, v2 / g
	local h1 = arc(0, v1, t1)
	local h2 = arc(h1, v2, t2)
	if t < t1 then
		return arc(0, v1, t)
	elseif t < t1 + t2 then
		return arc(h1, v2, t - t1)
	end
	return arc(h2, v3, t - t1 - t2)
end

return {
	["바운스 패드 + 퍼펙트 2번 같은 큰 상승은 통과한다"] = function()
		local at, reason = watch(padChain, 6)
		check.equal(at, nil, reason)
	end,

	["상승 기류를 끝까지 타고 3단 점프해도 통과한다"] = function()
		local column = 110 / Movement.UpdraftVelocity
		local function ride(t: number): number
			if t < column then
				return Movement.UpdraftVelocity * t
			end
			return arc(110, Movement.JumpVelocity[3], t - column)
		end
		local at, reason = watch(ride, 5)
		check.equal(at, nil, reason)
	end,

	["빠르게 탑을 오르는 정상 플레이 (8초마다 청크 하나)는 통과한다"] = function()
		local function climb(t: number): number
			local chunk = math.floor(t / 8)
			local inChunk = t - chunk * 8
			-- 청크마다 2초 동안 3단 점프로 75씩 두 번, 나머지는 발판에서 다음 점프 준비
			local gained = if inChunk < 2
				then inChunk / 2 * 75
				elseif inChunk < 4 then 75
				elseif inChunk < 6 then 75 + (inChunk - 4) / 2 * 75
				else 150
			return chunk * 150 + gained
		end
		local at, reason = watch(climb, 120)
		check.equal(at, nil, reason)
	end,

	["떨어졌다가 가 본 높이로 돌아오는 것은 예산을 쓰지 않는다"] = function()
		local function fallAndBack(t: number): number
			if t < 1 then
				return 300
			elseif t < 3 then
				return -600
			end
			return 300
		end
		local at, reason = watch(fallAndBack, 6)
		check.equal(at, nil, reason)
	end,

	["꼭대기로 순간이동하면 걸린다"] = function()
		local at, reason = watch(function(t: number)
			return if t < 1 then 0 else 1200
		end, 3)
		check.truthy(at ~= nil, "teleport not caught")
		check.equal(reason, "rise")
	end,

	["천천히 쉬지 않고 떠오르면 비행으로 걸린다"] = function()
		local at, reason = watch(function(t: number)
			return t * 5
		end, 20)
		check.truthy(at ~= nil and at <= Rush.GuardMaxRiseTime + DT * 2, "flying not caught")
		check.equal(reason, "flying")
	end,

	["예산을 넘는 빠른 연속 상승은 걸린다 (초당 120씩 계속)"] = function()
		local at, reason = watch(function(t: number)
			return t * 120
		end, 10)
		check.truthy(at ~= nil, "sustained fast rise not caught")
		check.equal(reason, "rise")
	end,
}

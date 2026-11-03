-- 이동 물리 순수 함수. Config 테이블을 인자로 받는다 (Roblox·Lune 공용).
local MovementLogic = {}

export type AirState = {
	jumpsUsed: number,
	sinceGrounded: number,
	vy: number,
	arcLaunched: boolean, -- 지금 궤적이 점프·반동으로 시작됐는가 (걸어서 떨어진 게 아닌가)
}

export type Jump = {
	index: number,
	velocity: number,
	perfect: boolean,
}

function MovementLogic.jumpHeight(velocity: number, gravity: number): number
	return velocity * velocity / (2 * gravity)
end

function MovementLogic.maxJumps(cfg): number
	return #cfg.JumpVelocity
end

-- 상승 중이면 정점까지 남은 시간, 하강 중이면 정점을 지난 시간
function MovementLogic.timeFromApex(vy: number, gravity: number): number
	return math.abs(vy) / gravity
end

function MovementLogic.isPerfect(cfg, vy: number): boolean
	return MovementLogic.timeFromApex(vy, cfg.Gravity) <= cfg.PerfectWindow
end

-- 공중에서 점프 입력이 들어왔을 때 낼 점프. 남은 점프가 없으면 nil
function MovementLogic.resolveAirJump(cfg, state: AirState): Jump?
	if state.jumpsUsed == 0 and state.sinceGrounded <= cfg.CoyoteTime then
		return { index = 1, velocity = cfg.JumpVelocity[1], perfect = false }
	end

	-- 점프 없이 발판에서 떨어졌으면 지면 점프는 쓴 것으로 본다
	local used = math.max(state.jumpsUsed, 1)
	if used >= #cfg.JumpVelocity then
		return nil
	end

	local index = used + 1
	local perfect = state.arcLaunched and MovementLogic.isPerfect(cfg, state.vy)
	local multiplier = if perfect then cfg.PerfectMultiplier else 1
	return { index = index, velocity = cfg.JumpVelocity[index] * multiplier, perfect = perfect }
end

function MovementLogic.jumpsAfterBounce(cfg, jumpsUsed: number): number
	return math.max(1, jumpsUsed - cfg.StompRestoreJumps)
end

function MovementLogic.clampFall(cfg, vy: number, stomping: boolean): number
	local limit = if stomping then cfg.StompDive else cfg.TerminalFall
	return math.max(vy, -limit)
end

local function chainVelocity(cfg, index: number, perfect: boolean): number
	local multiplier = if perfect and index > 1 then cfg.PerfectMultiplier else 1
	return cfg.JumpVelocity[index] * multiplier
end

-- 지면에서 시작해 공중 점프를 모두 정점에서 썼을 때의 총 높이
function MovementLogic.chainHeight(cfg, perfect: boolean): number
	local total = 0
	for index in cfg.JumpVelocity do
		total += MovementLogic.jumpHeight(chainVelocity(cfg, index, perfect), cfg.Gravity)
	end
	return total
end

-- 정점에서 같은 높이 지면까지 떨어지는 시간 (다이브 캠이 보여 줄 수 있는 시간)
function MovementLogic.chainFallTime(cfg, perfect: boolean): number
	return math.sqrt(2 * MovementLogic.chainHeight(cfg, perfect) / cfg.Gravity)
end

function MovementLogic.chainAirTime(cfg, perfect: boolean): number
	local rise = 0
	for index in cfg.JumpVelocity do
		rise += chainVelocity(cfg, index, perfect) / cfg.Gravity
	end
	return rise + MovementLogic.chainFallTime(cfg, perfect)
end

-- 같은 높이에 착지할 때의 수평 도달 거리
function MovementLogic.chainReach(cfg, perfect: boolean): number
	return cfg.AirSpeed * MovementLogic.chainAirTime(cfg, perfect)
end

-- 탄도 위치. origin·velocity는 X/Y/Z 필드를 가진 값 (Vector3 또는 테이블)
function MovementLogic.trajectoryPoint(origin, velocity, gravity: number, t: number): (number, number, number)
	return origin.X + velocity.X * t, origin.Y + velocity.Y * t - 0.5 * gravity * t * t, origin.Z + velocity.Z * t
end

return MovementLogic

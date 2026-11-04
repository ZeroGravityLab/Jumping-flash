-- MovementGuard 규칙 (GDD 14.2, 순수 함수). 서버가 일정 간격으로 본 높이를 넣으면 이상한 상승을 찾는다.
--   상승 예산: 새 최고 높이(peak)를 넘는 만큼 예산을 쓴다. 예산은 GuardRiseBurst까지 차고 초당 GuardRiseRate로 회복한다.
--     이미 가 본 높이로 돌아오는 것(낙하 후 안전 위치 복귀 등)은 예산을 쓰지 않는다.
--   비행: GuardMaxRiseTime초 넘게 쉬지 않고 오른다
local GuardLogic = {}

export type State = { budget: number, peak: number, lastY: number, risingFor: number }

function GuardLogic.new(cfg, y: number): State
	return { budget = cfg.GuardRiseBurst, peak = y, lastY = y, risingFor = 0 }
end

-- 한 번 본 결과. 문제가 없으면 true, 있으면 false와 이유("rise" | "flying"). 문제가 있으면 state를 바꾸지 않는다
function GuardLogic.step(cfg, state: State, y: number, dt: number): (boolean, string?)
	local budget = math.min(cfg.GuardRiseBurst, state.budget + cfg.GuardRiseRate * dt)
	local risingFor = if y > state.lastY + cfg.GuardRisingStep then state.risingFor + dt else 0
	if risingFor > cfg.GuardMaxRiseTime then
		return false, "flying"
	end
	local gain = y - state.peak
	if gain > budget then
		return false, "rise"
	end
	if gain > 0 then
		budget -= gain
		state.peak = y
	end
	state.budget = budget
	state.risingFor = risingFor
	state.lastY = y
	return true, nil
end

-- 되돌린 뒤: 그 높이에서 다시 본다 (연속 상승 시간도 처음부터)
function GuardLogic.reset(state: State, y: number)
	state.lastY = y
	state.risingFor = 0
end

return GuardLogic

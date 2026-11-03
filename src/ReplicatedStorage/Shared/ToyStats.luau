-- 토이 게이트 지표 (GDD 15장): 퍼펙트율이 시간이 갈수록 오르는가
local ToyStats = {}

export type AirJump = {
	t: number, -- 세션 시작 후 초
	perfect: boolean,
}

-- [fromTime, toTime) 구간의 퍼펙트율. 공중 점프가 없으면 nil
function ToyStats.perfectRate(jumps: { AirJump }, fromTime: number, toTime: number): number?
	local total, perfect = 0, 0
	for _, jump in jumps do
		if jump.t >= fromTime and jump.t < toTime then
			total += 1
			if jump.perfect then
				perfect += 1
			end
		end
	end
	if total == 0 then
		return nil
	end
	return perfect / total
end

return ToyStats

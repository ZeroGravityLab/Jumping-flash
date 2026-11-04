-- 클라우드 러시 규칙 (순수 함수, Roblox·Lune 공용): 해일 높이, 순위, 보상
local RushLogic = {}

export type Entry = { id: any, maxHeight: number, rangAt: number? }

-- 라운드 시작 뒤 elapsed초의 해일 높이 (탑 바닥 기준). TideDelay까지는 0, 그 뒤로 점점 빨라진다
function RushLogic.tideHeight(cfg, elapsed: number): number
	local t = elapsed - cfg.TideDelay
	if t <= 0 then
		return 0
	end
	return cfg.TideStartSpeed * t + cfg.TideAccel * t * t / 2
end

-- 순위: 종을 먼저 울린 사람, 그다음 최고 높이. 원본을 바꾸지 않는다
function RushLogic.rank(entries: { Entry }): { Entry }
	local sorted = table.clone(entries)
	table.sort(sorted, function(a, b)
		if a.rangAt and b.rangAt then
			return a.rangAt < b.rangAt
		elseif a.rangAt or b.rangAt then
			return a.rangAt ~= nil
		end
		return a.maxHeight > b.maxHeight
	end)
	return sorted
end

-- 라이벌 밟기를 인정하는가: 밟은 쪽이 위에 있고 가까우며, 밟힌 쪽이 무적이 아니다
-- rise = 밟은 쪽 루트 높이 - 밟힌 쪽 루트 높이, reach = 두 루트의 수평 거리
function RushLogic.canStomp(cfg, rise: number, reach: number, now: number, immuneUntil: number?): boolean
	return rise >= cfg.StompMinRise
		and rise <= cfg.StompMaxRise
		and reach <= cfg.StompMaxReach
		and now >= (immuneUntil or 0)
end

-- 코인: 높이(MetersPerCoin마다 1) + 순위 보너스(경쟁 상대가 있을 때만) + 종 보너스
function RushLogic.coins(cfg, heightMeters: number, rank: number, total: number, rang: boolean): number
	local coins = math.floor(math.max(heightMeters, 0) / cfg.MetersPerCoin)
	if total >= cfg.RankBonusMinPlayers then
		coins += cfg.RankBonus[rank] or 0
	end
	if rang then
		coins += cfg.BellBonus
	end
	return coins
end

return RushLogic

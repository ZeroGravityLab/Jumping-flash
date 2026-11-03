-- 의뢰 규칙 (순수 함수, Roblox·Lune 공용). 진행 상황 progress는 { [requestId] = { medal, bestTime } }
local RequestLogic = {}

local MEDAL_RANK = { bronze = 1, silver = 2, gold = 3 }

export type Progress = { [string]: { medal: string, bestTime: number } }

function RequestLogic.find(config, id: string)
	for _, request in config.Requests do
		if request.id == id then
			return request
		end
	end
	return nil
end

function RequestLogic.medalFor(request, seconds: number): string
	if seconds <= request.gold then
		return "gold"
	elseif seconds <= request.silver then
		return "silver"
	end
	return "bronze"
end

function RequestLogic.isBetter(medal: string, previous: string?): boolean
	return previous == nil or MEDAL_RANK[medal] > MEDAL_RANK[previous]
end

-- 선행 의뢰를 모두 끝냈으면 받을 수 있다. 끝낸 의뢰도 메달을 올리려고 다시 받을 수 있다
function RequestLogic.isAvailable(request, progress: Progress): boolean
	for _, id in request.requires or {} do
		if not progress[id] then
			return false
		end
	end
	return true
end

-- 주민이 지금 건넬 의뢰: 아직 안 끝낸 것 먼저, 다 끝냈으면 금메달이 아닌 것
function RequestLogic.nextFor(config, residentId: string, progress: Progress)
	local improvable = nil
	for _, request in config.Requests do
		if request.resident == residentId and RequestLogic.isAvailable(request, progress) then
			local record = progress[request.id]
			if not record then
				return request
			elseif record.medal ~= "gold" and not improvable then
				improvable = request
			end
		end
	end
	return improvable
end

-- 서버 시계로 잰 시간이 말이 되는가
function RequestLogic.isPlausible(request, seconds: number): boolean
	return seconds >= request.minTime
end

-- 처음 받는 메달은 전액, 더 좋은 메달로 올리면 차액만 준다
function RequestLogic.coinsFor(config, medal: string, previous: string?): number
	local gained = config.MedalCoins[medal]
	if previous == nil then
		return gained
	elseif MEDAL_RANK[medal] > MEDAL_RANK[previous] then
		return gained - config.MedalCoins[previous]
	end
	return 0
end

-- 장의 종 게이지: 끝낸 의뢰 수 / 보스까지 필요한 수
function RequestLogic.bellGauge(config, chapter: number, progress: Progress): (number, number)
	local done = 0
	for _, request in config.Requests do
		if request.chapter == chapter and progress[request.id] then
			done += 1
		end
	end
	local spec = config.Chapters[chapter]
	return done, if spec then spec.bossAt else 0
end

return RequestLogic

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

-- 선행 의뢰를 모두 끝냈으면 받을 수 있다. 끝낸 의뢰도 메달을 올리려고 다시 받을 수 있다.
-- 보스(request.boss)는 그 장의 종 게이지가 보스 열림 조건(Chapters.bossAt)까지 차야 한다
function RequestLogic.isAvailable(request, progress: Progress, config): boolean
	for _, id in request.requires or {} do
		if not progress[id] then
			return false
		end
	end
	if request.boss then
		local done, needed = RequestLogic.bellGauge(config, request.chapter, progress)
		return needed > 0 and done >= needed
	end
	return true
end

-- 주민이 지금 건넬 의뢰: 아직 안 끝낸 것 먼저, 다 끝냈으면 금메달이 아닌 것
function RequestLogic.nextFor(config, residentId: string, progress: Progress)
	local improvable = nil
	for _, request in config.Requests do
		if request.resident == residentId and RequestLogic.isAvailable(request, progress, config) then
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

-- 주민 상태 (말풍선·하늘 지도): "new" 안 끝낸 의뢰가 있다, "improve" 금메달이 아닌 의뢰만 남았다,
-- "done" 모두 금메달, "locked" 남은 의뢰가 다른 의뢰를 먼저 끝내야 열린다
function RequestLogic.residentState(config, residentId: string, progress: Progress): string
	local request = RequestLogic.nextFor(config, residentId, progress)
	if request then
		return if progress[request.id] then "improve" else "new"
	end
	for _, r in config.Requests do
		if r.resident == residentId and not progress[r.id] then
			return "locked"
		end
	end
	return "done"
end

-- 장의 의뢰 수: 끝낸 수, 전체 수 (보스는 세지 않는다)
function RequestLogic.chapterCount(config, chapter: number, progress: Progress): (number, number)
	local done, total = 0, 0
	for _, request in config.Requests do
		if request.chapter == chapter and not request.boss then
			total += 1
			if progress[request.id] then
				done += 1
			end
		end
	end
	return done, total
end

-- 장의 의뢰를 모두 끝냈는가 (0장 = 튜토리얼을 끝내면 하늘 지도가 열린다)
function RequestLogic.chapterComplete(config, chapter: number, progress: Progress): boolean
	local done, total = RequestLogic.chapterCount(config, chapter, progress)
	return total > 0 and done == total
end

-- 하늘 지도가 열렸는가: 튜토리얼(0장)을 다 끝냈거나, 튜토리얼을 건너뛰고 1장 이후 의뢰를 하나라도 끝냈다
function RequestLogic.isMapUnlocked(config, progress: Progress): boolean
	if RequestLogic.chapterComplete(config, 0, progress) then
		return true
	end
	for _, request in config.Requests do
		if request.chapter >= 1 and progress[request.id] then
			return true
		end
	end
	return false
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

-- 장의 종 게이지: 끝낸 의뢰 수 / 보스까지 필요한 수 (보스는 세지 않는다)
function RequestLogic.bellGauge(config, chapter: number, progress: Progress): (number, number)
	local done = 0
	for _, request in config.Requests do
		if request.chapter == chapter and not request.boss and progress[request.id] then
			done += 1
		end
	end
	local spec = config.Chapters[chapter]
	return done, if spec then spec.bossAt else 0
end

-- 장의 섬을 되살렸는가 (그 장의 보스를 이겼다)
function RequestLogic.isRestored(config, chapter: number, progress: Progress): boolean
	local spec = config.Chapters[chapter]
	return spec ~= nil and spec.boss ~= nil and progress[spec.boss] ~= nil
end

return RequestLogic

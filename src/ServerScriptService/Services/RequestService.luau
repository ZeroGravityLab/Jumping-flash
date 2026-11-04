-- 의뢰 시작·완료 검증과 보상. 시간은 서버 시계로만 잰다 (클라이언트가 보낸 시간은 받지 않는다)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Requests = require(ReplicatedStorage.Config.Requests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RequestLogic = require(ReplicatedStorage.Shared.RequestLogic)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Net)

local RequestService = {}

local CALL_INTERVAL = 0.5

local sessions: { [Player]: { id: string, startedAt: number } } = {}

local function start(player: Player, requestId: any): boolean
	if type(requestId) ~= "string" then
		return false
	end
	local request = RequestLogic.find(Requests, requestId)
	local profile = DataService.get(player)
	if not (request and profile and RequestLogic.isAvailable(request, profile.requests, Requests)) then
		return false
	end
	sessions[player] = { id = requestId, startedAt = os.clock() }
	return true
end

local function complete(player: Player, requestId: any)
	local session = sessions[player]
	if not session or session.id ~= requestId then
		return nil
	end
	sessions[player] = nil
	local request = RequestLogic.find(Requests, requestId)
	local profile = DataService.get(player)
	if not (request and profile) then
		return nil
	end
	local elapsed = os.clock() - session.startedAt
	if not RequestLogic.isPlausible(request, elapsed) then
		warn(
			string.format(
				"[RequestService] %s의 %s 보고가 너무 빠릅니다 (%.1fs)",
				player.Name,
				requestId,
				elapsed
			)
		)
		return nil
	end

	local medal = RequestLogic.medalFor(request, elapsed)
	local previous = profile.requests[requestId]
	local coins = RequestLogic.coinsFor(Requests, medal, previous and previous.medal)
	DataService.update(player, function(p)
		local record = p.requests[requestId]
		if not record then
			p.requests[requestId] = { medal = medal, bestTime = elapsed }
		else
			if RequestLogic.isBetter(medal, record.medal) then
				record.medal = medal
			end
			record.bestTime = math.min(record.bestTime, elapsed)
		end
	end)
	EconomyService.addCoins(player, coins)

	local bell, bellNeeded = RequestLogic.bellGauge(Requests, request.chapter, profile.requests)
	return {
		medal = medal,
		time = elapsed,
		coins = coins,
		isNew = previous == nil,
		chapter = request.chapter,
		bell = bell,
		bellNeeded = bellNeeded,
	}
end

function RequestService.start()
	Net.handleFunction(Remotes.RequestStart, CALL_INTERVAL, start)
	Net.handleFunction(Remotes.RequestComplete, CALL_INTERVAL, complete)
	Net.handleEvent(Remotes.RequestCancel, CALL_INTERVAL, function(player)
		sessions[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		Net.forget(player)
	end)
end

return RequestService

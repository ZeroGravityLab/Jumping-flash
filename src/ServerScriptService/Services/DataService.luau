-- 프로필 읽기·쓰기는 여기서만 한다 (CLAUDE.md). 세션 잠금과 저장(주기·퇴장·서버 종료)은 ProfileStore가 맡는다.
-- 새 필드는 TEMPLATE에 더하면 접속할 때 Reconcile로 채워진다. 기존 값의 뜻이 바뀌면 SCHEMA_VERSION을 올리고 변환 단계를 더한다.
-- Studio에서 API 접근이 꺼져 있으면 ProfileStore가 메모리 저장소를 쓴다 (플레이를 멈추면 사라짐).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local Strings = require(ReplicatedStorage.Shared.Strings)

local DataService = {}

local SCHEMA_VERSION = 1
-- Studio 테스트 데이터가 실제 플레이어 데이터에 섞이지 않게 저장소를 나눈다
local STORE_NAME = if RunService:IsStudio() then "SkyhopProfile_Studio" else "SkyhopProfile"

export type Profile = {
	schemaVersion: number,
	coins: number,
	requests: { [string]: { medal: string, bestTime: number } },
}

local TEMPLATE: Profile = { schemaVersion = SCHEMA_VERSION, coins = 0, requests = {} }

local store = ProfileStore.New(STORE_NAME, TEMPLATE)
local sessions: { [Player]: any } = {}

-- 클라이언트 표시용. 판단은 항상 서버의 프로필로 한다
local function publish(player: Player, data: Profile)
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("RequestProgress", HttpService:JSONEncode(data.requests))
end

local function load(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		if player.Parent == Players then
			player:Kick(Strings.get(player.LocaleId, "KickLoadFailed"))
		end
		return
	end
	profile:AddUserId(player.UserId) -- 데이터 삭제 요청(GDPR) 대응
	profile:Reconcile()
	-- 다른 서버가 세션을 가져가면 여기서는 더 쓰지 않는다
	profile.OnSessionEnd:Connect(function()
		if sessions[player] == profile then
			sessions[player] = nil
			player:Kick(Strings.get(player.LocaleId, "KickSessionMoved"))
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	sessions[player] = profile
	publish(player, profile.Data)
end

function DataService.get(player: Player): Profile?
	local profile = sessions[player]
	return if profile then profile.Data else nil
end

function DataService.update(player: Player, mutate: (Profile) -> ())
	local profile = sessions[player]
	if not profile then
		return
	end
	mutate(profile.Data)
	publish(player, profile.Data)
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = sessions[player]
		sessions[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService

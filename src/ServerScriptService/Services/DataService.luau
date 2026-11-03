-- 프로필 읽기·쓰기는 여기서만 한다 (CLAUDE.md). 스키마를 바꾸면 SCHEMA_VERSION을 올리고 migrate에 단계를 더한다.
-- Studio에서 API 접근이 꺼져 DataStore를 못 쓰면 메모리 프로필로 동작한다(저장 안 됨).
-- 세션 잠금이 없으므로 출시 전에 ProfileStore로 바꾼다 (GDD 15장 W6~W8)
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local DataService = {}

local SCHEMA_VERSION = 1
local STORE_NAME = "SkyhopProfile"
local AUTOSAVE_SECONDS = 90

export type Profile = {
	schemaVersion: number,
	coins: number,
	requests: { [string]: { medal: string, bestTime: number } },
}

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(
			"[DataService] DataStore를 쓸 수 없어 메모리 프로필로 동작합니다(저장 안 됨):",
			result
		)
	end
end

local function defaultProfile(): Profile
	return { schemaVersion = SCHEMA_VERSION, coins = 0, requests = {} }
end

local function migrate(data): Profile
	if type(data) ~= "table" then
		return defaultProfile()
	end
	data.coins = data.coins or 0
	data.requests = data.requests or {}
	data.schemaVersion = SCHEMA_VERSION
	return data
end

local function key(player: Player): string
	return "u" .. player.UserId
end

-- 클라이언트 표시용. 판단은 항상 서버의 profiles로 한다
local function publish(player: Player)
	local profile = profiles[player]
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("RequestProgress", HttpService:JSONEncode(profile.requests))
end

function DataService.load(player: Player)
	local data = nil
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(key(player))
		end)
		if ok then
			data = result
		else
			warn("[DataService] 불러오기 실패, 이번 세션은 저장되지 않습니다:", result)
		end
	end
	profiles[player] = migrate(data)
	publish(player)
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.update(player: Player, mutate: (Profile) -> ())
	local profile = profiles[player]
	if not profile then
		return
	end
	mutate(profile)
	dirty[player] = true
	publish(player)
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if not (store and profile and dirty[player]) then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), profile)
	end)
	if ok then
		dirty[player] = nil
	else
		warn("[DataService] 저장 실패:", err)
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(DataService.load)
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		profiles[player] = nil
		dirty[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			DataService.save(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				DataService.save(player)
			end
		end
	end)
end

return DataService

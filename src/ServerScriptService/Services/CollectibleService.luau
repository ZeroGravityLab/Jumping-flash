-- 숨은 별조각 줍기 확인과 보상. 클라이언트는 "닿았다"만 보내고, 서버가 캐릭터 위치로 확인한다.
-- 코인은 EconomyService, 프로필은 DataService만 바꾼다. 결과는 Shards 속성(DataService가 쓴다)으로 클라이언트에 알린다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Collectibles = require(ReplicatedStorage.Config.Collectibles)
local World = require(ReplicatedStorage.Config.World)
local CollectibleLogic = require(ReplicatedStorage.Shared.CollectibleLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Net)

local CollectibleService = {}

local CALL_INTERVAL = 0.3
-- 보고가 캐릭터 위치보다 먼저 도착할 수 있다(순간이동·지연). "멀다"면 이 간격으로 몇 번 더 위치를 본다
local RECHECK_INTERVAL = 0.25
local RECHECKS = 2

local function check(player: Player, shardId: any): (boolean, string?)
	local profile = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (profile and root and root:IsA("BasePart")) then
		return false, "nobody"
	end
	local p = root.Position
	return CollectibleLogic.canCollect(Collectibles, World, shardId, profile.shards, { p.X, p.Y, p.Z })
end

local function collect(player: Player, shardId: any)
	local ok, reason = check(player, shardId)
	for _ = 1, RECHECKS do
		if ok or reason ~= "far" then
			break
		end
		task.wait(RECHECK_INTERVAL)
		ok, reason = check(player, shardId)
	end
	if not ok then
		if reason == "far" then
			warn(
				string.format(
					"[CollectibleService] %s의 %s 보고가 너무 멉니다",
					player.Name,
					tostring(shardId)
				)
			)
		end
		return
	end
	local shard = CollectibleLogic.find(Collectibles, shardId)
	EconomyService.addCoins(player, Collectibles.ShardCoins)
	DataService.update(player, function(data)
		data.shards[shard.id] = true
		-- 그 섬을 다 모았으면 세트 보상(상점의 unlock 물건)을 준다
		local found, total = CollectibleLogic.islandProgress(Collectibles, shard.island, data.shards)
		local set = CollectibleLogic.setFor(Collectibles, shard.island)
		if set and found == total then
			data.owned[set.reward] = true
		end
	end)
end

function CollectibleService.start()
	Net.handleEvent(Remotes.ShardCollect, CALL_INTERVAL, collect)
end

return CollectibleService

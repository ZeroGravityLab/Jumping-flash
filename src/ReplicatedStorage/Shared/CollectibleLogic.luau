-- 숨은 별조각 규칙 (순수 함수). 서버가 줍기를 확인할 때와 클라이언트가 개수를 그릴 때 같이 쓴다
local CollectibleLogic = {}

export type Collected = { [string]: boolean }

function CollectibleLogic.find(config, id: any)
	if type(id) ~= "string" then
		return nil
	end
	for _, shard in config.Shards do
		if shard.id == id then
			return shard
		end
	end
	return nil
end

-- 섬 윗면 중심 + air. 월드 좌표를 {x, y, z}로 돌려준다 (Roblox 타입을 쓰지 않는다)
function CollectibleLogic.worldPosition(shard, worldConfig): { number }?
	for _, island in worldConfig.Islands do
		if island.id == shard.island then
			return {
				island.center[1] + shard.air[1],
				island.center[2] + shard.air[2],
				island.center[3] + shard.air[3],
			}
		end
	end
	return nil
end

-- 그 섬에서 찾은 개수와 전체 개수
function CollectibleLogic.islandProgress(config, island: string, collected: Collected): (number, number)
	local found, total = 0, 0
	for _, shard in config.Shards do
		if shard.island == island then
			total += 1
			if collected[shard.id] then
				found += 1
			end
		end
	end
	return found, total
end

function CollectibleLogic.setFor(config, island: string)
	for _, set in config.Sets do
		if set.island == island then
			return set
		end
	end
	return nil
end

-- 줍기 확인: 있는 별조각이고, 아직 안 주웠고, 루트가 reach 안에 있다. 이유는 로그용
function CollectibleLogic.canCollect(
	config,
	worldConfig,
	id: any,
	collected: Collected,
	root: { number }
): (boolean, string?)
	local shard = CollectibleLogic.find(config, id)
	if not shard then
		return false, "unknown"
	end
	if collected[shard.id] then
		return false, "already"
	end
	local at = CollectibleLogic.worldPosition(shard, worldConfig)
	if not at then
		return false, "island"
	end
	local d = math.sqrt((root[1] - at[1]) ^ 2 + (root[2] - at[2]) ^ 2 + (root[3] - at[3]) ^ 2)
	if d > config.ServerReach then
		return false, "far"
	end
	return true, nil
end

return CollectibleLogic

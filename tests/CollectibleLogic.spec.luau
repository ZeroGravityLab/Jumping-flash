local Collectibles = require("../src/ReplicatedStorage/Config/Collectibles")
local Shop = require("../src/ReplicatedStorage/Config/Shop")
local World = require("../src/ReplicatedStorage/Config/World")
local CollectibleLogic = require("../src/ReplicatedStorage/Shared/CollectibleLogic")
local ShopLogic = require("../src/ReplicatedStorage/Shared/ShopLogic")
local check = require("./check")

local function islandSpec(id)
	for _, island in World.Islands do
		if island.id == id then
			return island
		end
	end
	return nil
end

return {
	["별조각: id가 겹치지 않고, 있는 섬에 있고, 줍는 반경이 서버 확인 거리보다 작다"] = function()
		local seen = {}
		for _, shard in Collectibles.Shards do
			check.truthy(not seen[shard.id], shard.id .. " duplicated")
			seen[shard.id] = true
			check.truthy(islandSpec(shard.island) ~= nil, shard.id .. " unknown island")
			check.truthy(#shard.air == 3, shard.id .. " needs air {x, y, z}")
		end
		check.truthy(Collectibles.CollectRadius < Collectibles.ServerReach)
	end,

	["섬마다 세트가 있고, 보상은 그 섬을 unlock으로 가진 상점 물건이다"] = function()
		for _, shard in Collectibles.Shards do
			local set = CollectibleLogic.setFor(Collectibles, shard.island)
			check.truthy(set ~= nil, shard.island .. " has no set")
			local item = ShopLogic.find(Shop, set.reward)
			check.truthy(item ~= nil and item.unlock == shard.island, set.reward .. " must unlock on " .. shard.island)
		end
	end,

	["섬별 진행: 찾은 개수와 전체 개수"] = function()
		local found, total =
			CollectibleLogic.islandProgress(Collectibles, "Skyhaven", { hub_bell = true, mead_rim = true })
		check.equal(found, 1)
		check.truthy(total >= 3)
	end,

	["줍기 확인: 모르는 것·이미 주운 것·먼 것은 거절"] = function()
		local shard = CollectibleLogic.find(Collectibles, "hub_bell")
		local at = CollectibleLogic.worldPosition(shard, World)
		check.truthy(at ~= nil)
		check.equal(CollectibleLogic.canCollect(Collectibles, World, "hub_bell", {}, at), true)
		check.equal(select(2, CollectibleLogic.canCollect(Collectibles, World, "nope", {}, at)), "unknown")
		check.equal(
			select(2, CollectibleLogic.canCollect(Collectibles, World, "hub_bell", { hub_bell = true }, at)),
			"already"
		)
		local far = { at[1] + Collectibles.ServerReach + 1, at[2], at[3] }
		check.equal(select(2, CollectibleLogic.canCollect(Collectibles, World, "hub_bell", {}, far)), "far")
	end,

	["가장자리 아래 별조각은 섬 반경 밖 허공에 있다"] = function()
		for _, shard in Collectibles.Shards do
			if shard.air[2] < 0 then
				local island = islandSpec(shard.island)
				local r = math.sqrt(shard.air[1] ^ 2 + shard.air[3] ^ 2)
				check.truthy(r > island.radius, shard.id .. " must be outside the rim")
			end
		end
	end,
}

local Shop = require("../src/ReplicatedStorage/Config/Shop")
local ShopLogic = require("../src/ReplicatedStorage/Shared/ShopLogic")
local Strings = require("../src/ReplicatedStorage/Shared/Strings")
local check = require("./check")

local function color(rgb): boolean
	return type(rgb) == "table" and #rgb == 3 and rgb[1] >= 0 and rgb[1] <= 255
end

return {
	["상품: id가 겹치지 않고, 칸이 있고, 가격은 양의 정수, 이름 문구가 언어마다 있다"] = function()
		local seen = {}
		for _, item in Shop.Items do
			check.truthy(not seen[item.id], item.id .. " duplicated")
			seen[item.id] = true
			check.truthy(ShopLogic.isCategory(Shop, item.category), item.id .. " unknown category")
			check.truthy(item.price > 0 and item.price % 1 == 0, item.id .. " bad price")
			for code, texts in Strings.languages do
				check.truthy(texts["Item_" .. item.id] ~= nil, code .. " missing Item_" .. item.id)
			end
		end
		for _, category in Shop.Categories do
			for code, texts in Strings.languages do
				check.truthy(texts["ShopTab" .. category] ~= nil, code .. " missing ShopTab" .. category)
			end
		end
	end,

	["상품: 궤적은 색이 2개 이상, 부츠는 몸통·밑창·띠 색이 있다"] = function()
		for _, item in Shop.Items do
			if item.category == "Trail" then
				check.truthy(#item.colors >= 2, item.id .. " needs 2+ colors")
				for _, rgb in item.colors do
					check.truthy(color(rgb), item.id .. " bad color")
				end
			elseif item.category == "Boots" then
				check.truthy(color(item.body) and color(item.sole) and color(item.accent), item.id .. " bad colors")
			end
		end
	end,

	["구매: 모르는 물건, 이미 가진 물건, 코인이 모자라면 못 산다"] = function()
		local item = ShopLogic.find(Shop, "trail_cloud")
		check.truthy(item ~= nil)
		check.equal(select(2, ShopLogic.canBuy(nil, 9999, {})), "ShopUnknown")
		check.equal(select(2, ShopLogic.canBuy(item, 9999, { trail_cloud = true })), "ShopOwned")
		check.equal(select(2, ShopLogic.canBuy(item, item.price - 1, {})), "ShopNoCoins")
		check.equal(ShopLogic.canBuy(item, item.price, {}), true)
		check.equal(ShopLogic.find(Shop, 42), nil)
	end,

	["장착: 가진 물건을 맞는 칸에만, 빈 칸으로 벗을 수 있다"] = function()
		local owned = { trail_cloud = true, boots_sky = true }
		check.equal(ShopLogic.canEquip(Shop, "Trail", "trail_cloud", owned), true)
		check.equal(ShopLogic.canEquip(Shop, "Trail", "trail_rainbow", owned), false)
		check.equal(ShopLogic.canEquip(Shop, "Boots", "trail_cloud", owned), false)
		check.equal(ShopLogic.canEquip(Shop, "Hat", "trail_cloud", owned), false)
		check.equal(ShopLogic.canEquip(Shop, "Boots", nil, owned), true)
	end,

	["입은 모습: 장착 기록 중 가진 물건만, 칸이 맞는 것만"] = function()
		local worn = ShopLogic.worn(
			Shop,
			{ Trail = "trail_rainbow", Boots = "boots_sky" },
			{ boots_sky = true, trail_cloud = true }
		)
		check.equal(worn.Trail, nil)
		check.equal(worn.Boots and worn.Boots.id, "boots_sky")
		check.equal(ShopLogic.worn(Shop, { Trail = "boots_sky" }, { boots_sky = true }).Trail, nil)
	end,
}

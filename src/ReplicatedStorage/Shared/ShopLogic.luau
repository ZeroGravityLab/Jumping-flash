-- 코인 상점 규칙 (순수 함수). 서버가 구매·장착을 판단할 때와 클라이언트가 버튼을 그릴 때 같이 쓴다
local ShopLogic = {}

export type Owned = { [string]: boolean }
export type Equipped = { [string]: string }

function ShopLogic.find(config, id: any)
	if type(id) ~= "string" then
		return nil
	end
	for _, item in config.Items do
		if item.id == id then
			return item
		end
	end
	return nil
end

function ShopLogic.isCategory(config, category: any): boolean
	return type(category) == "string" and table.find(config.Categories, category) ~= nil
end

-- 살 수 있으면 true, 아니면 false와 이유(Strings 키)
function ShopLogic.canBuy(item, coins: number, owned: Owned): (boolean, string?)
	if not item then
		return false, "ShopUnknown"
	end
	if owned[item.id] then
		return false, "ShopOwned"
	end
	if item.unlock then
		return false, "ShopLocked" -- 별조각을 다 모아야 생긴다
	end
	if coins < item.price then
		return false, "ShopNoCoins"
	end
	return true, nil
end

-- itemId가 nil이면 그 칸을 비운다(벗기). 가진 물건만, 그 물건의 칸에만 장착한다
function ShopLogic.canEquip(config, category: any, itemId: any, owned: Owned): boolean
	if not ShopLogic.isCategory(config, category) then
		return false
	end
	if itemId == nil then
		return true
	end
	local item = ShopLogic.find(config, itemId)
	return item ~= nil and item.category == category and owned[item.id] == true
end

-- 칸마다 실제로 입힐 물건 (잃어버렸거나 없어진 물건은 빼고)
function ShopLogic.worn(config, equipped: Equipped, owned: Owned): { [string]: any }
	local result = {}
	for _, category in config.Categories do
		local item = ShopLogic.find(config, equipped[category])
		if item and item.category == category and owned[item.id] then
			result[category] = item
		end
	end
	return result
end

return ShopLogic

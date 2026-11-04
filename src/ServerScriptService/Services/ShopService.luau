-- 코인 상점 구매·장착 검증 (GDD 9.4~9.5). 클라이언트는 "이걸 사고 싶다"만 보내고 판단은 여기서 한다.
-- 코인은 EconomyService만, 프로필은 DataService만 바꾼다. 입은 모습은 CosmeticService가 ShopEquipped 속성을 보고 갱신한다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Config.Shop)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Net)

local ShopService = {}

local CALL_INTERVAL = 0.3

local function buy(player: Player, itemId: any): (boolean, string?)
	local profile = DataService.get(player)
	if not profile then
		return false, "ShopUnknown"
	end
	local item = ShopLogic.find(Shop, itemId)
	local ok, reason = ShopLogic.canBuy(item, profile.coins, profile.owned)
	if not ok then
		return false, reason
	end
	if not EconomyService.spend(player, item.price) then
		return false, "ShopNoCoins"
	end
	DataService.update(player, function(p)
		p.owned[item.id] = true
		p.equipped[item.category] = item.id
	end)
	return true, nil
end

local function equip(player: Player, category: any, itemId: any): boolean
	local profile = DataService.get(player)
	if not (profile and ShopLogic.canEquip(Shop, category, itemId, profile.owned)) then
		return false
	end
	DataService.update(player, function(p)
		p.equipped[category] = itemId
	end)
	return true
end

function ShopService.start()
	Net.handleFunction(Remotes.ShopBuy, CALL_INTERVAL, buy)
	Net.handleFunction(Remotes.ShopEquip, CALL_INTERVAL, equip)
end

return ShopService

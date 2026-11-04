-- 코인 증감은 여기서만 한다 (CLAUDE.md)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)

local EconomyService = {}

local STUDIO_GRANT_ATTRIBUTE = "StudioGrantCoins"

function EconomyService.addCoins(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	DataService.update(player, function(profile)
		profile.coins += amount
	end)
end

-- 코인이 충분할 때만 빼고 true. 확인과 차감 사이에 양보(yield)가 없어 두 번 빠지지 않는다
function EconomyService.spend(player: Player, amount: number): boolean
	local profile = DataService.get(player)
	if not profile or amount <= 0 or profile.coins < amount then
		return false
	end
	DataService.update(player, function(p)
		p.coins -= amount
	end)
	return true
end

-- Studio 테스트 전용: 서버 쪽 MCP Luau가 플레이어에 StudioGrantCoins 속성(숫자)을 쓰면 그만큼 코인을 준다.
-- 클라이언트가 쓴 속성은 서버로 복제되지 않고, 게시된 게임에서는 연결하지 않는다
function EconomyService.start()
	if not RunService:IsStudio() then
		return
	end
	local function watch(player: Player)
		player:GetAttributeChangedSignal(STUDIO_GRANT_ATTRIBUTE):Connect(function()
			local amount = player:GetAttribute(STUDIO_GRANT_ATTRIBUTE)
			if type(amount) == "number" and amount > 0 then
				player:SetAttribute(STUDIO_GRANT_ATTRIBUTE, nil)
				EconomyService.addCoins(player, math.floor(amount))
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return EconomyService

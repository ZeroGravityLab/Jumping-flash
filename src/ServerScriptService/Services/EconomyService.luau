-- 코인 증감은 여기서만 한다 (CLAUDE.md)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

function EconomyService.addCoins(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	DataService.update(player, function(profile)
		profile.coins += amount
	end)
end

return EconomyService

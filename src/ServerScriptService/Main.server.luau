-- 서버 부트스트랩
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage.Config.Movement)
local CosmeticService = require(script.Parent.Services.CosmeticService)
local DataService = require(script.Parent.Services.DataService)
local EconomyService = require(script.Parent.Services.EconomyService)
local RequestService = require(script.Parent.Services.RequestService)
local RoundService = require(script.Parent.Services.RoundService)
local ShopService = require(script.Parent.Services.ShopService)
local WorldBuilder = require(script.Parent.World.WorldBuilder)

workspace.Gravity = Movement.Gravity
DataService.start()
EconomyService.start()
RequestService.start()
ShopService.start()
CosmeticService.start()
-- 러시 상태(RushState)를 월드보다 먼저 만들어 클라이언트가 오래 기다리지 않게 한다. 첫 대기 시간 안에 월드가 다 지어진다
RoundService.start()

-- 섬이 다 만들어지기 전에 캐릭터가 허공에 생기지 않게 막아 둔다
Players.CharacterAutoLoads = false
local started = os.clock()
WorldBuilder.build()
print(string.format("[World] built in %.1fs", os.clock() - started))
Players.CharacterAutoLoads = true
for _, player in Players:GetPlayers() do
	if not player.Character then
		player:LoadCharacter()
	end
end

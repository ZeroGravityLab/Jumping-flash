-- 서버 부트스트랩
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage.Config.Movement)
local DataService = require(script.Parent.Services.DataService)
local RequestService = require(script.Parent.Services.RequestService)
local WorldBuilder = require(script.Parent.World.WorldBuilder)

workspace.Gravity = Movement.Gravity
DataService.start()
RequestService.start()

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

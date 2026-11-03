-- 서버 부트스트랩 (토이 단계)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage.Config.Movement)
local Playground = require(script.Parent.Toy.Playground)

workspace.Gravity = Movement.Gravity
Playground.build()

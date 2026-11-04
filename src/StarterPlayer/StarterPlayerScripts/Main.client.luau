-- 클라이언트 부트스트랩
local Movement = script.Parent:WaitForChild("Movement")
local Requests = script.Parent:WaitForChild("Requests")
local UI = script.Parent:WaitForChild("UI")

local HopController = require(Movement:WaitForChild("HopController"))
local SkyCamera = require(Movement:WaitForChild("SkyCamera"))
local LandingMarker = require(Movement:WaitForChild("LandingMarker"))
local Effects = require(Movement:WaitForChild("Effects"))
local Vertigo = require(Movement:WaitForChild("Vertigo"))
local Ambience = require(Movement:WaitForChild("Ambience"))
local RequestController = require(Requests:WaitForChild("RequestController"))
local Hud = require(UI:WaitForChild("Hud"))
local RequestUi = require(UI:WaitForChild("RequestUi"))
local SkyMap = require(UI:WaitForChild("SkyMap"))
local Stories = require(Requests:WaitForChild("Stories"))
local RushHud = require(UI:WaitForChild("RushHud"))
local Boss = require(Requests:WaitForChild("Boss"))

HopController.start()
SkyCamera.start(HopController)
LandingMarker.start(HopController)
Effects.start(HopController)
Vertigo.start(HopController)
Ambience.start()
RequestUi.start()
SkyMap.start(HopController, RequestUi)
Hud.start(HopController, SkyCamera, LandingMarker, Vertigo, SkyMap)
RequestController.start(HopController, RequestUi)
task.spawn(Stories.start, HopController, RequestUi, SkyMap) -- 섬이 다 지어질 때까지 기다린다
task.spawn(RushHud.start, HopController, RequestUi, RequestController, SkyCamera) -- 서버의 러시 상태를 기다린다
task.spawn(Boss.start, HopController, RequestUi, RequestController) -- 섬이 다 지어질 때까지 기다린다

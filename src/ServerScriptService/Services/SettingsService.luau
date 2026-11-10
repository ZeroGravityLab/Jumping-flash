-- 플레이어 설정 저장. 클라이언트가 보낸 표를 SettingsLogic으로 걸러 프로필에 넣는다 (Settings 속성으로 다시 알린다)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Config.Settings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SettingsLogic = require(ReplicatedStorage.Shared.SettingsLogic)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

local SettingsService = {}

local CALL_INTERVAL = 0.5

function SettingsService.start()
	Net.handleEvent(Remotes.SettingsSave, CALL_INTERVAL, function(player: Player, raw: any)
		local clean = SettingsLogic.sanitize(Settings, raw)
		DataService.update(player, function(profile)
			profile.settings = clean
		end)
	end)
end

return SettingsService

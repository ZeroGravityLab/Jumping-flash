local Settings = require("../src/ReplicatedStorage/Config/Settings")
local SettingsLogic = require("../src/ReplicatedStorage/Shared/SettingsLogic")
local check = require("./check")

return {
	["빈 값이나 표가 아닌 값은 기본값이 된다"] = function()
		for _, raw in { nil, 42, "x", {} } do
			local s = SettingsLogic.sanitize(Settings, raw)
			check.equal(s.music, Settings.Defaults.music)
			check.equal(s.sounds, Settings.Defaults.sounds)
			check.equal(s.shake, Settings.Defaults.shake)
			check.equal(s.marker, Settings.Defaults.marker)
			check.equal(s.view, Settings.Defaults.view)
		end
	end,

	["볼륨은 0~1 안에서 한 칸 단위로 맞춘다"] = function()
		local s = SettingsLogic.sanitize(Settings, { music = 1.7, sounds = -3 })
		check.equal(s.music, 1)
		check.equal(s.sounds, 0)
		check.near(SettingsLogic.sanitize(Settings, { music = 0.44 }).music, 0.4, 1e-9)
		check.equal(SettingsLogic.sanitize(Settings, { music = 0 / 0 }).music, Settings.Defaults.music)
	end,

	["틀린 형식은 버리고 모르는 키는 남기지 않는다"] = function()
		local s = SettingsLogic.sanitize(Settings, { shake = "no", marker = 1, view = "Top", coins = 999 })
		check.equal(s.shake, Settings.Defaults.shake)
		check.equal(s.marker, Settings.Defaults.marker)
		check.equal(s.view, Settings.Defaults.view)
		check.equal((s :: any).coins, nil)
		check.equal(SettingsLogic.sanitize(Settings, { view = "First" }).view, "First")
	end,

	["볼륨 한 칸 올리기·내리기는 끝에서 멈춘다"] = function()
		check.near(SettingsLogic.stepVolume(Settings, 0.5, 1), 0.6, 1e-9)
		check.near(SettingsLogic.stepVolume(Settings, 0.5, -1), 0.4, 1e-9)
		check.equal(SettingsLogic.stepVolume(Settings, 1, 1), 1)
		check.equal(SettingsLogic.stepVolume(Settings, 0, -1), 0)
	end,

	["저장되는 볼륨에 자투리가 붙지 않는다"] = function()
		local v = 1
		for _ = 1, 10 do
			v = SettingsLogic.stepVolume(Settings, v, -1)
			check.equal(v, tonumber(string.format("%.1f", v)))
		end
		check.equal(v, 0)
	end,
}

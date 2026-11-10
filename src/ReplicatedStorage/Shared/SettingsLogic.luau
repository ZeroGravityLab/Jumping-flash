-- 플레이어 설정 정리 (순수 함수). 서버가 저장하기 전에, 클라이언트가 받은 값을 쓰기 전에 같은 규칙으로 걸러 낸다
local SettingsLogic = {}

export type Settings = { music: number, sounds: number, shake: boolean, marker: boolean, view: string }

local function volume(config, value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	-- 칸 수로 나눠야 0.7000000000000001 같은 자투리 없이 저장된다
	local steps = math.round(1 / config.VolumeStep)
	return math.clamp(math.round(value * steps) / steps, 0, 1)
end

local function flag(value: any, fallback: boolean): boolean
	if type(value) == "boolean" then
		return value
	end
	return fallback
end

-- 모르는 키는 버리고, 틀린 값은 기본값으로 채운다
function SettingsLogic.sanitize(config, raw: any): Settings
	local input = if type(raw) == "table" then raw else {}
	local defaults = config.Defaults
	return {
		music = volume(config, input.music, defaults.music),
		sounds = volume(config, input.sounds, defaults.sounds),
		shake = flag(input.shake, defaults.shake),
		marker = flag(input.marker, defaults.marker),
		view = if table.find(config.Views, input.view) then input.view else defaults.view,
	}
end

-- 볼륨을 한 칸 올리거나 내린다
function SettingsLogic.stepVolume(config, value: number, direction: number): number
	return volume(config, value + direction * config.VolumeStep, value)
end

return SettingsLogic

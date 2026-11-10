-- 설정의 두 볼륨(음악, 효과음)이 거는 SoundGroup. 소리를 만드는 모듈은 Sound.SoundGroup을 여기서 받는다
local SoundService = game:GetService("SoundService")

local AudioGroups = {}

local groups: { [string]: SoundGroup } = {}

local function group(name: string): SoundGroup
	local existing = groups[name]
	if existing then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = "Skyhop" .. name
	g.Volume = 1
	g.Parent = SoundService
	groups[name] = g
	return g
end

-- 배경음악
function AudioGroups.music(): SoundGroup
	return group("Music")
end

-- 점프·차임·천둥 같은 효과음과 바람·새소리
function AudioGroups.sounds(): SoundGroup
	return group("Sounds")
end

return AudioGroups

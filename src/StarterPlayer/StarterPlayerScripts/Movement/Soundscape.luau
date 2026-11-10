-- 배경음악과 환경음 (Config Audio). 지금 있는 곳(가장 가까운 섬)·클라우드 러시·장 보스에 맞는 곡으로 천천히 바꾸고,
-- 섬 가까이 낮게 있을 때만 새소리를 깐다. 높이 오르면 Vertigo의 바람 소리가 그 자리를 채운다. 이 클라이언트에서만 튼다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Audio = require(ReplicatedStorage.Config.Audio)
local Requests = require(ReplicatedStorage.Config.Requests)
local World = require(ReplicatedStorage.Config.World)
local RequestLogic = require(ReplicatedStorage.Shared.RequestLogic)
local AudioGroups = require(script.Parent.AudioGroups)

local player = Players.LocalPlayer

local CHECK_INTERVAL = 0.5

local Soundscape = {}

local function sound(name: string, spec, group: SoundGroup): Sound
	local s = Instance.new("Sound")
	s.SoundGroup = group
	s.Name = name
	s.SoundId = "rbxassetid://" .. spec.id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return s
end

local function nearestIsland(position: Vector3)
	local best, bestDistance = nil, math.huge
	for _, island in World.Islands do
		local d = Vector2.new(position.X - island.center[1], position.Z - island.center[3]).Magnitude
		if d < bestDistance then
			best, bestDistance = island, d
		end
	end
	return best, bestDistance
end

function Soundscape.start(hop, requestController)
	local music: { [string]: Sound } = {}
	for key, spec in Audio.Music do
		music[key] = sound("Music_" .. key, spec, AudioGroups.music())
	end
	local birds = sound("Birds", Audio.Birds, AudioGroups.sounds())
	birds:Play()
	local current: string? = nil
	local fade = TweenInfo.new(Audio.MusicFadeSeconds, Enum.EasingStyle.Sine)

	-- 장 보스 > 클라우드 러시 > 가장 가까운 섬
	local function pick(root: BasePart): string?
		local activeId = requestController.activeId()
		local request = activeId and RequestLogic.find(Requests, activeId)
		if request and request.boss then
			return "Boss"
		end
		if player:GetAttribute("RushRunning") == true then
			return "Rush"
		end
		local island = nearestIsland(root.Position)
		return if island and Audio.Music[island.id] then island.id else nil
	end

	local function switch(target: string?)
		if target == current then
			return
		end
		if current then
			local oldKey = current
			local old = music[oldKey]
			local tween = TweenService:Create(old, fade, { Volume = 0 })
			tween.Completed:Connect(function()
				-- 그사이 다시 고른 곡이면 멈추지 않는다
				if current ~= oldKey then
					old:Pause()
				end
			end)
			tween:Play()
		end
		current = target
		if target then
			local new = music[target]
			if not new.IsPlaying then
				new:Resume()
			end
			TweenService:Create(new, fade, { Volume = Audio.Music[target].volume }):Play()
		end
	end

	task.spawn(function()
		while true do
			local root = hop.rootPart()
			if root then
				local target = pick(root)
				switch(target)
				-- 새소리: 섬 위 낮은 곳에서만, 러시·보스 중에는 끈다
				local volume = 0
				local island, distance = nearestIsland(root.Position)
				if island and (target == island.id) and distance <= island.radius * Audio.BirdsRangeScale then
					local height = root.Position.Y - island.center[2]
					if height > -10 then
						volume = Audio.Birds.volume * math.clamp(1 - height / Audio.BirdsFadeHeight, 0, 1)
					end
				end
				TweenService:Create(birds, TweenInfo.new(CHECK_INTERVAL), { Volume = volume }):Play()
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return Soundscape

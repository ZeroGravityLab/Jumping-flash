-- 점프·퍼펙트(연속 단계)·밟기·착지 연출. 클라이언트 전용.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Movement = require(ReplicatedStorage.Config.Movement)
local AudioGroups = require(script.Parent.AudioGroups)
local MovementLogic = require(ReplicatedStorage.Shared.MovementLogic)

-- Roblox 클라이언트 내장 사운드 (2026-11-02 로컬 content/sounds에서 확인). 전용 사운드는 아트 단계에서 교체
local SOUND_ID = {
	Jump = "rbxasset://sounds/action_jump.mp3",
	Land = "rbxasset://sounds/action_jump_land.mp3",
	Chime = "rbxasset://sounds/volume_slider.ogg",
}
local JUMP_PITCH = { 1, 1.26, 1.5 } -- 도·미·솔
-- 연속 퍼펙트 차임은 장음계로 한 음씩 오른다 (반음 수). 끝에 닿으면 높은 도에 머문다
local SCALE_STEPS = { 0, 2, 4, 5, 7, 9, 11, 12 }
local CHIME_BASE = 1.2
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local AURA_FROM_TIER = 3 -- 이 단계부터 연속이 끊길 때까지 몸에 반짝이가 붙는다

local COLOR = {
	Ring = Color3.fromRGB(255, 255, 255),
	Perfect = Color3.fromRGB(255, 205, 60),
	Shockwave = Color3.fromRGB(230, 240, 255),
}

local BOUNCE_COLOR = {
	stomp = Color3.fromRGB(255, 120, 200),
	pad = Color3.fromRGB(255, 212, 60),
	buddy = Color3.fromRGB(120, 255, 160),
}

local FLAT = CFrame.Angles(0, 0, math.rad(90))

local Effects = {}

local folder: Instance

local function play(name: string, speed: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = SOUND_ID[name]
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.SoundGroup = AudioGroups.sounds()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function ring(position: Vector3, color: Color3, fromSize: number, toSize: number, duration: number)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.2
	part.Size = Vector3.new(0.2, fromSize, fromSize)
	part.CFrame = CFrame.new(position) * FLAT
	part.Parent = folder
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, info, { Size = Vector3.new(0.2, toSize, toSize), Transparency = 1 }):Play()
	Debris:AddItem(part, duration + 0.1)
end

local function tierColor(tier: number): Color3
	local rgb = Movement.PerfectStreakTiers[tier].color
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function sparkleEmitter(color: Color3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	return emitter
end

-- 발밑에서 반짝이가 사방으로 한 번 터진다
local function sparkleBurst(position: Vector3, color: Color3, count: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = folder
	local emitter = sparkleEmitter(color)
	emitter.Parent = anchor
	emitter:Emit(count)
	Debris:AddItem(anchor, 1.2)
end

local function perfectChime(streak: number)
	local step = SCALE_STEPS[math.min(streak, #SCALE_STEPS)]
	play("Chime", CHIME_BASE * 2 ^ (step / 12), 0.6)
end

-- 기본 캐릭터 점프음은 단계별 음으로, 낙하음은 Vertigo의 바람 소리로 대신한다
local MUTED_DEFAULT_SOUNDS = { Jumping = true, FreeFalling = true }

local function muteDefaultJumpSound(character: Model)
	local root = character:WaitForChild("HumanoidRootPart")
	local function mute(child: Instance)
		if child:IsA("Sound") and MUTED_DEFAULT_SOUNDS[child.Name] then
			child.Volume = 0
		end
	end
	for _, child in root:GetChildren() do
		mute(child)
	end
	root.ChildAdded:Connect(mute)
end

function Effects.start(hop)
	folder = hop.localFolder

	local aura: ParticleEmitter? = nil
	local function clearAura()
		if aura then
			aura:Destroy()
			aura = nil
		end
	end
	local function setAura(tier: number)
		local root = hop.rootPart()
		if not root then
			return
		end
		if not aura or aura.Parent ~= root then
			clearAura()
			-- 몸을 감싸고, 날아가면 꼬리처럼 남는다
			aura = sparkleEmitter(tierColor(tier))
			aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) })
			aura.Speed = NumberRange.new(2, 5)
			aura.Drag = 1
			aura.Lifetime = NumberRange.new(0.7, 1.2)
			aura.Parent = root
		end
		aura.Color = ColorSequence.new(tierColor(tier), Color3.new(1, 1, 1))
		aura.Rate = 10 + tier * 10
	end

	hop.onJump:Connect(function(index, perfect, position, streak)
		play("Jump", JUMP_PITCH[index] or 1, 0.5)
		if not perfect then
			if index > 1 then
				ring(position, COLOR.Ring, 2, 9, 0.35)
			end
			return
		end
		-- 연속 단계가 오를수록 링이 커지고, 2단계부터 링이 겹치며 반짝이가 터진다
		local tier = MovementLogic.perfectTier(Movement, streak)
		local color = tierColor(tier)
		ring(position, color, 2, 14 + tier * 2, 0.35)
		if tier >= 2 then
			task.delay(0.08, ring, position, color, 4, 20 + tier * 4, 0.45)
			sparkleBurst(position, color, 6 + tier * 4)
		end
		if tier >= AURA_FROM_TIER then
			setAura(tier)
		end
		perfectChime(streak)
	end)
	hop.onPerfectStreakEnd:Connect(clearAura)

	hop.onBounce:Connect(function(kind, combo, position)
		-- 연쇄할수록 음이 오른다
		play("Jump", 1.5 + math.min(combo, 6) * 0.08, 0.6)
		ring(position, BOUNCE_COLOR[kind] or COLOR.Ring, 3, 12, 0.3)
	end)

	hop.onLand:Connect(function(stomped, position)
		if stomped then
			play("Land", 0.7, 0.8)
			ring(position, COLOR.Shockwave, 3, 22, 0.4)
		end
	end)

	-- 러시에서 밟혀 휘청: 쿵 소리와 머리 위를 도는 별
	hop.onStaggered:Connect(function(seconds)
		play("Land", 0.5, 1)
		local root = hop.rootPart()
		if not root then
			return
		end
		local stars = {}
		for i = 1, 3 do
			local star = Instance.new("Part")
			star.Name = "DizzyStar"
			star.Shape = Enum.PartType.Ball
			star.Anchored = true
			star.CanCollide = false
			star.CanQuery = false
			star.CanTouch = false
			star.CastShadow = false
			star.Material = Enum.Material.Neon
			star.Color = COLOR.Perfect
			star.Size = Vector3.new(0.9, 0.9, 0.9)
			star.Parent = folder
			stars[i] = star
		end
		local started = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			if t > seconds or not root.Parent then
				for _, star in stars do
					star:Destroy()
				end
				connection:Disconnect()
				return
			end
			for i, star in stars do
				local angle = t * 9 + i * math.pi * 2 / 3
				star.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * 1.8, 3.4, math.sin(angle) * 1.8))
			end
		end)
	end)

	hop.onBell:Connect(function(position)
		play("Chime", 0.5, 1)
		ring(position, COLOR.Perfect, 4, 40, 0.8)
	end)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(muteDefaultJumpSound)
	if player.Character then
		task.spawn(muteDefaultJumpSound, player.Character)
	end
end

return Effects

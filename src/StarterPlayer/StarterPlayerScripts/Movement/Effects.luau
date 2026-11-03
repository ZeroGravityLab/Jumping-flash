-- 점프·퍼펙트·밟기·착지 연출. 클라이언트 전용.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

-- Roblox 클라이언트 내장 사운드 (2026-11-02 로컬 content/sounds에서 확인). 전용 사운드는 아트 단계에서 교체
local SOUND_ID = {
	Jump = "rbxasset://sounds/action_jump.mp3",
	Land = "rbxasset://sounds/action_jump_land.mp3",
	Chime = "rbxasset://sounds/volume_slider.ogg",
}
local JUMP_PITCH = { 1, 1.26, 1.5 } -- 도·미·솔

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

-- 기본 캐릭터 점프음을 끄고 단계별 음으로 대신한다
local function muteDefaultJumpSound(character: Model)
	local root = character:WaitForChild("HumanoidRootPart")
	local function mute(child: Instance)
		if child:IsA("Sound") and child.Name == "Jumping" then
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

	hop.onJump:Connect(function(index, perfect, position)
		play("Jump", JUMP_PITCH[index] or 1, 0.5)
		if index > 1 then
			ring(position, if perfect then COLOR.Perfect else COLOR.Ring, 2, if perfect then 16 else 9, 0.35)
		end
		if perfect then
			play("Chime", 1.2, 0.6)
		end
	end)

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

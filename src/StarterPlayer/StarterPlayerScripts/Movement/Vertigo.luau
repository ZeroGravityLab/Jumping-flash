-- 아찔함 연출: 발밑이 깊을수록, 빨리 떨어질수록 바람이 거세지고 시야 가장자리가 어두워지며 바람 줄기가 스친다.
-- 구름을 통과하면 하얗게 가려지고, 섬 가장자리에서 아래를 보면 바람이 분다
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local CameraConfig = require(ReplicatedStorage.Config.Camera)
local Movement = require(ReplicatedStorage.Config.Movement)
local World = require(ReplicatedStorage.Config.World)
local Tags = require(ReplicatedStorage.Shared.Tags)
local AudioGroups = require(script.Parent.AudioGroups)

local player = Players.LocalPlayer

-- Roblox 클라이언트 내장 낙하 바람 소리 (2026-11-02 로컬 content/sounds에서 확인)
local WIND_SOUND = "rbxasset://sounds/action_falling.ogg"
local SMOOTHING = 6

local Vertigo = {
	fall = 0, -- 0~1 낙하 속도
	void = 0, -- 0~1 발밑 깊이
	edge = false, -- 섬 가장자리에서 허공을 보고 있는가
	drop = 0, -- 발밑까지 깊이(studs). 땅이 없으면 구름 바다까지
	intensity = 0,
}

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function edgeFrame(parent: Instance, anchor: Vector2, position: UDim2, size: UDim2, rotation: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = Color3.fromRGB(10, 18, 40)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	-- 바깥쪽만 진하고 안쪽으로 빠르게 사라져, 띠 네 개가 겹쳐도 사각 틀로 보이지 않게
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	frame.Parent = parent
	return frame
end

-- 화면 가장자리 어둠. CanvasGroup의 그룹 투명도는 이 환경에서 반영되지 않아(2026-11-04 확인) 프레임마다 투명도를 준다
local function buildVignette(): { Frame }
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkyhopVertigo"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1
	gui.Parent = player:WaitForChild("PlayerGui")
	return {
		edgeFrame(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.3, 1), 0),
		edgeFrame(gui, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.3, 1), 180),
		edgeFrame(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3), 90),
		edgeFrame(gui, Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.3), 270),
	}
end

-- 카메라 아래에서 위로 솟구치는 바람 줄기. 떨어질수록 많아진다
local function buildSpeedLines(folder: Instance): (BasePart, ParticleEmitter)
	local anchor = Instance.new("Part")
	anchor.Name = "SpeedLines"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(40, 1, 40)
	anchor.Parent = folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(150, 220)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(3, 3)
	emitter.Size = NumberSequence.new(0.18)
	emitter.Squash = NumberSequence.new(-3)
	emitter.LightEmission = 0.5
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
	emitter.Parent = anchor
	return anchor, emitter
end

-- 카메라가 구름 덩어리 안에 있는가 (구름 파트를 타원체로 본다)
local function insideCloud(puffs: { BasePart }, position: Vector3): boolean
	for _, part in puffs do
		local p = part.CFrame:PointToObjectSpace(position)
		local h = part.Size / 2
		if (p.X / h.X) ^ 2 + (p.Y / h.Y) ^ 2 + (p.Z / h.Z) ^ 2 <= 1 then
			return true
		end
	end
	return false
end

function Vertigo.start(hop)
	local wind = Instance.new("Sound")
	wind.Name = "VertigoWind"
	wind.SoundId = WIND_SOUND
	wind.Looped = true
	wind.Volume = 0
	wind.SoundGroup = AudioGroups.sounds()
	wind.Parent = SoundService
	wind:Play()

	local vignette = buildVignette()
	local lineAnchor, lines = buildSpeedLines(hop.localFolder)

	-- 구름 속 하얀 가림. 클라이언트에서만 보이게 카메라 아래에 둔다
	local fog = Instance.new("ColorCorrectionEffect")
	fog.Name = "CloudFog"
	fog.Parent = workspace.CurrentCamera or Lighting

	local puffs = CollectionService:GetTagged(Tags.CloudPuff)
	CollectionService:GetInstanceAddedSignal(Tags.CloudPuff):Connect(function(part)
		table.insert(puffs, part)
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local fogAmount = 0

	RunService.RenderStepped:Connect(function(dt)
		local root = hop.rootPart()
		local camera = workspace.CurrentCamera
		if not (root and camera) then
			return
		end
		params.FilterDescendantsInstances = { hop.character(), hop.localFolder }
		local feet = hop.feetPosition()

		-- 지면 높이에서 쏘면 땅을 놓치므로 조금 위에서 쏜다
		local below = workspace:Raycast(feet + Vector3.new(0, 2, 0), Vector3.new(0, -3000, 0), params)
		Vertigo.drop = math.max(0, if below then feet.Y - below.Position.Y else feet.Y - World.CloudSeaY)

		Vertigo.edge = false
		if hop.isGrounded() then
			local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.01 then
				local ahead = feet + look.Unit * CameraConfig.EdgeProbeDistance + Vector3.new(0, 2, 0)
				Vertigo.edge = workspace:Raycast(ahead, Vector3.new(0, -CameraConfig.VoidMinDepth, 0), params) == nil
			end
		end

		local fallSpeed = -hop.verticalSpeed()
		local fallTarget = clamp01((fallSpeed - 30) / (Movement.TerminalFall - 30))
		local voidTarget = clamp01(
			(Vertigo.drop - CameraConfig.VoidMinDepth) / (CameraConfig.VoidDepthFull - CameraConfig.VoidMinDepth)
		)
		local blend = 1 - math.exp(-SMOOTHING * dt)
		Vertigo.fall += (fallTarget - Vertigo.fall) * blend
		Vertigo.void += (voidTarget - Vertigo.void) * blend
		local edgeTerm = if Vertigo.edge then CameraConfig.EdgeIntensity else 0
		Vertigo.intensity = math.max(Vertigo.fall, Vertigo.void * 0.5, edgeTerm)

		wind.Volume = CameraConfig.WindVolumeMin
			+ (CameraConfig.WindVolumeMax - CameraConfig.WindVolumeMin) * Vertigo.intensity
		wind.PlaybackSpeed = 0.8 + Vertigo.fall * 0.5
		for _, frame in vignette do
			frame.BackgroundTransparency = 1 - Vertigo.intensity * CameraConfig.VignetteMax
		end

		lineAnchor.CFrame = CFrame.new(camera.CFrame.Position - Vector3.new(0, 45, 0))
		lines.Rate = if Vertigo.fall > 0.2 then CameraConfig.SpeedLineRate * Vertigo.fall else 0

		local inCloud = insideCloud(puffs, camera.CFrame.Position)
		fogAmount += ((if inCloud then 1 else 0) - fogAmount) * (1 - math.exp(-8 * dt))
		fog.Brightness = fogAmount * 0.45
		fog.Saturation = -fogAmount * 0.6
	end)
end

return Vertigo

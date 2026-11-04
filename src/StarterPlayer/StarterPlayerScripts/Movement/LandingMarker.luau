-- 착지 예상 지점 링과 발밑 그림자 (GDD 5.4). 클라이언트 전용이라 복제되지 않는다.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraConfig = require(ReplicatedStorage.Config.Camera)
local MovementLogic = require(ReplicatedStorage.Shared.MovementLogic)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)

local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥 축을 세워 원판으로 눕힌다
local MARKER_DIAMETER = 8
local MARKER_TRANSPARENCY = 0.15
local SHADOW_TRANSPARENCY = 0.35

-- 발판이 흰색·하늘색 계열이라 기본 마커는 진한 파랑으로 대비를 준다
local COLOR = {
	Default = Color3.fromRGB(0, 140, 255),
	Stompable = Color3.fromRGB(255, 120, 200),
	BouncePad = Color3.fromRGB(255, 212, 60),
	Buddy = Color3.fromRGB(120, 255, 160),
	Shadow = Color3.fromRGB(20, 30, 50),
}

local LandingMarker = {
	enabled = CameraConfig.MarkerEnabled,
	onToggled = Signal.new(),
}

local function disc(parent: Instance, diameter: number, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, diameter, diameter)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function colorFor(part: BasePart): Color3
	if CollectionService:HasTag(part, Tags.Stompable) then
		return COLOR.Stompable
	elseif CollectionService:HasTag(part, Tags.BouncePad) then
		return COLOR.BouncePad
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and Players:GetPlayerFromCharacter(model) then
		return COLOR.Buddy
	end
	return COLOR.Default
end

local function predictLanding(feet: Vector3, velocity: Vector3, params: RaycastParams): RaycastResult?
	local gravity = workspace.Gravity
	local previous = feet
	local t = 0
	while t < CameraConfig.MarkerPredictSeconds do
		t += CameraConfig.MarkerStep
		local x, y, z = MovementLogic.trajectoryPoint(feet, velocity, gravity, t)
		local point = Vector3.new(x, y, z)
		-- 올라가는 구간은 건너뛴다: 일방향 구름은 아래에서 통과하기 때문
		if point.Y < previous.Y then
			local hit = workspace:Raycast(previous, point - previous, params)
			if hit then
				return hit
			end
		end
		previous = point
	end
	return nil
end

function LandingMarker.start(hop)
	local marker = disc(hop.localFolder, MARKER_DIAMETER, COLOR.Default, Enum.Material.Neon)
	local shadow = disc(hop.localFolder, 4, COLOR.Shadow, Enum.Material.SmoothPlastic)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	RunService.RenderStepped:Connect(function()
		local root = hop.rootPart()
		if not (LandingMarker.enabled and root and not hop.isGrounded()) then
			marker.Transparency = 1
			shadow.Transparency = 1
			return
		end

		params.FilterDescendantsInstances = { hop.character(), hop.localFolder }
		local feet = hop.feetPosition()

		local landing = predictLanding(feet, root.AssemblyLinearVelocity, params)
		if landing then
			marker.Transparency = MARKER_TRANSPARENCY
			marker.Color = colorFor(landing.Instance)
			marker.CFrame = CFrame.new(landing.Position + Vector3.new(0, 0.12, 0)) * FLAT
		else
			marker.Transparency = 1
		end

		local below = workspace:Raycast(feet, Vector3.new(0, -2000, 0), params)
		if below then
			shadow.Transparency = SHADOW_TRANSPARENCY
			shadow.CFrame = CFrame.new(below.Position + Vector3.new(0, 0.08, 0)) * FLAT
		else
			shadow.Transparency = 1
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.L then
			LandingMarker.enabled = not LandingMarker.enabled
			LandingMarker.onToggled:Fire(LandingMarker.enabled)
		end
	end)
end

return LandingMarker

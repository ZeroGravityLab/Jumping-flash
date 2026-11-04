-- 이동 장치: 종, 바운스 꽃, 퍼플링, 구름 계단, 상승 기류 (GDD 8.2~8.3). 허브의 지도 탁자도 여기서 만든다.
-- 태그로 동작을 정하고(HopController가 읽는다) 모양은 파트로 만든다
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Decor = require(script.Parent.Decor)

local Features = {}

local COLOR = {
	Stone = Color3.fromRGB(226, 220, 208),
	StoneDark = Color3.fromRGB(176, 164, 150),
	Bell = Color3.fromRGB(255, 200, 70),
	Stem = Color3.fromRGB(96, 168, 92),
	Petal = Color3.fromRGB(255, 160, 200),
	Cap = Color3.fromRGB(255, 214, 80),
	Cloud = Color3.fromRGB(250, 252, 255),
	Puffling = Color3.fromRGB(255, 246, 252),
	Cheek = Color3.fromRGB(255, 170, 200),
	Eye = Color3.fromRGB(40, 40, 60),
	MapSky = Color3.fromRGB(150, 200, 245),
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function decorative(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- 세로축 원기둥의 회전 (Roblox 원기둥은 X축이 길이 방향)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function groundOrTop(top: Vector3, x: number, z: number): Vector3
	local hit = Decor.groundAt(top.X + x, top.Y, top.Z + z)
	return if hit then hit.Position else Vector3.new(top.X + x, top.Y, top.Z + z)
end

-- 종탑: 돌기둥 위에 황금 종
function Features.Bell(top: Vector3, spec, parent: Instance)
	local base = groundOrTop(top, spec.x, spec.z)
	local model = Instance.new("Model")
	model.Name = "BellTower"
	part({
		Name = "Plinth",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 16, 16),
		CFrame = CFrame.new(base + Vector3.new(0, 1, 0)) * UPRIGHT,
		Color = COLOR.StoneDark,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	part({
		Name = "Pillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(24, 6, 6),
		CFrame = CFrame.new(base + Vector3.new(0, 14, 0)) * UPRIGHT,
		Color = COLOR.Stone,
		Material = Enum.Material.Limestone,
		Parent = model,
	})
	part({
		Name = "Crown",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 12, 12),
		CFrame = CFrame.new(base + Vector3.new(0, 27, 0)) * UPRIGHT,
		Color = COLOR.StoneDark,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local bell = part({
		Name = "Bell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		CFrame = CFrame.new(base + Vector3.new(0, 32, 0)),
		Color = COLOR.Bell,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = COLOR.Bell
	light.Range = 18
	light.Brightness = 1.5
	light.Parent = bell
	CollectionService:AddTag(bell, Tags.Bell)
	model.Parent = parent
end

-- 지도 탁자: 돌 받침 위 하늘빛 원판에 작은 섬들. 말을 걸면 하늘 지도가 열린다 (클라이언트 SkyMap)
function Features.MapTable(top: Vector3, spec, parent: Instance)
	local base = groundOrTop(top, spec.x, spec.z)
	local model = Instance.new("Model")
	model.Name = "MapTable"
	part({
		Name = "Stand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 4, 4),
		CFrame = CFrame.new(base + Vector3.new(0, 1.6, 0)) * UPRIGHT,
		Color = COLOR.StoneDark,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local face = part({
		Name = "Face",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 10, 10),
		CFrame = CFrame.new(base + Vector3.new(0, 3.5, 0)) * UPRIGHT,
		Color = COLOR.MapSky,
		Parent = model,
	})
	-- 허브, 1장 섬, 아직 흐린 섬들
	for _, isle in
		{
			{ 0, 0, 2.2, COLOR.Stem },
			{ 2.8, -0.6, 1.8, COLOR.Stem },
			{ -2.6, -2.2, 1.2, COLOR.StoneDark },
			{ -3.1, 1.6, 1.2, COLOR.StoneDark },
			{ 0.2, 3.4, 1.2, COLOR.StoneDark },
			{ 3.1, 2.4, 1.2, COLOR.StoneDark },
		}
	do
		decorative(part({
			Name = "Isle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(isle[3] * 0.5, isle[3], isle[3]),
			CFrame = CFrame.new(base + Vector3.new(isle[1], 3.8 + isle[3] * 0.25, isle[2])) * UPRIGHT,
			Color = isle[4],
			Material = Enum.Material.Grass,
			Parent = model,
		}))
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "View map" -- 클라이언트가 언어에 맞게 바꾼다
	prompt.ObjectText = "Sky Map"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("SkyMap", true)
	prompt.Parent = face
	model.Parent = parent
end

-- 바운스 꽃: 노란 꽃잎 판을 밟으면 크게 튄다
function Features.BounceFlower(top: Vector3, spec, parent: Instance)
	local base = groundOrTop(top, spec.x, spec.z)
	local model = Instance.new("Model")
	model.Name = "BounceFlower"
	decorative(part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2.4, 2.4),
		CFrame = CFrame.new(base + Vector3.new(0, 3, 0)) * UPRIGHT,
		Color = COLOR.Stem,
		Parent = model,
	}))
	local cap = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 12, 12),
		CFrame = CFrame.new(base + Vector3.new(0, 6.5, 0)) * UPRIGHT,
		Color = COLOR.Cap,
		Parent = model,
	})
	CollectionService:AddTag(cap, Tags.BouncePad)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		decorative(part({
			Name = "Petal",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			CFrame = CFrame.new(base + Vector3.new(math.cos(angle) * 6.5, 6.2, math.sin(angle) * 6.5)),
			Color = COLOR.Petal,
			Parent = model,
		}))
	end
	model.Parent = parent
end

-- 퍼플링: 밟으면 튀어 오르는 구름 덩어리 생물 (충돌 없음, 밟기는 레이캐스트로 판정)
local function puffling(position: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Puffling"
	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 8, 8),
		CFrame = CFrame.new(position),
		Color = COLOR.Puffling,
		CanCollide = false,
		CanTouch = false,
		Parent = model,
	})
	CollectionService:AddTag(body, Tags.Stompable)
	for _, side in { -1, 1 } do
		decorative(part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = CFrame.new(position + Vector3.new(side * 1.5, 0.8, -3.6)),
			Color = COLOR.Eye,
			Parent = model,
		}))
		decorative(part({
			Name = "Cheek",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 0.8, 0.8),
			CFrame = CFrame.new(position + Vector3.new(side * 2.4, -0.6, -3.3)),
			Color = COLOR.Cheek,
			Parent = model,
		}))
	end
	model.Parent = parent
	return body
end

-- 퍼플링 줄: heights는 지면 기준 높이, step은 한 마리 사이 수평 간격
function Features.Pufflings(top: Vector3, spec, parent: Instance)
	local base = groundOrTop(top, spec.x, spec.z)
	for i, height in spec.heights do
		puffling(base + Vector3.new((i - 1) * spec.step, height, 0), parent)
	end
end

-- 일방향 구름 발판: 평평한 원판 하나(Cloud 태그) + 테두리 솜뭉치
local function cloudPlatform(center: Vector3, diameter: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "CloudPlatform"
	local top = part({
		Name = "Top",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, diameter, diameter),
		CFrame = CFrame.new(center) * UPRIGHT,
		Color = COLOR.Cloud,
		Parent = model,
	})
	CollectionService:AddTag(top, Tags.Cloud)
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		local r = diameter * 0.42
		local size = diameter * (0.28 + (i % 3) * 0.05)
		decorative(part({
			Name = "Puff",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.7, size),
			CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * r, -1, math.sin(angle) * r)),
			Color = COLOR.Cloud,
			Parent = model,
		}))
	end
	model.Parent = parent
end

function Features.CloudSteps(top: Vector3, spec, parent: Instance)
	local base = groundOrTop(top, spec.x, spec.z)
	for i = 1, spec.count do
		cloudPlatform(
			base + Vector3.new((i % 2) * 10, spec.rise * i, (i % 3) * 6),
			if i == spec.count then 34 else 26,
			parent
		)
	end
end

-- 상승 기류: 보이지 않는 기둥(Updraft 태그) + 위로 흐르는 바람 입자
function Features.Updraft(top: Vector3, spec, parent: Instance)
	local base = groundOrTop(top, spec.x, spec.z)
	local column = part({
		Name = "Updraft",
		Size = Vector3.new(18, spec.height, 18),
		CFrame = CFrame.new(base + Vector3.new(0, spec.height / 2, 0)),
		Transparency = 1,
		Parent = parent,
	})
	decorative(column)
	CollectionService:AddTag(column, Tags.Updraft)

	local wind = Instance.new("ParticleEmitter")
	wind.Rate = 40
	wind.Lifetime = NumberRange.new(2.5, 4)
	wind.Speed = NumberRange.new(45, 70)
	wind.EmissionDirection = Enum.NormalId.Top
	wind.SpreadAngle = Vector2.new(4, 4)
	wind.Size = NumberSequence.new(0.5)
	wind.Squash = NumberSequence.new(-2.5)
	wind.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	wind.LightEmission = 0.4
	wind.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
	wind.Parent = column
end

return Features

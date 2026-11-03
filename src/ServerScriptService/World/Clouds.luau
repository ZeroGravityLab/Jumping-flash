-- 구름: 섬 아래 멀리 깔린 구름 바다와, 섬 사이를 떠다니는 구름 덩어리.
-- 모양은 무료 구름 메시(Assets/Sky/Cloud, ASSETS.md)를 크기·방향을 바꿔 반복해 쓴다
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local WorldGen = require(ReplicatedStorage.Shared.WorldGen)
local Decor = require(script.Parent.Decor)

local Clouds = {}

-- 대기 안개색(Sky.luau)보다 확실히 밝아야 멀리 아래에서도 구름 바다가 드러난다.
-- 바닥판은 구름 골짜기의 그늘색이다. 뭉게구름보다 어두워야 판이 아니라 구름 무늬로 읽힌다
local CLOUD_COLOR = Color3.fromRGB(255, 255, 255)
local SHADE_COLOR = Color3.fromRGB(244, 247, 255)
local FLOOR_COLOR = Color3.fromRGB(214, 226, 246)
local MAX_PART_SIZE = 2048

local function pass(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- 구름 하나: 폭 width, 납작함 flatten(높이 배율), 색
local function cloud(
	template: Model,
	position: Vector3,
	width: number,
	flatten: number,
	yaw: number,
	color: Color3,
	parent: Instance
): Model
	local model = template:Clone()
	local footprint = template:GetAttribute("Footprint") :: number
	model:ScaleTo(model:GetScale() * width / footprint)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			pass(part)
			part.Color = color
			part.Size = part.Size * Vector3.new(1, flatten, 1)
		end
	end
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0))
	model.Parent = parent
	return model
end

-- 끝없이 펼쳐진 구름 바다. 바닥판이 틈을 메우고 그 위에 구름이 뭉게뭉게 솟는다
function Clouds.sea(config, parent: Instance)
	local template = Decor.template("Sky", "Cloud")
	local folder = Instance.new("Folder")
	folder.Name = "CloudSea"

	local tiles = math.ceil(config.CloudSeaFloorRadius * 2 / MAX_PART_SIZE)
	local start = -config.CloudSeaFloorRadius + MAX_PART_SIZE / 2
	for ix = 0, tiles - 1 do
		for iz = 0, tiles - 1 do
			local floor = Instance.new("Part")
			floor.Name = "Floor"
			floor.Material = Enum.Material.SmoothPlastic
			floor.Color = FLOOR_COLOR
			floor.Size = Vector3.new(MAX_PART_SIZE, 4, MAX_PART_SIZE)
			floor.CFrame = CFrame.new(start + ix * MAX_PART_SIZE, config.CloudSeaY - 30, start + iz * MAX_PART_SIZE)
			pass(floor)
			floor.Parent = folder
		end
	end

	if template then
		local rng = WorldGen.rng(31)
		for _ = 1, config.CloudSeaPuffs do
			local angle = rng:range(0, math.pi * 2)
			local dist = math.sqrt(rng:range(0, config.CloudSeaRadius ^ 2))
			local position =
				Vector3.new(math.cos(angle) * dist, config.CloudSeaY + rng:range(-24, 18), math.sin(angle) * dist)
			local color = if rng:next() < 0.35 then SHADE_COLOR else CLOUD_COLOR
			cloud(template, position, rng:range(170, 420), rng:range(0.45, 0.75), rng:range(0, 360), color, folder)
		end
	end
	folder.Parent = parent
end

-- 섬 사이 구름 덩어리. CloudPuff 태그로 클라이언트가 천천히 흘려보내고, 통과하면 바람 소리를 낸다
function Clouds.puffs(config, parent: Instance)
	local template = Decor.template("Sky", "Cloud")
	if not template then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CloudPuffs"
	local spec = config.CloudPuffs
	local rng = WorldGen.rng(37)
	for i = 1, spec.count do
		local angle = rng:range(0, math.pi * 2)
		local dist = rng:range(spec.minDistance, spec.maxDistance)
		local position = Vector3.new(math.cos(angle) * dist, rng:range(spec.minY, spec.maxY), math.sin(angle) * dist)
		local model =
			cloud(template, position, rng:range(50, 150), rng:range(0.6, 0.9), rng:range(0, 360), CLOUD_COLOR, folder)
		model.Name = "Puff" .. i
		model:SetAttribute("DriftPhase", rng:range(0, math.pi * 2))
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0.08
				CollectionService:AddTag(part, Tags.CloudPuff)
			end
		end
	end
	folder.Parent = parent
end

return Clouds

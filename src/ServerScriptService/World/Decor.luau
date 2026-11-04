-- 무료 에셋(ServerStorage.Assets)을 섬 위에 배치한다. 출처와 정화 방법은 ASSETS.md
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local WorldGen = require(ReplicatedStorage.Shared.WorldGen)

local Decor = {}

local TREE_VARIANTS = { "", "F", "T" }

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

function Decor.assets(): Folder?
	return ServerStorage:FindFirstChild("Assets")
end

function Decor.template(category: string, name: string): Model?
	local assets = Decor.assets()
	local folder = assets and assets:FindFirstChild(category)
	return folder and folder:FindFirstChild(name) :: Model?
end

-- 지형 윗면. 너무 가파른 비탈이면 nil
function Decor.groundAt(x: number, aboveY: number, z: number): RaycastResult?
	local hit = workspace:Raycast(Vector3.new(x, aboveY + 150, z), Vector3.new(0, -500, 0), groundParams)
	if hit and hit.Normal.Y >= 0.7 then
		return hit
	end
	return nil
end

function Decor.place(template: Model, position: Vector3, yaw: number, scale: number, parent: Instance): Model
	local model = template:Clone()
	if scale ~= 1 then
		-- ScaleTo는 제작자가 저장한 원래 크기 기준의 절댓값이라, 지금 배율에 곱해야 한다
		model:ScaleTo(model:GetScale() * scale)
	end
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0))
	model.Parent = parent
	return model
end

local function setPassThrough(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function pick(rng, list)
	return list[1 + math.floor(rng:next() * #list)]
end

export type ScatterSpec = {
	seed: number,
	radius: number,
	plazaRadius: number?,
	treePalette: { number },
	trees: number,
	flowers: number,
	rocks: number,
	treeScale: { number }?,
}

-- 잎이 sky 제외 구역(의뢰 랜턴 등)을 덮는 나무인가
local function shadesSky(x: number, z: number, canopy: number, exclusions: { any }): boolean
	for _, e in exclusions do
		if e.sky and (x - e.x) ^ 2 + (z - e.z) ^ 2 < (e.r + canopy) ^ 2 then
			return true
		end
	end
	return false
end

-- 섬 하나에 나무·꽃·바위를 흩뿌린다. exclusions는 섬 중심 기준 {x, z, r, sky?}
function Decor.scatterIsland(top: Vector3, spec: ScatterSpec, exclusions: { any }, parent: Instance)
	local rng = WorldGen.rng(spec.seed + 500)
	local inner = (spec.plazaRadius or 0) + 8
	local treeScale = spec.treeScale or { 0.65, 1.1 }

	local treePoints = WorldGen.scatter(spec.seed + 1, spec.trees, inner, spec.radius * 0.86, 15, exclusions)
	for _, p in treePoints do
		local name = "Tree_Tree" .. pick(rng, spec.treePalette) .. pick(rng, TREE_VARIANTS)
		local template = Decor.template("Trees", name)
		local yaw, scale = rng:range(0, 360), rng:range(treeScale[1], treeScale[2])
		if
			template and not shadesSky(p.x, p.z, (template:GetAttribute("Footprint") :: number) * scale / 2, exclusions)
		then
			local hit = Decor.groundAt(top.X + p.x, top.Y, top.Z + p.z)
			if hit then
				Decor.place(template, hit.Position - Vector3.new(0, 1, 0), yaw, scale, parent)
			end
		end
	end

	-- 꽃: 작은 꽃 몇 송이를 한 무더기로, 가끔 꽃덤불
	local flowerSmall = Decor.template("Plants", "Flower_Small")
	local flowerBush = Decor.template("Plants", "FlowerBush")
	local flowerPoints = WorldGen.scatter(spec.seed + 2, spec.flowers, inner, spec.radius * 0.9, 7, exclusions)
	for _, p in flowerPoints do
		local useBush = rng:next() < 0.25
		local clusterSize = if useBush then 1 else 3
		for _ = 1, clusterSize do
			local x = top.X + p.x + rng:range(-4, 4)
			local z = top.Z + p.z + rng:range(-4, 4)
			local hit = Decor.groundAt(x, top.Y, z)
			local template = if useBush then flowerBush else flowerSmall
			if hit and template then
				local scale = if useBush then rng:range(0.8, 1.3) else rng:range(1.4, 2.4)
				setPassThrough(Decor.place(template, hit.Position, rng:range(0, 360), scale, parent))
			end
		end
	end

	local rockPoints = WorldGen.scatter(spec.seed + 3, spec.rocks, inner, spec.radius * 0.92, 18, exclusions)
	for _, p in rockPoints do
		local hit = Decor.groundAt(top.X + p.x, top.Y, top.Z + p.z)
		local template = Decor.template("Rocks", "Rock_" .. (1 + math.floor(rng:next() * 6)))
		if hit and template then
			local scale = rng:range(0.7, 1.7)
			local rock =
				Decor.place(template, hit.Position - Vector3.new(0, scale, 0), rng:range(0, 360), scale, parent)
			-- 원본이 눈처럼 하얀 돌이라 따뜻한 돌색으로 칠한다
			local tone = rng:range(0.85, 1)
			for _, part in rock:GetDescendants() do
				if part:IsA("BasePart") then
					part.Color = Color3.fromRGB(176 * tone, 166 * tone, 152 * tone)
				end
			end
		end
	end
end

-- 건물 {이름, x, z, 방향(도), 배율?} (섬 중심 기준)
function Decor.building(top: Vector3, spec: { any }, parent: Instance): Model?
	local name, x, z, yaw, scale = spec[1], spec[2], spec[3], spec[4], spec[5] or 1
	local template = Decor.template("Buildings", name)
	local hit = Decor.groundAt(top.X + x, top.Y, top.Z + z)
	if not (template and hit) then
		warn("[Decor] building skipped:", name)
		return nil
	end
	local model = Decor.place(template, hit.Position - Vector3.new(0, 1, 0), yaw, scale, parent)

	-- 풍차 날개는 클라이언트(Ambience)가 돌린다
	local fan = model:FindFirstChild("Fan", true)
	local house = model:FindFirstChild("House", true)
	if fan and house and fan:IsA("Model") and house:IsA("Model") then
		local fanCenter = fan:GetBoundingBox().Position
		local axis = (fanCenter - house:GetBoundingBox().Position) * Vector3.new(1, 0, 1)
		fan:SetAttribute("SpinCenter", fanCenter)
		fan:SetAttribute("SpinAxis", axis.Unit)
		fan:SetAttribute("SpinSpeed", 0.35)
		CollectionService:AddTag(fan, Tags.Spin)
	end
	return model
end

-- 징검다리 작은 섬 {x, 윗면 y, z, 배율}
function Decor.steppingStone(spec: { number }, index: number, parent: Instance): Model?
	local template = Decor.template("Islets", "Islet_" .. (1 + (index - 1) % 3))
	if not template then
		return nil
	end
	local scale = spec[4]
	local height = (template:GetAttribute("Height") :: number) * scale
	return Decor.place(template, Vector3.new(spec[1], spec[2] - height, spec[3]), index * 47, scale, parent)
end

-- 열기구와 갈매기 떼: 위치만 정하고 움직임은 클라이언트(Ambience)가 맡는다
local GULLS_PER_FLOCK = 6
local GULL_SPACING = 7 -- 템플릿 날개폭(약 4.4)의 배율 1 기준 V자 간격

-- 갈매기 떼: Assets/Sky/Gull(날개 뼈대 WingL1·L2·R1·R2가 있는 스킨 메시, ASSETS.md)을 느슨한 V자로 세운다 (앞이 -Z).
-- 날갯짓·활공·흔들림·기울기는 클라이언트 Ambience가 뼈대와 기준점으로 매 프레임 정한다
local function gullFlock(template: Model, center: Vector3, scale: number, rng, parent: Instance): Model
	local flock = Instance.new("Model")
	flock.Name = "Gulls"
	flock:SetAttribute("Flock", true)
	for i = 1, GULLS_PER_FLOCK do
		local rank = i // 2
		local side = if i % 2 == 0 then -1 else 1
		local offset = if i == 1
			then Vector3.zero
			else Vector3.new(
				side * rank * GULL_SPACING + rng:range(-1.5, 1.5),
				rng:range(-2, 2),
				rank * GULL_SPACING * 0.8 + rng:range(-1.5, 1.5)
			) * scale
		local bird = template:Clone()
		bird:ScaleTo(bird:GetScale() * scale)
		bird:PivotTo(CFrame.new(center + offset))
		bird:SetAttribute("Offset", offset)
		bird:SetAttribute("Phase", rng:range(0, math.pi * 2))
		bird:SetAttribute("Scale", scale)
		bird.Parent = flock
	end
	flock.WorldPivot = CFrame.new(center)
	flock.Parent = parent
	return flock
end

function Decor.skyLife(config, parent: Instance)
	local balloon = Decor.template("Sky", "Balloon")
	local gullTemplate = Decor.template("Sky", "Gull")

	local rng = WorldGen.rng(config.Balloons.seed)
	for _ = 1, config.Balloons.count do
		if not balloon then
			break
		end
		local angle = rng:range(0, math.pi * 2)
		local dist = rng:range(config.Balloons.minDistance, config.Balloons.maxDistance)
		local position = Vector3.new(
			math.cos(angle) * dist,
			rng:range(config.Balloons.minY, config.Balloons.maxY),
			math.sin(angle) * dist
		)
		local model = Decor.place(balloon, position, rng:range(0, 360), rng:range(2.2, 3.2), parent)
		setPassThrough(model)
		model:SetAttribute("DriftPhase", rng:range(0, math.pi * 2))
		CollectionService:AddTag(model, Tags.Drift)
	end

	rng = WorldGen.rng(config.BirdFlocks.seed)
	for _ = 1, config.BirdFlocks.count do
		local angle = rng:range(0, math.pi * 2)
		local dist = rng:range(config.BirdFlocks.minDistance, config.BirdFlocks.maxDistance)
		local center = Vector3.new(
			math.cos(angle) * dist,
			rng:range(config.BirdFlocks.minY, config.BirdFlocks.maxY),
			math.sin(angle) * dist
		)
		if not gullTemplate then
			break
		end
		local model = gullFlock(gullTemplate, center, rng:range(1.6, 2.4), rng, parent)
		model:SetAttribute("OrbitCenter", center)
		model:SetAttribute("OrbitRadius", rng:range(40, 110))
		model:SetAttribute("OrbitSpeed", rng:range(0.08, 0.16) * (if rng:next() < 0.5 then -1 else 1))
		model:SetAttribute("OrbitPhase", rng:range(0, math.pi * 2))
		CollectionService:AddTag(model, Tags.Orbit)
	end
end

return Decor

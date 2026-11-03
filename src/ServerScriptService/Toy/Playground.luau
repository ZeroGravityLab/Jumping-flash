-- 토이 그레이박스 놀이터. 목표 없이 뛰어다니며 이동 감각만 확인한다 (GDD 15장 토이 게이트).
-- 위치·높이는 레벨 배치값이라 Config가 아니라 여기 둔다. W2에 청크 시스템(GDD 8.1)으로 대체한다.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Playground = {}

local COLOR = {
	Plaza = Color3.fromRGB(232, 240, 250),
	PlazaAlt = Color3.fromRGB(200, 216, 238),
	Spawn = Color3.fromRGB(150, 200, 255),
	Step = Color3.fromRGB(214, 228, 246),
	Tower = Color3.fromRGB(196, 214, 238),
	Island = Color3.fromRGB(246, 249, 255),
	Cloud = Color3.fromRGB(255, 255, 255),
	CloudSea = Color3.fromRGB(250, 252, 255),
	BouncePad = Color3.fromRGB(255, 212, 60),
	Updraft = Color3.fromRGB(140, 210, 255),
	Puffling = Color3.fromRGB(255, 236, 250),
	Bell = Color3.fromRGB(255, 196, 40),
	Pole = Color3.fromRGB(120, 136, 160),
}

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- 윗면 높이(top) 기준으로 놓는다
local function platform(parent: Instance, name: string, size: Vector3, x: number, top: number, z: number, color: Color3)
	return newPart(parent, name, size, CFrame.new(x, top - size.Y / 2, z), color)
end

-- 지면(0)에서 top까지 솟은 기둥
local function column(parent: Instance, name: string, width: number, x: number, top: number, z: number, color: Color3)
	return platform(parent, name, Vector3.new(width, top, width), x, top, z, color)
end

local function decoration(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function heightLabel(part: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 44)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 4, 0)
	gui.MaxDistance = 1500
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

local function buildBase(folder: Folder)
	-- 단색 광장은 위에서 내려다볼 때 높이를 가늠할 단서가 없어서 체크무늬 타일로 깐다
	local plazaSize, tile = 400, 40
	for ix = 0, plazaSize / tile - 1 do
		for iz = 0, plazaSize / tile - 1 do
			local x = -plazaSize / 2 + tile * (ix + 0.5)
			local z = -plazaSize / 2 + tile * (iz + 0.5)
			local color = if (ix + iz) % 2 == 0 then COLOR.Plaza else COLOR.PlazaAlt
			platform(folder, "PlazaTile", Vector3.new(tile, 10, tile), x, 0, z, color)
		end
	end

	local sea = newPart(folder, "CloudSea", Vector3.new(4000, 2, 4000), CFrame.new(0, -60, 0), COLOR.CloudSea)
	sea.Transparency = 0.3
	decoration(sea)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 120)
	spawn.Color = COLOR.Spawn
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder
end

-- 스폰 옆 높이 막대: 높이 감각의 기준점
local function buildHeightPole(folder: Folder)
	local x, z = -24, 120
	column(folder, "HeightPole", 2, x, 600, z, COLOR.Pole)
	for height = 50, 600, 50 do
		local band = platform(folder, "Band" .. height, Vector3.new(6, 1, 6), x, height, z, COLOR.Pole)
		if height % 100 == 0 then
			heightLabel(band, height .. " m")
		end
	end
end

-- 1단 → 2단 → 3단 점프를 차례로 익히는 계단
local function buildWarmupSteps(folder: Folder)
	local steps = { { 30, 12, 90 }, { 50, 32, 66 }, { 74, 60, 44 }, { 100, 95, 24 }, { 128, 160, 0 } }
	for index, step in steps do
		platform(folder, "Step" .. index, Vector3.new(16, 4, 16), step[1], step[2], step[3], COLOR.Step)
	end
end

-- 높이 비교용 탑. 150은 2·3단을 모두 퍼펙트로 뛰어야 닿는다 (tests/MovementLogic.spec)
local function buildTowers(folder: Folder)
	for index, height in { 30, 60, 100, 150 } do
		local tower = column(folder, "Tower" .. height, 18, -150, height, 110 - (index - 1) * 55, COLOR.Tower)
		heightLabel(tower, height .. " m")
	end
end

-- 중앙 첨탑을 감아 오르는 섬 나선과 정상의 종
local function buildSpiral(folder: Folder)
	local centerX, centerZ = 0, -110
	local radius, angleStep, rise, count = 70, math.rad(40), 45, 11
	local summitTop = 520

	for index = 1, count do
		local angle = (index - 1) * angleStep
		local x = centerX + math.cos(angle) * radius
		local z = centerZ + math.sin(angle) * radius
		platform(folder, "SpiralIsland" .. index, Vector3.new(16, 3, 16), x, rise * index, z, COLOR.Island)
	end

	column(folder, "Spire", 14, centerX, summitTop - 3, centerZ, COLOR.Tower)
	local summit = platform(folder, "Summit", Vector3.new(30, 3, 30), centerX, summitTop, centerZ, COLOR.Island)
	heightLabel(summit, summitTop .. " m")

	local bell =
		newPart(folder, "SummitBell", Vector3.new(7, 7, 7), CFrame.new(centerX, summitTop + 8, centerZ), COLOR.Bell)
	bell.Shape = Enum.PartType.Ball
	bell.Material = Enum.Material.Neon
	bell.CanCollide = false
	CollectionService:AddTag(bell, Tags.Bell)
end

-- 아래에서 통과하고 위에서 착지하는 구름 사다리
local function buildCloudLadder(folder: Folder)
	local x, z = 150, -40
	for index = 1, 10 do
		local cloud = platform(folder, "Cloud" .. index, Vector3.new(26, 2, 26), x, 35 * index, z, COLOR.Cloud)
		cloud.Transparency = 0.2
		CollectionService:AddTag(cloud, Tags.Cloud)
	end
	platform(folder, "CloudTop", Vector3.new(20, 3, 20), x + 34, 385, z, COLOR.Island)
end

local function bouncePad(folder: Folder, name: string, x: number, top: number, z: number)
	local pad = platform(folder, name, Vector3.new(10, 1, 10), x, top, z, COLOR.BouncePad)
	pad.Material = Enum.Material.Neon
	CollectionService:AddTag(pad, Tags.BouncePad)
end

-- 바운스 패드 → 섬 → 패드 → 높은 정원
local function buildBounceGarden(folder: Folder)
	bouncePad(folder, "PadNearSpawn", 36, 1, 140)
	bouncePad(folder, "PadGround", -70, 1, 150)
	platform(folder, "BounceIsland", Vector3.new(22, 3, 22), -70, 170, 105, COLOR.Island)
	bouncePad(folder, "PadIsland", -70, 171, 105)
	platform(folder, "HighGarden", Vector3.new(22, 3, 22), -70, 330, 60, COLOR.Island)
end

local function puffling(folder: Folder, name: string, x: number, y: number, z: number)
	local ball = newPart(folder, name, Vector3.new(8, 8, 8), CFrame.new(x, y, z), COLOR.Puffling)
	ball.Shape = Enum.PartType.Ball
	-- 옆에서 부딪혀 끼지 않게 충돌은 끄고, 밟기는 레이캐스트로 판정한다
	ball.CanCollide = false
	ball.CanTouch = false
	CollectionService:AddTag(ball, Tags.Stompable)
end

-- 땅에 닿지 않고 밟아 오르는 퍼플링 사슬
local function buildStompChain(folder: Folder)
	for index, offset in { { -58, 10, 195 }, { -42, 14, 195 }, { -26, 18, 195 } } do
		puffling(folder, "PracticePuff" .. index, offset[1], offset[2], offset[3])
	end
	for index = 1, 6 do
		puffling(folder, "ChainPuff" .. index, -10 + 24 * (index - 1), 30 * index, 175)
	end
	platform(folder, "PuffPerch", Vector3.new(16, 3, 16), 140, 215, 175, COLOR.Island)
end

-- 안에 있으면 떠오르는 상승 기류
local function buildUpdraft(folder: Folder)
	local x, z, height = -150, -130, 260
	local updraft = newPart(folder, "Updraft", Vector3.new(16, height, 16), CFrame.new(x, height / 2, z), COLOR.Updraft)
	updraft.Transparency = 0.75
	decoration(updraft)
	CollectionService:AddTag(updraft, Tags.Updraft)
	platform(folder, "WindTop", Vector3.new(18, 3, 18), x + 30, 285, z, COLOR.Island)
end

-- 구름 바다 위에 흩어진 섬. 시드를 고정해 매번 같은 배치
local function buildScatter(folder: Folder)
	local rng = Random.new(20261102)
	for index = 1, 16 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(240, 340)
		local width = rng:NextInteger(14, 26)
		local top = rng:NextInteger(40, 420)
		platform(
			folder,
			"ScatterIsland" .. index,
			Vector3.new(width, 3, width),
			math.cos(angle) * distance,
			top,
			math.sin(angle) * distance,
			COLOR.Island
		)
	end
end

local function setupLighting()
	Lighting.ClockTime = 13
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.2
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(199, 215, 235)
	atmosphere.Haze = 0.5
	atmosphere.Parent = Lighting
end

function Playground.build()
	local existing = workspace:FindFirstChild("Playground")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Playground"

	buildBase(folder)
	buildHeightPole(folder)
	buildWarmupSteps(folder)
	buildTowers(folder)
	buildSpiral(folder)
	buildCloudLadder(folder)
	buildBounceGarden(folder)
	buildStompChain(folder)
	buildUpdraft(folder)
	buildScatter(folder)
	setupLighting()

	folder.Parent = workspace
end

return Playground

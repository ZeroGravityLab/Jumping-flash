-- 월드 조립: Config/World를 읽어 만든다.
-- 1단계 지형을 모두 채우고, 지형 충돌이 반영된 뒤 2단계로 건물·장치·장식을 지면에 올린다
-- (지형을 채운 같은 프레임에는 레이캐스트가 지형을 찾지 못한다. 2026-11-04 플레이테스트에서 확인)
-- 플레이어가 들어오기 전에 끝나야 하므로 Main이 캐릭터 생성을 잠시 막고 호출한다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Requests = require(ReplicatedStorage.Config.Requests)
local World = require(ReplicatedStorage.Config.World)
local WorldGen = require(ReplicatedStorage.Shared.WorldGen)
local Clouds = require(script.Parent.Clouds)
local Decor = require(script.Parent.Decor)
local Features = require(script.Parent.Features)
local IslandTerrain = require(script.Parent.IslandTerrain)
local Residents = require(script.Parent.Residents)
local Sky = require(script.Parent.Sky)

local WorldBuilder = {}

local TERRAIN_SETTLE_TIMEOUT = 5
local REQUEST_SPOT_RADIUS = 8 -- 랜턴 스톰프 판정 반경과 같다

local function vec(a: { number }): Vector3
	return Vector3.new(a[1], a[2], a[3])
end

local function folderIn(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local TREE_CLEAR_HEIGHT = 50 -- 이보다 낮은 공중 지점도 나무 수관에 묻히지 않게 비워 둔다

-- 이 섬 의뢰의 바닥 근처 지점(섬 중심 기준)과 의뢰가 쓰는 위성 섬 번호
local function requestSpots(islandId: string): ({ any }, { [number]: boolean })
	local residentIsland = {}
	for _, resident in Requests.Residents do
		residentIsland[resident.id] = resident.island
	end
	local surface, satellites = {}, {}
	for _, request in Requests.Requests do
		local specs = table.clone(request.points or {})
		if request.target then
			table.insert(specs, request.target)
		end
		for _, spec in specs do
			if (spec.island or residentIsland[request.resident]) ~= islandId then
				continue
			end
			if spec.surface then
				table.insert(surface, { x = spec.surface[1], z = spec.surface[2] })
			elseif spec.air and spec.air[2] < TREE_CLEAR_HEIGHT then
				table.insert(surface, { x = spec.air[1], z = spec.air[3] })
			elseif spec.satellite then
				satellites[spec.satellite[1]] = true
			end
		end
	end
	return surface, satellites
end

-- 건물·장치 자리를 비워 두고 나무를 심기 위한 제외 구역 (섬 중심 기준)
local function exclusionsFor(island, spots: { any }): { any }
	local list = {}
	if (island.plazaRadius or 0) > 0 then
		table.insert(list, { x = 0, z = 0, r = island.plazaRadius + 6 })
	end
	for _, b in island.buildings or {} do
		local template = Decor.template("Buildings", b[1])
		local footprint = if template then (template:GetAttribute("Footprint") :: number) * (b[5] or 1) else 30
		table.insert(list, { x = b[2], z = b[3], r = footprint * 0.6 + 6 })
	end
	for _, f in island.features or {} do
		table.insert(list, { x = f.x, z = f.z, r = 14 })
	end
	-- 의뢰 지점(랜턴·배달지 등)은 나무 잎이 덮지 않게 한다
	for _, spot in spots do
		table.insert(list, { x = spot.x, z = spot.z, r = REQUEST_SPOT_RADIUS, sky = true })
	end
	return list
end

-- 섬 하나의 지형을 채우고, 지면 위에 올릴 작업은 decorate 목록에 미뤄 둔다
local function buildIsland(island, root: Folder, decorate: { () -> () })
	local top = vec(island.center)
	local folder = folderIn(root, island.id)
	local spots, requestSatellites = requestSpots(island.id)
	IslandTerrain.build(top, island.radius, island.depth, island.seed, {
		hills = island.hills,
		plazaRadius = island.plazaRadius,
	})
	table.insert(decorate, function()
		for _, b in island.buildings or {} do
			Decor.building(top, b, folder)
		end
		for _, f in island.features or {} do
			local builder = Features[f.type]
			if builder then
				builder(top, f, folder)
			else
				warn("[WorldBuilder] unknown feature:", f.type)
			end
		end
		Decor.scatterIsland(top, {
			seed = island.seed,
			radius = island.radius,
			plazaRadius = island.plazaRadius,
			treePalette = island.treePalette,
			trees = island.trees,
			flowers = island.flowers,
			rocks = island.rocks,
		}, exclusionsFor(island, spots), folder)
	end)

	-- 섬을 감아 오르는 작은 섬 정원과 꼭대기
	local s = island.satellites
	if s then
		for i, p in WorldGen.spiral(s.count, s.orbit, s.rise, s.startAngle, s.angleStep, top.Y) do
			local satTop = Vector3.new(top.X + p.x, p.y, top.Z + p.z)
			local seed = island.seed * 31 + i
			IslandTerrain.build(satTop, s.radius, s.radius * 2.6, seed)
			-- 의뢰 랜턴이 서는 위성 섬은 가운데를 비우므로 나무가 잎 폭만큼 밀려나 대개 빠진다
			local exclusions = if requestSatellites[i]
				then { { x = 0, z = 0, r = REQUEST_SPOT_RADIUS, sky = true } }
				else {}
			table.insert(decorate, function()
				Decor.scatterIsland(satTop, {
					seed = seed,
					radius = s.radius,
					treePalette = island.treePalette,
					trees = 1,
					flowers = 5,
					rocks = 1,
				}, exclusions, folder)
			end)
		end
	end
	if island.summit then
		local summitTop = Vector3.new(top.X, island.summit.height, top.Z)
		local radius = island.summit.radius
		IslandTerrain.build(summitTop, radius, radius * 3, island.seed * 7, { plazaRadius = 10 })
		table.insert(decorate, function()
			Features.Bell(summitTop, { x = 0, z = 0 }, folder)
			Decor.scatterIsland(summitTop, {
				seed = island.seed * 7,
				radius = radius,
				plazaRadius = 10,
				treePalette = island.treePalette,
				trees = 2,
				flowers = 10,
				rocks = 2,
			}, {}, folder)
		end)
	end
end

-- 멀리 보이는 풍경용 섬. 거리감과 아름다움이 목적이라 장치는 없다
local function buildDistant(root: Folder, decorate: { () -> () })
	local spec = World.DistantIslands
	local folder = folderIn(root, "Distant")
	local rng = WorldGen.rng(spec.seed)
	for i = 1, spec.count do
		local angle = (i / spec.count) * math.pi * 2 + rng:range(-0.15, 0.15)
		local dist = rng:range(spec.minDistance, spec.maxDistance)
		local radius = rng:range(spec.minRadius, spec.maxRadius)
		local top = Vector3.new(math.cos(angle) * dist, rng:range(spec.minY, spec.maxY), math.sin(angle) * dist)
		local seed = spec.seed * 100 + i
		IslandTerrain.build(top, radius, radius * rng:range(1.5, 2.3), seed, { hills = math.floor(radius / 30) })
		local palette = { 1 + math.floor(rng:next() * 10), 1 + math.floor(rng:next() * 10), 1, 3 }
		table.insert(decorate, function()
			Decor.scatterIsland(top, {
				seed = seed,
				radius = radius,
				treePalette = palette,
				trees = math.floor(radius / 9),
				flowers = math.floor(radius / 4),
				rocks = 2,
				treeScale = { 0.8, 1.4 },
			}, {}, folder)
		end)
		task.wait()
	end
end

local function buildSpawn(root: Folder)
	local hub = World.Islands[1]
	local top = vec(hub.center)
	local hit = Decor.groundAt(top.X, top.Y, top.Z + 22)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Size = Vector3.new(10, 1, 10)
	local ground = if hit then hit.Position else top + Vector3.new(0, 0, 22)
	-- 처음 눈에 들어오는 것이 종탑 기둥이 아니라 1장 섬 쪽 하늘이 되게 동쪽을 본다
	spawn.CFrame = CFrame.lookAt(ground + Vector3.new(0, 0.5, 0), ground + Vector3.new(1, 0.5, -0.2))
	spawn.Parent = root
end

-- 지형 충돌이 반영될 때까지 허브 중심을 레이캐스트로 확인한다
local function waitForTerrain()
	local hub = vec(World.Islands[1].center)
	local started = os.clock()
	repeat
		task.wait()
	until Decor.groundAt(hub.X, hub.Y, hub.Z) or os.clock() - started > TERRAIN_SETTLE_TIMEOUT
end

function WorldBuilder.build()
	if not Decor.assets() then
		warn(
			"[WorldBuilder] ServerStorage.Assets가 없습니다. tools/ImportAssets.luau로 에셋을 다시 가져오세요"
		)
	end

	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	workspace.Terrain:Clear()
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = workspace

	Sky.apply()

	local decorate = {}
	for _, island in World.Islands do
		buildIsland(island, root, decorate)
		task.wait()
	end
	buildDistant(root, decorate)
	waitForTerrain()

	for _, job in decorate do
		job()
		task.wait()
	end

	local stones = folderIn(root, "SteppingStones")
	for i, spec in World.SteppingStones do
		Decor.steppingStone(spec, i, stones)
	end
	Clouds.sea(World, root)
	Clouds.puffs(World, root)
	Decor.skyLife(World, folderIn(root, "SkyLife"))
	Residents.build(root)
	buildSpawn(root)
end

return WorldBuilder

-- 주민 이야기 끝 (GDD 6.6): 마지막 의뢰를 처음 끝내면 엔딩 카드가 뜨고 허브가 바뀐다.
-- 진행은 플레이어마다 다르므로 바뀐 모습은 이 클라이언트에만 만든다 (workspace.StoryLocal, 복제되지 않는다).
-- 이미 끝낸 이야기는 접속할 때 연출 없이 바로 세운다
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Requests = require(ReplicatedStorage.Config.Requests)
local World = require(ReplicatedStorage.Config.World)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Tags = require(ReplicatedStorage.Shared.Tags)

local player = Players.LocalPlayer

local COLOR = {
	Wood = Color3.fromRGB(150, 104, 66),
	Bread = Color3.fromRGB(214, 150, 80),
	Bun = Color3.fromRGB(236, 178, 104),
	Icing = Color3.fromRGB(255, 244, 236),
	Stripe = Color3.fromRGB(255, 140, 170),
	StripeLight = Color3.fromRGB(255, 246, 240),
	Sign = Color3.fromRGB(255, 236, 200),
	Ink = Color3.fromRGB(110, 60, 40),
	Smoke = Color3.fromRGB(205, 205, 212),
	Sparkle = Color3.fromRGB(255, 220, 120),
	Stone = Color3.fromRGB(150, 150, 158),
	TowerWhite = Color3.fromRGB(246, 244, 238),
	TowerRed = Color3.fromRGB(214, 70, 64),
	Window = Color3.fromRGB(60, 80, 120),
	Iron = Color3.fromRGB(70, 72, 84),
	Glass = Color3.fromRGB(210, 236, 255),
	Lamp = Color3.fromRGB(255, 230, 150),
	Gold = Color3.fromRGB(255, 200, 80),
	Cloud = Color3.fromRGB(250, 250, 255),
	Sail = Color3.fromRGB(255, 248, 228),
	Hull = Color3.fromRGB(150, 98, 60),
	KitePanel = Color3.fromRGB(255, 252, 244),
}
local RESULT_WAIT = 4.5 -- 결과 창(RequestUi RESULT_SECONDS)이 닫힌 뒤에 엔딩을 띄운다
local APPEAR_SECONDS = 0.8
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local UP = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥 축을 세운다

local Stories = {}

local folder: Folder
local built: { [string]: boolean } = {}
local loaded = false

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function progress(): { [string]: any }
	local raw = player:GetAttribute("RequestProgress")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then decoded else {}
end

local function islandTop(id: string): Vector3
	for _, island in World.Islands do
		if island.id == id then
			return Vector3.new(island.center[1], island.center[2], island.center[3])
		end
	end
	return Vector3.zero
end

-- 섬 기준 {x, z}의 땅 위치
local function ground(islandId: string, spot: { number }): Vector3
	local top = islandTop(islandId)
	local x, z = spot[1], spot[2]
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(top + Vector3.new(x, 120, z), Vector3.new(0, -240, 0), params)
	return if hit then hit.Position else top + Vector3.new(x, 0, z)
end

-- 나타날 때는 투명에서 서서히 보인다 (appear = false면 바로)
local function part(props: { [string]: any }, appear: boolean): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	if appear then
		local final = p.Transparency
		p.Transparency = 1
		TweenService:Create(p, TweenInfo.new(APPEAR_SECONDS, Enum.EasingStyle.Quad), { Transparency = final }):Play()
	end
	p.Parent = folder
	return p
end

local function sparkle(position: Vector3)
	local anchor = part({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(position) }, false)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(COLOR.Sparkle)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(10, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(40)
	task.delay(1.5, anchor.Destroy, anchor)
end

-- 통통 빵: 밟으면 바운스 꽃처럼 튄다 (BouncePad 태그, HopController가 읽는다)
local function bun(position: Vector3, appear: boolean)
	local body = part({
		Name = "Bun",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 3.6, 9),
		Color = COLOR.Bun,
		CanCollide = true,
		CanQuery = true,
		CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0)),
	}, appear)
	CollectionService:AddTag(body, Tags.BouncePad)
	part({
		Name = "Icing",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 1.4, 7),
		Color = COLOR.Icing,
		CFrame = CFrame.new(position + Vector3.new(0, 3.1, 0)),
	}, appear)
end

-- 섬 기준 {x, z}에 가장 가까운 집 모델
local function nearestHouse(islandId: string, spot: { number }): Model?
	local worldFolder = workspace:FindFirstChild("World")
	local island = worldFolder and worldFolder:FindFirstChild(islandId)
	if not island then
		return nil
	end
	local target = islandTop(islandId) + Vector3.new(spot[1], 0, spot[2])
	local best, bestDistance = nil, math.huge
	for _, child in island:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 5) == "House" then
			local p = child:GetPivot().Position
			local d = Vector3.new(p.X - target.X, 0, p.Z - target.Z).Magnitude
			if d < bestDistance then
				best, bestDistance = child, d
			end
		end
	end
	return best
end

local BUILDERS = {}

-- 모모네 빵집: 광장을 보는 빵 가판대와 간판, 빵집 굴뚝 연기, 가판대 옆과 지붕 위 통통 빵
function BUILDERS.Bakery(story, appear: boolean)
	local base = ground(story.island, story.spots.stall)
	local center = islandTop(story.island)
	local facing = CFrame.lookAt(base, Vector3.new(center.X, base.Y, center.Z))
	local function at(x: number, y: number, z: number): CFrame
		return facing * CFrame.new(x, y, z)
	end
	part({
		Name = "Counter",
		Size = Vector3.new(9, 3, 3.5),
		Color = COLOR.Wood,
		Material = Enum.Material.WoodPlanks,
		CanCollide = true,
		CanQuery = true,
		CFrame = at(0, 1.5, 0),
	}, appear)
	for i, x in { -3, -1, 1, 3 } do
		part({
			Name = "Loaf",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.1, 1.2),
			Color = if i % 2 == 0 then COLOR.Bread else COLOR.Bun,
			CFrame = at(x, 3.5, -0.4),
		}, appear)
	end
	for _, x in { -4.2, 4.2 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.4, 7.4, 0.4),
			Color = COLOR.Wood,
			CFrame = at(x, 3.7, 1.5),
		}, appear)
	end
	-- 줄무늬 차양: 뒤가 높고 앞으로 기운다
	for i = 1, 6 do
		part({
			Name = "Awning",
			Size = Vector3.new(1.6, 0.2, 4.6),
			Color = if i % 2 == 0 then COLOR.StripeLight else COLOR.Stripe,
			CFrame = at(-4 + (i - 0.5) * 1.6, 7, -0.4) * CFrame.Angles(math.rad(-16), 0, 0),
		}, appear)
	end
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(7, 1.6, 0.3),
		Color = COLOR.Sign,
		CFrame = at(0, 8.6, 1.6),
	}, appear)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = COLOR.Ink
	text.Text = t("StoryBakerySign")
	text.Parent = surface
	surface.Parent = sign

	bun(ground(story.island, story.spots.bun), appear)

	-- 빵집(모모 뒤 집) 굴뚝 연기와 지붕 위 통통 빵
	local house = nearestHouse(story.island, story.house)
	if house then
		local cframe, size = house:GetBoundingBox()
		local roof = cframe.Position + Vector3.new(0, size.Y / 2, 0)
		local smokeAnchor =
			part({ Name = "Chimney", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(roof) }, false)
		local smoke = Instance.new("Smoke")
		smoke.Color = COLOR.Smoke
		smoke.Opacity = 0.12
		smoke.RiseVelocity = 4
		smoke.Size = 2.5
		smoke.Parent = smokeAnchor
		bun(roof, appear)
	end

	if appear then
		sparkle(at(0, 4, -2).Position)
	end
end

local function with(props: { [string]: any }, extra: { [string]: any }): { [string]: any }
	for key, value in extra do
		props[key] = value
	end
	return props
end
local SOLID = { CanCollide = true, CanQuery = true }

-- 등대 (레아): 줄무늬 탑, 올라설 수 있는 꼭대기 전망대, 도는 불빛, 섬 둘레를 도는 구름배
local TOWER_BANDS = 4
local BAND_HEIGHT = 11
local BEAM_LENGTH = 150
local BEAM_SPIN = 0.7
local SHIPS = { -- 허브 중심 기준 궤도 (Ambience의 Orbit 태그가 움직인다)
	{ radius = 250, height = 20, speed = 0.04, phase = 0 },
	{ radius = 280, height = -30, speed = -0.032, phase = 2.1 },
	{ radius = 265, height = 55, speed = 0.036, phase = 4.2 },
}

-- 장식 모델 안의 파트 (충돌·판정 없음)
local function decorPart(model: Model, props: { [string]: any }, cframe: CFrame, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = cframe
	p.Parent = model
	return p
end

local function cloudShip(spec, hub: Vector3)
	local model = Instance.new("Model")
	model.Name = "CloudShip"
	-- 뱃머리가 -Z
	local hull = decorPart(model, { Size = Vector3.new(5, 2.2, 12), Color = COLOR.Hull }, CFrame.new(0, 1.1, 0))
	decorPart(
		model,
		{ Size = Vector3.new(5, 2.2, 4), Color = COLOR.Hull },
		CFrame.new(0, 1.1, -8) * CFrame.Angles(0, 0, math.pi),
		"WedgePart"
	)
	decorPart(
		model,
		{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 0.5, 0.5), Color = COLOR.Wood },
		CFrame.new(0, 6.5, -1) * UP
	)
	decorPart(model, { Size = Vector3.new(6, 5.5, 0.2), Color = COLOR.Sail }, CFrame.new(0, 7, -1.3))
	decorPart(model, { Size = Vector3.new(1.6, 0.9, 0.08), Color = COLOR.TowerRed }, CFrame.new(0.8, 10.6, -1))
	local lantern = decorPart(
		model,
		{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = COLOR.Lamp, Material = Enum.Material.Neon },
		CFrame.new(0, 3, -9.2)
	)
	local light = Instance.new("PointLight")
	light.Color = COLOR.Lamp
	light.Range = 14
	light.Parent = lantern
	for _, offset in
		{ Vector3.new(-3, -0.5, 4), Vector3.new(3, -0.6, 3), Vector3.new(0, -0.8, -3), Vector3.new(-2, -0.4, -7) }
	do
		decorPart(
			model,
			{ Shape = Enum.PartType.Ball, Size = Vector3.new(7, 4, 7), Color = COLOR.Cloud },
			CFrame.new(offset)
		)
	end
	model.PrimaryPart = hull
	local center = hub + Vector3.new(0, spec.height, 0)
	model:PivotTo(CFrame.new(center + Vector3.new(math.cos(spec.phase), 0, math.sin(spec.phase)) * spec.radius))
	model:SetAttribute("OrbitCenter", center)
	model:SetAttribute("OrbitRadius", spec.radius)
	model:SetAttribute("OrbitSpeed", spec.speed)
	model:SetAttribute("OrbitPhase", spec.phase)
	model.Parent = folder
	CollectionService:AddTag(model, Tags.Orbit)
end

-- 등불에서 양쪽으로 퍼지는 빛줄기 (Ambience의 Spin 태그가 돌린다)
local function lampBeam(position: Vector3)
	local model = Instance.new("Model")
	model.Name = "LighthouseBeam"
	local pivot = decorPart(model, { Transparency = 1, Size = Vector3.one }, CFrame.new(position))
	for _, side in { 1, -1 } do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(side * 1.5, 0, 0)
		a0.Parent = pivot
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(side * BEAM_LENGTH, -8, 0)
		a1.Parent = pivot
		local shaft = Instance.new("Beam")
		shaft.Attachment0 = a0
		shaft.Attachment1 = a1
		shaft.Width0 = 2.5
		shaft.Width1 = 22
		shaft.Color = ColorSequence.new(COLOR.Lamp)
		shaft.LightEmission = 1
		shaft.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		shaft.FaceCamera = true
		shaft.Segments = 1
		shaft.Parent = pivot
	end
	model.PrimaryPart = pivot
	model:SetAttribute("SpinCenter", position)
	model:SetAttribute("SpinAxis", Vector3.yAxis)
	model:SetAttribute("SpinSpeed", BEAM_SPIN)
	model.Parent = folder
	CollectionService:AddTag(model, Tags.Spin)
end

function BUILDERS.Lighthouse(story, appear: boolean)
	local base = ground(story.island, story.spots.tower)
	local hub = islandTop(story.island)
	local facing = CFrame.lookAt(base, Vector3.new(hub.X, base.Y, hub.Z))
	local function at(x: number, y: number, z: number): CFrame
		return facing * CFrame.new(x, y, z)
	end

	part(
		with({
			Name = "Foundation",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 18, 18),
			Color = COLOR.Stone,
			Material = Enum.Material.Slate,
			CFrame = at(0, 0.6, 0) * UP,
		}, SOLID),
		appear
	)
	local y = 1.8
	for i = 1, TOWER_BANDS do
		local diameter = 13 - (i - 1)
		part(
			with({
				Name = "Tower",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(BAND_HEIGHT, diameter, diameter),
				Color = if i % 2 == 1 then COLOR.TowerWhite else COLOR.TowerRed,
				CFrame = at(0, y + BAND_HEIGHT / 2, 0) * UP,
			}, SOLID),
			appear
		)
		if i > 1 then
			part({
				Name = "Window",
				Size = Vector3.new(1.4, 2.2, 0.4),
				Color = COLOR.Window,
				CFrame = at(0, y + BAND_HEIGHT / 2, -diameter / 2 + 0.1),
			}, appear)
		end
		y += BAND_HEIGHT
	end
	part({ Name = "Door", Size = Vector3.new(3, 5, 0.5), Color = COLOR.Ink, CFrame = at(0, 4.3, -6.35) }, appear)

	-- 전망대: 탑보다 넓은 원판. 난간은 장식이라 걸리지 않는다
	part(
		with({
			Name = "Deck",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 21, 21),
			Color = COLOR.Iron,
			CFrame = at(0, y + 0.5, 0) * UP,
		}, SOLID),
		appear
	)
	local deckTop = y + 1
	for k = 1, 16 do
		local a1 = (k - 1) / 16 * math.pi * 2
		local a2 = k / 16 * math.pi * 2
		local p1 = Vector3.new(math.cos(a1) * 10, deckTop, math.sin(a1) * 10)
		local p2 = Vector3.new(math.cos(a2) * 10, deckTop, math.sin(a2) * 10)
		part({
			Name = "Rail",
			Size = Vector3.new(0.25, 2.6, 0.25),
			Color = COLOR.Iron,
			CFrame = at(p1.X, deckTop + 1.3, p1.Z),
		}, appear)
		local lift = Vector3.new(0, 2.6, 0)
		part({
			Name = "Rail",
			Size = Vector3.new(0.2, 0.2, (p2 - p1).Magnitude),
			Color = COLOR.Iron,
			CFrame = facing * CFrame.lookAt((p1 + p2) / 2 + lift, p2 + lift),
		}, appear)
	end
	-- 망원경: 바깥 하늘을 본다
	part({
		Name = "Telescope",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 0.7, 0.7),
		Color = COLOR.Gold,
		CFrame = at(0, deckTop + 2.4, 7) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(20)),
	}, appear)
	part({
		Name = "Telescope",
		Size = Vector3.new(0.3, 2.2, 0.3),
		Color = COLOR.Iron,
		CFrame = at(0, deckTop + 1.1, 7),
	}, appear)

	-- 등실: 유리, 불빛, 빨간 지붕
	part(
		with({
			Name = "LampRoom",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 8, 8),
			Color = COLOR.Glass,
			Material = Enum.Material.Glass,
			Transparency = 0.55,
			CastShadow = false,
			CFrame = at(0, deckTop + 3, 0) * UP,
		}, SOLID),
		appear
	)
	local lamp = part({
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3.6,
		Color = COLOR.Lamp,
		Material = Enum.Material.Neon,
		CFrame = at(0, deckTop + 3, 0),
	}, appear)
	local glow = Instance.new("PointLight")
	glow.Color = COLOR.Lamp
	glow.Range = 60
	glow.Brightness = 3
	glow.Parent = lamp
	part(
		with({
			Name = "Roof",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, 10, 10),
			Color = COLOR.TowerRed,
			CFrame = at(0, deckTop + 6.4, 0) * UP,
		}, SOLID),
		appear
	)
	part(
		with({
			Name = "Roof",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(9, 4, 9),
			Color = COLOR.TowerRed,
			CFrame = at(0, deckTop + 7, 0),
		}, SOLID),
		appear
	)
	part({
		Name = "Finial",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.1,
		Color = COLOR.Gold,
		CFrame = at(0, deckTop + 9.4, 0),
	}, appear)

	lampBeam(lamp.Position)
	for _, spec in SHIPS do
		cloudShip(spec, hub)
	end
	if appear then
		sparkle(lamp.Position)
	end
end

-- 연 축제 (렌): 얼레에서 감아 오르는 연 계단(일방향 발판), 꼭대기 큰 연은 바운스 패드. 광장 둘레에는 날리는 연
local KITE_COLORS = {
	Color3.fromRGB(255, 96, 110),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(255, 226, 90),
	Color3.fromRGB(110, 220, 110),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(170, 110, 240),
}
local KITE_STEPS = 6
local KITE_FIRST = 40 -- 땅에서 첫 연까지 (3단 점프면 약 124까지 오른다)
local KITE_RISE = 36 -- 연 사이 높이 (2단 점프면 약 59)
local KITE_RADIUS = 22
local KITE_START_ANGLE = 200
local KITE_SIZE = 11
local BIG_KITE_SIZE = 16
local FLYING_KITE_STAKE = 38 -- 광장(반경 36) 바로 바깥, 나무를 비운 띠 안
local FLYING_KITES = { -- 말뚝 각도와 연 높이
	{ angle = 30, height = 70 },
	{ angle = 120, height = 86 },
	{ angle = 210, height = 78 },
	{ angle = 300, height = 94 },
}

local function tether(from: Attachment, to: Attachment, parent: Instance)
	local line = Instance.new("Beam")
	line.Attachment0 = from
	line.Attachment1 = to
	line.Width0 = 0.1
	line.Width1 = 0.1
	line.Color = ColorSequence.new(COLOR.KitePanel)
	line.FaceCamera = true
	line.Segments = 1
	line.Parent = parent
end

-- 밟을 수 있는 마름모 연. 윗면이 평평하고, 아래에서는 뚫고 올라간다 (Cloud 태그)
local function stepKite(center: Vector3, size: number, color: Color3, outward: Vector3, appear: boolean): BasePart
	local diamond = CFrame.new(center) * CFrame.Angles(0, math.rad(45), 0)
	local sail = part(
		with({ Name = "Kite", Size = Vector3.new(size, 0.6, size), Color = color, CFrame = diamond }, SOLID),
		appear
	)
	CollectionService:AddTag(sail, Tags.Cloud)
	part({
		Name = "KitePanel",
		Size = Vector3.new(size * 0.5, 0.64, size * 0.5),
		Color = COLOR.KitePanel,
		CFrame = diamond,
	}, appear)
	local span = size * math.sqrt(2)
	local spar = CFrame.new(center + Vector3.new(0, 0.38, 0))
	part({ Name = "Spar", Size = Vector3.new(span, 0.2, 0.3), Color = COLOR.Wood, CFrame = spar }, appear)
	part({ Name = "Spar", Size = Vector3.new(0.3, 0.2, span), Color = COLOR.Wood, CFrame = spar }, appear)
	-- 꼬리 리본: 바깥 꼭짓점에서 늘어진다
	local corner = center + outward * (span / 2)
	for i = 1, 5 do
		local p = corner + outward * (i * 1.1) + Vector3.new(0, -i * 1.7, 0)
		part({
			Name = "Tail",
			Size = Vector3.new(1.3, 0.25, 0.9),
			Color = if i % 2 == 0 then COLOR.KitePanel else color,
			CFrame = CFrame.lookAt(p, p + outward) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 25 else -25)),
		}, appear)
	end
	return sail
end

-- 광장 가장자리 말뚝에 매어 하늘에 띄운 장식 연 (Ambience의 Drift 태그가 흔든다)
local function flyingKite(stake: Vector3, hub: Vector3, spec, index: number, appear: boolean)
	local post = part({
		Name = "Stake",
		Size = Vector3.new(0.6, 2.4, 0.6),
		Color = COLOR.Wood,
		CFrame = CFrame.new(stake + Vector3.new(0, 1.2, 0)),
	}, appear)
	local model = Instance.new("Model")
	model.Name = "FestivalKite"
	local outward = Vector3.new(stake.X - hub.X, 0, stake.Z - hub.Z).Unit
	local high = Vector3.new(0, spec.height, 0)
	local at = CFrame.lookAt(stake + outward * 24 + high, stake + high) * CFrame.Angles(math.rad(-20), 0, 0)
	local color = KITE_COLORS[(index - 1) % #KITE_COLORS + 1]
	local sail =
		decorPart(model, { Size = Vector3.new(6, 6, 0.15), Color = color }, at * CFrame.Angles(0, 0, math.rad(45)))
	decorPart(model, { Size = Vector3.new(3, 3, 0.2), Color = COLOR.KitePanel }, at * CFrame.Angles(0, 0, math.rad(45)))
	for i = 1, 6 do
		decorPart(
			model,
			{ Size = Vector3.new(1, 0.6, 0.1), Color = if i % 2 == 0 then COLOR.KitePanel else color },
			at * CFrame.new(0, -4.2 - i * 1.3, 0)
		)
	end
	model.PrimaryPart = sail
	model:SetAttribute("DriftPhase", index * 1.7)
	local from = Instance.new("Attachment")
	from.Position = Vector3.new(0, 1.2, 0)
	from.Parent = post
	local to = Instance.new("Attachment")
	to.Parent = sail
	tether(from, to, sail)
	model.Parent = folder
	CollectionService:AddTag(model, Tags.Drift)
end

function BUILDERS.Kites(story, appear: boolean)
	local base = ground(story.island, story.spots.hill)
	local reel = part(
		with({
			Name = "ReelPost",
			Size = Vector3.new(1, 5, 1),
			Color = COLOR.Wood,
			CFrame = CFrame.new(base + Vector3.new(0, 2.5, 0)),
		}, SOLID),
		appear
	)
	part({
		Name = "Reel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 2.8, 2.8),
		Color = COLOR.Stripe,
		CFrame = CFrame.new(base + Vector3.new(0, 4.4, 0)),
	}, appear)
	local reelTop = Instance.new("Attachment")
	reelTop.Position = Vector3.new(0, 2.5, 0)
	reelTop.Parent = reel

	-- 얼레 둘레를 60도씩 감아 오르고, 마지막 큰 연은 얼레 바로 위에 뜬다
	for k = 1, KITE_STEPS + 1 do
		local big = k > KITE_STEPS
		local angle = math.rad(KITE_START_ANGLE + (k - 1) * 60)
		local ring = if big then Vector3.zero else Vector3.new(math.cos(angle), 0, math.sin(angle)) * KITE_RADIUS
		local sail = stepKite(
			base + ring + Vector3.new(0, KITE_FIRST + (k - 1) * KITE_RISE, 0),
			if big then BIG_KITE_SIZE else KITE_SIZE,
			if big then COLOR.Stripe else KITE_COLORS[(k - 1) % #KITE_COLORS + 1],
			if big then Vector3.new(0, 0, 1) else ring.Unit,
			appear
		)
		if big then
			CollectionService:AddTag(sail, Tags.BouncePad)
		end
		local knot = Instance.new("Attachment")
		knot.Position = Vector3.new(0, -0.3, 0)
		knot.Parent = sail
		tether(reelTop, knot, sail)
	end

	local hub = islandTop(story.island)
	for index, spec in FLYING_KITES do
		local a = math.rad(spec.angle)
		local stake = ground(story.island, { math.cos(a) * FLYING_KITE_STAKE, math.sin(a) * FLYING_KITE_STAKE })
		flyingKite(stake, hub, spec, index, appear)
	end
	if appear then
		sparkle(base + Vector3.new(0, KITE_FIRST, 0))
	end
end

local RAINBOW = {
	Color3.fromRGB(255, 96, 96),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(255, 230, 90),
	Color3.fromRGB(110, 220, 110),
	Color3.fromRGB(90, 160, 255),
	Color3.fromRGB(170, 110, 240),
}
local RAINBOW_RADIUS = 230
local RAINBOW_SEGMENTS = 24

-- 장 복구 (1장 보스를 이겼다): 되살아난 섬 위에 허브 쪽에서 보이는 무지개. 먹구름이 걷히는 것은 Boss가 맡는다
function BUILDERS.Chapter1(story, appear: boolean)
	local center = islandTop(story.island) + Vector3.new(0, 30, 0)
	for band, color in RAINBOW do
		local radius = RAINBOW_RADIUS - (band - 1) * 6
		for k = 1, RAINBOW_SEGMENTS do
			local a1 = (k - 1) / RAINBOW_SEGMENTS * math.pi
			local a2 = k / RAINBOW_SEGMENTS * math.pi
			local p1 = center + Vector3.new(0, math.sin(a1), math.cos(a1)) * radius
			local p2 = center + Vector3.new(0, math.sin(a2), math.cos(a2)) * radius
			part({
				Name = "Rainbow",
				Size = Vector3.new(1.5, 5.6, (p2 - p1).Magnitude + 0.6),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.45,
				CFrame = CFrame.lookAt((p1 + p2) / 2, p2),
			}, appear)
		end
	end
end

local function refresh(ui, skyMap)
	if type(player:GetAttribute("RequestProgress")) ~= "string" then
		return
	end
	local current = progress()
	for _, story in Requests.Stories do
		if current[story.final] and not built[story.id] and BUILDERS[story.id] then
			built[story.id] = true
			if loaded then
				task.delay(RESULT_WAIT, function()
					BUILDERS[story.id](story, true)
					ui.showStory(story.id, function()
						if story.showAt then
							skyMap.guide(story.showAt)
						elseif story.showSpot then
							skyMap.guideAt(
								ground(story.island, story.spots[story.showSpot]),
								t("StoryPlace_" .. story.id)
							)
						end
					end)
				end)
			else
				BUILDERS[story.id](story, false)
			end
		end
	end
	loaded = true
end

function Stories.start(_hop, ui, skyMap)
	folder = Instance.new("Folder")
	folder.Name = "StoryLocal"
	folder.Parent = workspace
	-- 섬이 다 지어진 뒤에 세운다 (집 위치를 찾아야 한다)
	local worldFolder = workspace:WaitForChild("World")
	for _, story in Requests.Stories do
		worldFolder:WaitForChild(story.island)
	end
	refresh(ui, skyMap)
	player:GetAttributeChangedSignal("RequestProgress"):Connect(function()
		refresh(ui, skyMap)
	end)
end

return Stories

-- 의뢰 유형별 목표 (GDD 6.5): Collect 수집, Beacons 봉화, Rings 고리 다이빙, Delivery 배달, Murk 머크 청소, Race 경주,
-- Boss 장 보스 (GDD 6.3, 썬더헤드).
-- 목표 오브젝트는 이 플레이어에게만 보이게 hop.localFolder에 만든다 (GDD 6.4)
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Config.World)
local Tags = require(ReplicatedStorage.Shared.Tags)
local WorldGen = require(ReplicatedStorage.Shared.WorldGen)

local Objectives = {}

local COLOR = {
	Letter = Color3.fromRGB(255, 250, 235),
	Seal = Color3.fromRGB(230, 90, 90),
	BeaconOff = Color3.fromRGB(120, 130, 150),
	BeaconOn = Color3.fromRGB(255, 196, 70),
	RingNext = Color3.fromRGB(120, 230, 255),
	RingLater = Color3.fromRGB(200, 210, 230),
	RingDone = Color3.fromRGB(140, 255, 160),
	Pot = Color3.fromRGB(214, 120, 80),
	Bloom = Color3.fromRGB(255, 150, 200),
	Sack = Color3.fromRGB(238, 226, 196),
	Twine = Color3.fromRGB(170, 120, 80),
	Target = Color3.fromRGB(140, 255, 160),
	Murk = Color3.fromRGB(92, 74, 118),
	MurkTuft = Color3.fromRGB(116, 96, 142),
	Eye = Color3.fromRGB(255, 255, 255),
	Pupil = Color3.fromRGB(30, 24, 40),
	Poof = Color3.fromRGB(255, 255, 255),
	Pin = Color3.fromRGB(200, 160, 110),
	Knot = Color3.fromRGB(255, 255, 255),
	Kite = Color3.fromRGB(255, 110, 90),
	KiteTrim = Color3.fromRGB(255, 220, 90),
	Spar = Color3.fromRGB(150, 110, 70),
	Finish = Color3.fromRGB(255, 205, 60),
}
local CLOTH_COLORS = {
	Color3.fromRGB(120, 180, 240),
	Color3.fromRGB(255, 170, 190),
	Color3.fromRGB(255, 222, 120),
	Color3.fromRGB(150, 220, 160),
	Color3.fromRGB(250, 250, 250),
}
local COLLECT_RADIUS = 5
local BEACON_RADIUS = 8
local RING_RADIUS = 9
local DELIVERY_RADIUS = 9
local MURK_SIZE = 7
local FINISH_RADIUS = 14 -- 경주 결승점: 수평 반경, 발 높이는 결승점 -3 ~ +14
local KITE_HOVER = 8 -- 연이 결승점 위 이만큼에 닿는다

export type Callbacks = {
	progress: (done: number, total: number) -> (),
	countdown: (seconds: number) -> (), -- 경주: 연이 닿기까지 남은 초
	success: () -> (),
	fail: (reasonKey: string) -> (),
	notice: (key: string) -> (), -- 실패는 아니지만 알려 줄 일
}

local function islandSpec(id: string)
	for _, island in World.Islands do
		if island.id == id then
			return island
		end
	end
	return nil
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- 의뢰 좌표 → 월드 위치 (Config/Requests 맨 위 설명 참고)
function Objectives.resolve(spec, islandId: string, exclude: { Instance }): Vector3?
	local island = islandSpec(spec.island or islandId)
	if not island then
		return nil
	end
	local top = Vector3.new(island.center[1], island.center[2], island.center[3])
	if spec.air then
		return top + Vector3.new(spec.air[1], spec.air[2], spec.air[3])
	elseif spec.surface then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		local origin = top + Vector3.new(spec.surface[1], 400, spec.surface[2])
		local hit = workspace:Raycast(origin, Vector3.new(0, -800, 0), params)
		local base = if hit then hit.Position else top + Vector3.new(spec.surface[1], 0, spec.surface[2])
		return base + Vector3.new(0, spec.surface[3], 0)
	elseif spec.satellite then
		local s = island.satellites
		local points = WorldGen.spiral(s.count, s.orbit, s.rise, s.startAngle, s.angleStep, top.Y)
		local p = points[spec.satellite[1]]
		return Vector3.new(top.X + p.x, p.y + spec.satellite[2], top.Z + p.z)
	end
	return nil
end

local function letter(position: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	part({
		Name = "Paper",
		Size = Vector3.new(3, 0.3, 2.1),
		Color = COLOR.Letter,
		CFrame = CFrame.new(position),
		Parent = model,
	})
	part({
		Name = "Seal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 0.8, 0.8),
		Color = COLOR.Seal,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 240, 200)
	light.Parent = model:FindFirstChild("Paper")
	model.Parent = parent
	return model
end

-- 바람에 날아간 빨래 한 장 (티셔츠 모양)
local function laundry(position: Vector3, parent: Instance, index: number): Model
	local model = Instance.new("Model")
	local color = CLOTH_COLORS[(index - 1) % #CLOTH_COLORS + 1]
	local cloth = part({
		Name = "Cloth",
		Size = Vector3.new(2.6, 3, 0.25),
		Color = color,
		Material = Enum.Material.Fabric,
		CFrame = CFrame.new(position),
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Sleeve",
			Size = Vector3.new(1.3, 1.1, 0.25),
			Color = color,
			Material = Enum.Material.Fabric,
			CFrame = CFrame.new(position + Vector3.new(side * 1.8, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(side * -20)),
			Parent = model,
		})
	end
	part({
		Name = "Pin",
		Size = Vector3.new(0.35, 0.9, 0.5),
		Color = COLOR.Pin,
		CFrame = CFrame.new(position + Vector3.new(0, 1.7, 0)),
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.2
	light.Color = color
	light.Parent = cloth
	model.WorldPivot = CFrame.new(position)
	model.Parent = parent
	return model
end

-- 연 꼬리 리본 (나비 매듭)
local function ribbon(position: Vector3, parent: Instance, index: number): Model
	local model = Instance.new("Model")
	local color = CLOTH_COLORS[(index - 1) % #CLOTH_COLORS + 1]
	local knot = part({
		Name = "Knot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
		Color = COLOR.Knot,
		CFrame = CFrame.new(position),
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Loop",
			Size = Vector3.new(1.8, 1.3, 0.3),
			Color = color,
			Material = Enum.Material.Fabric,
			CFrame = CFrame.new(position + Vector3.new(side * 1.2, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(side * 20)),
			Parent = model,
		})
		part({
			Name = "Tail",
			Size = Vector3.new(0.5, 2.2, 0.2),
			Color = color,
			Material = Enum.Material.Fabric,
			CFrame = CFrame.new(position + Vector3.new(side * 0.6, -1.3, 0)) * CFrame.Angles(0, 0, math.rad(side * 18)),
			Parent = model,
		})
	end
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.2
	light.Color = color
	light.Parent = knot
	model.WorldPivot = CFrame.new(position)
	model.Parent = parent
	return model
end

local COLLECT_ITEMS = {
	Letter = function(position: Vector3, parent: Instance, _: number): Model
		return letter(position, parent)
	end,
	Laundry = laundry,
	Ribbon = ribbon,
}

-- 경주 상대인 연. 원점 기준(앞면이 -Z)으로 만들고 꼬리는 Trail로 그린다
local function kite(parent: Instance): Model
	local model = Instance.new("Model")
	local sail = part({
		Name = "Sail",
		Size = Vector3.new(6, 6, 0.2),
		Color = COLOR.Kite,
		CFrame = CFrame.Angles(0, 0, math.rad(45)),
		Parent = model,
	})
	part({
		Name = "Trim",
		Size = Vector3.new(2.6, 2.6, 0.2),
		Color = COLOR.KiteTrim,
		CFrame = CFrame.new(0, 0, -0.15) * CFrame.Angles(0, 0, math.rad(45)),
		Parent = model,
	})
	local spine = part({
		Name = "Spar",
		Size = Vector3.new(0.25, 8.5, 0.25),
		Color = COLOR.Spar,
		CFrame = CFrame.new(0, 0, 0.2),
		Parent = model,
	})
	part({
		Name = "Spar",
		Size = Vector3.new(8.5, 0.25, 0.25),
		Color = COLOR.Spar,
		CFrame = CFrame.new(0, 0, 0.2),
		Parent = model,
	})
	-- 꼬리는 아래 꼭짓점에서 나온다 (두 어태치먼트 간격이 꼬리 폭)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, -3.9, 0)
	top.Parent = spine
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -4.7, 0)
	bottom.Parent = spine
	local tail = Instance.new("Trail")
	tail.Attachment0 = top
	tail.Attachment1 = bottom
	tail.Color = ColorSequence.new(COLOR.KiteTrim, COLOR.Kite)
	tail.Transparency = NumberSequence.new(0, 1)
	tail.Lifetime = 0.9
	tail.FaceCamera = true
	tail.LightEmission = 0.4
	tail.Parent = sail
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.5
	light.Color = COLOR.KiteTrim
	light.Parent = sail
	model.WorldPivot = CFrame.new()
	model.Parent = parent
	return model
end

-- 배달 물건. 원점 기준으로 만들어 머리 위로 옮긴다. fail은 밟았을 때 보여 줄 문자열 키
local function carriedPot(parent: Instance): Model
	local model = Instance.new("Model")
	part({
		Name = "Pot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 2.4, 2.4),
		Color = COLOR.Pot,
		CFrame = CFrame.Angles(0, 0, math.rad(90)),
		Parent = model,
	})
	part({
		Name = "Bloom",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 2.6, 2.6),
		Color = COLOR.Bloom,
		CFrame = CFrame.new(0, 1.6, 0),
		Parent = model,
	})
	model.WorldPivot = CFrame.new()
	model.Parent = parent
	return model
end

local function carriedFlour(parent: Instance): Model
	local model = Instance.new("Model")
	part({
		Name = "Sack",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.2, 3.2, 3.2),
		Color = COLOR.Sack,
		CFrame = CFrame.new(0, 0.6, 0),
		Parent = model,
	})
	part({
		Name = "Neck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 1.3, 1.3),
		Color = COLOR.Sack,
		CFrame = CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = model,
	})
	part({
		Name = "Twine",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1.5, 1.5),
		Color = COLOR.Twine,
		CFrame = CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = model,
	})
	model.WorldPivot = CFrame.new()
	model.Parent = parent
	return model
end

local CARRIED = {
	Pot = { build = carriedPot, fail = "FailBroke" },
	Flour = { build = carriedFlour, fail = "FailBurst" },
}

-- 머크 덩어리. 몸통만 밟기 판정(Stompable)에 잡히고 장식은 빠진다
local function murk(position: Vector3, parent: Instance): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Murk"
	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * MURK_SIZE,
		Color = COLOR.Murk,
		Material = Enum.Material.Sand,
		CanQuery = true,
		CFrame = CFrame.new(position),
		Parent = model,
	})
	CollectionService:AddTag(body, Tags.Stompable)
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		part({
			Name = "Tuft",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3.4,
			Color = COLOR.MurkTuft,
			Material = Enum.Material.Sand,
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 3, -1.2, math.sin(angle) * 3)),
			Parent = model,
		})
	end
	for _, side in { -1, 1 } do
		part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.5,
			Color = COLOR.Eye,
			CFrame = CFrame.new(position + Vector3.new(side * 1.2, 0.8, -3)),
			Parent = model,
		})
		part({
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7,
			Color = COLOR.Pupil,
			CFrame = CFrame.new(position + Vector3.new(side * 1.1, 0.7, -3.6)),
			Parent = model,
		})
	end
	model.WorldPivot = CFrame.new(position)
	model.Parent = parent
	return model, body
end

-- 머크가 "퐁" 하고 구름으로 흩어진다 (GDD 6.1)
local STORM = {
	Dark = Color3.fromRGB(66, 68, 88),
	Mid = Color3.fromRGB(96, 98, 122),
	Eye = Color3.fromRGB(255, 230, 90),
	Brow = Color3.fromRGB(36, 36, 50),
	Ledge = Color3.fromRGB(150, 152, 178),
	Rod = Color3.fromRGB(255, 205, 70),
	RodSpent = Color3.fromRGB(90, 90, 100),
	Bolt = Color3.fromRGB(255, 250, 200),
	Warn = Color3.fromRGB(255, 220, 80),
}
local THUNDER_SOUND = "rbxasset://sounds/impact_explosion_03.mp3"
local ZAP_EVERY = 2.4 -- 번개 사이 간격(초)
local ZAP_WARNING = 1.1 -- 떨어질 자리가 먼저 빛나는 시간
local ZAP_RADIUS = 7
local ROD_RADIUS = 8

local function thunder(speed: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = THUNDER_SOUND
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- 썬더헤드 몸통: 먹구름 덩어리와 성난 얼굴(허브 쪽 -X를 본다). 지나갈 수 있고 밟기 판정에도 걸리지 않는다
function Objectives.stormBody(center: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Thunderhead"
	local random = Random.new(13)
	for i = 1, 20 do
		local offset = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-0.6, 0.8), random:NextNumber(-1, 1))
		local size = random:NextNumber(30, 48)
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.8, size),
			Color = STORM.Dark:Lerp(STORM.Mid, (i % 5) / 4),
			CFrame = CFrame.new(center + offset.Unit * random:NextNumber(4, 30)),
			Parent = model,
		})
	end
	-- 얼굴: 노란 눈, 찌푸린 눈썹
	for _, side in { -1, 1 } do
		local eye = center + Vector3.new(-38, 8, side * 13)
		part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 9, 7),
			Color = STORM.Eye,
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(eye),
			Parent = model,
		})
		part({
			Name = "Brow",
			Size = Vector3.new(2, 2.2, 12),
			Color = STORM.Brow,
			CFrame = CFrame.new(eye + Vector3.new(-2.5, 7, -side * 1.5)) * CFrame.Angles(math.rad(side * 24), 0, 0),
			Parent = model,
		})
	end
	part({
		Name = "Frown",
		Size = Vector3.new(2, 2.4, 18),
		Color = STORM.Brow,
		CFrame = CFrame.new(center + Vector3.new(-39, -10, 0)),
		Parent = model,
	})
	-- 몸속에서 번쩍이는 빛
	local core =
		part({ Name = "Core", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(center), Parent = model })
	local light = Instance.new("PointLight")
	light.Color = STORM.Bolt
	light.Range = 60
	light.Brightness = 0
	light.Parent = core
	TweenService
		:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.InOut, -1, true, 1.8), {
			Brightness = 6,
		})
		:Play()
	model.WorldPivot = CFrame.new(center)
	model.Parent = parent
	return model
end

-- 먹구름이 흩어진다 (보스를 이겼을 때)
function Objectives.dispelStorm(model: Model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Quad), {
				Transparency = 1,
				Size = p.Size * 1.6,
			}):Play()
		end
	end
	task.delay(1.5, model.Destroy, model)
end

local function poof(position: Vector3, parent: Instance)
	local cloud = part({
		Name = "Poof",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * MURK_SIZE,
		Color = COLOR.Poof,
		Transparency = 0.2,
		CFrame = CFrame.new(position),
		Parent = parent,
	})
	TweenService:Create(cloud, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * MURK_SIZE * 2.4,
		Transparency = 1,
	}):Play()
	task.delay(0.45, cloud.Destroy, cloud)
end

local function beacon(position: Vector3, parent: Instance): BasePart
	part({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 9, 9),
		Color = Color3.fromRGB(150, 140, 130),
		Material = Enum.Material.Slate,
		CanCollide = true,
		CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = parent,
	})
	return part({
		Name = "Flame",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Color = COLOR.BeaconOff,
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0)),
		Parent = parent,
	})
end

local function ring(center: Vector3, parent: Instance): { BasePart }
	local segments = {}
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		table.insert(
			segments,
			part({
				Name = "Hoop",
				Size = Vector3.new(1, 1, RING_RADIUS * 0.42),
				Color = COLOR.RingLater,
				Material = Enum.Material.Neon,
				CFrame = CFrame.new(
					center + Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
				) * CFrame.Angles(0, -angle, 0),
				Parent = parent,
			})
		)
	end
	return segments
end

local function paint(parts: { BasePart }, color: Color3)
	for _, p in parts do
		p.Color = color
	end
end

-- 목표 하나를 실행한다. 돌려준 함수를 부르면 정리한다
function Objectives.run(request, islandId: string, hop, callbacks: Callbacks): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "Request_" .. request.id
	folder.Parent = hop.localFolder
	-- 밟을 수 있는 목표는 밟기 판정이 localFolder를 건너뛰므로 따로 둔다 (역시 복제되지 않는다)
	local solid = Instance.new("Folder")
	solid.Name = "RequestSolid_" .. request.id
	solid.Parent = workspace
	local exclude = { hop.character(), hop.localFolder, solid }
	local connections = {}
	local finished = false

	local function cleanup()
		finished = true
		for _, c in connections do
			c:Disconnect()
		end
		folder:Destroy()
		solid:Destroy()
	end
	local function finish(ok: boolean, reason: string?)
		if finished then
			return
		end
		cleanup()
		if ok then
			callbacks.success()
		else
			callbacks.fail(reason or "FailServer")
		end
	end
	table.insert(
		connections,
		hop.onRespawn:Connect(function()
			finish(false, "FailFell")
		end)
	)

	if request.type == "Collect" then
		local build = COLLECT_ITEMS[request.item or "Letter"]
		local items = {}
		for i, spec in request.points do
			local position = Objectives.resolve(spec, islandId, exclude)
			if position then
				table.insert(items, { model = build(position, folder, i), position = position })
			end
		end
		local total, done = #items, 0
		callbacks.progress(0, total)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				local root = hop.rootPart()
				if not root then
					return
				end
				local t = os.clock()
				for _, item in items do
					if not item.done then
						item.model:PivotTo(
							CFrame.new(item.position + Vector3.new(0, math.sin(t * 2) * 0.6, 0))
								* CFrame.Angles(0, t, 0)
						)
						if (root.Position - item.position).Magnitude <= COLLECT_RADIUS + 2 then
							item.done = true
							item.model:Destroy()
							done += 1
							callbacks.progress(done, total)
							if done == total then
								finish(true)
							end
						end
					end
				end
			end)
		)
	elseif request.type == "Beacons" then
		local beacons = {}
		for _, spec in request.points do
			local position = Objectives.resolve(spec, islandId, exclude)
			if position then
				table.insert(beacons, { flame = beacon(position, folder), position = position })
			end
		end
		local total, done = #beacons, 0
		callbacks.progress(0, total)
		-- 스톰프로 내려앉아야 켜진다
		table.insert(
			connections,
			hop.onLand:Connect(function(stomped, feet)
				if not stomped then
					return
				end
				for _, b in beacons do
					local flat = Vector3.new(feet.X - b.position.X, 0, feet.Z - b.position.Z).Magnitude
					if not b.lit and flat <= BEACON_RADIUS and math.abs(feet.Y - b.position.Y) <= 6 then
						b.lit = true
						b.flame.Color = COLOR.BeaconOn
						b.flame.Material = Enum.Material.Neon
						local light = Instance.new("PointLight")
						light.Color = COLOR.BeaconOn
						light.Range = 20
						light.Brightness = 2
						light.Parent = b.flame
						done += 1
						callbacks.progress(done, total)
						if done == total then
							task.delay(0.4, finish, true)
						end
					end
				end
			end)
		)
	elseif request.type == "Rings" then
		local rings = {}
		for _, spec in request.points do
			local center = Objectives.resolve(spec, islandId, exclude)
			if center then
				table.insert(rings, { center = center, parts = ring(center, folder) })
			end
		end
		local total, nextIndex = #rings, 1
		paint(rings[1].parts, COLOR.RingNext)
		callbacks.progress(0, total)
		local previous: Vector3? = nil
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				local root = hop.rootPart()
				if not root then
					return
				end
				local now = root.Position
				local target = rings[nextIndex]
				-- 지난 프레임과 이번 프레임 사이에 고리 평면을 아래로 지나갔는가
				if target and previous and previous.Y >= target.center.Y and now.Y < target.center.Y then
					local t = (previous.Y - target.center.Y) / math.max(previous.Y - now.Y, 1e-3)
					local crossing = previous:Lerp(now, t)
					local flat = Vector3.new(crossing.X - target.center.X, 0, crossing.Z - target.center.Z).Magnitude
					if flat <= RING_RADIUS then
						paint(target.parts, COLOR.RingDone)
						callbacks.progress(nextIndex, total)
						nextIndex += 1
						if nextIndex > total then
							finish(true)
							return
						end
						paint(rings[nextIndex].parts, COLOR.RingNext)
					elseif nextIndex > 1 then
						finish(false, "FailMissed")
						return
					end
				end
				previous = now
			end)
		)
		-- 첫 고리를 지난 뒤 땅에 내려앉으면 놓친 것
		table.insert(
			connections,
			hop.onLand:Connect(function()
				if nextIndex > 1 then
					finish(false, "FailMissed")
				end
			end)
		)
	elseif request.type == "Delivery" then
		local target = Objectives.resolve(request.target, islandId, exclude)
		local carried = CARRIED[request.item or "Pot"]
		local load = carried.build(folder)
		-- 멀리서도 배달지가 보이게 빛기둥을 세운다
		part({
			Name = "Pillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(90, 3, 3),
			Color = COLOR.Target,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CFrame = CFrame.new(target + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = folder,
		})
		local marker = part({
			Name = "Target",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, DELIVERY_RADIUS * 2, DELIVERY_RADIUS * 2),
			Color = COLOR.Target,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CFrame = CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = folder,
		})
		TweenService:Create(marker, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.75,
		}):Play()
		callbacks.progress(0, 1)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				local root = hop.rootPart()
				if not root then
					return
				end
				load:PivotTo(CFrame.new(root.Position + Vector3.new(0, 4.2, 0)))
				if (hop.feetPosition() - target).Magnitude <= DELIVERY_RADIUS then
					callbacks.progress(1, 1)
					finish(true)
				end
			end)
		)
		table.insert(
			connections,
			hop.onLand:Connect(function(stomped)
				if stomped then
					finish(false, carried.fail)
				end
			end)
		)
		table.insert(
			connections,
			hop.onBounce:Connect(function(kind)
				if kind == "stomp" or kind == "buddy" then
					finish(false, carried.fail)
				end
			end)
		)
	elseif request.type == "Murk" then
		local blobs = {}
		for _, spec in request.points do
			local position = Objectives.resolve(spec, islandId, exclude)
			if position then
				local model, body = murk(position, solid)
				table.insert(blobs, { position = position, model = model, body = body })
			end
		end
		local total, done = #blobs, 0
		callbacks.progress(0, total)
		-- 둥실거리며 카메라 쪽을 바라본다
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				local t = os.clock()
				local eye = workspace.CurrentCamera.CFrame.Position
				for i, b in blobs do
					if not b.popped then
						local p = b.position + Vector3.new(0, math.sin(t * 1.6 + i) * 0.8, 0)
						local facing = Vector3.new(eye.X, p.Y, eye.Z)
						b.model:PivotTo(
							if (facing - p).Magnitude > 0.1 then CFrame.lookAt(p, facing) else CFrame.new(p)
						)
					end
				end
			end)
		)
		table.insert(
			connections,
			hop.onBounce:Connect(function(_, _, _, hitPart)
				for _, b in blobs do
					if not b.popped and b.body == hitPart then
						b.popped = true
						poof(b.position, folder)
						b.model:Destroy()
						done += 1
						callbacks.progress(done, total)
						if done == total then
							finish(true)
						end
						return
					end
				end
			end)
		)
		-- 땅(지붕 포함)에 내려앉으면 터뜨린 머크가 모두 다시 뭉친다
		table.insert(
			connections,
			hop.onLand:Connect(function()
				if done == 0 or done == total then
					return
				end
				for _, b in blobs do
					if b.popped then
						b.popped = false
						b.model, b.body = murk(b.position, solid)
					end
				end
				done = 0
				callbacks.progress(0, total)
				callbacks.notice("MurkRegrow")
			end)
		)
	elseif request.type == "Race" then
		local goal = Objectives.resolve(request.target, islandId, exclude)
		local root = hop.rootPart()
		-- 연은 플레이어 머리 위에서 출발해 points를 지나 결승점 위로 간다
		local path = { (if root then root.Position else goal) + Vector3.new(0, 10, 0) }
		for _, spec in request.points do
			local p = Objectives.resolve(spec, islandId, exclude)
			if p then
				table.insert(path, p)
			end
		end
		table.insert(path, goal + Vector3.new(0, KITE_HOVER, 0))
		local reach = { 0 } -- 출발점에서 각 지점까지의 경로 길이
		for i = 2, #path do
			reach[i] = reach[i - 1] + (path[i] - path[i - 1]).Magnitude
		end
		local length = reach[#path]

		part({
			Name = "Pillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(120, 3, 3),
			Color = COLOR.Finish,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CFrame = CFrame.new(goal + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = folder,
		})
		paint(ring(goal + Vector3.new(0, 1, 0), folder), COLOR.Finish)
		local flyer = kite(folder)
		local startedAt = os.clock()
		local shown = -1
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				local elapsed = os.clock() - startedAt
				if hop.rootPart() then
					local feet = hop.feetPosition()
					local flat = Vector3.new(feet.X - goal.X, 0, feet.Z - goal.Z).Magnitude
					if flat <= FINISH_RADIUS and feet.Y >= goal.Y - 3 and feet.Y <= goal.Y + 14 then
						finish(true)
						return
					end
				end
				if elapsed >= request.kiteTime then
					finish(false, "FailKiteWon")
					return
				end
				local remaining = math.ceil(request.kiteTime - elapsed)
				if remaining ~= shown then
					shown = remaining
					callbacks.countdown(remaining)
				end

				local distance = elapsed / request.kiteTime * length
				local i = 2
				while i < #path and reach[i] < distance do
					i += 1
				end
				local from, to = path[i - 1], path[i]
				local span = reach[i] - reach[i - 1]
				local alpha = if span > 0 then math.clamp((distance - reach[i - 1]) / span, 0, 1) else 1
				local position = from:Lerp(to, alpha) + Vector3.new(0, math.sin(elapsed * 2.5) * 1.2, 0)
				local heading = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
				if heading.Magnitude < 1e-3 then
					heading = Vector3.new(0, 0, -1)
				end
				-- 앞면이 뒤따라오는 플레이어 쪽을 보고, 바람에 흔들린다
				flyer:PivotTo(
					CFrame.lookAt(position, position - heading)
						* CFrame.Angles(math.rad(-20), 0, math.sin(elapsed * 3) * 0.25)
				)
			end)
		)
	elseif request.type == "Boss" then
		-- 썬더헤드: 먹구름을 감아 오르는 일방향 구름 발판, 꼭대기 피뢰침을 스톰프로 내려앉아 끈다. 오르는 동안 번개
		local center = Objectives.resolve(request.center, islandId, exclude)
		local island = islandSpec(islandId)
		local fallY = island.center[2] + request.fallBelow
		local body = Objectives.stormBody(center, folder)

		local function ledge(top: Vector3, diameter: number): BasePart
			local p = part({
				Name = "StormLedge",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(3, diameter, diameter),
				Color = STORM.Ledge,
				CanCollide = true,
				CanQuery = true,
				CFrame = CFrame.new(top - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Parent = solid,
			})
			CollectionService:AddTag(p, Tags.Cloud)
			return p
		end
		for _, spec in request.points do
			local top = Objectives.resolve(spec, islandId, exclude)
			if top then
				ledge(top, 18)
			end
		end
		local rods = {}
		for _, spec in request.rods do
			local top = Objectives.resolve(spec, islandId, exclude)
			if top then
				ledge(top, 14)
				local rod = part({
					Name = "Rod",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(10, 1.2, 1.2),
					Color = STORM.Rod,
					Material = Enum.Material.Neon,
					CFrame = CFrame.new(top + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Parent = folder,
				})
				local tip = part({
					Name = "RodTip",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(2.2, 2.2, 2.2),
					Color = STORM.Rod,
					Material = Enum.Material.Neon,
					CFrame = CFrame.new(top + Vector3.new(0, 10.5, 0)),
					Parent = folder,
				})
				local light = Instance.new("PointLight")
				light.Color = STORM.Rod
				light.Range = 18
				light.Brightness = 2
				light.Parent = tip
				table.insert(rods, { top = top, parts = { rod, tip }, light = light })
			end
		end
		local total, done = #rods, 0
		callbacks.progress(0, total)

		-- 피뢰침 발판에 스톰프로 내려앉으면 그 피뢰침이 꺼진다
		table.insert(
			connections,
			hop.onLand:Connect(function(stomped, feet)
				if not stomped then
					return
				end
				for _, rod in rods do
					local flat = Vector3.new(feet.X - rod.top.X, 0, feet.Z - rod.top.Z).Magnitude
					if not rod.spent and flat <= ROD_RADIUS and math.abs(feet.Y - rod.top.Y) <= 6 then
						rod.spent = true
						paint(rod.parts, STORM.RodSpent)
						for _, p in rod.parts do
							p.Material = Enum.Material.SmoothPlastic
						end
						rod.light:Destroy()
						poof(rod.top + Vector3.new(0, 6, 0), folder)
						thunder(0.8, 0.5)
						done += 1
						callbacks.progress(done, total)
						if done == total then
							Objectives.dispelStorm(body)
							thunder(0.45, 0.8)
							task.delay(1.2, finish, true)
						end
					end
				end
			end)
		)

		-- 정상 아래로 떨어지면 실패
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				if hop.rootPart() and hop.feetPosition().Y < fallY then
					finish(false, "FailStorm")
				end
			end)
		)

		-- 번개: 플레이어 발밑 근처가 먼저 빛나고, 잠시 뒤 내리친다. 맞으면 휘청하며 튕겨 나간다
		local random = Random.new()
		task.spawn(function()
			while not finished do
				task.wait(ZAP_EVERY)
				if finished or done == total or not hop.rootPart() then
					continue
				end
				local feet = hop.feetPosition()
				if feet.Y < center.Y - 130 then
					continue -- 아직 정상에 있다
				end
				local angle = random:NextNumber(0, math.pi * 2)
				local spot = feet + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(0, 5)
				local warning = part({
					Name = "ZapWarning",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.3, ZAP_RADIUS * 2, ZAP_RADIUS * 2),
					Color = STORM.Warn,
					Material = Enum.Material.Neon,
					Transparency = 0.7,
					CFrame = CFrame.new(spot + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Parent = folder,
				})
				TweenService:Create(warning, TweenInfo.new(ZAP_WARNING), { Transparency = 0.15 }):Play()
				task.wait(ZAP_WARNING)
				if finished then
					return
				end
				warning:Destroy()
				local bolt = part({
					Name = "Bolt",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(90, 1.6, 1.6),
					Color = STORM.Bolt,
					Material = Enum.Material.Neon,
					CFrame = CFrame.new(spot + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Parent = folder,
				})
				Debris:AddItem(bolt, 0.18)
				thunder(0.6, 0.6)
				local root = hop.rootPart()
				if root then
					local now = hop.feetPosition()
					local away = Vector3.new(now.X - spot.X, 0, now.Z - spot.Z)
					if away.Magnitude <= ZAP_RADIUS and math.abs(now.Y - spot.Y) <= 8 then
						local push = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
						root.AssemblyLinearVelocity = push * 35 + Vector3.new(0, 45, 0)
						hop.stagger(0.6, 1, "zap")
					end
				end
			end
		end)
	end

	return cleanup
end

return Objectives

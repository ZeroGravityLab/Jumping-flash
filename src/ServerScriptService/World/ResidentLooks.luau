-- 주민 외형 소품 (GDD 6.6). 기본 R15 몸에 모자·얼굴·손에 든 물건을 붙여 누구인지 멀리서도 알아보게 한다.
-- 좌표는 붙일 신체 부위 기준이고 앞이 -Z다 (머리 크기 약 1.16)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local ResidentLooks = {}

local UP = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥 축을 세운다
local FRONT = CFrame.Angles(0, math.rad(90), 0) -- 원기둥 축을 앞뒤로

local C = {
	Navy = Color3.fromRGB(46, 64, 122),
	NavyDark = Color3.fromRGB(30, 42, 84),
	Gold = Color3.fromRGB(255, 205, 80),
	Beak = Color3.fromRGB(255, 168, 60),
	Leather = Color3.fromRGB(140, 92, 54),
	LeatherDark = Color3.fromRGB(104, 66, 38),
	Paper = Color3.fromRGB(250, 248, 240),
	White = Color3.fromRGB(252, 252, 250),
	Grey = Color3.fromRGB(196, 196, 204),
	Pink = Color3.fromRGB(255, 150, 176),
	Frame = Color3.fromRGB(84, 54, 36),
	Wood = Color3.fromRGB(196, 146, 92),
	WoodDark = Color3.fromRGB(130, 88, 52),
	Rain = Color3.fromRGB(250, 204, 60),
	Auburn = Color3.fromRGB(150, 74, 46),
	Scarf = Color3.fromRGB(216, 64, 64),
	Lamp = Color3.fromRGB(255, 214, 120),
	Iron = Color3.fromRGB(60, 60, 70),
	Straw = Color3.fromRGB(232, 202, 122),
	Band = Color3.fromRGB(190, 60, 50),
	Beard = Color3.fromRGB(150, 100, 62),
	BeardDark = Color3.fromRGB(110, 70, 42),
	Sack = Color3.fromRGB(238, 230, 210),
	Rope = Color3.fromRGB(176, 140, 90),
	Strap = Color3.fromRGB(70, 52, 40),
	Lens = Color3.fromRGB(110, 220, 210),
	Brass = Color3.fromRGB(214, 170, 80),
	Hair = Color3.fromRGB(92, 60, 40),
	Orange = Color3.fromRGB(255, 140, 50),
	KiteA = Color3.fromRGB(255, 96, 110),
	KiteB = Color3.fromRGB(255, 226, 90),
	KiteC = Color3.fromRGB(90, 170, 255),
}

-- 신체 부위에 용접한 소품 하나. 충돌·판정은 없고 질량도 없다
local function piece(model: Model, baseName: string, props: { [string]: any }, offset: CFrame): BasePart?
	local base = model:FindFirstChild(baseName)
	if not (base and base:IsA("BasePart")) then
		return nil
	end
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function ball(size: Vector3, color: Color3, extra: { [string]: any }?): { [string]: any }
	local props: { [string]: any } = { Shape = Enum.PartType.Ball, Size = size, Color = color }
	for key, value in extra or {} do
		props[key] = value
	end
	return props
end

local function cylinder(length: number, diameter: number, color: Color3, extra: { [string]: any }?): { [string]: any }
	local props: { [string]: any } =
		{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), Color = color }
	for key, value in extra or {} do
		props[key] = value
	end
	return props
end

local function block(size: Vector3, color: Color3, extra: { [string]: any }?): { [string]: any }
	local props: { [string]: any } = { Size = size, Color = color }
	for key, value in extra or {} do
		props[key] = value
	end
	return props
end

local LOOKS = {}

-- 우체부 새: 남색 우편 모자, 부리, 깃털 날개, 어깨에 멘 우편 가방
function LOOKS.Pip(model: Model, tint: Color3)
	piece(model, "Head", cylinder(0.42, 1.3, C.Navy), CFrame.new(0, 0.6, 0.02) * UP)
	piece(
		model,
		"Head",
		block(Vector3.new(1.05, 0.08, 0.5), C.NavyDark),
		CFrame.new(0, 0.42, -0.72) * CFrame.Angles(math.rad(-12), 0, 0)
	)
	piece(model, "Head", ball(Vector3.new(0.24, 0.24, 0.1), C.Gold), CFrame.new(0, 0.62, -0.65))
	piece(
		model,
		"Head",
		ball(Vector3.new(0.34, 0.24, 0.62), C.Beak),
		CFrame.new(0, -0.1, -0.7) * CFrame.Angles(math.rad(-8), 0, 0)
	)
	for _, side in { -1, 1 } do
		local arm = if side < 0 then "LeftUpperArm" else "RightUpperArm"
		piece(
			model,
			arm,
			block(Vector3.new(0.14, 1.2, 0.95), tint:Lerp(C.White, 0.25)),
			CFrame.new(side * 0.56, -0.1, 0.1) * CFrame.Angles(0, 0, math.rad(side * -6))
		)
	end
	for _, z in { -0.53, 0.53 } do
		piece(
			model,
			"UpperTorso",
			block(Vector3.new(0.24, 2.3, 0.06), C.Leather),
			CFrame.new(0.1, -0.1, z) * CFrame.Angles(0, 0, math.rad(38))
		)
	end
	piece(model, "LowerTorso", block(Vector3.new(0.5, 0.95, 1.05), C.Leather), CFrame.new(1.2, 0.05, 0))
	piece(model, "LowerTorso", block(Vector3.new(0.54, 0.36, 1.08), C.LeatherDark), CFrame.new(1.2, 0.4, 0))
	piece(
		model,
		"LowerTorso",
		block(Vector3.new(0.06, 0.5, 0.72), C.Paper),
		CFrame.new(1.2, 0.72, 0.05) * CFrame.Angles(0, 0, math.rad(-8))
	)
end

-- 빵집 할머니: 요리사 모자, 회색 머리, 동그란 안경, 앞치마, 밀대
function LOOKS.Momo(model: Model, _tint: Color3)
	piece(model, "Head", cylinder(0.7, 1.2, C.White), CFrame.new(0, 0.78, 0) * UP)
	piece(model, "Head", ball(Vector3.new(1.65, 1.0, 1.65), C.White), CFrame.new(0, 1.3, 0))
	for _, side in { -1, 1 } do
		piece(model, "Head", ball(Vector3.new(0.34, 0.62, 0.55), C.Grey), CFrame.new(side * 0.58, 0.05, 0.12))
		-- 안경테: 투명한 알은 흰 얼굴에 묻혀 안 보였다
		local lens = CFrame.new(side * 0.22, 0.15, -0.6)
		for _, y in { -0.16, 0.16 } do
			piece(model, "Head", block(Vector3.new(0.38, 0.05, 0.04), C.Frame), lens * CFrame.new(0, y, 0))
		end
		for _, x in { -0.17, 0.17 } do
			piece(model, "Head", block(Vector3.new(0.05, 0.32, 0.04), C.Frame), lens * CFrame.new(x, 0, 0))
		end
	end
	piece(model, "Head", block(Vector3.new(0.1, 0.05, 0.04), C.Frame), CFrame.new(0, 0.17, -0.6))
	piece(model, "Head", ball(Vector3.new(0.62, 0.62, 0.62), C.Grey), CFrame.new(0, 0.28, 0.62))
	piece(model, "UpperTorso", block(Vector3.new(1.45, 1.25, 0.06), C.White), CFrame.new(0, -0.18, -0.53))
	piece(model, "UpperTorso", block(Vector3.new(0.5, 0.36, 0.07), C.Pink), CFrame.new(0, -0.5, -0.56))
	piece(model, "LowerTorso", block(Vector3.new(1.75, 1.5, 0.06), C.White), CFrame.new(0, -0.65, -0.55))
	piece(model, "RightHand", cylinder(1.8, 0.34, C.Wood), CFrame.new(0, -0.15, -0.2) * FRONT)
	for _, z in { -1.2, 0.8 } do
		piece(model, "RightHand", cylinder(0.35, 0.18, C.WoodDark), CFrame.new(0, -0.15, z) * FRONT)
	end
end

-- 등대지기: 노란 비옷 모자, 땋은 머리, 목도리, 불 켜진 랜턴
function LOOKS.Rhea(model: Model, _tint: Color3)
	piece(model, "Head", cylinder(0.1, 1.95, C.Rain), CFrame.new(0, 0.38, 0.12) * UP)
	piece(model, "Head", ball(Vector3.new(1.32, 0.85, 1.32), C.Rain), CFrame.new(0, 0.62, 0.04))
	for i, y in { -0.2, -0.58, -0.95 } do
		piece(model, "Head", ball(Vector3.one * (0.42 - i * 0.04), C.Auburn), CFrame.new(0, y, 0.64 + i * 0.04))
	end
	piece(model, "UpperTorso", cylinder(0.32, 1.3, C.Scarf), CFrame.new(0, 0.82, 0) * UP)
	piece(
		model,
		"UpperTorso",
		block(Vector3.new(0.36, 0.95, 0.08), C.Scarf),
		CFrame.new(-0.42, 0.2, -0.56) * CFrame.Angles(0, 0, math.rad(8))
	)
	piece(model, "LeftHand", block(Vector3.new(0.08, 0.4, 0.08), C.Iron), CFrame.new(0, -0.3, 0))
	piece(model, "LeftHand", block(Vector3.new(0.62, 0.12, 0.62), C.Iron), CFrame.new(0, -0.5, 0))
	piece(model, "LeftHand", block(Vector3.new(0.62, 0.12, 0.62), C.Iron), CFrame.new(0, -1.15, 0))
	local glow = piece(
		model,
		"LeftHand",
		cylinder(0.5, 0.5, C.Lamp, { Material = Enum.Material.Neon }),
		CFrame.new(0, -0.82, 0) * UP
	)
	if glow then
		local light = Instance.new("PointLight")
		light.Color = C.Lamp
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = glow
	end
end

-- 풍차지기: 밀짚모자, 수염, 등에 진 밀가루 자루, 멜빵
function LOOKS.Bram(model: Model, _tint: Color3)
	-- Fabric 재질은 밀짚색을 칙칙한 갈색으로 만들어서 매끈한 재질을 쓴다
	piece(model, "Head", cylinder(0.1, 2.35, C.Straw), CFrame.new(0, 0.46, 0) * UP)
	piece(model, "Head", cylinder(0.55, 1.25, C.Straw), CFrame.new(0, 0.74, 0) * UP)
	piece(model, "Head", cylinder(0.16, 1.28, C.Band), CFrame.new(0, 0.58, 0) * UP)
	-- 턱수염은 얼굴 아래쪽을 덮는다 (턱 밑에 두면 목에 단 항아리처럼 보였다)
	piece(model, "Head", ball(Vector3.new(1.08, 0.62, 0.4), C.Beard), CFrame.new(0, -0.36, -0.46))
	piece(model, "Head", ball(Vector3.new(0.78, 0.2, 0.24), C.BeardDark), CFrame.new(0, -0.1, -0.62))
	piece(
		model,
		"UpperTorso",
		ball(Vector3.new(1.4, 1.75, 0.95), C.Sack, { Material = Enum.Material.Fabric }),
		CFrame.new(0, 0.05, 0.95)
	)
	piece(model, "UpperTorso", cylinder(0.2, 0.5, C.Rope), CFrame.new(0, 0.95, 0.95) * UP)
	for _, x in { -0.5, 0.5 } do
		piece(model, "UpperTorso", block(Vector3.new(0.18, 1.72, 0.06), C.Strap), CFrame.new(x, 0, -0.53))
	end
end

-- 연 만드는 아이: 머리에 올린 비행 고글, 휘날리는 목도리, 머리 위에 띄운 연 (실은 Beam이라 연이 흔들려도 따라간다)
function LOOKS.Wren(model: Model, _tint: Color3)
	piece(model, "Head", ball(Vector3.new(1.25, 0.55, 1.25), C.Hair), CFrame.new(0, 0.5, 0.06))
	piece(model, "Head", cylinder(0.2, 1.24, C.Strap), CFrame.new(0, 0.3, 0) * UP)
	for _, side in { -1, 1 } do
		piece(model, "Head", cylinder(0.12, 0.5, C.Brass), CFrame.new(side * 0.25, 0.36, -0.6) * FRONT)
		piece(
			model,
			"Head",
			cylinder(0.14, 0.38, C.Lens, { Material = Enum.Material.Glass, Transparency = 0.15 }),
			CFrame.new(side * 0.25, 0.36, -0.64) * FRONT
		)
	end
	piece(model, "UpperTorso", cylinder(0.3, 1.3, C.Orange), CFrame.new(0, 0.82, 0) * UP)
	piece(
		model,
		"UpperTorso",
		block(Vector3.new(0.34, 0.08, 1.7), C.Orange),
		CFrame.new(0.32, 0.7, 1.25) * CFrame.Angles(math.rad(14), math.rad(12), 0)
	)

	local hand = model:FindFirstChild("RightHand")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hand and hand:IsA("BasePart") and root and root:IsA("BasePart")) then
		return
	end
	-- 연은 따로 떠 있는 모델이다 (클라이언트 Ambience가 Drift 태그로 천천히 흔든다)
	local kite = Instance.new("Model")
	kite.Name = "WrenKite"
	local at = root.CFrame * CFrame.new(2.5, 9, 3) * CFrame.Angles(math.rad(-25), 0, 0)
	local function kitePart(props: { [string]: any }, offset: CFrame): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		for key, value in props do
			(p :: any)[key] = value
		end
		p.CFrame = at * offset
		p.Parent = kite
		return p
	end
	local sail = kitePart(block(Vector3.new(2.6, 2.6, 0.08), C.KiteA), CFrame.Angles(0, 0, math.rad(45)))
	kitePart(block(Vector3.new(1.5, 1.5, 0.1), C.KiteB), CFrame.Angles(0, 0, math.rad(45)))
	kitePart(block(Vector3.new(0.08, 3.6, 0.14), C.WoodDark), CFrame.identity)
	kitePart(block(Vector3.new(3.6, 0.08, 0.14), C.WoodDark), CFrame.identity)
	for i = 1, 4 do
		kitePart(
			block(Vector3.new(0.5, 0.3, 0.06), if i % 2 == 0 then C.KiteC else C.KiteB),
			CFrame.new(0, -1.9 - i * 0.65, 0.1) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 20 else -20))
		)
	end
	-- PrimaryPart 대신 기준점을 직접 둔다. 클라이언트가 부품을 받기 전에 기준점을 읽으면 원점(0,0,0)으로 끌려갔다
	kite.WorldPivot = sail.CFrame
	kite:SetAttribute("DriftPhase", 1.3)

	local from = Instance.new("Attachment")
	from.Name = "KiteString"
	from.Parent = hand
	local to = Instance.new("Attachment")
	to.Name = "KiteString"
	to.Position = Vector3.new(0, -0.2, 0.06)
	to.Parent = sail
	local line = Instance.new("Beam")
	line.Attachment0 = from
	line.Attachment1 = to
	line.Width0 = 0.05
	line.Width1 = 0.05
	line.Color = ColorSequence.new(C.Paper)
	line.FaceCamera = true
	line.CurveSize0 = -1.5
	line.Segments = 8
	line.Parent = sail

	kite.Parent = model
	CollectionService:AddTag(kite, Tags.Drift)
end

function ResidentLooks.apply(model: Model, id: string, tint: Color3)
	local look = LOOKS[id]
	if look then
		look(model, tint)
	end
end

return ResidentLooks

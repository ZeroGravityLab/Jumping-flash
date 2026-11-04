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
}
local RESULT_WAIT = 4.5 -- 결과 창(RequestUi RESULT_SECONDS)이 닫힌 뒤에 엔딩을 띄운다
local APPEAR_SECONDS = 0.8
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

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
						skyMap.guide(story.showAt)
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

-- 하늘 지도 (GDD 6.2·6.4·7.1): 섬과 장 진행, 의뢰가 있는 주민 위치, 길 안내 빛기둥.
-- 튜토리얼(0장)을 끝내거나 1장 이후 의뢰를 하나라도 끝내면 열린다 (RequestLogic.isMapUnlocked).
-- M 키, 터치 지도 버튼(Hud), 허브 광장의 지도 탁자로 연다
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Collectibles = require(ReplicatedStorage.Config.Collectibles)
local Requests = require(ReplicatedStorage.Config.Requests)
local World = require(ReplicatedStorage.Config.World)
local CollectibleLogic = require(ReplicatedStorage.Shared.CollectibleLogic)
local RequestLogic = require(ReplicatedStorage.Shared.RequestLogic)
local Strings = require(ReplicatedStorage.Shared.Strings)

local player = Players.LocalPlayer

local COLOR = {
	Backdrop = Color3.fromRGB(8, 14, 28),
	Panel = Color3.fromRGB(24, 34, 58),
	Sky = Color3.fromRGB(92, 146, 206),
	Text = Color3.fromRGB(255, 255, 255),
	Soft = Color3.fromRGB(200, 214, 240),
	Hub = Color3.fromRGB(170, 222, 140),
	Island = Color3.fromRGB(120, 196, 110),
	Upcoming = Color3.fromRGB(96, 110, 138),
	Rim = Color3.fromRGB(255, 255, 255),
	Ink = Color3.fromRGB(40, 32, 20),
	Guide = Color3.fromRGB(255, 210, 70),
	Accept = Color3.fromRGB(96, 186, 120),
	Close = Color3.fromRGB(90, 100, 130),
	-- 주민 상태 (RequestLogic.residentState)와 최고 메달
	new = Color3.fromRGB(255, 210, 70),
	boss = Color3.fromRGB(255, 120, 90),
	storm = Color3.fromRGB(96, 98, 122),
	locked = Color3.fromRGB(120, 130, 150),
	gold = Color3.fromRGB(255, 205, 60),
	silver = Color3.fromRGB(210, 220, 235),
	bronze = Color3.fromRGB(220, 150, 100),
}
local MEDAL_KEY = { gold = "MedalGold", silver = "MedalSilver", bronze = "MedalBronze" }
local MEDAL_RANK = { bronze = 1, silver = 2, gold = 3 }
local GUIDE_CLEAR_DISTANCE = 16 -- 이만큼 다가가면 빛기둥이 사라진다
local GUIDE_HEIGHT = 400

local SkyMap = {}

local hop, ui
local gui: ScreenGui
local window, mapArea, side: Frame
local chapterLabel, detailName, detailState, detailGoal: TextLabel
local guideButton, closeButton: TextButton
local you: Frame
local drawn: { Instance } = {}
local selected: string? = nil
local unlocked = false
local loaded = false
local guideBeam: BasePart? = nil
local guideTarget: string? = nil
local guidePosition: Vector3? = nil
local toMap: ((x: number, z: number) -> Vector2)? = nil

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function progress(): RequestLogic.Progress
	local raw = player:GetAttribute("RequestProgress")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then decoded else {}
end

local function shardsFound(): { [string]: boolean }
	local raw = player:GetAttribute("Shards")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded else {}
end

local function rounded(inst: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = inst
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = COLOR.Text
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	return text
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = COLOR.Text
	b.TextSize = 18
	b.Text = text
	rounded(b, UDim.new(0, 10))
	b.Parent = parent
	return b
end

local function residentSpec(id: string)
	for _, resident in Requests.Residents do
		if resident.id == id then
			return resident
		end
	end
	return nil
end

local function islandSpec(id: string)
	for _, island in World.Islands do
		if island.id == id then
			return island
		end
	end
	return nil
end

-- 지도 핀은 주민 id 또는 장 보스 의뢰 id다
local function bossOf(id: string)
	local request = RequestLogic.find(Requests, id)
	return if request and request.boss then request else nil
end

local function displayName(id: string): string
	local boss = bossOf(id)
	return if boss then t(boss.name) else id
end

-- 길 안내 목적지: 주민이 서 있는 곳, 보스는 정상의 폭풍 받침대
local function targetPosition(id: string): Vector3?
	local boss = bossOf(id)
	if boss then
		local island = islandSpec(boss.island)
		local air = boss.gate.air
		return Vector3.new(island.center[1] + air[1], island.center[2] + air[2], island.center[3] + air[3])
	end
	local folder = workspace:FindFirstChild("World")
	local residents = folder and folder:FindFirstChild("Residents")
	local model = residents and residents:FindFirstChild(id)
	return if model and model:IsA("Model") then model:GetPivot().Position else nil
end

-- 지도에 그릴 섬: 월드의 섬과 아직 없는 섬
local function mapEntries()
	local list = {}
	for _, island in World.Islands do
		table.insert(list, {
			id = island.id,
			x = island.center[1],
			z = island.center[3],
			radius = island.radius,
			chapter = island.chapter,
		})
	end
	for _, upcoming in World.MapUpcoming do
		table.insert(list, {
			id = upcoming.id,
			x = upcoming.x,
			z = upcoming.z,
			radius = World.MapUpcomingRadius,
			chapter = upcoming.chapter,
			upcoming = true,
		})
	end
	return list
end

-- 월드 x, z → 지도 픽셀 (위쪽이 -Z). 모든 섬이 들어가게 맞춘다
local function fit(entries, size: number, padding: number): (x: number, z: number) -> Vector2
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, e in entries do
		minX = math.min(minX, e.x - e.radius)
		maxX = math.max(maxX, e.x + e.radius)
		minZ = math.min(minZ, e.z - e.radius)
		maxZ = math.max(maxZ, e.z + e.radius)
	end
	local s = (size - padding * 2) / math.max(maxX - minX, maxZ - minZ)
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	return function(x: number, z: number): Vector2
		return Vector2.new(size / 2 + (x - cx) * s, size / 2 + (z - cz) * s)
	end
end

-- 한 섬 안의 주민 핀이 겹치지 않게 서로 밀어낸다
local function spread(points: { Vector2 }, minDistance: number)
	for _ = 1, 12 do
		for i = 1, #points do
			for j = i + 1, #points do
				local d = points[j] - points[i]
				local gap = d.Magnitude
				if gap < minDistance then
					local dir = if gap > 1e-3 then d / gap else Vector2.new(1, 0)
					local push = dir * (minDistance - gap) / 2
					points[i] -= push
					points[j] += push
				end
			end
		end
	end
end

local function clearGuide()
	if guideBeam then
		guideBeam:Destroy()
		guideBeam = nil
	end
	guideTarget = nil
	guidePosition = nil
end

function SkyMap.close()
	gui.Enabled = false
end

local function placeBeam(position: Vector3)
	local beam = Instance.new("Part")
	beam.Name = "GuideBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = COLOR.Guide
	beam.Transparency = 0.35
	beam.Size = Vector3.new(GUIDE_HEIGHT, 6, 6)
	beam.CFrame = CFrame.new(position + Vector3.new(0, GUIDE_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = hop.localFolder
	guideBeam = beam
	SkyMap.close()
end

-- 그 주민(또는 보스 받침대) 위로 빛기둥을 세운다 (이 플레이어에게만 보인다)
function SkyMap.guide(residentId: string)
	clearGuide()
	local position = targetPosition(residentId)
	if not position then
		return
	end
	placeBeam(position)
	guideTarget = residentId
	ui.toast(t("MapGuiding", displayName(residentId)))
end

-- 주민이 아닌 장소(이야기 끝에 생긴 등대 등)로 안내한다
function SkyMap.guideAt(position: Vector3, name: string)
	clearGuide()
	placeBeam(position)
	guidePosition = position
	ui.toast(t("MapGuidingPlace", name))
end

-- 보스 핀을 골랐을 때: 열렸으면 의뢰처럼, 아직이면 종 게이지가 얼마나 남았는지
local function showBossDetail(boss, current)
	detailName.Text = string.format("%s · %s", t(boss.name), t("Island_" .. boss.island))
	local record = current[boss.id]
	if not RequestLogic.isAvailable(boss, current, Requests) then
		local done, needed = RequestLogic.bellGauge(Requests, boss.chapter, current)
		detailState.Text = t("MapStateLocked")
		detailState.TextColor3 = COLOR.locked
		detailGoal.Text = t("BossLocked", done, needed)
	else
		if not record then
			detailState.Text = t("MapStateNew")
			detailState.TextColor3 = COLOR.new
		elseif record.medal ~= "gold" then
			detailState.Text = t("MapStateImprove", t(MEDAL_KEY[record.medal]))
			detailState.TextColor3 = COLOR[record.medal]
		else
			detailState.Text = t("MapStateDone")
			detailState.TextColor3 = COLOR.gold
		end
		detailGoal.Text = t("Req_" .. boss.id .. "_Goal")
	end
	guideButton.Visible = true
end

local function showDetail()
	local current = progress()
	if not selected then
		detailName.Text = ""
		detailState.Text = ""
		detailGoal.Text = t("MapPick")
		guideButton.Visible = false
		closeButton.Position = UDim2.fromOffset(0, 196)
		return
	end
	closeButton.Position = UDim2.fromOffset(138, 196)
	local boss = bossOf(selected)
	if boss then
		showBossDetail(boss, current)
		return
	end
	local resident = residentSpec(selected)
	local state = RequestLogic.residentState(Requests, selected, current)
	detailName.Text = string.format("%s · %s", selected, t("Island_" .. resident.island))
	local request = RequestLogic.nextFor(Requests, selected, current)
	if state == "new" then
		detailState.Text = t("MapStateNew")
		detailState.TextColor3 = COLOR.new
	elseif state == "improve" then
		local medal = current[request.id].medal
		detailState.Text = t("MapStateImprove", t(MEDAL_KEY[medal]))
		detailState.TextColor3 = COLOR[medal]
	elseif state == "done" then
		detailState.Text = t("MapStateDone")
		detailState.TextColor3 = COLOR.gold
	else
		detailState.Text = t("MapStateLocked")
		detailState.TextColor3 = COLOR.locked
	end
	detailGoal.Text = if request then t("Req_" .. request.id .. "_Goal") else ""
	guideButton.Visible = true
end

-- 주민 핀 색: 새 의뢰는 노란 "!", 그 밖에는 그 주민 의뢰의 가장 낮은 메달 색.
-- 보스 핀: 열렸으면 주홍 "!", 아직이면 먹구름색, 이겼으면 그 메달 색
local function pinLook(residentId: string, current): (Color3, string)
	local boss = bossOf(residentId)
	if boss then
		local record = current[boss.id]
		if record then
			return COLOR[record.medal], ""
		end
		return if RequestLogic.isAvailable(boss, current, Requests) then COLOR.boss else COLOR.storm,
			if RequestLogic.isAvailable(boss, current, Requests) then "!" else ""
	end
	local state = RequestLogic.residentState(Requests, residentId, current)
	if state == "new" then
		return COLOR.new, "!"
	elseif state == "locked" then
		return COLOR.locked, ""
	end
	local lowest = "gold"
	for _, request in Requests.Requests do
		local record = request.resident == residentId and current[request.id]
		if record and MEDAL_RANK[record.medal] < MEDAL_RANK[lowest] then
			lowest = record.medal
		end
	end
	return COLOR[lowest], ""
end

local function redraw(mapSize: number)
	for _, inst in drawn do
		inst:Destroy()
	end
	table.clear(drawn)
	local current = progress()
	local entries = mapEntries()
	local position = fit(entries, mapSize, mapSize * 0.08)
	toMap = position
	local scale = (position(1000, 0) - position(0, 0)).X / 1000
	-- 터치 기기는 손가락으로 누를 만큼 키운다
	local minPin = if UserInputService.TouchEnabled then 26 else 18
	local pinSize = math.clamp(math.floor(mapSize * 0.06), minPin, 28)

	for _, e in entries do
		local center = position(e.x, e.z)
		local radius = if e.upcoming
			then math.max(e.radius * scale, mapSize * 0.05)
			else math.max(e.radius * scale, mapSize * 0.1)
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromOffset(center.X, center.Y)
		circle.Size = UDim2.fromOffset(radius * 2, radius * 2)
		circle.BackgroundColor3 = if e.upcoming then COLOR.Upcoming elseif e.chapter then COLOR.Island else COLOR.Hub
		circle.BackgroundTransparency = if e.upcoming then 0.35 else 0
		rounded(circle, UDim.new(0.5, 0))
		-- 되살린 섬은 금빛 테두리
		local restored = e.chapter ~= nil and not e.upcoming and RequestLogic.isRestored(Requests, e.chapter, current)
		local rim = Instance.new("UIStroke")
		rim.Color = if restored then COLOR.gold else COLOR.Rim
		rim.Thickness = if e.upcoming then 1 elseif restored then 4 else 2
		rim.Transparency = if e.upcoming then 0.6 else 0.1
		rim.Parent = circle
		circle.Parent = mapArea
		table.insert(drawn, circle)

		local lines = { t("Island_" .. e.id) }
		if e.upcoming then
			table.insert(lines, t("MapUpcoming"))
		else
			-- 숨은 별조각: 찾은 개수 (어디 있는지는 알려 주지 않는다)
			local found, total = CollectibleLogic.islandProgress(Collectibles, e.id, shardsFound())
			if total > 0 then
				table.insert(lines, t("MapShards", found, total))
			end
			if restored then
				table.insert(lines, t("MapRestored"))
			end
		end
		local caption = label(mapArea, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(center.X, center.Y + radius + 2),
			Size = UDim2.fromOffset(150, 17 * #lines),
			TextSize = if e.upcoming then 12 else 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if e.upcoming then COLOR.Soft else COLOR.Text,
			Text = table.concat(lines, "\n"),
		})
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Color = COLOR.Backdrop
		stroke.Parent = caption
		table.insert(drawn, caption)

		if not e.upcoming then
			-- 주민 핀: 섬 안의 실제 자리에서 출발해 겹치지 않게 벌린다
			local residents, points = {}, {}
			local island = islandSpec(e.id)
			for _, resident in Requests.Residents do
				if resident.island == e.id then
					table.insert(residents, resident)
					local offset = Vector2.new(resident.x, resident.z) / island.radius * (radius - pinSize / 2)
					table.insert(points, center + offset)
				end
			end
			-- 장 보스 핀은 섬 가운데(정상)에. 섬을 되살리면 금빛 테두리가 대신한다
			local chapterSpec = e.chapter and Requests.Chapters[e.chapter]
			if chapterSpec and chapterSpec.boss and not restored then
				table.insert(residents, { id = chapterSpec.boss })
				table.insert(points, center)
			end
			spread(points, pinSize + 4)
			for i, resident in residents do
				local color, mark = pinLook(resident.id, current)
				local pin = Instance.new("TextButton")
				pin.Name = "Pin_" .. resident.id
				pin.AnchorPoint = Vector2.new(0.5, 0.5)
				pin.Position = UDim2.fromOffset(points[i].X, points[i].Y)
				pin.Size = UDim2.fromOffset(pinSize, pinSize)
				pin.BackgroundColor3 = color
				pin.Font = Enum.Font.FredokaOne
				pin.Text = mark
				pin.TextColor3 = COLOR.Ink
				pin.TextSize = pinSize - 4
				pin.ZIndex = 3
				rounded(pin, UDim.new(0.5, 0))
				local ring = Instance.new("UIStroke")
				ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				ring.Thickness = if selected == resident.id then 3 else 1.5
				ring.Color = if selected == resident.id then COLOR.Rim else COLOR.Ink
				ring.Parent = pin
				pin.Activated:Connect(function()
					selected = resident.id
					redraw(mapSize)
				end)
				pin.Parent = mapArea
				table.insert(drawn, pin)
			end
		end
	end

	local lines = {}
	for chapter, spec in Requests.Chapters do
		local bell, needed = RequestLogic.bellGauge(Requests, chapter, current)
		local done, total = RequestLogic.chapterCount(Requests, chapter, current)
		local title = t("MapChapter", chapter, t("Island_" .. spec.island))
		if RequestLogic.isRestored(Requests, chapter, current) then
			title ..= " · " .. t("MapRestored")
		end
		table.insert(lines, title)
		table.insert(lines, t("MapChapterProgress", bell, needed, done, total))
	end
	chapterLabel.Text = table.concat(lines, "\n")
	showDetail()
end

-- 화면 크기에 맞춘 배치. 가로 화면은 지도 왼쪽·설명 오른쪽, 세로 화면은 지도 위·설명 아래.
-- 목표 문장은 설명 칸 맨 위에 두어 짧은 가로 화면(휴대폰)에서도 지도를 크게 쓴다
local HEADER = 46
local SIDE_HEIGHT = 236

local function layout(): number
	-- 화면 위쪽 Roblox 버튼 줄은 비워 둔다 (IgnoreGuiInset = false)
	local camera = workspace.CurrentCamera
	local topLeft, bottomRight = GuiService:GetGuiInset()
	local viewport = (if camera then camera.ViewportSize else Vector2.new(1280, 720)) - topLeft - bottomRight
	local portrait = viewport.Y > viewport.X
	local width, height, mapSize
	if portrait then
		width = math.min(480, viewport.X - 16)
		height = math.min(viewport.Y - 16, HEADER + (width - 24) + 12 + SIDE_HEIGHT + 12)
		mapSize = math.min(width - 24, height - HEADER - SIDE_HEIGHT - 24)
		mapArea.Position = UDim2.fromOffset((width - mapSize) / 2, HEADER)
		side.Position = UDim2.fromOffset(16, HEADER + mapSize + 12)
		side.Size = UDim2.fromOffset(width - 32, SIDE_HEIGHT)
	else
		width = math.min(780, viewport.X - 24)
		height = math.min(500, viewport.Y - 16)
		mapSize = height - HEADER - 12
		local sideWidth = width - mapSize - 40
		if sideWidth < 220 then
			mapSize = width - 40 - 220
			sideWidth = 220
		end
		mapArea.Position = UDim2.fromOffset(12, HEADER)
		side.Position = UDim2.fromOffset(28 + mapSize, HEADER)
		side.Size = UDim2.fromOffset(sideWidth, mapSize)
	end
	window.Size = UDim2.fromOffset(width, height)
	mapArea.Size = UDim2.fromOffset(mapSize, mapSize)
	return mapSize
end

function SkyMap.open()
	if not unlocked then
		ui.toast(t("MapLockedHint"))
		return
	end
	gui.Enabled = true
	redraw(layout())
end

function SkyMap.toggle()
	if gui.Enabled then
		SkyMap.close()
	else
		SkyMap.open()
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "SkyhopMap"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 바깥을 누르면 닫힌다
	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = COLOR.Backdrop
	backdrop.BackgroundTransparency = 0.45
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Parent = gui
	backdrop.Activated:Connect(SkyMap.close)

	window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.BackgroundColor3 = COLOR.Panel
	window.BackgroundTransparency = 0.05
	window.Active = true
	rounded(window, UDim.new(0, 16))
	window.Parent = gui

	label(window, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 30),
		TextSize = 26,
		Text = t("MapTitle"),
	})
	mapArea = Instance.new("Frame")
	mapArea.Name = "Map"
	mapArea.BackgroundColor3 = COLOR.Sky
	mapArea.ClipsDescendants = true
	rounded(mapArea, UDim.new(0, 12))
	mapArea.Parent = window

	you = Instance.new("Frame")
	you.Name = "You"
	you.AnchorPoint = Vector2.new(0.5, 0.5)
	you.Size = UDim2.fromOffset(14, 14)
	you.BackgroundColor3 = COLOR.Rim
	you.ZIndex = 4
	rounded(you, UDim.new(0.5, 0))
	local youRing = Instance.new("UIStroke")
	youRing.Thickness = 2
	youRing.Color = COLOR.Ink
	youRing.Parent = you
	local facing = Instance.new("Frame")
	facing.AnchorPoint = Vector2.new(0.5, 1)
	facing.Position = UDim2.fromScale(0.5, 0.5)
	facing.Size = UDim2.fromOffset(4, 16)
	facing.BackgroundColor3 = COLOR.Ink
	facing.BorderSizePixel = 0
	facing.ZIndex = 5
	facing.Parent = you
	you.Parent = mapArea

	side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Parent = window
	label(side, {
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 14,
		TextColor3 = COLOR.Soft,
		Text = t("MapGoal"),
	})
	chapterLabel = label(side, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 44), TextSize = 16 })
	detailName = label(side, { Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 24), TextSize = 20 })
	detailState = label(side, { Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 0, 20), TextSize = 15 })
	detailGoal = label(side, {
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 15,
		TextColor3 = COLOR.Soft,
	})
	guideButton = button(side, t("MapGuide"), COLOR.Accept)
	guideButton.Name = "GuideButton"
	guideButton.Position = UDim2.fromOffset(0, 196)
	guideButton.Size = UDim2.fromOffset(128, 36)
	guideButton.Activated:Connect(function()
		if selected then
			SkyMap.guide(selected)
		end
	end)
	closeButton = button(side, t("MapClose"), COLOR.Close)
	closeButton.Name = "CloseButton"
	closeButton.Position = UDim2.fromOffset(138, 196)
	closeButton.Size = UDim2.fromOffset(96, 36)
	closeButton.Activated:Connect(SkyMap.close)
end

-- 막 열렸을 때만 알린다 (이미 열린 플레이어가 들어올 때는 조용히 연다)
local function refreshUnlock()
	if type(player:GetAttribute("RequestProgress")) ~= "string" then
		return
	end
	local now = RequestLogic.isMapUnlocked(Requests, progress())
	if now and not unlocked and loaded then
		ui.toast(t("MapUnlocked"))
	end
	unlocked = now
	loaded = true
end

local function attachPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("SkyMap") then
		prompt.ActionText = t("MapView")
		prompt.ObjectText = t("MapTitle")
	end
end

function SkyMap.start(hopController, requestUi)
	hop = hopController
	ui = requestUi
	build()

	refreshUnlock()
	player:GetAttributeChangedSignal("RequestProgress"):Connect(function()
		refreshUnlock()
		if gui.Enabled then
			redraw(layout())
		end
	end)
	player:GetAttributeChangedSignal("Shards"):Connect(function()
		if gui.Enabled then
			redraw(layout())
		end
	end)

	for _, inst in workspace:GetDescendants() do
		attachPrompt(inst)
	end
	workspace.DescendantAdded:Connect(attachPrompt)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("SkyMap") then
			SkyMap.open()
		elseif
			guideTarget
			and (prompt:GetAttribute("Resident") == guideTarget or prompt:GetAttribute("Boss") == guideTarget)
		then
			clearGuide()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			SkyMap.toggle()
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if gui.Enabled then
				redraw(layout())
			end
		end)
	end

	RunService.RenderStepped:Connect(function()
		local root = hop.rootPart()
		if (guideTarget or guidePosition) and root then
			local target = if guideTarget then targetPosition(guideTarget) else guidePosition
			if target and (root.Position - target).Magnitude <= GUIDE_CLEAR_DISTANCE then
				clearGuide()
			end
		end
		if gui.Enabled and root and toMap then
			-- 내 위치와 카메라가 보는 방향 (위쪽이 -Z)
			local at = toMap(root.Position.X, root.Position.Z)
			local size = mapArea.Size.X.Offset
			you.Position = UDim2.fromOffset(math.clamp(at.X, 8, size - 8), math.clamp(at.Y, 8, size - 8))
			local look = workspace.CurrentCamera.CFrame.LookVector
			you.Rotation = math.deg(math.atan2(look.X, -look.Z))
		end
	end)
end

return SkyMap

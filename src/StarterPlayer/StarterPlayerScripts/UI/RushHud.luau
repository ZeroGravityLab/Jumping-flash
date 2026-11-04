-- 클라우드 러시 화면 (GDD 7.2, 13): 대기 중에는 구석의 작은 참가 버튼, 참가했거나 탑 위에 있으면
-- 위쪽 가운데 띠(남은 시간·남은 사람·해일까지 거리), 결과 창.
-- 작은 버튼은 튜토리얼을 끝낸 뒤(하늘 지도가 열린 뒤)에만 보인다. 첫 접속에서는 핍의 첫 의뢰에 집중하게 한다.
-- 해일은 서버 시간과 Config로 각자 계산해 부드럽게 그린다 (탈락 판정은 서버 RoundService)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RequestLogic = require(ReplicatedStorage.Shared.RequestLogic)
local Requests = require(ReplicatedStorage.Config.Requests)
local Rush = require(ReplicatedStorage.Config.Rush)
local RushLogic = require(ReplicatedStorage.Shared.RushLogic)
local Strings = require(ReplicatedStorage.Shared.Strings)

local player = Players.LocalPlayer

local COLOR = {
	Panel = Color3.fromRGB(24, 34, 58),
	Text = Color3.fromRGB(255, 255, 255),
	Soft = Color3.fromRGB(200, 214, 240),
	Join = Color3.fromRGB(96, 186, 120),
	Leave = Color3.fromRGB(90, 100, 130),
	Danger = Color3.fromRGB(255, 120, 120),
	Gold = Color3.fromRGB(255, 205, 60),
	Stroke = Color3.fromRGB(40, 60, 90),
	-- 아래 흰 구름 바다와 구분되게 연보랏빛 회색 폭풍 구름으로 (2026-11-04 Studio 확인)
	Tide = Color3.fromRGB(172, 164, 214),
	TidePuff = Color3.fromRGB(198, 192, 232),
}
-- 탑(허브에서 380)과 허브 가장자리(170) 사이에서 멈춘다. 900이면 허브 하늘까지 덮었다
local TIDE_DIAMETER = 400
local TIDE_WARNING = 30 -- 해일이 발밑 이 거리 안이면 빨갛게
local TIDE_PUFFS = 12

local RushHud = {}

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function rounded(inst: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = COLOR.Text
	text.TextWrapped = true
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	return text
end

-- 구름 해일: 탑을 둘러싼 넓은 원판과 그 위의 솜뭉치 (이 클라이언트에만)
local function buildTide(): (BasePart, { BasePart })
	local folder = Instance.new("Folder")
	folder.Name = "RushLocal"
	folder.Parent = workspace
	local function cloudPart(props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = COLOR.Tide
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = folder
		return p
	end
	local tide = cloudPart({
		Name = "Tide",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, TIDE_DIAMETER, TIDE_DIAMETER),
	})
	local puffs = {}
	for i = 1, TIDE_PUFFS do
		local size = 50 + (i % 4) * 22
		local puff = cloudPart({
			Name = "TidePuff",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.45, size),
			Color = COLOR.TidePuff,
		})
		puff:SetAttribute("Angle", i / TIDE_PUFFS * math.pi * 2)
		puff:SetAttribute("Radius", 70 + (i * 53) % 120)
		table.insert(puffs, puff)
	end
	return tide, puffs
end

function RushHud.start(hop, ui, requestController, skyCamera)
	local state = ReplicatedStorage:WaitForChild("RushState")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local joinRemote = remotes:WaitForChild(Remotes.RushJoin) :: RemoteEvent
	local resultRemote = remotes:WaitForChild(Remotes.RushResult) :: RemoteEvent
	local stompRemote = remotes:WaitForChild(Remotes.RushStomp) :: RemoteEvent
	local stompedRemote = remotes:WaitForChild(Remotes.RushStomped) :: RemoteEvent

	-- 라이벌 밟기: 탑 위에서 다른 참가자의 머리를 밟으면 서버에 알린다 (밟힌 쪽 효과는 서버가 확인한 뒤 보낸다)
	hop.onBounce:Connect(function(kind, _, _, part)
		if kind ~= "buddy" or not part or player:GetAttribute("RushRunning") ~= true then
			return
		end
		local model = part:FindFirstAncestorOfClass("Model")
		local victim = model and Players:GetPlayerFromCharacter(model)
		if victim then
			stompRemote:FireServer(victim)
		end
	end)
	stompedRemote.OnClientEvent:Connect(function(seconds, jumpsLost)
		if type(seconds) == "number" and type(jumpsLost) == "number" then
			hop.stagger(seconds, jumpsLost)
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkyhopRush"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- Hud와 같은 기준 (고도·최고·아래 거리 표시 바로 밑에 띠를 둔다)
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 고도 표시 아래의 띠: 상태 한두 줄 + 참가 버튼
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 116)
	banner.BackgroundColor3 = COLOR.Panel
	banner.BackgroundTransparency = 0.25
	rounded(banner, 12)
	banner.Parent = gui
	local bannerText = label(banner, {
		Position = UDim2.fromOffset(12, 4),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local bannerSub = label(banner, {
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLOR.Soft,
	})
	local joinButton = Instance.new("TextButton")
	joinButton.Name = "JoinButton"
	joinButton.AnchorPoint = Vector2.new(1, 0.5)
	joinButton.Position = UDim2.new(1, -6, 0.5, 0)
	joinButton.Size = UDim2.fromOffset(78, 32)
	joinButton.Font = Enum.Font.FredokaOne
	joinButton.TextSize = 17
	joinButton.TextColor3 = COLOR.Text
	rounded(joinButton, 10)
	joinButton.Parent = banner
	joinButton.Activated:Connect(function()
		joinRemote:FireServer(not player:GetAttribute("RushJoined"))
	end)

	-- 대기 중 작은 참가 버튼 (누르면 바로 참가하고, 그때부터 위쪽 띠가 보인다)
	local pill = Instance.new("TextButton")
	pill.Name = "RushPill"
	pill.BackgroundColor3 = COLOR.Panel
	pill.BackgroundTransparency = 0.2
	pill.Font = Enum.Font.FredokaOne
	pill.TextSize = 16
	pill.TextColor3 = COLOR.Text
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 34)
	pill.Visible = false
	rounded(pill, 17)
	local pillPadding = Instance.new("UIPadding")
	pillPadding.PaddingLeft = UDim.new(0, 14)
	pillPadding.PaddingRight = UDim.new(0, 14)
	pillPadding.Parent = pill
	local pillStroke = Instance.new("UIStroke")
	pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pillStroke.Color = COLOR.Join
	pillStroke.Thickness = 2
	pillStroke.Parent = pill
	pill.Parent = gui
	pill.Activated:Connect(function()
		joinRemote:FireServer(true)
	end)

	-- 튜토리얼을 끝냈는가 (하늘 지도와 같은 조건)
	local unlocked = false
	local function refreshUnlock()
		local raw = player:GetAttribute("RequestProgress")
		local ok, progress = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "{}")
		unlocked = ok and RequestLogic.isMapUnlocked(Requests, progress)
	end
	refreshUnlock()
	player:GetAttributeChangedSignal("RequestProgress"):Connect(refreshUnlock)

	-- 화면 가운데 큰 글씨 (카운트다운, 출발)
	local center = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(600, 70),
		TextSize = 44,
		TextColor3 = COLOR.Gold,
		Visible = false,
	})
	local centerStroke = Instance.new("UIStroke")
	centerStroke.Thickness = 3
	centerStroke.Color = COLOR.Stroke
	centerStroke.Parent = center

	-- 결과 창
	local result = Instance.new("Frame")
	result.Name = "Result"
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, 0.45)
	result.BackgroundColor3 = COLOR.Panel
	result.BackgroundTransparency = 0.1
	result.Visible = false
	rounded(result, 14)
	result.Parent = gui
	label(result, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 26,
		Text = t("RushResultTitle"),
	})
	local resultRank = label(result, {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 34,
		TextColor3 = COLOR.Gold,
	})
	local resultDetail = label(result, {
		Position = UDim2.fromOffset(16, 94),
		Size = UDim2.new(1, -32, 0, 80),
		TextSize = 18,
		TextColor3 = COLOR.Soft,
	})
	local resultToken = 0
	resultRemote.OnClientEvent:Connect(function(data)
		resultToken += 1
		local token = resultToken
		resultRank.Text = t("RushResultRank", data.rank, data.total)
		local lines = { t("RushResultHeight", data.height), t("ResultCoins", data.coins) }
		if data.rang then
			table.insert(lines, 1, t("RushResultBell"))
		end
		resultDetail.Text = table.concat(lines, "\n")
		result.Visible = true
		task.delay(Rush.ResultsSeconds, function()
			if token == resultToken then
				result.Visible = false
			end
		end)
	end)

	-- 세로 터치 화면은 오른쪽 버튼 줄(지도·시점·기록)을 피해 왼쪽에 두고 두 줄로 접는다
	local function layout()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local narrow = UserInputService.TouchEnabled and viewport.Y > viewport.X
		if narrow then
			banner.AnchorPoint = Vector2.new(0, 0)
			banner.Position = UDim2.fromOffset(12, 116)
			banner.Size = UDim2.fromOffset(viewport.X - 124, 64)
			bannerText.Size = UDim2.new(1, -100, 0, 38)
			bannerText.TextSize = 15
			bannerSub.Position = UDim2.fromOffset(12, 42)
			bannerSub.TextSize = 14
		else
			banner.AnchorPoint = Vector2.new(0.5, 0)
			banner.Position = UDim2.new(0.5, 0, 0, 116)
			banner.Size = UDim2.fromOffset(math.min(400, viewport.X - 24), 50)
			bannerText.Size = UDim2.new(1, -110, 0, 22)
			bannerText.TextSize = 17
			bannerSub.Position = UDim2.fromOffset(12, 26)
			bannerSub.TextSize = 15
		end
		bannerSub.Size = UDim2.new(1, -110, 0, 18)
		-- 작은 버튼: PC는 왼쪽 위 시점·마커 표시 아래, 터치는 왼쪽 위 (의뢰 중에는 그 자리를 의뢰 진행 표시가 쓰고 버튼은 숨는다)
		local touch = UserInputService.TouchEnabled
		pill.Position = if not touch
			then UDim2.fromOffset(12, 58)
			elseif narrow then UDim2.fromOffset(12, 118)
			else UDim2.fromOffset(12, 8)
		result.Size = UDim2.fromOffset(math.min(340, viewport.X - 24), 186)
		center.Size = UDim2.fromOffset(math.min(600, viewport.X - 24), 70)
		center.TextSize = if viewport.X < 600 then 32 else 44
	end
	layout()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end

	local tide, puffs = buildTide()
	local hiddenCFrame = CFrame.new(0, -5000, 0)
	local function placeTide(y: number?)
		if not y then
			tide.CFrame = hiddenCFrame
			for _, puff in puffs do
				puff.CFrame = hiddenCFrame
			end
			return
		end
		local origin = Rush.TowerOrigin
		tide.CFrame = CFrame.new(origin[1], y - 4, origin[3]) * CFrame.Angles(0, 0, math.rad(90))
		local wobble = os.clock() * 0.3
		for _, puff in puffs do
			local angle = puff:GetAttribute("Angle") + wobble * 0.05
			local radius = puff:GetAttribute("Radius")
			puff.CFrame = CFrame.new(
				origin[1] + math.cos(angle) * radius,
				y + math.sin(wobble + angle * 3) * 2,
				origin[3] + math.sin(angle) * radius
			)
		end
	end
	placeTide(nil)

	-- 탑에 올라가면 하던 의뢰를 그만두고, 진행 중에 내려오면(해일에 잠기면) 알린다
	local lastPhase = state:GetAttribute("Phase")
	player:GetAttributeChangedSignal("RushRunning"):Connect(function()
		if player:GetAttribute("RushRunning") then
			requestController.cancelActive()
			-- 서버가 옮긴 위치가 도착한 뒤 탑 가운데를 보게 한다
			task.delay(0.3, function()
				local root = hop.rootPart()
				if root then
					local origin = Rush.TowerOrigin
					skyCamera.faceToward(Vector3.new(origin[1], root.Position.Y, origin[3]))
				end
			end)
		elseif state:GetAttribute("Phase") == "Running" then
			ui.toast(t("RushOut"))
		end
	end)

	local goUntil = 0
	RunService.RenderStepped:Connect(function()
		local phase = state:GetAttribute("Phase")
		local now = workspace:GetServerTimeNow()
		local left = math.max(0, math.ceil((state:GetAttribute("PhaseEndsAt") or now) - now))
		local running = player:GetAttribute("RushRunning") == true
		local joined = player:GetAttribute("RushJoined") == true
		local alive = state:GetAttribute("Alive") or 0

		if phase ~= lastPhase then
			if phase == "Running" and running then
				goUntil = os.clock() + 1.6
			end
			lastPhase = phase
		end

		local main, sub, subColor = "", "", COLOR.Soft
		if phase == "Lobby" then
			main = if joined then t("RushJoined", left) else t("RushLobby", left)
		elseif phase == "Countdown" then
			main = if running then t("RushCountdown", left) else t("RushStarting")
		elseif phase == "Running" then
			local elapsed = now - (state:GetAttribute("StartedAt") or now)
			if running then
				main = t("RushRunning", clock(elapsed), alive)
				local tideIn = Rush.TideDelay - elapsed
				if tideIn > 0 then
					sub = t("RushTideIn", math.ceil(tideIn))
				else
					local tideY = (state:GetAttribute("TowerBaseY") or 0) + RushLogic.tideHeight(Rush, elapsed)
					local root = hop.rootPart()
					local gap = if root then math.floor(hop.feetPosition().Y - tideY) else 0
					sub = t("RushTideBelow", math.max(0, gap))
					if gap < TIDE_WARNING then
						subColor = COLOR.Danger
					end
				end
			else
				main = t("RushWatching", alive)
			end
		elseif phase == "Results" then
			main = t("RushResults")
		end
		bannerText.Text = main
		bannerSub.Text = sub
		bannerSub.TextColor3 = subColor
		-- 큰 띠는 참가했거나 탑 위에 있을 때만. 그 밖의 대기 중에는 구석의 작은 버튼만 (튜토리얼을 끝낸 뒤)
		-- 의뢰 중이거나 대화창·엔딩 카드가 떠 있으면 둘 다 숨긴다 (탑 위에 있을 때는 의뢰가 이미 취소됐다)
		local busy = requestController.isActive() or ui.isBusy()
		banner.Visible = phase ~= nil and (running or (joined and not busy))
		pill.Visible = phase == "Lobby" and not joined and not running and unlocked and not busy
		if pill.Visible then
			pill.Text = t("RushPill", left)
		end
		joinButton.Visible = not running
		joinButton.Text = if joined then t("RushLeave") else t("RushJoin")
		joinButton.BackgroundColor3 = if joined then COLOR.Leave else COLOR.Join

		if phase == "Countdown" and running then
			center.Text = t("RushCountdown", left)
			center.Visible = true
		elseif os.clock() < goUntil then
			center.Text = t("RushGo")
			center.Visible = true
		else
			center.Visible = false
		end

		if phase == "Running" or phase == "Results" then
			local startedAt = state:GetAttribute("StartedAt") or now
			placeTide((state:GetAttribute("TowerBaseY") or 0) + RushLogic.tideHeight(Rush, now - startedAt))
		else
			placeTide(nil)
		end
	end)
end

return RushHud

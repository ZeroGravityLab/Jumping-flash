-- 토이 HUD: 고도, 남은 점프, 퍼펙트·콤보 팝업, 모바일 버튼, 토이 기록(F2)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Movement = require(ReplicatedStorage.Config.Movement)
local MovementLogic = require(ReplicatedStorage.Shared.MovementLogic)
local Strings = require(ReplicatedStorage.Shared.Strings)
local ToyStats = require(ReplicatedStorage.Shared.ToyStats)

local player = Players.LocalPlayer

local TREND_WINDOW = 180 -- 퍼펙트율 비교 구간(초): 처음 3분 vs 최근 3분
local STATS_REFRESH = 0.5

local COLOR = {
	Text = Color3.fromRGB(255, 255, 255),
	Stroke = Color3.fromRGB(40, 60, 90),
	Perfect = Color3.fromRGB(255, 205, 60),
	Stomp = Color3.fromRGB(255, 140, 210),
	Pad = Color3.fromRGB(255, 220, 90),
	Buddy = Color3.fromRGB(130, 255, 170),
	PipOn = Color3.fromRGB(255, 255, 255),
	PipOff = Color3.fromRGB(90, 110, 140),
	Panel = Color3.fromRGB(20, 30, 50),
}

local Hud = {}

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function newLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = COLOR.Text
	for key, value in props do
		(label :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = COLOR.Stroke
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function newButton(parent: Instance, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = COLOR.Panel
	button.BackgroundTransparency = 0.35
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = COLOR.Text
	button.TextScaled = true
	button.Text = text
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.15, 0)
	padding.PaddingRight = UDim.new(0.15, 0)
	padding.PaddingTop = UDim.new(0.25, 0)
	padding.PaddingBottom = UDim.new(0.25, 0)
	padding.Parent = button
	button.Parent = parent
	return button
end

local function percent(rate: number?): string
	if rate == nil then
		return t("NoData")
	end
	return string.format("%d%%", math.floor(rate * 100 + 0.5))
end

local function clock(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function Hud.start(hop, skyCamera, landingMarker)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkyhopHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 고도
	local altitude = newLabel(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(260, 52),
		TextSize = 46,
	})
	local best = newLabel(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(260, 24),
		TextSize = 20,
	})

	-- 남은 점프
	local pipRow = Instance.new("Frame")
	pipRow.AnchorPoint = Vector2.new(0.5, 1)
	pipRow.Position = UDim2.new(0.5, 0, 1, -48)
	pipRow.Size = UDim2.fromOffset(140, 26)
	pipRow.BackgroundTransparency = 1
	pipRow.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = pipRow
	local pips = {}
	for index = 1, MovementLogic.maxJumps(Movement) do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(22, 22)
		pip.LayoutOrder = index
		pip.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = pip
		-- 흰 바닥 위에서도 보이게 외곽선을 두른다
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = COLOR.Stroke
		stroke.Parent = pip
		pip.Parent = pipRow
		pips[index] = pip
	end

	-- 팝업
	local popup = newLabel(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(480, 64),
		TextSize = 44,
		TextTransparency = 1,
	})
	local popupStroke = popup:FindFirstChildOfClass("UIStroke")
	popupStroke.Transparency = 1

	local function showPopup(text: string, color: Color3)
		popup.Text = text
		popup.TextColor3 = color
		popup.TextTransparency = 0
		popupStroke.Transparency = 0
		popup.TextSize = 54
		TweenService:Create(popup, TweenInfo.new(0.15), { TextSize = 44 }):Play()
		local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
		TweenService:Create(popup, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(popupStroke, fade, { Transparency = 1 }):Play()
	end

	-- 시점·마커 상태
	local status = newLabel(gui, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(320, 44),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local function refreshStatus()
		local view = if skyCamera.mode == "First" then t("ViewFirst") else t("ViewSky")
		local marker = if landingMarker.enabled then t("MarkerOn") else t("MarkerOff")
		status.Text = view .. "\n" .. marker
	end
	refreshStatus()
	skyCamera.onModeChanged:Connect(refreshStatus)
	landingMarker.onToggled:Connect(refreshStatus)

	-- 토이 기록 (토이 게이트 측정용)
	local statsPanel = newLabel(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 60),
		Size = UDim2.fromOffset(380, 150),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		BackgroundColor3 = COLOR.Panel,
		BackgroundTransparency = 0.4,
		Visible = false,
	})
	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingLeft = UDim.new(0, 10)
	panelPadding.PaddingTop = UDim.new(0, 8)
	panelPadding.Parent = statsPanel

	local viewSeconds = { Sky = 0, First = 0 }
	local function statsText(): string
		local stats = hop.stats
		local elapsed = os.clock() - stats.startedAt
		return table.concat({
			t("StatsTitle"),
			t("StatsTime", clock(elapsed)),
			t("StatsJumps", #stats.airJumps, percent(ToyStats.perfectRate(stats.airJumps, 0, math.huge))),
			t(
				"StatsTrend",
				percent(ToyStats.perfectRate(stats.airJumps, 0, TREND_WINDOW)),
				percent(ToyStats.perfectRate(stats.airJumps, math.max(0, elapsed - TREND_WINDOW), math.huge))
			),
			t("StatsStomps", stats.stomps, stats.bells),
			t("StatsHighest", math.round(stats.maxAltitude)),
			t("StatsView", clock(viewSeconds.Sky), clock(viewSeconds.First)),
		}, "\n")
	end
	local function toggleStats()
		statsPanel.Visible = not statsPanel.Visible
		if statsPanel.Visible then
			statsPanel.Text = statsText()
		end
	end

	-- 입력 안내 (키보드)
	if UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
		newLabel(gui, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -10),
			Size = UDim2.new(0.6, 0, 0, 20),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = t("ControlsKeyboard"),
		})
	end

	-- 모바일 버튼. 밟기 버튼은 기본 점프 버튼 바로 위에 둔다
	if UserInputService.TouchEnabled then
		local stompButton = newButton(gui, t("ButtonStomp"), UDim2.fromOffset(84, 84), UDim2.new(1, -110, 1, -240))
		local function placeStomp()
			local camera = workspace.CurrentCamera
			local viewport = if camera then camera.ViewportSize else Vector2.new(1000, 1000)
			local small = math.min(viewport.X, viewport.Y) <= 500
			stompButton.Size = if small then UDim2.fromOffset(64, 64) else UDim2.fromOffset(96, 96)
			stompButton.Position = if small then UDim2.new(1, -60, 1, -130) else UDim2.new(1, -110, 1, -270)
		end
		placeStomp()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeStomp)
		end
		stompButton.Activated:Connect(hop.stomp)

		local viewButton = newButton(gui, t("ButtonView"), UDim2.fromOffset(96, 40), UDim2.new(1, -70, 0, 30))
		viewButton.Activated:Connect(skyCamera.toggle)
		local statsButton = newButton(gui, t("ButtonStats"), UDim2.fromOffset(96, 40), UDim2.new(1, -176, 0, 30))
		statsButton.Activated:Connect(toggleStats)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			toggleStats()
		end
	end)

	hop.onJump:Connect(function(_, perfect)
		if perfect then
			showPopup(t("Perfect"), COLOR.Perfect)
		end
	end)
	hop.onBounce:Connect(function(kind, combo)
		if kind == "pad" then
			showPopup(t("BouncePad"), COLOR.Pad)
		elseif kind == "buddy" then
			showPopup(t("Buddy"), COLOR.Buddy)
		elseif combo >= 2 then
			showPopup(t("StompCombo", combo), COLOR.Stomp)
		end
	end)
	hop.onBell:Connect(function()
		showPopup(t("Bell"), COLOR.Perfect)
	end)

	local sinceStatsRefresh = 0
	RunService.RenderStepped:Connect(function(dt)
		altitude.Text = t("Altitude", math.round(hop.altitude()))
		best.Text = t("Best", math.round(hop.stats.maxAltitude))

		local left = hop.jumpsLeft()
		for index, pip in pips do
			pip.BackgroundColor3 = if index <= left then COLOR.PipOn else COLOR.PipOff
		end

		viewSeconds[skyCamera.mode] += dt
		sinceStatsRefresh += dt
		if statsPanel.Visible and sinceStatsRefresh >= STATS_REFRESH then
			sinceStatsRefresh = 0
			statsPanel.Text = statsText()
		end
	end)
end

return Hud

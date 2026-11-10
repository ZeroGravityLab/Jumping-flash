-- 설정 화면 (GDD 13장): 배경음악·효과음 볼륨, 떨어질 때 화면 흔들림, 착지 예상 링, 시점.
-- 값은 서버 프로필(Settings 속성)에서 받아 적용하고, 바꾸면 잠시 뒤 한 번 저장한다.
-- V(시점)·L(링) 키로 바꾼 것도 같이 저장한다. 설정 버튼(PC는 O 키도)으로 연다
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage.Config.Settings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SettingsLogic = require(ReplicatedStorage.Shared.SettingsLogic)
local Strings = require(ReplicatedStorage.Shared.Strings)
local AudioGroups = require(script.Parent.Parent.Movement.AudioGroups)

local player = Players.LocalPlayer

local COLOR = {
	Panel = Color3.fromRGB(24, 34, 58),
	Row = Color3.fromRGB(40, 54, 88),
	Text = Color3.fromRGB(255, 255, 255),
	Soft = Color3.fromRGB(200, 214, 240),
	On = Color3.fromRGB(96, 186, 120),
	Off = Color3.fromRGB(96, 104, 126),
	Step = Color3.fromRGB(70, 110, 170),
	Bar = Color3.fromRGB(255, 205, 60),
	BarBack = Color3.fromRGB(20, 26, 44),
}
local ROW_HEIGHT = 52

local SettingsUi = {}

local current: SettingsLogic.Settings = SettingsLogic.sanitize(Settings, nil)
local gui: ScreenGui
local panel: Frame
local uiScale: UIScale
local refreshers: { () -> () } = {}
local saveToken = 0
local applying = false
local saveRemote: RemoteEvent
local skyCamera, landingMarker

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function rounded(inst: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = COLOR.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = COLOR.Text
	b.TextSize = 18
	b.AutoButtonColor = true
	for key, value in props do
		(b :: any)[key] = value
	end
	rounded(b, 10)
	b.Parent = parent
	return b
end

-- 지금 값을 게임에 적용한다 (볼륨, 흔들림, 링, 시점)
local function apply()
	applying = true
	AudioGroups.music().Volume = current.music
	AudioGroups.sounds().Volume = current.sounds
	skyCamera.shakeEnabled = current.shake
	if landingMarker.enabled ~= current.marker then
		landingMarker.enabled = current.marker
		landingMarker.onToggled:Fire(current.marker)
	end
	skyCamera.setMode(current.view)
	applying = false
	for _, refresh in refreshers do
		refresh()
	end
end

-- 마지막으로 바꾼 뒤 SaveDelay가 지나면 한 번 보낸다
local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(Settings.SaveDelay, function()
		if token == saveToken then
			saveRemote:FireServer(current)
		end
	end)
end

local function change(key: string, value: any)
	local nextSettings = table.clone(current) :: any
	nextSettings[key] = value
	current = SettingsLogic.sanitize(Settings, nextSettings)
	apply()
	scheduleSave()
end

local function row(index: number, title: string, key: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = key
	frame.BackgroundColor3 = COLOR.Row
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset(14, 56 + (index - 1) * (ROW_HEIGHT + 8))
	frame.Size = UDim2.new(1, -28, 0, ROW_HEIGHT)
	rounded(frame, 12)
	frame.Parent = panel
	text(frame, {
		Text = title,
		TextSize = 18,
		TextWrapped = true,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0.5, -14, 1, 0),
	})
	return frame
end

-- 볼륨: [-] 막대 [+], 값은 % 로
local function volumeRow(index: number, title: string, key: string)
	local frame = row(index, title, key)
	local minus = button(frame, {
		Name = "Minus",
		Text = "-",
		TextSize = 24,
		BackgroundColor3 = COLOR.Step,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(38, 36),
	})
	local back = Instance.new("Frame")
	back.BackgroundColor3 = COLOR.BarBack
	back.BorderSizePixel = 0
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0.5, 46, 0.5, 0)
	back.Size = UDim2.new(0.5, -138, 0, 14)
	rounded(back, 7)
	back.Parent = frame
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = COLOR.Bar
	fill.BorderSizePixel = 0
	rounded(fill, 7)
	fill.Parent = back
	local plus = button(frame, {
		Name = "Plus",
		Text = "+",
		TextSize = 24,
		BackgroundColor3 = COLOR.Step,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(38, 36),
	})
	local value = text(frame, {
		TextSize = 16,
		TextColor3 = COLOR.Soft,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(36, 24),
	})
	minus.Activated:Connect(function()
		change(key, SettingsLogic.stepVolume(Settings, (current :: any)[key], -1))
	end)
	plus.Activated:Connect(function()
		change(key, SettingsLogic.stepVolume(Settings, (current :: any)[key], 1))
	end)
	table.insert(refreshers, function()
		local v = (current :: any)[key] :: number
		fill.Size = UDim2.fromScale(v, 1)
		fill.Visible = v > 0
		value.Text = string.format("%d%%", math.round(v * 100))
	end)
end

-- 두 값 중 하나를 고르는 칸 (켬/끔, 스카이 캠/1인칭)
local function choiceRow(index: number, title: string, options: { { label: string, value: any } }, key: string)
	local frame = row(index, title, key)
	local buttons = {}
	for i, option in options do
		local b = button(frame, {
			Name = "Option" .. i,
			Text = option.label,
			TextSize = 16,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.5 + (i - 1) * 0.25, 0.5),
			Size = UDim2.new(0.25, -8, 0, 36),
		})
		b.Activated:Connect(function()
			change(key, option.value)
		end)
		buttons[i] = b
	end
	table.insert(refreshers, function()
		for i, option in options do
			buttons[i].BackgroundColor3 = if (current :: any)[key] == option.value then COLOR.On else COLOR.Off
		end
	end)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "SkyhopSettings"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = COLOR.Panel
	rounded(panel, 16)
	uiScale = Instance.new("UIScale")
	uiScale.Parent = panel
	panel.Parent = gui
	text(panel, {
		Text = t("SettingsTitle"),
		TextSize = 26,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -80, 0, 40),
	})
	local close = button(panel, {
		Name = "Close",
		Text = "X",
		BackgroundColor3 = COLOR.Off,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(40, 36),
	})
	close.Modal = true -- 창이 열려 있는 동안 1인칭의 마우스 고정을 푼다
	close.Activated:Connect(SettingsUi.close)

	volumeRow(1, t("SettingsMusic"), "music")
	volumeRow(2, t("SettingsSounds"), "sounds")
	local onOff = { { label = t("SettingsOn"), value = true }, { label = t("SettingsOff"), value = false } }
	choiceRow(3, t("SettingsShake"), onOff, "shake")
	choiceRow(4, t("SettingsMarker"), onOff, "marker")
	choiceRow(
		5,
		t("SettingsView"),
		{ { label = t("SettingsViewSky"), value = "Sky" }, { label = t("SettingsViewFirst"), value = "First" } },
		"view"
	)
	text(panel, {
		Text = t("SettingsNote"),
		TextSize = 14,
		TextColor3 = COLOR.Soft,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -8),
		Size = UDim2.new(1, -32, 0, 20),
	})
end

-- Roblox 메뉴 막대 아래 남는 자리에 맞춘다. 가로 폰처럼 높이가 모자라면 통째로 줄이고, 폭은 화면에 맞춘다
local function layout()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local topLeft, bottomRight = GuiService:GetGuiInset()
	local room = viewport - topLeft - bottomRight
	local height = 56 + 5 * (ROW_HEIGHT + 8) + 30
	local scale = math.min(1, (room.Y - 16) / height)
	uiScale.Scale = scale
	panel.Size = UDim2.fromOffset(math.min(520, (room.X - 24) / scale), height)
end

function SettingsUi.open()
	if not gui then
		return -- 아직 서버의 저장 Remote를 기다리는 중
	end
	layout()
	gui.Enabled = true
end

function SettingsUi.close()
	gui.Enabled = false
end

function SettingsUi.toggle()
	if gui and gui.Enabled then
		SettingsUi.close()
	else
		SettingsUi.open()
	end
end

function SettingsUi.start(skyCameraModule, landingMarkerModule)
	skyCamera = skyCameraModule
	landingMarker = landingMarkerModule
	saveRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Remotes.SettingsSave) :: RemoteEvent
	build()

	-- 서버가 프로필을 읽으면 Settings 속성이 온다 (저장 뒤에도 같은 값이 다시 온다)
	local function load()
		local raw = player:GetAttribute("Settings")
		if type(raw) ~= "string" then
			return
		end
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		current = SettingsLogic.sanitize(Settings, if ok then decoded else nil)
		apply()
	end
	load()
	player:GetAttributeChangedSignal("Settings"):Connect(function()
		-- 처음 프로필을 읽었을 때만 받는다. 그 뒤로는 이 화면에서 바꾼 값이 기준이다 (저장 대기 중에 덮어쓰지 않게)
		if saveToken == 0 then
			load()
		end
	end)

	-- 키보드 V·L로 바꾼 것도 저장한다
	skyCamera.onModeChanged:Connect(function(mode)
		if not applying and mode ~= current.view then
			change("view", mode)
		end
	end)
	landingMarker.onToggled:Connect(function(enabled)
		if not applying and enabled ~= current.marker then
			change("marker", enabled)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.O then
			SettingsUi.toggle()
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if gui.Enabled then
				layout()
			end
		end)
	end
end

return SettingsUi

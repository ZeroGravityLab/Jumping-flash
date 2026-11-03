-- 의뢰 화면: 주민 대화창, 진행 표시, 결과 창, 실패 알림
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Strings = require(ReplicatedStorage.Shared.Strings)

local player = Players.LocalPlayer

local COLOR = {
	Panel = Color3.fromRGB(24, 34, 58),
	Text = Color3.fromRGB(255, 255, 255),
	Soft = Color3.fromRGB(200, 214, 240),
	Accept = Color3.fromRGB(96, 186, 120),
	gold = Color3.fromRGB(255, 205, 60),
	silver = Color3.fromRGB(210, 220, 235),
	bronze = Color3.fromRGB(220, 150, 100),
	Fail = Color3.fromRGB(255, 150, 150),
}
local MEDAL_KEY = { gold = "MedalGold", silver = "MedalSilver", bronze = "MedalBronze" }
local RESULT_SECONDS = 4

local RequestUi = {}

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function clock(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function rounded(inst: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
end

local function panel(parent: Instance, props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = COLOR.Panel
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	for key, value in props do
		(frame :: any)[key] = value
	end
	rounded(frame, 14)
	frame.Parent = parent
	return frame
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = COLOR.Text
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	return text
end

local function button(parent: Instance, color: Color3, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = position
	b.Size = UDim2.fromOffset(120, 40)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = COLOR.Text
	b.TextSize = 22
	rounded(b, 12)
	b.Parent = parent
	return b
end

local gui: ScreenGui
local dialog, tracker, result: Frame
local dialogName, dialogLine, dialogGoal, dialogMedals, dialogBest: TextLabel
local startButton, laterButton: TextButton
local trackerGoal, trackerProgress, trackerTime: TextLabel
local resultTitle, resultMedal, resultDetail: TextLabel
local toastLabel: TextLabel
local onStartCallback: (() -> ())? = nil
local resultToken = 0

function RequestUi.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "SkyhopRequests"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	dialog = panel(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(560, 200),
	})
	dialogName = label(dialog, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 28), TextSize = 26 })
	dialogLine = label(dialog, {
		Position = UDim2.fromOffset(20, 44),
		Size = UDim2.new(1, -40, 0, 52),
		TextSize = 19,
		TextColor3 = COLOR.Soft,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	dialogGoal = label(dialog, { Position = UDim2.fromOffset(20, 100), Size = UDim2.new(1, -40, 0, 24), TextSize = 20 })
	dialogMedals = label(dialog, {
		Position = UDim2.fromOffset(20, 128),
		Size = UDim2.new(1, -300, 0, 20),
		TextSize = 16,
		TextColor3 = COLOR.gold,
	})
	dialogBest = label(dialog, {
		Position = UDim2.fromOffset(20, 152),
		Size = UDim2.new(1, -300, 0, 20),
		TextSize = 16,
		TextColor3 = COLOR.Soft,
	})
	dialog.Name = "Dialog"
	startButton = button(dialog, COLOR.Accept, UDim2.new(1, -16, 1, -16))
	startButton.Name = "StartButton"
	laterButton = button(dialog, Color3.fromRGB(90, 100, 130), UDim2.new(1, -146, 1, -16))
	laterButton.Name = "LaterButton"
	startButton.Activated:Connect(function()
		dialog.Visible = false
		local callback = onStartCallback
		onStartCallback = nil
		if callback then
			callback()
		end
	end)
	laterButton.Activated:Connect(RequestUi.hideDialog)

	tracker = panel(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 220),
		Size = UDim2.fromOffset(320, 84),
	})
	trackerGoal = label(tracker, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 40), TextSize = 17 })
	trackerProgress = label(tracker, {
		Position = UDim2.fromOffset(14, 52),
		Size = UDim2.new(0.5, -14, 0, 24),
		TextSize = 22,
		TextColor3 = COLOR.gold,
	})
	trackerTime = label(tracker, {
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(0.5, -14, 0, 24),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	result = panel(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(380, 170),
	})
	resultTitle = label(result, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	resultMedal = label(result, {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	resultDetail = label(result, {
		Position = UDim2.fromOffset(20, 96),
		Size = UDim2.new(1, -40, 0, 60),
		TextSize = 18,
		TextColor3 = COLOR.Soft,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	tracker.Name = "Tracker"
	result.Name = "Result"
	toastLabel = label(gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(600, 32),
		Text = "",
		TextSize = 24,
		TextColor3 = COLOR.Fail,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
	})
	-- 외곽선도 숨겨 두어야 빈 알림이 비쳐 보이지 않는다
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(60, 30, 40)
	stroke.Transparency = 1
	stroke.Parent = toastLabel
end

function RequestUi.text(key: string, ...: any): string
	return t(key, ...)
end

-- 주민 대화. request가 nil이면 부탁할 게 없다는 인사만
function RequestUi.showDialog(residentId: string, request, record, onStart: () -> ())
	dialogName.Text = residentId
	if not request then
		dialogLine.Text = t("ResidentDone")
		dialogGoal.Text = ""
		dialogMedals.Text = ""
		dialogBest.Text = ""
		startButton.Visible = false
		laterButton.Text = t("Ok")
	else
		dialogLine.Text = t("Req_" .. request.id .. "_Line")
		dialogGoal.Text = t("Goal", t("Req_" .. request.id .. "_Goal"))
		dialogMedals.Text = t("MedalTimes", request.gold, request.silver)
		dialogBest.Text = if record then t("BestRecord", t(MEDAL_KEY[record.medal]), clock(record.bestTime)) else ""
		startButton.Visible = true
		startButton.Text = t("Start")
		laterButton.Text = t("Later")
	end
	onStartCallback = onStart
	dialog.Visible = true
end

function RequestUi.hideDialog()
	dialog.Visible = false
	onStartCallback = nil
end

function RequestUi.isDialogOpen(): boolean
	return dialog.Visible
end

function RequestUi.showTracker(request)
	trackerGoal.Text = t("Req_" .. request.id .. "_Goal")
	trackerProgress.Text = ""
	trackerTime.Text = clock(0)
	tracker.Visible = true
end

function RequestUi.setProgress(done: number, total: number)
	trackerProgress.Text = t("Progress", done, total)
end

function RequestUi.setTime(seconds: number)
	trackerTime.Text = clock(seconds)
end

function RequestUi.hideTracker()
	tracker.Visible = false
end

function RequestUi.showResult(data)
	resultToken += 1
	local token = resultToken
	resultTitle.Text = t("ResultTitle")
	resultMedal.Text = t(MEDAL_KEY[data.medal])
	resultMedal.TextColor3 = COLOR[data.medal]
	local lines = { t("ResultTime", clock(data.time)) }
	if data.coins > 0 then
		table.insert(lines, t("ResultCoins", data.coins))
	end
	if data.bellNeeded > 0 then
		table.insert(lines, t("ResultBell", data.bell, data.bellNeeded))
	end
	resultDetail.Text = table.concat(lines, "\n")
	result.Visible = true
	task.delay(RESULT_SECONDS, function()
		if token == resultToken then
			result.Visible = false
		end
	end)
end

function RequestUi.toast(text: string)
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	local stroke = toastLabel:FindFirstChildOfClass("UIStroke")
	stroke.Transparency = 0
	local fade = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.2)
	TweenService:Create(toastLabel, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
end

return RequestUi

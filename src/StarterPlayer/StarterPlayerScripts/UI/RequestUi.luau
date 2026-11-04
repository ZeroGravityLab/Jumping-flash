-- 의뢰 화면: 주민 대화창, 진행 표시, 결과 창, 주민 이야기 엔딩 카드, 실패 알림
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
local storyCard: Frame
local storyTitle, storyLines, storyChange: TextLabel
local onStartCallback: (() -> ())? = nil
local onStoryClosed: (() -> ())? = nil
local resultToken = 0
local STORY_SECONDS = 14 -- 엔딩 카드는 이만큼 뒤에 저절로 닫힌다

-- 대화창 글자 배치: 넓은 화면과 좁은 화면(세로 휴대폰). 좁으면 메달 기준을 버튼 위 전체 폭으로 쓴다
local DIALOG_LAYOUT = {
	wide = {
		height = 200,
		name = { y = 12, h = 28, size = 26 },
		line = { y = 44, h = 52, size = 19 },
		goal = { y = 100, h = 24, size = 20 },
		medals = { y = 128, size = 16 },
		best = { y = 152, size = 16 },
		textInset = 300,
	},
	narrow = {
		height = 250,
		name = { y = 10, h = 24, size = 22 },
		line = { y = 38, h = 66, size = 16 },
		goal = { y = 106, h = 40, size = 17 },
		medals = { y = 150, size = 15 },
		best = { y = 170, size = 15 },
		textInset = 40,
	},
}

-- 화면 크기에 맞춘 배치. 터치 기기는 오른쪽 아래(밟기·점프 버튼)를 비우고,
-- 세로 화면에서는 위쪽 고도 표시 아래로 내린다
local function layout()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local touch = UserInputService.TouchEnabled
	local portrait = viewport.Y > viewport.X

	local width = math.min(560, viewport.X - 24)
	local spec = if width < 520 then DIALOG_LAYOUT.narrow else DIALOG_LAYOUT.wide
	dialog.Size = UDim2.fromOffset(width, spec.height)
	for _, item in
		{
			{ dialogName, spec.name },
			{ dialogLine, spec.line },
			{ dialogGoal, spec.goal },
		}
	do
		item[1].Position = UDim2.fromOffset(20, item[2].y)
		item[1].Size = UDim2.new(1, -40, 0, item[2].h)
		item[1].TextSize = item[2].size
	end
	for _, item in { { dialogMedals, spec.medals }, { dialogBest, spec.best } } do
		item[1].Position = UDim2.fromOffset(20, item[2].y)
		item[1].Size = UDim2.new(1, -spec.textInset, 0, 20)
		item[1].TextSize = item[2].size
	end

	if not touch then
		tracker.AnchorPoint = Vector2.new(1, 0)
		tracker.Position = UDim2.new(1, -12, 0, 220)
		tracker.Size = UDim2.fromOffset(320, 84)
	elseif portrait then
		tracker.AnchorPoint = Vector2.new(0, 0)
		tracker.Position = UDim2.fromOffset(12, 118)
		tracker.Size = UDim2.fromOffset(math.min(280, viewport.X - 134), 84)
	else
		tracker.AnchorPoint = Vector2.new(0, 0)
		tracker.Position = UDim2.fromOffset(12, 8)
		tracker.Size = UDim2.fromOffset(250, 84)
	end
	trackerGoal.TextSize = if touch then 15 else 17

	result.Size = UDim2.fromOffset(math.min(380, viewport.X - 24), 170)
	storyCard.Size = UDim2.fromOffset(math.min(540, viewport.X - 24), if viewport.X < 520 then 330 else 290)
	toastLabel.Position = UDim2.new(0.5, 0, 0, if touch and portrait then 214 else 120)
	toastLabel.Size = UDim2.fromOffset(math.min(600, viewport.X - 24), 56)
	toastLabel.TextSize = if viewport.X < 600 then 20 else 24
end

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
	dialogName = label(dialog, {})
	dialogLine = label(dialog, { TextColor3 = COLOR.Soft, TextYAlignment = Enum.TextYAlignment.Top })
	dialogGoal = label(dialog, { TextYAlignment = Enum.TextYAlignment.Top })
	dialogMedals = label(dialog, { TextColor3 = COLOR.gold })
	dialogBest = label(dialog, { TextColor3 = COLOR.Soft })
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

	tracker = panel(gui, {})
	trackerGoal = label(tracker, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 40) })
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

	-- 주민 이야기 엔딩 카드
	storyCard = panel(gui, {
		Name = "Story",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
	})
	label(storyCard, {
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 22),
		TextSize = 18,
		TextColor3 = COLOR.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = t("StoryComplete"),
	})
	storyTitle = label(storyCard, {
		Position = UDim2.fromOffset(20, 38),
		Size = UDim2.new(1, -40, 0, 34),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- 대사는 남는 높이를 모두 쓰고, 바뀐 것 안내는 버튼 바로 위
	storyLines = label(storyCard, {
		Position = UDim2.fromOffset(24, 80),
		Size = UDim2.new(1, -48, 1, -196),
		TextSize = 17,
		TextColor3 = COLOR.Soft,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	storyChange = label(storyCard, {
		Position = UDim2.new(0, 24, 1, -108),
		Size = UDim2.new(1, -48, 0, 46),
		TextSize = 16,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local storyOk = button(storyCard, COLOR.Accept, UDim2.new(1, -16, 1, -12))
	storyOk.Name = "OkButton"
	storyOk.Text = t("Ok")
	storyOk.Activated:Connect(RequestUi.hideStory)

	tracker.Name = "Tracker"
	result.Name = "Result"
	toastLabel = label(gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "",
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

	layout()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
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

function RequestUi.setCountdown(seconds: number)
	trackerProgress.Text = t("RaceCountdown", seconds)
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

-- 주민 이야기 엔딩: 제목, 주민들의 대사, 허브에서 바뀐 것. 닫히면 onClosed를 부른다
function RequestUi.showStory(storyId: string, onClosed: (() -> ())?)
	storyTitle.Text = t("Story_" .. storyId .. "_Title")
	storyLines.Text = t("Story_" .. storyId .. "_Line")
	storyChange.Text = t("Story_" .. storyId .. "_Change")
	onStoryClosed = onClosed
	storyCard.Visible = true
	task.delay(STORY_SECONDS, function()
		if storyCard.Visible and onStoryClosed == onClosed then
			RequestUi.hideStory()
		end
	end)
end

-- 대화창이나 엔딩 카드가 떠 있는가 (다른 화면이 그 뒤에 비치지 않게 숨길 때)
function RequestUi.isBusy(): boolean
	return dialog.Visible or storyCard.Visible
end

function RequestUi.hideStory()
	storyCard.Visible = false
	local callback = onStoryClosed
	onStoryClosed = nil
	if callback then
		callback()
	end
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

-- 의뢰 목표 표시 (GDD 6.4): 남은 목표 위에 아이콘과 거리, 가장 가까운 목표가 화면 밖이면 그쪽 가장자리에 화살표.
-- 이 클라이언트에만 그린다. 숨은 수집품처럼 찾는 재미가 핵심인 것에는 쓰지 않는다
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local COLOR = {
	Icon = Color3.fromRGB(255, 205, 60),
	Stroke = Color3.fromRGB(70, 46, 20),
	Text = Color3.fromRGB(255, 255, 255),
	TextStroke = Color3.fromRGB(40, 60, 90),
	Badge = Color3.fromRGB(30, 40, 62),
}
local NEAR = 16 -- 이보다 가까우면 표시를 숨겨 목표물 자체를 보게 한다
local LIFT = 5 -- 목표 위로 띄우는 높이
local EDGE_MARGIN = 48 -- 화면 밖 화살표가 가장자리에서 떨어진 거리(px)

type Mark = { position: Vector3, billboard: BillboardGui, label: TextLabel }

local Waypoints = {}

local hop
local anchor: Part
local arrow: Frame
local arrowLabel: TextLabel
local marks: { Mark } = {}

local function stroke(parent: GuiObject, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function distanceLabel(parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 15
	label.TextColor3 = COLOR.Text
	label.TextStrokeColor3 = COLOR.TextStroke
	label.TextStrokeTransparency = 0
	label.Parent = parent
	return label
end

local function diamond(parent: Instance, size: number, y: number)
	local icon = Instance.new("Frame")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0, y)
	icon.Size = UDim2.fromOffset(size, size)
	icon.Rotation = 45
	icon.BackgroundColor3 = COLOR.Icon
	icon.BorderSizePixel = 0
	stroke(icon, COLOR.Stroke, 2)
	icon.Parent = parent
end

-- 목표 위치 목록을 통째로 바꾼다 (빈 목록이면 모두 지운다)
function Waypoints.set(positions: { Vector3 })
	for _, mark in marks do
		mark.billboard.Parent:Destroy()
	end
	table.clear(marks)
	for _, position in positions do
		local attachment = Instance.new("Attachment")
		attachment.Position = position + Vector3.new(0, LIFT, 0) -- anchor가 원점이라 월드 좌표와 같다
		attachment.Parent = anchor
		local billboard = Instance.new("BillboardGui")
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.MaxDistance = math.huge
		billboard.Size = UDim2.fromOffset(64, 46)
		billboard.Parent = attachment
		diamond(billboard, 16, 12)
		local label = distanceLabel(billboard)
		label.Position = UDim2.fromOffset(0, 24)
		label.Size = UDim2.new(1, 0, 0, 18)
		table.insert(marks, { position = position, billboard = billboard, label = label })
	end
	if #marks == 0 then
		arrow.Visible = false
		arrowLabel.Visible = false
	end
end

function Waypoints.clear()
	Waypoints.set({})
end

local function meters(d: number): string
	return string.format("%d m", math.floor(d + 0.5))
end

-- 화면 밖 목표 쪽 가장자리 표시: 원 위로 뾰족한 끝이 튀어나온 핀 모양을 목표 쪽으로 돌린다.
-- 꺾쇠(^)를 쓰면 기울었을 때 "7"이나 모서리처럼 읽혔다
local function buildArrow(gui: ScreenGui)
	arrow = Instance.new("Frame")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(44, 44)
	arrow.BackgroundTransparency = 1
	arrow.Visible = false
	arrow.Parent = gui
	-- 원 뒤에 놓은 마름모의 윗부분만 보여 끝이 된다 (형제 ZIndex로 순서를 정한다)
	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.new(0.5, 0, 0, 6)
	tip.Size = UDim2.fromOffset(18, 18)
	tip.Rotation = 45
	tip.BackgroundColor3 = COLOR.Icon
	tip.BorderSizePixel = 0
	tip.ZIndex = 1
	stroke(tip, COLOR.Stroke, 2)
	tip.Parent = arrow
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.new(0.5, 0, 0.5, 3)
	disc.Size = UDim2.fromOffset(34, 34)
	disc.BackgroundColor3 = COLOR.Badge
	disc.BorderSizePixel = 0
	disc.ZIndex = 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc
	stroke(disc, COLOR.Icon, 2)
	disc.Parent = arrow
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(12, 12)
	dot.Rotation = 45
	dot.BackgroundColor3 = COLOR.Icon
	dot.BorderSizePixel = 0
	dot.ZIndex = 3
	dot.Parent = disc
	arrowLabel = distanceLabel(gui)
	arrowLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowLabel.Size = UDim2.fromOffset(70, 20)
	arrowLabel.Visible = false
end

local function update()
	if #marks == 0 then
		return
	end
	local root = hop.rootPart()
	local camera = workspace.CurrentCamera
	if not (root and camera) then
		return
	end
	local nearest: Mark? = nil
	local nearestDistance = math.huge
	for _, mark in marks do
		local d = (mark.position - root.Position).Magnitude
		mark.billboard.Enabled = d > NEAR
		mark.label.Text = meters(d)
		if d < nearestDistance then
			nearest, nearestDistance = mark, d
		end
	end
	if not nearest then
		return
	end

	local point, onScreen = camera:WorldToViewportPoint(nearest.position + Vector3.new(0, LIFT, 0))
	if (onScreen and point.Z > 0) or nearestDistance <= NEAR then
		arrow.Visible = false
		arrowLabel.Visible = false
		return
	end
	-- 화면 가운데에서 목표 쪽으로 뻗은 방향이 가장자리 사각형과 만나는 곳 (카메라 뒤면 방향을 뒤집는다)
	local center = camera.ViewportSize / 2
	local direction = Vector2.new(point.X, point.Y) - center
	if point.Z < 0 then
		direction = -direction
	end
	direction = if direction.Magnitude > 1e-3 then direction.Unit else Vector2.new(0, -1)
	local half = center - Vector2.new(EDGE_MARGIN, EDGE_MARGIN)
	local reach =
		math.min(half.X / math.max(math.abs(direction.X), 1e-3), half.Y / math.max(math.abs(direction.Y), 1e-3))
	local at = center + direction * reach
	arrow.Position = UDim2.fromOffset(at.X, at.Y)
	arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
	arrow.Visible = true
	local labelAt = at - direction * 34
	arrowLabel.Position = UDim2.fromOffset(labelAt.X, labelAt.Y)
	arrowLabel.Text = meters(nearestDistance)
	arrowLabel.Visible = true
end

function Waypoints.start(hopController)
	hop = hopController
	anchor = Instance.new("Part")
	anchor.Name = "WaypointAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.identity
	anchor.Parent = hop.localFolder

	-- 화살표는 화면 전체 좌표(WorldToViewportPoint)를 쓰므로 상단 인셋을 무시한다
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkyhopWaypoints"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")
	buildArrow(gui)

	RunService.RenderStepped:Connect(update)
end

return Waypoints

-- 스카이 캠(3인칭)과 1인칭. 하강하면 시선이 자동으로 아래를 향한다 (다이브 캠, GDD 5.4).
-- 기본 카메라 모듈은 Scriptable 타입에서 멈추므로 시점·마우스 동작은 전부 여기서 맡는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraConfig = require(ReplicatedStorage.Config.Camera)
local Movement = require(ReplicatedStorage.Config.Movement)
local Signal = require(ReplicatedStorage.Shared.Signal)

local player = Players.LocalPlayer

local SkyCamera = {
	mode = CameraConfig.DefaultMode, -- "Sky" | "First"
	onModeChanged = Signal.new(),
	shakeEnabled = true, -- 멀미에 약한 사람을 위해 설정에서 끌 수 있게 둔다
}

local fallEffect = 0 -- 0~1, 빠르게 떨어질수록 커진다

-- 빠른 낙하: 시야가 넓어지고 화면이 미세하게 떨린다 (고소공포 연출)
local function fallKick(hop, dt: number): (number, Vector3)
	local target = math.clamp((-hop.verticalSpeed() - 30) / (Movement.TerminalFall - 30), 0, 1)
	fallEffect += (target - fallEffect) * (1 - math.exp(-6 * dt))
	local fovBonus = CameraConfig.FallFovBonus * fallEffect
	local shake = Vector3.zero
	if SkyCamera.shakeEnabled and fallEffect > CameraConfig.FallShakeFrom then
		local amount = CameraConfig.FallShake
			* (fallEffect - CameraConfig.FallShakeFrom)
			/ (1 - CameraConfig.FallShakeFrom)
		local t = os.clock() * 14
		shake = Vector3.new(math.noise(t, 0.3), math.noise(0.7, t), math.noise(t, 1.9)) * amount
	end
	return fovBonus, shake
end

local PITCH_MIN = math.rad(CameraConfig.PitchMin)
local PITCH_MAX = math.rad(CameraConfig.PitchMax)

local yaw = 0
local pitch = math.rad(CameraConfig.DefaultPitch)
local autoPitch = 0
local zoom = CameraConfig.Distance
local rotating = false
local cameraTouches = {}
local stick = Vector2.zero

-- 일방향 구름처럼 지금 통과 중인 것에 카메라가 걸리지 않게 충돌 여부를 따른다
local occlusionParams = RaycastParams.new()
occlusionParams.FilterType = Enum.RaycastFilterType.Exclude
occlusionParams.RespectCanCollide = true

local dropParams = RaycastParams.new()
dropParams.FilterType = Enum.RaycastFilterType.Exclude

-- 창(설정·상점·지도·대화)의 Modal 버튼이 화면에 보이면 1인칭이어도 마우스를 풀고 시점을 돌리지 않는다
local modalButtons: { [GuiButton]: true } = {}

local function shownOnScreen(item: Instance): boolean
	local node: Instance? = item
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") then
			return (node :: ScreenGui).Enabled
		end
		node = node.Parent
	end
	return false
end

local function cursorFree(): boolean
	for b in modalButtons do
		if shownOnScreen(b) then
			return true
		end
	end
	return false
end

local function turn(yawDelta: number, pitchDelta: number)
	yaw -= yawDelta
	pitch = math.clamp(pitch - pitchDelta, PITCH_MIN, PITCH_MAX)
end

local function setCharacterHidden(character: Model, hidden: boolean)
	local modifier = if hidden then 1 else 0
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = modifier
		end
	end
end

-- 카메라가 캐릭터 뒤에서 target 쪽을 보게 돌린다 (러시 출발처럼 순간이동한 뒤)
function SkyCamera.faceToward(target: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local d = target - root.Position
	if Vector3.new(d.X, 0, d.Z).Magnitude > 1e-3 then
		yaw = math.atan2(-d.X, -d.Z)
	end
end

-- 설정에서 저장된 시점을 되살릴 때
function SkyCamera.setMode(mode: string)
	if mode ~= SkyCamera.mode then
		SkyCamera.toggle()
	end
end

function SkyCamera.toggle()
	SkyCamera.mode = if SkyCamera.mode == "Sky" then "First" else "Sky"
	local character = player.Character
	if character and SkyCamera.mode == "Sky" then
		setCharacterHidden(character, false)
	end
	SkyCamera.onModeChanged:Fire(SkyCamera.mode)
end

-- 떨어지는 중이고 발밑이 충분히 깊을 때만 내려다본다 (작은 턱에서는 흔들지 않는다)
local function isDiving(hop, exclude: { Instance }): boolean
	if hop.isGrounded() or hop.verticalSpeed() > -CameraConfig.DiveMinFallSpeed then
		return false
	end
	dropParams.FilterDescendantsInstances = exclude
	return workspace:Raycast(hop.feetPosition(), Vector3.new(0, -CameraConfig.DiveMinDrop, 0), dropParams) == nil
end

local function update(hop, dt: number)
	local camera = workspace.CurrentCamera
	local character = hop.character()
	local root = hop.rootPart()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (camera and root and humanoid) then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	if stick.Magnitude > CameraConfig.StickDeadzone then
		local speed = math.rad(CameraConfig.GamepadSpeed) * dt
		turn(stick.X * speed, -stick.Y * speed)
	end

	local exclude = { character, hop.localFolder }
	local target = if isDiving(hop, exclude) then math.rad(CameraConfig.DiveAngle) else 0
	local rate = if target > autoPitch then CameraConfig.DiveInRate else CameraConfig.DiveOutRate
	autoPitch += (target - autoPitch) * (1 - math.exp(-rate * dt))

	local rotation = CFrame.fromEulerAnglesYXZ(math.clamp(pitch - autoPitch, PITCH_MIN, PITCH_MAX), yaw, 0)
	local altitude01 = math.clamp(hop.altitude() / CameraConfig.SkyCamAltitude, 0, 1)
	local fovBonus, shake = fallKick(hop, dt)
	camera.FieldOfView = CameraConfig.Fov + (CameraConfig.FovMax - CameraConfig.Fov) * altitude01 + fovBonus

	if SkyCamera.mode == "First" then
		UserInputService.MouseBehavior = if cursorFree()
			then Enum.MouseBehavior.Default
			else Enum.MouseBehavior.LockCenter
		humanoid.AutoRotate = false
		root.CFrame = CFrame.new(root.Position) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
		setCharacterHidden(character, true)
		local eye = root.Position + Vector3.new(0, CameraConfig.FirstPersonHeight, 0)
		camera.CFrame = CFrame.new(eye + shake) * rotation
		camera.Focus = CFrame.new(eye)
	else
		UserInputService.MouseBehavior = if rotating
			then Enum.MouseBehavior.LockCurrentPosition
			else Enum.MouseBehavior.Default
		humanoid.AutoRotate = true
		local focus = root.Position + Vector3.new(0, CameraConfig.FocusHeight, 0)
		local back = -rotation.LookVector * (zoom + CameraConfig.SkyDistanceBonus * altitude01)
		occlusionParams.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(focus, back, occlusionParams)
		if hit then
			back = back.Unit * math.max(0.5, (hit.Position - focus).Magnitude - 0.5)
		end
		camera.CFrame = CFrame.new(focus + back + shake) * rotation
		camera.Focus = CFrame.new(focus)
	end
end

function SkyCamera.start(hop)
	local playerGui = player:WaitForChild("PlayerGui")
	local function track(item: Instance)
		-- 창 코드는 버튼을 붙인 뒤에 Modal을 켜므로 한 박자 늦게 본다
		task.defer(function()
			if item:IsA("GuiButton") and item.Modal and item:IsDescendantOf(playerGui) then
				modalButtons[item] = true
			end
		end)
	end
	for _, item in playerGui:GetDescendants() do
		track(item)
	end
	playerGui.DescendantAdded:Connect(track)
	playerGui.DescendantRemoving:Connect(function(item)
		modalButtons[item :: GuiButton] = nil
	end)

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart")
		local _, characterYaw = root.CFrame:ToEulerAnglesYXZ()
		yaw = characterYaw
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = true
		elseif input.UserInputType == Enum.UserInputType.Touch then
			-- 썸스틱·버튼 위에서 시작한 터치는 processed라 여기 오지 않는다
			cameraTouches[input] = true
		elseif input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.ButtonY then
			SkyCamera.toggle()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = false
		elseif input.UserInputType == Enum.UserInputType.Touch then
			cameraTouches[input] = nil
		end
	end)

	UserInputService.InputChanged:Connect(function(input, processed)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseMovement then
			if rotating or (SkyCamera.mode == "First" and not cursorFree()) then
				local sensitivity = math.rad(CameraConfig.MouseSensitivity)
				turn(input.Delta.X * sensitivity, input.Delta.Y * sensitivity)
			end
		elseif inputType == Enum.UserInputType.Touch then
			if cameraTouches[input] then
				local sensitivity = math.rad(CameraConfig.TouchSensitivity)
				turn(input.Delta.X * sensitivity, input.Delta.Y * sensitivity)
			end
		elseif inputType == Enum.UserInputType.MouseWheel then
			if not processed then
				local zoomed = zoom - input.Position.Z * CameraConfig.ZoomStep
				zoom = math.clamp(zoomed, CameraConfig.ZoomMin, CameraConfig.ZoomMax)
			end
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	RunService:BindToRenderStep("SkyCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		update(hop, dt)
	end)
end

return SkyCamera

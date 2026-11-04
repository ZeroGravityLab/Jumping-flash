-- 3단 점프·정점 퍼펙트·스톰프·반동 (GDD 5.1~5.5).
-- 로컬 캐릭터 물리는 클라이언트 소유라 여기서 즉시 처리한다. 지면 점프는 Humanoid 기본 입력에 맡긴다.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Movement = require(ReplicatedStorage.Config.Movement)
local MovementLogic = require(ReplicatedStorage.Shared.MovementLogic)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)

local player = Players.LocalPlayer

local HopController = {
	onJump = Signal.new(), -- (index, perfect, feetPosition)
	onBounce = Signal.new(), -- (kind: "stomp" | "pad" | "buddy", combo, feetPosition, part?)
	onLand = Signal.new(), -- (stomped, feetPosition)
	onBell = Signal.new(), -- (feetPosition)
	onRespawn = Signal.new(), -- 구름 바다로 떨어져 되돌아왔을 때
	stats = {
		startedAt = os.clock(),
		airJumps = {}, -- ToyStats.AirJump 목록
		stomps = 0,
		bells = 0,
		maxAltitude = 0,
	},
	localFolder = nil :: Folder?, -- 복제되지 않는 클라이언트 전용 파트
}

local character, humanoid, root

local jumpsUsed = 0
local grounded = true
local arcLaunched = false
local stomping = false
local combo = 0
local lastGroundedAt = -math.huge
local groundLockUntil = 0
local lastLaunchAt = -math.huge
local lastJumpRequestAt = -math.huge
local bufferedJumpAt = -math.huge
local launchVelocity: number? = nil -- Humanoid가 덧붙인 초속을 되돌릴 목표값
local lastBellAt = -math.huge
local nearBell = false
local safePosition: Vector3? = nil -- 떨어졌을 때 돌아올 곳: 마지막으로 가장자리가 아닌 땅에 서 있던 자리
local lastSafeCheckAt = 0

local cloudParts, updraftParts, bellParts

local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude

local function trackTag(tag: string): { BasePart }
	local list = CollectionService:GetTagged(tag)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		table.insert(list, instance)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		local index = table.find(list, instance)
		if index then
			table.remove(list, index)
		end
	end)
	return list
end

local function feetOffset(): number
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 3
	end
	return humanoid.HipHeight + root.Size.Y / 2
end

function HopController.character(): Model?
	return character
end

function HopController.rootPart(): BasePart?
	return root
end

function HopController.isGrounded(): boolean
	return grounded
end

function HopController.isStomping(): boolean
	return stomping
end

function HopController.verticalSpeed(): number
	return if root then root.AssemblyLinearVelocity.Y else 0
end

function HopController.feetPosition(): Vector3
	return root.Position - Vector3.new(0, feetOffset(), 0)
end

function HopController.altitude(): number
	if not root then
		return 0
	end
	return math.max(0, HopController.feetPosition().Y - Movement.AltitudeZeroY)
end

function HopController.jumpsLeft(): number
	local used = jumpsUsed
	if not grounded and used == 0 and os.clock() - lastGroundedAt > Movement.CoyoteTime then
		used = 1
	end
	return MovementLogic.maxJumps(Movement) - used
end

local function launch(velocity: number)
	lastLaunchAt = os.clock()
	groundLockUntil = lastLaunchAt + Movement.GroundLockTime
	grounded = false
	arcLaunched = true
	stomping = false
	humanoid.WalkSpeed = Movement.AirSpeed
	-- Humanoid가 점프 상태에서 JumpPower를 초속으로 쓰므로 둘을 맞춘다
	humanoid.JumpPower = velocity
	launchVelocity = velocity
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, velocity, v.Z)
end

local function land(now: number)
	local wasStomping = stomping
	grounded = true
	jumpsUsed = 0
	arcLaunched = false
	stomping = false
	combo = 0
	humanoid.WalkSpeed = Movement.WalkSpeed
	humanoid.JumpPower = Movement.JumpVelocity[1]
	HopController.onLand:Fire(wasStomping, HopController.feetPosition())

	if now - bufferedJumpAt <= Movement.JumpBuffer then
		bufferedJumpAt = -math.huge
		jumpsUsed = 1
		launch(Movement.JumpVelocity[1])
		HopController.onJump:Fire(1, false, HopController.feetPosition())
	end
end

local function resetAirState()
	jumpsUsed = 0
	grounded = false
	arcLaunched = false
	stomping = false
	combo = 0
	lastGroundedAt = -math.huge
	bufferedJumpAt = -math.huge
	humanoid.WalkSpeed = Movement.AirSpeed
	humanoid.JumpPower = Movement.JumpVelocity[1]
end

local function respawnAfterFall()
	local target
	if safePosition then
		target = CFrame.new(safePosition + Vector3.new(0, 3, 0))
	else
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		target = if spawn then spawn.CFrame + Vector3.new(0, 5, 0) else CFrame.new(0, 20, 0)
	end
	character:PivotTo(target)
	root.AssemblyLinearVelocity = Vector3.zero
	resetAirState()
	HopController.onRespawn:Fire()
end

local safeParams = RaycastParams.new()
safeParams.FilterType = Enum.RaycastFilterType.Exclude

-- 발밑 사방이 모두 땅이면(가장자리가 아니면) 돌아올 자리로 기억한다
local function rememberSafeGround(now: number)
	if now - lastSafeCheckAt < 0.5 then
		return
	end
	lastSafeCheckAt = now
	safeParams.FilterDescendantsInstances = { character, HopController.localFolder }
	local feet = HopController.feetPosition()
	for _, offset in { Vector3.new(4, 0, 0), Vector3.new(-4, 0, 0), Vector3.new(0, 0, 4), Vector3.new(0, 0, -4) } do
		if not workspace:Raycast(feet + offset + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), safeParams) then
			return
		end
	end
	safePosition = root.Position
end

local function onJumpPressed()
	if not root or humanoid.Health <= 0 or grounded then
		return -- 지면 점프는 Humanoid 기본 입력이 처리한다
	end
	local now = os.clock()
	local rising = root.AssemblyLinearVelocity.Y > Movement.LandingMaxVy
	if humanoid.FloorMaterial ~= Enum.Material.Air and not rising and now >= groundLockUntil then
		return -- 이번 프레임에 막 착지했다
	end

	local jump = MovementLogic.resolveAirJump(Movement, {
		jumpsUsed = jumpsUsed,
		sinceGrounded = now - lastGroundedAt,
		vy = root.AssemblyLinearVelocity.Y,
		arcLaunched = arcLaunched,
	})
	if not jump then
		bufferedJumpAt = now
		return
	end

	jumpsUsed = jump.index
	launch(jump.velocity)
	if jump.index > 1 then
		table.insert(HopController.stats.airJumps, {
			t = now - HopController.stats.startedAt,
			perfect = jump.perfect,
		})
	end
	HopController.onJump:Fire(jump.index, jump.perfect, HopController.feetPosition())
end

function HopController.stomp()
	if not root or grounded or stomping or humanoid.Health <= 0 then
		return
	end
	stomping = true
	humanoid.WalkSpeed = 0 -- 급강하 중에는 수평 이동을 막는다
	root.AssemblyLinearVelocity = Vector3.new(0, -Movement.StompDive, 0)
end

local function bounce(kind: string, velocity: number, part: BasePart?)
	if kind == "pad" then
		jumpsUsed = 1
	else
		jumpsUsed = MovementLogic.jumpsAfterBounce(Movement, jumpsUsed)
		combo += 1
	end
	launch(velocity)
	HopController.onBounce:Fire(kind, combo, HopController.feetPosition(), part)
end

local function popPuffling(part: BasePart)
	part.Transparency = 1
	part.CanQuery = false
	task.delay(Movement.PufflingRespawn, function()
		part.Transparency = 0
		part.CanQuery = true
	end)
end

local function isOtherCharacter(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model ~= character and Players:GetPlayerFromCharacter(model) ~= nil
end

local function probeBelow(extra: number): RaycastResult?
	probeParams.FilterDescendantsInstances = { character, HopController.localFolder }
	local distance = math.max(0.1, feetOffset() - Movement.ProbeRadius + extra)
	return workspace:Spherecast(root.Position, Movement.ProbeRadius, Vector3.new(0, -distance, 0), probeParams)
end

-- 하강 중 발밑에 밟을 것이 있으면 튀어 오른다
local function tryBounce(hit: RaycastResult): boolean
	local part = hit.Instance
	if CollectionService:HasTag(part, Tags.Stompable) then
		popPuffling(part)
		HopController.stats.stomps += 1
		bounce("stomp", Movement.StompBounce, part)
	elseif CollectionService:HasTag(part, Tags.BouncePad) then
		bounce("pad", Movement.BouncePadVelocity, part)
	elseif isOtherCharacter(part) then
		bounce("buddy", Movement.StompBounce * Movement.BuddyBounceMult, part)
	else
		return false
	end
	return true
end

local function isInside(part: BasePart, position: Vector3): boolean
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function applyUpdraft()
	for _, updraft in updraftParts do
		if isInside(updraft, root.Position) then
			local v = root.AssemblyLinearVelocity
			if grounded then
				launch(Movement.UpdraftVelocity)
			elseif v.Y < Movement.UpdraftVelocity then
				stomping = false
				humanoid.WalkSpeed = Movement.AirSpeed
				arcLaunched = true
				root.AssemblyLinearVelocity = Vector3.new(v.X, Movement.UpdraftVelocity, v.Z)
			end
			jumpsUsed = math.max(jumpsUsed, 1)
			return
		end
	end
end

-- 일방향 구름: 발이 윗면보다 아래면 통과. 로컬 충돌만 바꾸므로 다른 플레이어에게 영향이 없다
local function updateClouds(feetY: number)
	for _, cloud in cloudParts do
		local top = cloud.Position.Y + cloud.Size.Y / 2
		cloud.CanCollide = feetY >= top - Movement.CloudSnap
	end
end

-- 종 반경에 들어오는 순간에만 울린다 (옆에 서 있는 동안 반복해서 울리지 않게)
local function checkBells(now: number)
	local near = false
	for _, bell in bellParts do
		if (bell.Position - root.Position).Magnitude <= Movement.BellRadius then
			near = true
			break
		end
	end
	if near and not nearBell and now - lastBellAt >= Movement.BellCooldown then
		lastBellAt = now
		HopController.stats.bells += 1
		HopController.onBell:Fire(HopController.feetPosition())
	end
	nearBell = near
end

local function step(dt: number)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()

	if root.Position.Y < Movement.FallResetY then
		respawnAfterFall()
		return
	end

	updateClouds(HopController.feetPosition().Y)
	applyUpdraft()

	local v = root.AssemblyLinearVelocity
	local vy = MovementLogic.clampFall(Movement, v.Y, stomping)
	if vy ~= v.Y then
		root.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
	end

	-- Humanoid 점프는 JumpPower보다 약 5% 큰 초속을 낸다 (2026-11-03 플레이테스트 실측). Config 값으로 되돌린다
	if launchVelocity then
		local elapsed = now - lastLaunchAt
		local target = launchVelocity - workspace.Gravity * elapsed
		if vy > target + Movement.LaunchOvershootTolerance then
			vy = target
			root.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
			launchVelocity = nil
		elseif elapsed > Movement.GroundLockTime then
			launchVelocity = nil
		end
	end

	if not grounded and vy < 0 then
		local hit = probeBelow(math.max(Movement.ProbeLookahead, -vy * dt * 1.5))
		if hit and tryBounce(hit) then
			return
		end
	elseif grounded then
		local hit = probeBelow(0.5)
		if hit and CollectionService:HasTag(hit.Instance, Tags.BouncePad) then
			bounce("pad", Movement.BouncePadVelocity)
			return
		end
	end

	-- 일방향 구름을 뚫고 올라가는 순간에도 바닥이 감지되므로, 올라가는 중에는 착지로 보지 않는다
	local onFloor = humanoid.FloorMaterial ~= Enum.Material.Air and now >= groundLockUntil
	if onFloor and not grounded and vy <= Movement.LandingMaxVy then
		land(now)
	elseif not onFloor and grounded and now >= groundLockUntil then
		grounded = false
		lastGroundedAt = now
		humanoid.WalkSpeed = Movement.AirSpeed
	end
	if grounded and onFloor then
		rememberSafeGround(now)
	end

	if humanoid.JumpPower ~= Movement.JumpVelocity[1] and now - lastLaunchAt > Movement.GroundLockTime then
		humanoid.JumpPower = Movement.JumpVelocity[1]
	end

	checkBells(now)
	HopController.stats.maxAltitude = math.max(HopController.stats.maxAltitude, HopController.altitude())
end

local function onStateChanged(_, newState: Enum.HumanoidStateType)
	if newState ~= Enum.HumanoidStateType.Jumping then
		return
	end
	local now = os.clock()
	if now - lastLaunchAt <= Movement.GroundLockTime then
		return -- launch()가 일으킨 점프
	end
	-- Humanoid 기본 입력으로 뛴 지면 점프. 점프 키를 누른 채 착지하면 land()보다 먼저 올 수 있다
	lastLaunchAt = now
	launchVelocity = Movement.JumpVelocity[1]
	groundLockUntil = now + Movement.GroundLockTime
	grounded = false
	arcLaunched = true
	stomping = false
	combo = 0
	jumpsUsed = 1
	humanoid.WalkSpeed = Movement.AirSpeed
	HopController.onJump:Fire(1, false, HopController.feetPosition())
end

local function onCharacterAdded(newCharacter: Model)
	-- 첫 캐릭터가 아니면 죽었다 되살아난 것이다. 낙하 복귀와 같이 알린다 (진행 중 의뢰 실패)
	local revived = character ~= nil
	humanoid, root = nil, nil
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	root = newCharacter:WaitForChild("HumanoidRootPart")
	humanoid.UseJumpPower = true
	resetAirState()
	humanoid.WalkSpeed = Movement.WalkSpeed
	humanoid.StateChanged:Connect(onStateChanged)
	if revived then
		safePosition = nil
		HopController.onRespawn:Fire()
	end
end

function HopController.start()
	local folder = Instance.new("Folder")
	folder.Name = "SkyhopLocal"
	folder.Parent = workspace
	HopController.localFolder = folder

	cloudParts = trackTag(Tags.Cloud)
	updraftParts = trackTag(Tags.Updraft)
	bellParts = trackTag(Tags.Bell)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	-- JumpRequest는 한 번 눌러도 여러 번 오고, 누르고 있으면 계속 온다. 간격으로 새 입력만 골라낸다
	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local isNewPress = now - lastJumpRequestAt > Movement.JumpPressGap
		lastJumpRequestAt = now
		if isNewPress then
			onJumpPressed()
		end
	end)

	ContextActionService:BindAction("SkyhopStomp", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			HopController.stomp()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonX)

	RunService.Heartbeat:Connect(step)
end

return HopController

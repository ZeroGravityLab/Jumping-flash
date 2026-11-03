-- 의뢰 유형별 목표 (GDD 6.5): Collect 수집, Beacons 봉화, Rings 고리 다이빙, Delivery 배달.
-- 목표 오브젝트는 이 플레이어에게만 보이게 hop.localFolder에 만든다 (GDD 6.4)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Config.World)
local WorldGen = require(ReplicatedStorage.Shared.WorldGen)

local Objectives = {}

local COLOR = {
	Letter = Color3.fromRGB(255, 250, 235),
	Seal = Color3.fromRGB(230, 90, 90),
	BeaconOff = Color3.fromRGB(120, 130, 150),
	BeaconOn = Color3.fromRGB(255, 196, 70),
	RingNext = Color3.fromRGB(120, 230, 255),
	RingLater = Color3.fromRGB(200, 210, 230),
	RingDone = Color3.fromRGB(140, 255, 160),
	Pot = Color3.fromRGB(214, 120, 80),
	Bloom = Color3.fromRGB(255, 150, 200),
	Target = Color3.fromRGB(140, 255, 160),
}
local COLLECT_RADIUS = 5
local BEACON_RADIUS = 8
local RING_RADIUS = 9
local DELIVERY_RADIUS = 9

export type Callbacks = {
	progress: (done: number, total: number) -> (),
	success: () -> (),
	fail: (reasonKey: string) -> (),
}

local function islandSpec(id: string)
	for _, island in World.Islands do
		if island.id == id then
			return island
		end
	end
	return nil
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- 의뢰 좌표 → 월드 위치 (Config/Requests 맨 위 설명 참고)
function Objectives.resolve(spec, islandId: string, exclude: { Instance }): Vector3?
	local island = islandSpec(islandId)
	if not island then
		return nil
	end
	local top = Vector3.new(island.center[1], island.center[2], island.center[3])
	if spec.air then
		return top + Vector3.new(spec.air[1], spec.air[2], spec.air[3])
	elseif spec.surface then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		local origin = top + Vector3.new(spec.surface[1], 400, spec.surface[2])
		local hit = workspace:Raycast(origin, Vector3.new(0, -800, 0), params)
		local base = if hit then hit.Position else top + Vector3.new(spec.surface[1], 0, spec.surface[2])
		return base + Vector3.new(0, spec.surface[3], 0)
	elseif spec.satellite then
		local s = island.satellites
		local points = WorldGen.spiral(s.count, s.orbit, s.rise, s.startAngle, s.angleStep, top.Y)
		local p = points[spec.satellite[1]]
		return Vector3.new(top.X + p.x, p.y + spec.satellite[2], top.Z + p.z)
	end
	return nil
end

local function letter(position: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	part({
		Name = "Paper",
		Size = Vector3.new(3, 0.3, 2.1),
		Color = COLOR.Letter,
		CFrame = CFrame.new(position),
		Parent = model,
	})
	part({
		Name = "Seal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 0.8, 0.8),
		Color = COLOR.Seal,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 240, 200)
	light.Parent = model:FindFirstChild("Paper")
	model.Parent = parent
	return model
end

local function beacon(position: Vector3, parent: Instance): BasePart
	part({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 9, 9),
		Color = Color3.fromRGB(150, 140, 130),
		Material = Enum.Material.Slate,
		CanCollide = true,
		CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = parent,
	})
	return part({
		Name = "Flame",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Color = COLOR.BeaconOff,
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0)),
		Parent = parent,
	})
end

local function ring(center: Vector3, parent: Instance): { BasePart }
	local segments = {}
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		table.insert(
			segments,
			part({
				Name = "Hoop",
				Size = Vector3.new(1, 1, RING_RADIUS * 0.42),
				Color = COLOR.RingLater,
				Material = Enum.Material.Neon,
				CFrame = CFrame.new(
					center + Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
				) * CFrame.Angles(0, -angle, 0),
				Parent = parent,
			})
		)
	end
	return segments
end

local function paint(parts: { BasePart }, color: Color3)
	for _, p in parts do
		p.Color = color
	end
end

-- 목표 하나를 실행한다. 돌려준 함수를 부르면 정리한다
function Objectives.run(request, islandId: string, hop, callbacks: Callbacks): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "Request_" .. request.id
	folder.Parent = hop.localFolder
	local exclude = { hop.character(), hop.localFolder }
	local connections = {}
	local finished = false

	local function finish(ok: boolean, reason: string?)
		if finished then
			return
		end
		finished = true
		for _, c in connections do
			c:Disconnect()
		end
		folder:Destroy()
		if ok then
			callbacks.success()
		else
			callbacks.fail(reason or "FailServer")
		end
	end
	local function cleanup()
		finished = true
		for _, c in connections do
			c:Disconnect()
		end
		folder:Destroy()
	end
	table.insert(
		connections,
		hop.onRespawn:Connect(function()
			finish(false, "FailFell")
		end)
	)

	if request.type == "Collect" then
		local items = {}
		for _, spec in request.points do
			local position = Objectives.resolve(spec, islandId, exclude)
			if position then
				table.insert(items, { model = letter(position, folder), position = position })
			end
		end
		local total, done = #items, 0
		callbacks.progress(0, total)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				local root = hop.rootPart()
				if not root then
					return
				end
				local t = os.clock()
				for _, item in items do
					if not item.done then
						item.model:PivotTo(
							CFrame.new(item.position + Vector3.new(0, math.sin(t * 2) * 0.6, 0))
								* CFrame.Angles(0, t, 0)
						)
						if (root.Position - item.position).Magnitude <= COLLECT_RADIUS + 2 then
							item.done = true
							item.model:Destroy()
							done += 1
							callbacks.progress(done, total)
							if done == total then
								finish(true)
							end
						end
					end
				end
			end)
		)
	elseif request.type == "Beacons" then
		local beacons = {}
		for _, spec in request.points do
			local position = Objectives.resolve(spec, islandId, exclude)
			if position then
				table.insert(beacons, { flame = beacon(position, folder), position = position })
			end
		end
		local total, done = #beacons, 0
		callbacks.progress(0, total)
		-- 스톰프로 내려앉아야 켜진다
		table.insert(
			connections,
			hop.onLand:Connect(function(stomped, feet)
				if not stomped then
					return
				end
				for _, b in beacons do
					local flat = Vector3.new(feet.X - b.position.X, 0, feet.Z - b.position.Z).Magnitude
					if not b.lit and flat <= BEACON_RADIUS and math.abs(feet.Y - b.position.Y) <= 6 then
						b.lit = true
						b.flame.Color = COLOR.BeaconOn
						b.flame.Material = Enum.Material.Neon
						local light = Instance.new("PointLight")
						light.Color = COLOR.BeaconOn
						light.Range = 20
						light.Brightness = 2
						light.Parent = b.flame
						done += 1
						callbacks.progress(done, total)
						if done == total then
							task.delay(0.4, finish, true)
						end
					end
				end
			end)
		)
	elseif request.type == "Rings" then
		local rings = {}
		for _, spec in request.points do
			local center = Objectives.resolve(spec, islandId, exclude)
			if center then
				table.insert(rings, { center = center, parts = ring(center, folder) })
			end
		end
		local total, nextIndex = #rings, 1
		paint(rings[1].parts, COLOR.RingNext)
		callbacks.progress(0, total)
		local previous: Vector3? = nil
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				local root = hop.rootPart()
				if not root then
					return
				end
				local now = root.Position
				local target = rings[nextIndex]
				-- 지난 프레임과 이번 프레임 사이에 고리 평면을 아래로 지나갔는가
				if target and previous and previous.Y >= target.center.Y and now.Y < target.center.Y then
					local t = (previous.Y - target.center.Y) / math.max(previous.Y - now.Y, 1e-3)
					local crossing = previous:Lerp(now, t)
					local flat = Vector3.new(crossing.X - target.center.X, 0, crossing.Z - target.center.Z).Magnitude
					if flat <= RING_RADIUS then
						paint(target.parts, COLOR.RingDone)
						callbacks.progress(nextIndex, total)
						nextIndex += 1
						if nextIndex > total then
							finish(true)
							return
						end
						paint(rings[nextIndex].parts, COLOR.RingNext)
					elseif nextIndex > 1 then
						finish(false, "FailMissed")
						return
					end
				end
				previous = now
			end)
		)
		-- 첫 고리를 지난 뒤 땅에 내려앉으면 놓친 것
		table.insert(
			connections,
			hop.onLand:Connect(function()
				if nextIndex > 1 then
					finish(false, "FailMissed")
				end
			end)
		)
	elseif request.type == "Delivery" then
		local target = Objectives.resolve(request.target, islandId, exclude)
		local pot = part({
			Name = "Pot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.2, 2.4, 2.4),
			Color = COLOR.Pot,
			Parent = folder,
		})
		local bloom = part({
			Name = "Bloom",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			Color = COLOR.Bloom,
			Parent = folder,
		})
		local marker = part({
			Name = "Target",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, DELIVERY_RADIUS * 2, DELIVERY_RADIUS * 2),
			Color = COLOR.Target,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CFrame = CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = folder,
		})
		TweenService:Create(marker, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.75,
		}):Play()
		callbacks.progress(0, 1)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				local root = hop.rootPart()
				if not root then
					return
				end
				local head = root.Position + Vector3.new(0, 4.2, 0)
				pot.CFrame = CFrame.new(head) * CFrame.Angles(0, 0, math.rad(90))
				bloom.CFrame = CFrame.new(head + Vector3.new(0, 1.6, 0))
				if (hop.feetPosition() - target).Magnitude <= DELIVERY_RADIUS then
					callbacks.progress(1, 1)
					finish(true)
				end
			end)
		)
		table.insert(
			connections,
			hop.onLand:Connect(function(stomped)
				if stomped then
					finish(false, "FailBroke")
				end
			end)
		)
		table.insert(
			connections,
			hop.onBounce:Connect(function(kind)
				if kind == "stomp" or kind == "buddy" then
					finish(false, "FailBroke")
				end
			end)
		)
	end

	return cleanup
end

return Objectives

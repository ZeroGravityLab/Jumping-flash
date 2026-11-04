-- 풍경을 살아 있게: 풍차 날개 회전, 열기구 흔들림, 갈매기 떼 선회(날갯짓·활공), 구름 흐름. 모두 클라이언트 로컬 움직임
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Ambience = {}

local BALLOON_BOB = 5
local BALLOON_SPEED = 0.35
local CLOUD_WANDER = 40
local CLOUD_SPEED = 0.025
-- 갈매기: 날갯짓하다가 활공하기를 되풀이한다 (CYCLE초마다 FLAP_SHARE만큼 날갯짓)
local GULL_CYCLE = 3.6
local GULL_FLAP_SHARE = 0.5
local GULL_FLAP_SPEED = 8
local GULL_FLAP_ANGLE = 0.55 -- 어깨 뼈 회전 (라디안). 날개 끝 뼈는 그 0.6배를 더 굽힌다
local GULL_BANK = 0.28 -- 선회 쪽으로 기우는 각도 (라디안)
-- 왼쪽 날개(-X)는 몸통 앞 방향 축으로 +회전하면 올라가고, 오른쪽은 -회전하면 올라간다 (2026-11-04 Studio 확인)
local WING_SIDE = { WingL1 = 1, WingL2 = 1, WingR1 = -1, WingR2 = -1 }
local WING_TIP = { WingL2 = true, WingR2 = true }

type GullRig = { bones: { { bone: Bone, axis: Vector3, side: number, tip: boolean } } }
local gullRigs: { [Model]: GullRig } = {}

-- 뼈마다 몸통 앞 방향 축을 뼈 기준으로 한 번만 구해 둔다 (모든 Transform이 비어 있을 때)
local function rigFor(bird: Model): GullRig
	local rig = gullRigs[bird]
	if rig then
		return rig
	end
	rig = { bones = {} }
	local forward = bird:GetPivot().LookVector
	for _, bone in bird:GetDescendants() do
		if bone:IsA("Bone") and WING_SIDE[bone.Name] then
			table.insert(rig.bones, {
				bone = bone,
				axis = bone.WorldCFrame:VectorToObjectSpace(forward),
				side = WING_SIDE[bone.Name],
				tip = WING_TIP[bone.Name] == true,
			})
		end
	end
	gullRigs[bird] = rig
	bird.Destroying:Connect(function()
		gullRigs[bird] = nil
	end)
	return rig
end

-- 갈매기 한 마리: 떼 안 자리 + 새마다 다른 흔들림·기울기로 기준점을 옮기고, 날개 뼈를 굽힌다
local function poseGull(bird: Model, flock: CFrame, t: number, bank: number)
	local offset = bird:GetAttribute("Offset") :: Vector3?
	local phase = (bird:GetAttribute("Phase") :: number?) or 0
	local s = (bird:GetAttribute("Scale") :: number?) or 1
	if not offset then
		return
	end
	local rig = rigFor(bird)
	local cycle = (t / GULL_CYCLE + phase) % 1
	local flap = if cycle < GULL_FLAP_SHARE
		then math.sin(t * GULL_FLAP_SPEED + phase * 5) * GULL_FLAP_ANGLE
		else 0.08 + math.sin(t * 1.3 + phase) * 0.04 -- 활공: 날개를 살짝 들고 바람에 떤다
	local drift = Vector3.new(math.sin(t * 0.7 + phase) * 0.8, math.sin(t * 1.1 + phase * 2) * 1.2, 0) * s
	bird:PivotTo(
		flock
			* CFrame.new(offset + drift)
			* CFrame.Angles(math.sin(t * 0.9 + phase) * 0.06, 0, bank + math.sin(t * 0.6 + phase) * 0.08)
	)
	for _, entry in rig.bones do
		local angle = flap * entry.side * (if entry.tip then 0.6 else 1)
		entry.bone.Transform = CFrame.fromAxisAngle(entry.axis, angle)
	end
end

function Ambience.start()
	local spinners, balloons, flocks, clouds = {}, {}, {}, {}

	local function trackSpin(model: Instance)
		local center = model:GetAttribute("SpinCenter")
		local axis = model:GetAttribute("SpinAxis")
		if not (model:IsA("Model") and center and axis) then
			return
		end
		local hub = CFrame.new(center)
		table.insert(spinners, {
			model = model,
			hub = hub,
			offset = hub:ToObjectSpace(model:GetPivot()),
			axis = axis,
			speed = model:GetAttribute("SpinSpeed") or 0.3,
		})
	end

	local function trackDrift(model: Instance)
		if model:IsA("Model") then
			table.insert(
				balloons,
				{ model = model, base = model:GetPivot(), phase = model:GetAttribute("DriftPhase") or 0 }
			)
		end
	end

	local function trackOrbit(model: Instance)
		if model:IsA("Model") then
			table.insert(flocks, {
				model = model,
				center = model:GetAttribute("OrbitCenter"),
				radius = model:GetAttribute("OrbitRadius") or 60,
				speed = model:GetAttribute("OrbitSpeed") or 0.1,
				phase = model:GetAttribute("OrbitPhase") or 0,
			})
		end
	end

	local function each(tag: string, handler: (Instance) -> ())
		for _, inst in CollectionService:GetTagged(tag) do
			handler(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(handler)
	end
	each(Tags.Spin, trackSpin)
	each(Tags.Drift, trackDrift)
	each(Tags.Orbit, trackOrbit)

	-- 구름 덩어리는 모델 단위로 흘려보낸다 (태그는 파트에 붙어 있다)
	local seenClouds = {}
	each(Tags.CloudPuff, function(part)
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seenClouds[model] then
			seenClouds[model] = true
			table.insert(
				clouds,
				{ model = model, base = model:GetPivot(), phase = model:GetAttribute("DriftPhase") or 0 }
			)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, s in spinners do
			s.model:PivotTo(s.hub * CFrame.fromAxisAngle(s.axis, t * s.speed) * s.offset)
		end
		for _, b in balloons do
			local bob = math.sin(t * BALLOON_SPEED + b.phase) * BALLOON_BOB
			b.model:PivotTo(b.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, math.sin(t * 0.05 + b.phase) * 0.3, 0))
		end
		for _, f in flocks do
			local angle = f.phase + t * f.speed
			local position = f.center
				+ Vector3.new(math.cos(angle) * f.radius, math.sin(t * 0.5 + f.phase) * 3, math.sin(angle) * f.radius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * math.sign(f.speed)
			local frame = CFrame.lookAt(position, position + tangent)
			if f.model:GetAttribute("Flock") then
				-- 갈매기 떼: 새마다 따로 자세를 잡는다. 원을 돌므로 늘 안쪽으로 기운다
				local bank = -GULL_BANK * math.sign(f.speed)
				for _, bird in f.model:GetChildren() do
					if bird:IsA("Model") then
						poseGull(bird, frame, t, bank)
					end
				end
			else
				f.model:PivotTo(frame)
			end
		end
		for _, c in clouds do
			local offset = Vector3.new(
				math.sin(t * CLOUD_SPEED + c.phase) * CLOUD_WANDER,
				0,
				math.cos(t * CLOUD_SPEED * 0.8 + c.phase) * CLOUD_WANDER
			)
			c.model:PivotTo(c.base + offset)
		end
	end)
end

return Ambience

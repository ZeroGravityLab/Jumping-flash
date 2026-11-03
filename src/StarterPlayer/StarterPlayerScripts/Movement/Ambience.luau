-- 풍경을 살아 있게: 풍차 날개 회전, 열기구 흔들림, 새 떼 선회, 구름 흐름. 모두 클라이언트 로컬 움직임
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Ambience = {}

local BALLOON_BOB = 5
local BALLOON_SPEED = 0.35
local CLOUD_WANDER = 40
local CLOUD_SPEED = 0.025

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
			f.model:PivotTo(CFrame.lookAt(position, position + tangent))
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

-- 의뢰를 주는 주민 NPC. 대화는 ProximityPrompt로 시작하고, 프롬프트의 Resident 속성으로 누구인지 알린다.
-- 외형은 기본 R15 몸에 색을 입히고 ResidentLooks의 소품을 붙인다. 서 있는 동안 기본 숨쉬기 동작을 튼다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Requests = require(ReplicatedStorage.Config.Requests)
local World = require(ReplicatedStorage.Config.World)
local Decor = require(script.Parent.Decor)
local ResidentLooks = require(script.Parent.ResidentLooks)

-- Roblox 기본 R15 대기 동작 중 숨쉬기 (507766666은 고개를 옆으로 크게 돌려 말 거는 사람을 안 보는 것처럼 보였다)
local IDLE_ANIMATION = "rbxassetid://507766951"

local Residents = {}

local function islandTop(id: string): Vector3?
	for _, island in World.Islands do
		if island.id == id then
			return Vector3.new(island.center[1], island.center[2], island.center[3])
		end
	end
	return nil
end

local function describe(color: { number }): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	local tint = Color3.fromRGB(color[1], color[2], color[3])
	local skin = Color3.fromRGB(255, 220, 190)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = tint
	desc.LeftLegColor = tint:Lerp(Color3.new(0, 0, 0), 0.25)
	desc.RightLegColor = tint:Lerp(Color3.new(0, 0, 0), 0.25)
	return desc
end

local function build(resident, parent: Instance)
	local top = islandTop(resident.island)
	local hit = top and Decor.groundAt(top.X + resident.x, top.Y, top.Z + resident.z)
	if not hit then
		warn("[Residents] no ground for", resident.id)
		return
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(resident.color), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Residents] could not create", resident.id, model)
		return
	end
	model.Name = resident.id
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayName = resident.id
	humanoid.NameDisplayDistance = 60
	root.Anchored = true
	local height = humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(CFrame.new(hit.Position + Vector3.new(0, height, 0)) * CFrame.Angles(0, math.rad(resident.yaw), 0))
	ResidentLooks.apply(model, resident.id, Color3.fromRGB(resident.color[1], resident.color[2], resident.color[3]))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk" -- 클라이언트가 언어에 맞게 바꾼다
	prompt.ObjectText = resident.id
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Resident", resident.id)
	prompt.Parent = root
	model.Parent = parent

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = IDLE_ANIMATION
	local ok2, track = pcall(animator.LoadAnimation, animator, animation)
	if ok2 then
		track.Looped = true
		track:Play(0)
		track:AdjustSpeed(0.85 + (#resident.id % 4) * 0.08) -- 주민끼리 박자가 맞지 않게
	end
end

function Residents.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Residents"
	folder.Parent = parent
	for _, resident in Requests.Residents do
		build(resident, folder)
	end
end

return Residents

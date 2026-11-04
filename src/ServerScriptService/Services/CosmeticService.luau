-- 장착한 상점 외형(궤적·부츠)을 캐릭터에 입힌다 (GDD 9.4). 서버가 붙이므로 모든 플레이어에게 보인다.
-- 충돌·판정·질량이 없어서 이동과 착지에 영향을 주지 않는다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Config.Shop)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local DataService = require(script.Parent.DataService)

local CosmeticService = {}

local FOLDER = "Cosmetics"
local TRAIL_TAG = "CosmeticTrail"
local TRAIL_HALF_WIDTH = 1
local TRAIL_LIFETIME = 0.7
local APPEARANCE_TIMEOUT = 10

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function clear(character: Model)
	local folder = character:FindFirstChild(FOLDER)
	if folder then
		folder:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, child in root:GetChildren() do
			if child.Name == TRAIL_TAG then
				child:Destroy()
			end
		end
	end
end

-- 몸 양옆 두 점 사이의 띠가 카메라를 향한 채 꼬리로 남는다 (수직으로 뛰어도 폭이 보인다)
local function addTrail(character: Model, item)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = TRAIL_TAG
	a0.Position = Vector3.new(-TRAIL_HALF_WIDTH, -0.4, 0.3)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = TRAIL_TAG
	a1.Position = Vector3.new(TRAIL_HALF_WIDTH, -0.4, 0.3)
	a1.Parent = root
	local keys = {}
	for i, c in item.colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#item.colors - 1), rgb(c)))
	end
	local trail = Instance.new("Trail")
	trail.Name = TRAIL_TAG
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keys)
	trail.Lifetime = TRAIL_LIFETIME
	trail.MinLength = 0.15
	trail.FaceCamera = true
	trail.LightEmission = 0.5
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.35) })
	trail.Parent = root
end

local function bootPiece(
	folder: Folder,
	foot: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	glow: boolean?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = "Boot"
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.CFrame = foot.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = foot
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

-- 발을 감싸는 몸통, 둥근 앞코, 조금 더 넓은 밑창, 몸통 가운데를 두르는 띠.
-- 띠를 몸통 위에 얹으면 윗면을 다 덮어 빛나는 상자처럼 보였다
local function addBoots(character: Model, folder: Folder, item)
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local s = foot.Size
			local bottom = -s.Y / 2
			local width, length = s.X + 0.2, s.Z + 0.1
			local body = bootPiece(
				folder,
				foot,
				Vector3.new(width, 0.62, length * 0.8),
				CFrame.new(0, bottom + 0.4, length * 0.1),
				rgb(item.body)
			)
			local toe = bootPiece(
				folder,
				foot,
				Vector3.new(width, 0.5, length * 0.45),
				CFrame.new(0, bottom + 0.3, -length * 0.3),
				rgb(item.body),
				false,
				Enum.PartType.Ball
			)
			if item.metal then
				body.Reflectance = 0.25
				toe.Reflectance = 0.25
			end
			bootPiece(
				folder,
				foot,
				Vector3.new(width + 0.1, 0.18, length + 0.12),
				CFrame.new(0, bottom + 0.06, 0),
				rgb(item.sole)
			)
			bootPiece(
				folder,
				foot,
				Vector3.new(width + 0.04, 0.1, length * 0.8 + 0.04),
				CFrame.new(0, bottom + 0.5, length * 0.1),
				rgb(item.accent),
				item.glow
			)
		end
	end
end

function CosmeticService.apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	clear(character)
	local worn = ShopLogic.worn(Shop, profile.equipped, profile.owned)
	if worn.Trail then
		addTrail(character, worn.Trail)
	end
	if worn.Boots then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = character
		addBoots(character, folder, worn.Boots)
	end
end

local function watch(player: Player)
	-- DataService가 프로필을 읽거나 장착이 바뀌면 이 속성을 새로 쓴다 (갱신 신호로만 쓰고, 판단은 프로필로 한다)
	player:GetAttributeChangedSignal("ShopEquipped"):Connect(function()
		CosmeticService.apply(player)
	end)
	player.CharacterAdded:Connect(function(character)
		-- 아바타 외형이 로드되면 발 부품이 새것으로 바뀌어, 그 전에 붙인 부츠는 떨어져 사라졌다. 로드를 기다린다
		local started = os.clock()
		while not player:HasAppearanceLoaded() and character.Parent and os.clock() - started < APPEARANCE_TIMEOUT do
			task.wait(0.2)
		end
		if player.Character ~= character then
			return
		end
		CosmeticService.apply(player)
		-- 그 뒤에도 발이 바뀌면(외형 갱신) 다시 입힌다
		character.ChildAdded:Connect(function(child)
			if child.Name == "LeftFoot" or child.Name == "RightFoot" then
				task.defer(CosmeticService.apply, player)
			end
		end)
	end)
	if player.Character then
		CosmeticService.apply(player)
	end
end

function CosmeticService.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return CosmeticService

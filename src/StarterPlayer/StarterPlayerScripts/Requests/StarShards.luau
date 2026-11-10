-- 숨은 별조각 (Config Collectibles): 아직 안 주운 것만 이 클라이언트에 그린다. 목표 표시는 띄우지 않는다.
-- 닿으면 서버에 알리고(ShardCollect), 결과는 서버가 쓰는 Shards 속성으로 받는다
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Collectibles = require(ReplicatedStorage.Config.Collectibles)
local Shop = require(ReplicatedStorage.Config.Shop)
local World = require(ReplicatedStorage.Config.World)
local CollectibleLogic = require(ReplicatedStorage.Shared.CollectibleLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopLogic = require(ReplicatedStorage.Shared.ShopLogic)
local Strings = require(ReplicatedStorage.Shared.Strings)
local AudioGroups = require(script.Parent.Parent.Movement.AudioGroups)

local player = Players.LocalPlayer

local COLOR = {
	Core = Color3.fromRGB(255, 244, 200),
	Spike = Color3.fromRGB(255, 214, 90),
}
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local CHIME = "rbxasset://sounds/volume_slider.ogg"
local PENDING_SECONDS = 3 -- 서버 답이 이만큼 없으면 다시 보이게 한다
local SET_TOAST_DELAY = 2

local StarShards = {}

type Shard = { shard: any, position: Vector3, model: Model, pendingAt: number? }

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function collected(): { [string]: boolean }
	local raw = player:GetAttribute("Shards")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(value) == "table" then value else {}
end

local function neon(model: Model, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- 네 갈래 별: 빛나는 심, 십자 가시, 작게 기운 십자, 반짝이와 빛
local function build(position: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "StarShard"
	local core = neon(model, Vector3.one * 1.6, COLOR.Core, Enum.PartType.Ball)
	for _, spec in { { 0.5, 4.2, 0.5 }, { 4.2, 0.5, 0.5 } } do
		neon(model, Vector3.new(spec[1], spec[2], spec[3]), COLOR.Spike)
	end
	for _, roll in { 45, -45 } do
		local p = neon(model, Vector3.new(0.35, 2.4, 0.35), COLOR.Spike)
		p:SetAttribute("Roll", roll)
	end
	local light = Instance.new("PointLight")
	light.Color = COLOR.Spike
	light.Range = 16
	light.Brightness = 2
	light.Parent = core
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = SPARKLE_TEXTURE
	sparkle.Color = ColorSequence.new(COLOR.Spike)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 6
	sparkle.Parent = core
	model.PrimaryPart = core
	model:PivotTo(CFrame.new(position))
	model.Parent = parent
	return model
end

-- 심을 중심으로 돌고 살짝 떠오른다 (기운 십자는 각자 기울기를 유지한다)
local function pose(entry: Shard, clock: number, index: number)
	local pivot = CFrame.new(entry.position + Vector3.new(0, math.sin(clock * 2 + index) * 0.6, 0))
		* CFrame.Angles(0, clock * 1.5 + index, 0)
	for _, p in entry.model:GetChildren() do
		if p:IsA("BasePart") then
			local roll = p:GetAttribute("Roll")
			p.CFrame = if roll then pivot * CFrame.Angles(0, 0, math.rad(roll :: number)) else pivot
		end
	end
end

local function setVisible(model: Model, visible: boolean)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = if visible then 0 else 1
		elseif p:IsA("ParticleEmitter") or p:IsA("PointLight") then
			p.Enabled = visible
		end
	end
end

local function chime(speed: number)
	local sound = Instance.new("Sound")
	sound.SoundId = CHIME
	sound.PlaybackSpeed = speed
	sound.Volume = 0.8
	sound.SoundGroup = AudioGroups.sounds()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

function StarShards.start(hop, ui)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Remotes.ShardCollect) :: RemoteEvent
	local entries: { [string]: Shard } = {}
	local known: { [string]: boolean }? = nil -- 처음 받은 진행 (접속할 때는 알림을 띄우지 않는다)

	local function sync()
		local current = collected()
		for _, shard in Collectibles.Shards do
			local entry = entries[shard.id]
			if current[shard.id] then
				if entry then
					entry.model:Destroy()
					entries[shard.id] = nil
				end
			elseif not entry then
				local at = CollectibleLogic.worldPosition(shard, World)
				if at then
					local position = Vector3.new(at[1], at[2], at[3])
					entries[shard.id] = { shard = shard, position = position, model = build(position, hop.localFolder) }
				end
			end
		end
		-- 새로 주운 것 알림, 섬을 다 모으면 보상 알림
		if known then
			for id in current do
				if not known[id] then
					local shard = CollectibleLogic.find(Collectibles, id)
					if shard then
						local found, total = CollectibleLogic.islandProgress(Collectibles, shard.island, current)
						local island = t("Island_" .. shard.island)
						ui.toast(t("ShardFound", island, found, total))
						chime(1.6)
						local set = CollectibleLogic.setFor(Collectibles, shard.island)
						local reward = set and ShopLogic.find(Shop, set.reward)
						if reward and found == total then
							task.delay(SET_TOAST_DELAY, function()
								ui.toast(t("ShardSetDone", island, t("Item_" .. reward.id)))
								chime(2)
							end)
						end
					end
				end
			end
		end
		if type(player:GetAttribute("Shards")) == "string" then
			known = current
		end
	end

	sync()
	player:GetAttributeChangedSignal("Shards"):Connect(sync)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local root = hop.rootPart()
		local index = 0
		for id, entry in entries do
			index += 1
			pose(entry, now, index)
			if entry.pendingAt then
				if now - entry.pendingAt > PENDING_SECONDS then
					entry.pendingAt = nil
					setVisible(entry.model, true)
				end
			elseif root and (root.Position - entry.position).Magnitude <= Collectibles.CollectRadius then
				-- 먼저 숨기고 서버 답(Shards 속성)을 기다린다
				entry.pendingAt = now
				setVisible(entry.model, false)
				remote:FireServer(id)
			end
		end
	end)
end

return StarShards

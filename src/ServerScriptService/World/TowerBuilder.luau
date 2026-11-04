-- 클라우드 러시 탑: TowerGen 배치를 파트로 세운다 (GDD 7.2, 8.1·8.2). 라운드가 끝나면 통째로 지운다.
-- 발판 색은 팔레트(GDD 8.2)를 따른다: 고정 하늘색, 구름 흰색, 바운스 노랑.
-- 고정 발판을 흰색으로 하면 아래 구름 바다와 섞여 위에서 안 보여서(2026-11-04 Studio 확인) 하늘색 두 톤 + 진한 테두리로 한다
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local TowerGen = require(ReplicatedStorage.Shared.TowerGen)
local Features = require(script.Parent.Features)

local TowerBuilder = {}

local COLOR = {
	SlabA = Color3.fromRGB(150, 205, 255),
	SlabB = Color3.fromRGB(118, 178, 245),
	Rim = Color3.fromRGB(60, 96, 170),
	Start = Color3.fromRGB(176, 214, 255),
	Summit = Color3.fromRGB(255, 236, 186),
	Pillar = Color3.fromRGB(226, 220, 208),
	Bell = Color3.fromRGB(255, 200, 70),
}
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ENTRY_DIAMETER = 16

export type Info = { origin: Vector3, top: Vector3, bell: Vector3, height: number }

-- 둥근 고정 발판. 윗면이 top. 위에서 봐도 보이게 아래에 진한 테두리를 깐다
local function slab(top: Vector3, diameter: number, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = "Slab"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.new(2, diameter, diameter)
	p.CFrame = CFrame.new(top - Vector3.new(0, 1, 0)) * UPRIGHT
	p.Parent = parent
	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Shape = Enum.PartType.Cylinder
	rim.Anchored = true
	rim.CanCollide = false
	rim.CanQuery = false
	rim.CanTouch = false
	rim.Material = Enum.Material.SmoothPlastic
	rim.Color = COLOR.Rim
	rim.Size = Vector3.new(1.4, diameter + 1.2, diameter + 1.2)
	rim.CFrame = CFrame.new(top - Vector3.new(0, 1.9, 0)) * UPRIGHT
	rim.Parent = parent
	return p
end

local function summitBell(top: Vector3, parent: Instance): BasePart
	local pillar = Instance.new("Part")
	pillar.Name = "BellPillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Anchored = true
	pillar.Material = Enum.Material.Limestone
	pillar.Color = COLOR.Pillar
	pillar.Size = Vector3.new(10, 4, 4)
	pillar.CFrame = CFrame.new(top + Vector3.new(0, 5, 0)) * UPRIGHT
	pillar.Parent = parent
	local bell = Instance.new("Part")
	bell.Name = "RushBell"
	bell.Shape = Enum.PartType.Ball
	bell.Anchored = true
	bell.CanCollide = false
	bell.Material = Enum.Material.Neon
	bell.Color = COLOR.Bell
	bell.Size = Vector3.new(8, 8, 8)
	bell.CFrame = CFrame.new(top + Vector3.new(0, 14, 0))
	bell.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = COLOR.Bell
	light.Range = 40
	light.Brightness = 3
	light.Parent = bell
	-- 클라이언트 종 연출(딩 소리·팝업)은 허브 종과 같은 태그로 받는다. 우승 판정은 서버(RoundService)가 한다
	CollectionService:AddTag(bell, Tags.Bell)
	return bell
end

function TowerBuilder.build(layout: { TowerGen.Placed }, cfg): (Model, Info)
	local origin = Vector3.new(cfg.TowerOrigin[1], cfg.TowerOrigin[2], cfg.TowerOrigin[3])
	local model = Instance.new("Model")
	model.Name = "RushTower"
	slab(origin, cfg.StartRadius * 2, COLOR.Start, model)

	for i, placed in layout do
		local base = origin + Vector3.new(0, (i - 1) * cfg.ChunkHeight, 0)
		if i > 1 then
			slab(base, ENTRY_DIAMETER, COLOR.SlabA, model)
		end
		for n, p in placed.chunk.platforms do
			local kind = p[1]
			local x, z = TowerGen.rotate(p[2], p[4], placed.yaw)
			local at = base + Vector3.new(x, p[3], z)
			if kind == "slab" then
				slab(at, p[5], if n % 2 == 0 then COLOR.SlabA else COLOR.SlabB, model)
			elseif kind == "cloud" then
				Features.cloudPlatform(at - Vector3.new(0, 1.5, 0), p[5], model)
			elseif kind == "pad" then
				Features.padAt(at, model)
			elseif kind == "updraft" then
				Features.updraftAt(at, p[5], model)
			elseif kind == "puff" then
				Features.puffling(at, model)
			else
				warn("[TowerBuilder] unknown platform kind:", kind, placed.chunk.id)
			end
		end
	end

	local height = #layout * cfg.ChunkHeight
	local top = origin + Vector3.new(0, height, 0)
	slab(top, cfg.SummitRadius * 2, COLOR.Summit, model)
	local bell = summitBell(top, model)
	model.Parent = workspace
	return model, { origin = origin, top = top, bell = bell.Position, height = height }
end

return TowerBuilder

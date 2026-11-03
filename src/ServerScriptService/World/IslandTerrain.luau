-- 떠 있는 섬 지형. 몸통 모양은 Shared/WorldGen이 계산하고 여기서는 Terrain에 채우기만 한다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldGen = require(ReplicatedStorage.Shared.WorldGen)

local IslandTerrain = {}

local LAYER_MATERIAL = {
	soil = Enum.Material.Ground,
	sand = Enum.Material.Sandstone,
	rock = Enum.Material.Rock,
}

export type Options = {
	hills: number?,
	plazaRadius: number?,
}

-- top은 잔디 윗면 중심
function IslandTerrain.build(top: Vector3, radius: number, depth: number, seed: number, options: Options?)
	local terrain = workspace.Terrain
	local opts = options or {}

	for _, piece in WorldGen.islandBody(radius, depth, top.Y, seed) do
		local center = Vector3.new(top.X + piece.x, piece.y, top.Z + piece.z)
		local material = LAYER_MATERIAL[piece.layer]
		if piece.shape == "slice" then
			terrain:FillCylinder(CFrame.new(center), piece.h, piece.r, material)
		else
			terrain:FillBall(center, piece.r, material)
		end
	end

	terrain:FillCylinder(CFrame.new(top - Vector3.new(0, 8, 0)), 12, radius * 0.97, Enum.Material.Ground)
	terrain:FillCylinder(CFrame.new(top - Vector3.new(0, 2.5, 0)), 5, radius, Enum.Material.Grass)

	-- 완만한 언덕: 구의 윗부분만 지면 위로 나오게 묻는다
	local plazaRadius = opts.plazaRadius or 0
	local rng = WorldGen.rng(seed + 101)
	for _ = 1, opts.hills or 0 do
		local angle = rng:range(0, math.pi * 2)
		local dist = rng:range(plazaRadius + 30, radius * 0.7)
		local r = rng:range(18, 36)
		local rise = r * rng:range(0.22, 0.36)
		local center = top + Vector3.new(math.cos(angle) * dist, rise - r, math.sin(angle) * dist)
		terrain:FillBall(center, r, Enum.Material.Grass)
	end

	if plazaRadius > 0 then
		terrain:FillCylinder(CFrame.new(top - Vector3.new(0, 1, 0)), 2, plazaRadius, Enum.Material.Cobblestone)
	end
end

return IslandTerrain

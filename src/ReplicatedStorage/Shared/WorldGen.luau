-- 월드 생성 계산 (순수 함수, Roblox·Lune 공용). 지형·인스턴스는 서버 World 모듈이 만든다.
local WorldGen = {}

export type Rng = { next: (self: Rng) -> number, range: (self: Rng, number, number) -> number }
-- slice: 세로축 원판 (h는 두께), ball: 구
export type Piece = { shape: string, x: number, y: number, z: number, r: number, h: number, layer: string }
export type Point = { x: number, z: number }
-- sky: 위가 트여 있어야 하는 자리 (나무 잎도 덮으면 안 된다)
export type Exclusion = { x: number, z: number, r: number, sky: boolean? }

-- 결정적 난수 (Park–Miller). 같은 시드면 Roblox와 Lune에서 같은 결과
local Rng = {}
Rng.__index = Rng

function WorldGen.rng(seed: number): Rng
	return setmetatable({ state = (math.floor(seed) % 2147483646) + 1 }, Rng) :: any
end

function Rng:next(): number
	self.state = (self.state * 48271) % 2147483647
	return (self.state - 1) / 2147483646
end

function Rng:range(min: number, max: number): number
	return min + (max - min) * self:next()
end

local function layerAt(t: number): string
	return if t < 0.2 then "soil" elseif t < 0.6 then "sand" else "rock"
end

local function bodyRadius(radius: number, t: number): number
	return radius * (1 - t) ^ 1.4 * 0.96 + 2
end

-- 섬 몸통. 아래로 갈수록 좁아지는 원판을 쌓아 바위 뿌리를 만들고(지층처럼 보인다), 옆면에 혹을 붙인다.
-- 모든 조각은 윗면(top)보다 아래에 있다. 잔디 윗면은 서버가 따로 덮는다
function WorldGen.islandBody(radius: number, depth: number, top: number, seed: number): { Piece }
	local rng = WorldGen.rng(seed)
	local pieces = {}
	local sliceHeight = math.clamp(depth / 14, 6, 18)
	local slices = math.ceil(depth / sliceHeight)
	for k = 1, slices do
		local t = (k - 0.5) / slices
		local jitter = radius * 0.08 * t
		local angle = rng:range(0, math.pi * 2)
		table.insert(pieces, {
			shape = "slice",
			x = math.cos(angle) * jitter,
			y = top - 6 - t * depth,
			z = math.sin(angle) * jitter,
			r = bodyRadius(radius, t),
			h = sliceHeight + 2,
			layer = layerAt(t),
		})
	end
	local lumps = math.floor(radius / 8)
	for _ = 1, lumps do
		local t = rng:range(0.12, 0.85)
		local side = bodyRadius(radius, t)
		local r = math.max(4, side * rng:range(0.18, 0.35))
		local angle = rng:range(0, math.pi * 2)
		table.insert(pieces, {
			shape = "ball",
			x = math.cos(angle) * side * 0.95,
			y = math.min(top - 6 - t * depth, top - 6 - r),
			z = math.sin(angle) * side * 0.95,
			r = r,
			h = r * 2,
			layer = layerAt(t),
		})
	end
	return pieces
end

local function isFree(x: number, z: number, points: { Point }, minSpacing: number, exclusions: { Exclusion }): boolean
	for _, e in exclusions do
		local dx, dz = x - e.x, z - e.z
		if dx * dx + dz * dz < e.r * e.r then
			return false
		end
	end
	for _, p in points do
		local dx, dz = x - p.x, z - p.z
		if dx * dx + dz * dz < minSpacing * minSpacing then
			return false
		end
	end
	return true
end

-- 원판 안에 서로 minSpacing 이상 떨어진 점을 뿌린다. 자리가 없으면 count보다 적게 돌려준다
function WorldGen.scatter(
	seed: number,
	count: number,
	minRadius: number,
	maxRadius: number,
	minSpacing: number,
	exclusions: { Exclusion }
): { Point }
	local rng = WorldGen.rng(seed)
	local points = {}
	local attempts = 0
	while #points < count and attempts < count * 40 do
		attempts += 1
		local angle = rng:range(0, math.pi * 2)
		-- 면적에 고르게 퍼지도록 반경은 제곱근 분포
		local dist = math.sqrt(rng:range(minRadius * minRadius, maxRadius * maxRadius))
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		if isFree(x, z, points, minSpacing, exclusions) then
			table.insert(points, { x = x, z = z })
		end
	end
	return points
end

-- 섬을 감아 오르는 작은 섬들의 위치 (섬 중심 기준)
function WorldGen.spiral(
	count: number,
	orbit: number,
	rise: number,
	startAngle: number,
	angleStep: number,
	baseY: number
)
	local points = {}
	for i = 1, count do
		local angle = math.rad(startAngle + angleStep * (i - 1))
		table.insert(points, { x = math.cos(angle) * orbit, y = baseY + rise * i, z = math.sin(angle) * orbit })
	end
	return points
end

return WorldGen

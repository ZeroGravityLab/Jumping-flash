local World = require("../src/ReplicatedStorage/Config/World")
local WorldGen = require("../src/ReplicatedStorage/Shared/WorldGen")
local check = require("./check")

return {
	["같은 시드는 같은 난수열"] = function()
		local a, b = WorldGen.rng(42), WorldGen.rng(42)
		for _ = 1, 20 do
			check.equal(a:next(), b:next())
		end
	end,

	["난수는 [0, 1) 범위"] = function()
		local rng = WorldGen.rng(1)
		for _ = 1, 1000 do
			local v = rng:next()
			check.truthy(v >= 0 and v < 1)
		end
	end,

	["섬 몸통은 아래로 갈수록 가늘어진다"] = function()
		local slices = {}
		for _, piece in WorldGen.islandBody(150, 250, 0, 3) do
			if piece.shape == "slice" then
				table.insert(slices, piece)
			end
		end
		table.sort(slices, function(p, q)
			return p.y > q.y
		end)
		local previous = math.huge
		for _, slice in slices do
			check.truthy(slice.r <= previous + 1e-6, "radius grew going down")
			previous = slice.r
		end
		check.truthy(#slices >= 8, "too few slices")
	end,

	["몸통 조각은 잔디 윗면 위로 솟지 않고 깊이 안에 있다"] = function()
		local top, depth = 50, 200
		for _, piece in WorldGen.islandBody(120, depth, top, 9) do
			local upper = if piece.shape == "slice" then piece.y + piece.h / 2 else piece.y + piece.r
			check.truthy(upper <= top - 4, piece.shape .. " pokes above the surface")
			check.truthy(piece.y >= top - 6 - depth - 1e-6, "below the island depth")
		end
	end,

	["흩뿌린 점은 간격과 제외 구역을 지킨다"] = function()
		local exclusions = { { x = 0, z = 0, r = 40 } }
		local points = WorldGen.scatter(5, 60, 0, 150, 12, exclusions)
		check.truthy(#points > 30, "too few points")
		for i, p in points do
			check.truthy(math.sqrt(p.x * p.x + p.z * p.z) >= 40 - 1e-6, "inside exclusion")
			check.truthy(math.sqrt(p.x * p.x + p.z * p.z) <= 150 + 1e-6, "outside disc")
			for j = i + 1, #points do
				local q = points[j]
				check.truthy(math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2) >= 12 - 1e-6, "too close")
			end
		end
	end,

	["나선 섬은 한 칸마다 일정하게 오른다"] = function()
		local points = WorldGen.spiral(5, 100, 50, 0, 40, 20)
		for i, p in points do
			check.near(p.y, 20 + 50 * i, 1e-9)
			check.near(math.sqrt(p.x * p.x + p.z * p.z), 100, 1e-9)
		end
	end,

	["1장 정상의 종은 마지막 나선 섬보다 높다"] = function()
		for _, island in World.Islands do
			if island.satellites and island.summit then
				local s = island.satellites
				local lastTop = island.center[2] + s.rise * s.count
				check.truthy(island.summit.height > lastTop, island.id .. " summit below satellites")
			end
		end
	end,

	["나선 섬 사이 간격은 3단 점프로 닿는다 (수평 115 이하, 수직 125 이하)"] = function()
		for _, island in World.Islands do
			local s = island.satellites
			if s then
				local points = WorldGen.spiral(s.count, s.orbit, s.rise, s.startAngle, s.angleStep, 0)
				for i = 2, #points do
					local a, b = points[i - 1], points[i]
					local gap = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) - s.radius * 2
					check.truthy(gap <= 115, island.id .. " satellite gap too wide")
					check.truthy(b.y - a.y <= 125, island.id .. " satellite rise too high")
				end
			end
		end
	end,
}

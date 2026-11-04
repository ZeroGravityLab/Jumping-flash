local Chunks = require("../src/ReplicatedStorage/Config/Chunks")
local Rush = require("../src/ReplicatedStorage/Config/Rush")
local TowerGen = require("../src/ReplicatedStorage/Shared/TowerGen")
local check = require("./check")

local function ids(layout): string
	local list = {}
	for _, placed in layout do
		table.insert(list, placed.chunk.id .. "@" .. placed.yaw)
	end
	return table.concat(list, ",")
end

return {
	["청크는 15종이고 id가 겹치지 않으며 쉬는 청크가 있다"] = function()
		check.equal(#Chunks, 15)
		local seen, rests = {}, 0
		for _, chunk in Chunks do
			check.truthy(not seen[chunk.id], "duplicate " .. chunk.id)
			seen[chunk.id] = true
			if chunk.rest then
				rests += 1
			end
			check.truthy(chunk.difficulty >= 1 and chunk.difficulty <= 5, chunk.id .. " difficulty out of range")
		end
		check.truthy(rests >= 1, "no rest chunk")
	end,

	-- GDD 14.3: 모든 청크가 퍼펙트 없이도 오를 수 있어야 한다
	["도달 가능성 린트: 모든 청크를 퍼펙트 없이 오를 수 있다"] = function()
		for _, chunk in Chunks do
			local problems = TowerGen.lint(chunk, Rush)
			check.truthy(#problems == 0, table.concat(problems, "; "))
		end
	end,

	["발판은 청크 높이 안에 있고 탑 축에서 멀지 않다"] = function()
		for _, chunk in Chunks do
			for i, p in chunk.platforms do
				local top = if p[1] == "updraft" then p[3] + p[5] else p[3]
				check.truthy(p[3] >= 0 and top < Rush.ChunkHeight, string.format("%s #%d height", chunk.id, i))
				check.truthy(math.sqrt(p[2] ^ 2 + p[4] ^ 2) <= 60, string.format("%s #%d too far", chunk.id, i))
			end
		end
	end,

	["같은 시드는 같은 탑, 다른 시드는 다른 탑"] = function()
		check.equal(ids(TowerGen.generate(42, Chunks, Rush)), ids(TowerGen.generate(42, Chunks, Rush)))
		local different = 0
		for seed = 1, 20 do
			if ids(TowerGen.generate(seed, Chunks, Rush)) ~= ids(TowerGen.generate(seed + 1000, Chunks, Rush)) then
				different += 1
			end
		end
		check.truthy(different >= 18, "seeds barely change the tower")
	end,

	["탑 규칙: 청크 수, 같은 청크 연속 금지, 쉬는 청크 자리, 어려운 청크 연속 상한"] = function()
		for seed = 1, 200 do
			local layout = TowerGen.generate(seed, Chunks, Rush)
			check.truthy(#layout >= Rush.ChunkCountMin and #layout <= Rush.ChunkCountMax, "count")
			local hardRun = 0
			for i, placed in layout do
				if i > 1 then
					check.truthy(placed.chunk ~= layout[i - 1].chunk, string.format("seed %d repeats at %d", seed, i))
				end
				check.equal(placed.chunk.rest == true, i % Rush.RestEvery == 0)
				check.truthy(placed.yaw % 90 == 0 and placed.yaw < 360, "yaw")
				hardRun = if not placed.chunk.rest and placed.chunk.difficulty >= 4 then hardRun + 1 else 0
				check.truthy(hardRun <= Rush.MaxHardInRow, string.format("seed %d: too many hard chunks", seed))
			end
		end
	end,

	["위로 갈수록 어려워진다 (아래 절반 평균 < 위 절반 평균)"] = function()
		local lower, upper, nl, nu = 0, 0, 0, 0
		for seed = 1, 200 do
			local layout = TowerGen.generate(seed, Chunks, Rush)
			for i, placed in layout do
				if not placed.chunk.rest then
					if i <= #layout / 2 then
						lower += placed.chunk.difficulty
						nl += 1
					else
						upper += placed.chunk.difficulty
						nu += 1
					end
				end
			end
		end
		check.truthy(lower / nl + 1 < upper / nu, string.format("lower %.2f upper %.2f", lower / nl, upper / nu))
	end,

	["회전은 90도 배수로 정확하다"] = function()
		local x, z = TowerGen.rotate(30, 10, 90)
		check.near(x, -10, 1e-9)
		check.near(z, 30, 1e-9)
		x, z = TowerGen.rotate(30, 10, 180)
		check.near(x, -30, 1e-9)
		check.near(z, -10, 1e-9)
	end,
}

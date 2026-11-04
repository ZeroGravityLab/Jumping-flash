local Requests = require("../src/ReplicatedStorage/Config/Requests")
local World = require("../src/ReplicatedStorage/Config/World")
local RequestLogic = require("../src/ReplicatedStorage/Shared/RequestLogic")
local Strings = require("../src/ReplicatedStorage/Shared/Strings")
local WorldGen = require("../src/ReplicatedStorage/Shared/WorldGen")
local check = require("./check")

local letters = RequestLogic.find(Requests, "tut_letters")

return {
	["의뢰 id는 겹치지 않고 주민이 실제로 있다"] = function()
		local seen, residents = {}, {}
		for _, r in Requests.Residents do
			residents[r.id] = true
		end
		for _, request in Requests.Requests do
			check.truthy(not seen[request.id], "duplicate " .. request.id)
			seen[request.id] = true
			check.truthy(residents[request.resident], request.id .. " has unknown resident")
		end
	end,

	["메달 기준은 금 < 은이고 최소 시간보다 크다"] = function()
		for _, request in Requests.Requests do
			check.truthy(request.minTime < request.gold, request.id .. " gold below minTime")
			check.truthy(request.gold < request.silver, request.id .. " gold not faster than silver")
		end
	end,

	["선행 의뢰는 실제로 있는 의뢰다"] = function()
		for _, request in Requests.Requests do
			for _, id in request.requires or {} do
				check.truthy(RequestLogic.find(Requests, id) ~= nil, request.id .. " requires unknown " .. id)
			end
		end
	end,

	-- surface 지점은 위에서 내려 쏜 레이캐스트로 찾으므로, 위에 떠 있는 섬이 있으면 그 섬에 찍힌다
	["surface 지점 위에 위성 섬·정상 섬이 없다"] = function()
		local islands, residentIsland = {}, {}
		for _, island in World.Islands do
			islands[island.id] = island
		end
		for _, r in Requests.Residents do
			residentIsland[r.id] = r.island
		end
		for _, request in Requests.Requests do
			local specs = table.clone(request.points or {})
			if request.target then
				table.insert(specs, request.target)
			end
			for _, spec in specs do
				local island = islands[spec.island or residentIsland[request.resident]]
				check.truthy(island ~= nil, request.id .. " point on unknown island")
				if spec.surface then
					local x, z = spec.surface[1], spec.surface[2]
					check.truthy(math.sqrt(x * x + z * z) < island.radius, request.id .. " point off island")
					local s = island.satellites
					if s then
						for i, p in WorldGen.spiral(s.count, s.orbit, s.rise, s.startAngle, s.angleStep, 0) do
							local gap = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
							check.truthy(
								gap > s.radius + 4,
								string.format("%s point under satellite %d", request.id, i)
							)
						end
					end
					if island.summit then
						check.truthy(
							math.sqrt(x * x + z * z) > island.summit.radius + 4,
							request.id .. " point under summit"
						)
					end
				end
			end
		end
	end,

	["모든 의뢰에 언어별 대사와 목표 문장이 있다"] = function()
		for code, texts in Strings.languages do
			for _, request in Requests.Requests do
				for _, suffix in { "_Line", "_Goal" } do
					local key = "Req_" .. request.id .. suffix
					check.truthy(texts[key] ~= nil, code .. " missing " .. key)
				end
			end
		end
	end,

	["장마다 보스를 열 만큼 의뢰가 있다"] = function()
		for chapter, spec in Requests.Chapters do
			local count = 0
			for _, request in Requests.Requests do
				if request.chapter == chapter then
					count += 1
				end
			end
			check.truthy(count >= spec.bossAt, string.format("chapter %d has %d of %d", chapter, count, spec.bossAt))
		end
	end,

	["시간으로 메달을 정한다"] = function()
		check.equal(RequestLogic.medalFor(letters, letters.gold), "gold")
		check.equal(RequestLogic.medalFor(letters, letters.gold + 1), "silver")
		check.equal(RequestLogic.medalFor(letters, letters.silver + 1), "bronze")
	end,

	["선행 의뢰를 끝내야 다음 의뢰가 열린다"] = function()
		local dive = RequestLogic.find(Requests, "tut_dive")
		check.equal(RequestLogic.isAvailable(dive, {}), false)
		check.equal(RequestLogic.isAvailable(dive, { tut_letters = { medal = "bronze", bestTime = 99 } }), true)
	end,

	["주민은 안 끝낸 의뢰부터, 다 끝냈으면 금메달 아닌 것을 건넨다"] = function()
		check.equal(RequestLogic.nextFor(Requests, "Pip", {}).id, "tut_letters")
		local progress = { tut_letters = { medal = "silver", bestTime = 60 } }
		check.equal(RequestLogic.nextFor(Requests, "Pip", progress).id, "tut_dive")
		progress.tut_dive = { medal = "gold", bestTime = 20 }
		check.equal(RequestLogic.nextFor(Requests, "Pip", progress).id, "tut_letters")
		progress.tut_letters = { medal = "gold", bestTime = 30 }
		check.equal(RequestLogic.nextFor(Requests, "Pip", progress), nil)
	end,

	["너무 빠른 보고는 거절한다"] = function()
		check.equal(RequestLogic.isPlausible(letters, letters.minTime - 1), false)
		check.equal(RequestLogic.isPlausible(letters, letters.minTime), true)
	end,

	["코인: 처음은 전액, 올리면 차액, 같거나 낮으면 0"] = function()
		local coins = Requests.MedalCoins
		check.equal(RequestLogic.coinsFor(Requests, "silver", nil), coins.silver)
		check.equal(RequestLogic.coinsFor(Requests, "gold", "silver"), coins.gold - coins.silver)
		check.equal(RequestLogic.coinsFor(Requests, "silver", "silver"), 0)
		check.equal(RequestLogic.coinsFor(Requests, "bronze", "gold"), 0)
	end,

	["종 게이지는 그 장에서 끝낸 의뢰만 센다"] = function()
		local progress = {
			c1_delivery = { medal = "bronze", bestTime = 60 },
			tut_letters = { medal = "gold", bestTime = 30 },
		}
		local done, needed = RequestLogic.bellGauge(Requests, 1, progress)
		check.equal(done, 1)
		check.equal(needed, Requests.Chapters[1].bossAt)
	end,
}

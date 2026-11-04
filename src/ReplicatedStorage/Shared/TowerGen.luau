-- 클라우드 러시 탑 생성 (GDD 8.1, 14.3). 순수 함수: 같은 시드면 언제나 같은 탑이다.
-- 흐름: 시드 → 청크 수 → 칸마다 난이도 목표 → 청크 선택(같은 청크 연속 금지, 어려운 청크 연속 상한, 쉬는 청크) → 회전
local TowerGen = {}

export type Placed = { chunk: any, yaw: number, index: number }

-- 결정적 난수 (Lune·Roblox 공용, Park–Miller). 0 이상 1 미만
function TowerGen.random(seed: number): () -> number
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

function TowerGen.generate(seed: number, chunks, cfg): { Placed }
	local random = TowerGen.random(seed)
	local count = cfg.ChunkCountMin + math.floor(random() * (cfg.ChunkCountMax - cfg.ChunkCountMin + 1))
	local rests, normal = {}, {}
	for _, chunk in chunks do
		table.insert(if chunk.rest then rests else normal, chunk)
	end

	local layout = {}
	local previous, hardRun = nil, 0
	for i = 1, count do
		local pick
		if i % cfg.RestEvery == 0 and #rests > 0 then
			pick = rests[1 + math.floor(random() * #rests)]
		else
			-- 아래는 쉽고 위로 갈수록 어려워진다 (1 → 5)
			local target = 1 + 4 * (i - 1) / math.max(count - 1, 1)
			-- 목표 난이도 ±1에서 고르고, 없으면 난이도 조건만 푼다 (연속 금지·어려운 청크 상한은 지킨다)
			local candidates = {}
			for _, nearTarget in { true, false } do
				for _, chunk in normal do
					local tooHard = chunk.difficulty >= 4 and hardRun >= cfg.MaxHardInRow
					local fits = not nearTarget or math.abs(chunk.difficulty - target) <= 1
					if chunk ~= previous and fits and not tooHard then
						table.insert(candidates, chunk)
					end
				end
				if #candidates > 0 then
					break
				end
			end
			pick = candidates[1 + math.floor(random() * #candidates)]
		end
		hardRun = if not pick.rest and pick.difficulty >= 4 then hardRun + 1 else 0
		previous = pick
		table.insert(layout, { chunk = pick, yaw = 90 * math.floor(random() * 4), index = i })
	end
	return layout
end

-- 청크 안 수평 좌표를 yaw(도, 90의 배수)만큼 돌린다
function TowerGen.rotate(x: number, z: number, yaw: number): (number, number)
	local r = math.rad(yaw)
	local c, s = math.cos(r), math.sin(r)
	local rx, rz = x * c - z * s, x * s + z * c
	-- 90도 배수에서 생기는 아주 작은 오차를 지운다
	return math.round(rx * 1e6) / 1e6, math.round(rz * 1e6) / 1e6
end

-- 발판 하나: 도착 높이(올라서는 높이), 출발 높이(거기서 다시 뛰는 높이), 수평 반경, 거기서 오를 수 있는 높이
local function footing(platform, cfg)
	local kind, x, y, z, size = platform[1], platform[2], platform[3], platform[4], platform[5]
	if kind == "slab" or kind == "cloud" then
		return { x = x, z = z, arrive = y, depart = y, r = size / 2, rise = cfg.LintMaxRise }
	elseif kind == "pad" then
		return { x = x, z = z, arrive = y, depart = y, r = 6, rise = cfg.LintPadRise }
	elseif kind == "updraft" then
		-- 기둥 아무 높이로나 들어가 꼭대기에서 나온다
		return { x = x, z = z, arrive = y, depart = y + size, r = 9, rise = cfg.LintMaxRise }
	elseif kind == "puff" then
		return { x = x, z = z, arrive = y + 4, depart = y + 4, r = 4, rise = cfg.LintPuffRise }
	end
	return nil
end

-- 도달 가능성 린트: 입구 → path → 출구의 각 단계가 오를 수 있는 높이·간격인지. 문제 목록을 돌려준다
function TowerGen.lint(chunk, cfg): { string }
	local problems = {}
	local entry = { x = 0, z = 0, arrive = 0, depart = 0, r = 8, rise = cfg.LintMaxRise }
	local steps = { entry }
	for _, index in chunk.path do
		local foot = footing(chunk.platforms[index], cfg)
		if not foot then
			table.insert(problems, string.format("%s: platform %d has unknown kind", chunk.id, index))
			return problems
		end
		table.insert(steps, foot)
	end
	table.insert(steps, { x = 0, z = 0, arrive = cfg.ChunkHeight, depart = cfg.ChunkHeight, r = 8, rise = 0 })
	for i = 2, #steps do
		local from, to = steps[i - 1], steps[i]
		local rise = to.arrive - from.depart
		local gap = math.sqrt((to.x - from.x) ^ 2 + (to.z - from.z) ^ 2) - from.r - to.r
		if rise > from.rise then
			table.insert(problems, string.format("%s: step %d rises %d > %d", chunk.id, i - 1, rise, from.rise))
		end
		if gap > cfg.LintMaxGap then
			table.insert(problems, string.format("%s: step %d gap %.0f > %d", chunk.id, i - 1, gap, cfg.LintMaxGap))
		end
	end
	return problems
end

return TowerGen

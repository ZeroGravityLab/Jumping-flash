-- 클라우드 러시 청크 21종 (GDD 8.1). 청크 하나는 높이 150(Rush.ChunkHeight)의 수직 구간이다.
-- 원점은 청크 바닥 가운데의 입구 발판 윗면이고, 출구는 (0, 150, 0) = 다음 청크의 입구(또는 꼭대기 종).
-- 발판 { 종류, x, y, z, 크기 }
--   slab    고정 발판. 지름이 크기, 윗면이 y
--   cloud   일방향 구름 (아래에서 통과). 지름이 크기, 윗면이 y
--   pad     바운스 패드 (지름 12). 윗면이 y
--   updraft 상승 기류. 밑면이 y, 높이가 크기
--   puff    퍼플링 (밟으면 반동). 중심이 y
-- path는 의도한 길의 발판 번호 순서. 도달 가능성 린트(tests/TowerGen.spec)가 입구 → path → 출구를 검사한다.
-- difficulty 1~5, rest = 쉬는 청크
return {
	{
		id = "Steps",
		difficulty = 1,
		platforms = { { "slab", 30, 50, 10, 14 }, { "slab", 5, 100, 35, 14 } },
		path = { 1, 2 },
	},
	{
		id = "Clouds",
		difficulty = 1,
		platforms = { { "cloud", 0, 40, -25, 20 }, { "cloud", -25, 85, 0, 20 }, { "cloud", 0, 125, 25, 20 } },
		path = { 1, 2, 3 },
	},
	{
		id = "Spring",
		difficulty = 2,
		platforms = { { "slab", -20, 25, -20, 12 }, { "pad", 25, 15, 10 } },
		path = { 2 },
	},
	{
		id = "Updraft",
		difficulty = 2,
		platforms = { { "slab", -30, 8, 0, 16 }, { "updraft", -30, 8, 0, 110 } },
		path = { 1, 2 },
	},
	{
		id = "CloudSpiral",
		difficulty = 2,
		platforms = {
			{ "cloud", 30, 30, 0, 18 },
			{ "cloud", 0, 60, 30, 18 },
			{ "cloud", -30, 90, 0, 18 },
			{ "cloud", 0, 120, -30, 18 },
		},
		path = { 1, 2, 3, 4 },
	},
	{
		id = "PuffLadder",
		difficulty = 3,
		platforms = { { "puff", 20, 35, 0 }, { "puff", 0, 70, 20 }, { "puff", -20, 105, 0 } },
		path = { 1, 2, 3 },
	},
	{
		id = "Zigzag",
		difficulty = 3,
		platforms = { { "slab", 35, 40, 0, 10 }, { "slab", 0, 80, -35, 10 }, { "slab", -35, 120, 0, 10 } },
		path = { 1, 2, 3 },
	},
	{
		id = "PadBridge",
		difficulty = 3,
		platforms = { { "pad", -30, 30, 20 }, { "slab", 25, 120, -15, 10 } },
		path = { 1, 2 },
	},
	{
		id = "CloudPad",
		difficulty = 3,
		platforms = { { "cloud", -30, 40, 0, 18 }, { "pad", 0, 60, 30 }, { "cloud", 20, 140, 0, 18 } },
		path = { 1, 2, 3 },
	},
	{
		id = "Pillars",
		difficulty = 4,
		platforms = { { "slab", 25, 45, 15, 8 }, { "slab", -10, 90, 30, 8 }, { "slab", -30, 130, -5, 8 } },
		path = { 1, 2, 3 },
	},
	{
		id = "DraftPuff",
		difficulty = 4,
		platforms = { { "updraft", 25, 0, 25, 70 }, { "puff", 0, 100, 30 }, { "slab", -25, 125, 5, 12 } },
		path = { 1, 2, 3 },
	},
	{
		id = "LongJump",
		difficulty = 4,
		platforms = { { "slab", 45, 30, 0, 12 }, { "slab", 0, 70, 45, 12 }, { "slab", -45, 110, 0, 12 } },
		path = { 1, 2, 3 },
	},
	{
		id = "PuffSwarm",
		difficulty = 5,
		platforms = {
			{ "puff", 25, 30, 0 },
			{ "puff", 25, 65, 30 },
			{ "puff", -5, 95, 35 },
			{ "puff", -30, 125, 10 },
		},
		path = { 1, 2, 3, 4 },
	},
	{
		id = "SkyMix",
		difficulty = 5,
		platforms = { { "slab", 30, 45, -20, 8 }, { "puff", 0, 85, -35 }, { "cloud", -30, 120, -10, 14 } },
		path = { 1, 2, 3 },
	},
	{
		id = "CloudNet",
		difficulty = 1,
		rest = true,
		platforms = { { "cloud", 0, 60, 0, 40 }, { "slab", 25, 105, 0, 16 } },
		path = { 1, 2 },
	},
	-- 완성도 작업에서 더한 청크 (15 → 21종)
	{
		id = "Terrace",
		difficulty = 1,
		platforms = { { "slab", -25, 40, 20, 18 }, { "slab", 15, 80, 30, 18 }, { "slab", 25, 120, -10, 18 } },
		path = { 1, 2, 3 },
	},
	{
		id = "PadHop",
		difficulty = 2,
		platforms = { { "pad", -25, 10, -15 }, { "cloud", 25, 110, 15, 16 } },
		path = { 1, 2 },
	},
	{
		id = "DraftRelay",
		difficulty = 3,
		platforms = {
			{ "updraft", 30, 0, 0, 60 },
			{ "slab", 0, 70, 30, 12 },
			{ "updraft", -30, 70, 0, 60 },
		},
		path = { 1, 2, 3 },
	},
	{
		id = "PuffTower",
		difficulty = 4,
		platforms = { { "puff", 15, 30, 15 }, { "puff", -15, 95, 15 }, { "slab", 0, 140, -20, 10 } },
		path = { 1, 2, 3 },
	},
	{
		id = "Needles",
		difficulty = 5,
		platforms = { { "slab", 40, 40, 20, 6 }, { "slab", 0, 85, 45, 6 }, { "slab", -40, 125, 15, 6 } },
		path = { 1, 2, 3 },
	},
	{
		id = "Meadow",
		difficulty = 1,
		rest = true,
		platforms = { { "slab", 0, 50, 25, 30 }, { "cloud", -20, 100, 0, 24 } },
		path = { 1, 2 },
	},
}

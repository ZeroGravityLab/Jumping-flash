-- 월드 배치 (GDD 6.3: 섬 하나 = 한 장). 단위 studs, 고도 1 stud = 1 m.
-- 좌표는 배열 {x, y, z}. 섬의 y는 잔디 윗면 높이이고, 건물·기능 좌표는 섬 중심 기준 {x, z}다.
-- 나무 팔레트는 ServerStorage.Assets.Trees의 번호: 1 초록, 2 진초록, 3 연두, 4 청록, 5 파랑, 6 보라, 7 자주, 8 분홍, 9 장미, 10 빨강
return {
	CloudSeaY = -620,
	CloudSeaRadius = 3000, -- 뭉게구름이 솟는 범위
	CloudSeaPuffs = 320,
	-- 바닥판은 대기 안개에 끝이 묻힐 만큼 넓게 깐다 (3000이면 지평선에 판 모서리가 보였다)
	CloudSeaFloorRadius = 9000,

	-- 섬 사이를 떠다니는 구름 덩어리. 떨어지며 통과하면 깊이가 느껴진다
	CloudPuffs = { count = 46, minDistance = 200, maxDistance = 1400, minY = -460, maxY = 380 },

	Islands = {
		{
			id = "Skyhaven", -- 허브
			center = { 0, 0, 0 },
			radius = 170,
			depth = 280,
			seed = 11,
			plazaRadius = 36,
			treePalette = { 1, 3, 4, 8, 8 },
			trees = 34,
			flowers = 70,
			rocks = 10,
			hills = 6,
			buildings = {
				{ "House_LowPoly", -66, 46, 135 },
				{ "House_Euro", 62, 58, 215 },
				{ "House_Village", -24, -84, 15 },
				{ "House_LowPoly", 84, -44, 265 },
			},
			features = {
				{ type = "Bell", x = 0, z = 0 },
				{ type = "BounceFlower", x = 34, z = 74 },
				{ type = "BounceFlower", x = -96, z = -14 },
				{ type = "Pufflings", x = -54, z = 104, heights = { 9, 14, 19 }, step = 16 },
				{ type = "CloudSteps", x = 116, z = 54, count = 6, rise = 32 },
			},
		},
		{
			id = "WindmillMeadow", -- 1장 풍차 초원
			chapter = 1,
			center = { 480, 24, -70 },
			radius = 150,
			depth = 250,
			seed = 23,
			plazaRadius = 0,
			treePalette = { 3, 3, 1, 8, 7, 6 },
			trees = 30,
			flowers = 110,
			rocks = 12,
			hills = 8,
			buildings = {
				{ "Windmill", 22, -18, 200, 0.72 },
				{ "House_Village", -66, 58, 40 },
				{ "House_Euro", 58, -70, 300 }, -- c1_delivery 배달지. 위성 섬 궤도 안쪽에 둔다
			},
			features = {
				{ type = "Updraft", x = -38, z = -52, height = 230 },
				{ type = "BounceFlower", x = -20, z = 90 },
				{ type = "BounceFlower", x = 96, z = -10 },
				{ type = "Pufflings", x = 40, z = 40, heights = { 30, 60, 90, 120, 150 }, step = 22 },
			},
			-- 섬을 감아 오르는 작은 섬 정원. 꼭대기에 1장의 종
			satellites = { count = 8, orbit = 118, rise = 52, startAngle = 200, angleStep = 42, radius = 22 },
			summit = { height = 470, radius = 30 },
		},
	},

	-- 허브에서 1장으로 건너가는 징검다리 (자산 Islet, {x, 윗면 y, z, 크기 배율})
	SteppingStones = {
		{ 208, 6, -18, 1.6 },
		{ 252, 14, -36, 1.4 },
		{ 294, 22, -52, 1.5 },
	},

	-- 멀리 떠 있는 풍경용 섬. 시드로 매번 같은 배치
	DistantIslands = {
		count = 16,
		seed = 7,
		minDistance = 700,
		maxDistance = 1350,
		minY = -260,
		maxY = 420,
		minRadius = 35,
		maxRadius = 115,
	},

	Balloons = { count = 8, seed = 5, minDistance = 260, maxDistance = 950, minY = 60, maxY = 520 },
	BirdFlocks = { count = 6, seed = 9, minDistance = 120, maxDistance = 700, minY = -180, maxY = 60 },
}

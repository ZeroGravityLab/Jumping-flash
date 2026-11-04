-- 의뢰와 주민 (GDD 6.4~6.6). 좌표는 섬 중심 기준.
-- surface 좌표 {x, z, 높이}: 그 자리 맨 위 표면(지붕·땅) 위로 높이만큼 띄운다. 이 지점 주변엔 나무를 심지 않는다
-- air 좌표 {x, y, z}: 섬 윗면 높이 기준의 고정 위치
-- satellite 좌표 {n, 높이}: 그 섬의 n번째 나선 섬 윗면 위
-- 좌표에 island를 적으면 주민의 섬 대신 그 섬 기준이다 (섬을 건너는 배달)
-- item: 수집·배달 물건의 모양 (없으면 편지·화분)
-- 경주(Race): 연이 플레이어 머리 위에서 출발해 points를 지나 target에 kiteTime초 뒤에 닿는다. 그보다 먼저 target에 닿아야 한다
-- 시간은 초. minTime보다 빨리 끝난 보고는 서버가 거절한다
return {
	MedalCoins = { bronze = 15, silver = 25, gold = 40 },

	-- boss: 그 장의 보스 의뢰. 이기면 섬이 되살아난다 (RequestLogic.isRestored)
	Chapters = {
		[1] = { island = "WindmillMeadow", bossAt = 6, boss = "c1_boss" },
	},

	-- 주민 이야기 (GDD 6.6): final 의뢰를 처음 끝내면 엔딩 카드가 뜨고 허브가 바뀐다 (그 플레이어에게만).
	-- 바뀐 모습은 클라이언트 Requests/Stories의 같은 id 빌더가 만들고, 카드를 닫으면 showAt 주민에게 길 안내한다.
	-- spots는 island 중심 기준 {x, z}이고, 월드 생성 때 그 주변에 나무를 심지 않는다
	Stories = {
		{
			id = "Bakery",
			resident = "Bram",
			final = "c1_flour",
			showAt = "Momo",
			island = "Skyhaven",
			spots = { stall = { -30, 24 }, bun = { -22, 44 } },
			house = { -66, 46 }, -- 모모 뒤 집: 굴뚝 연기와 지붕 위 통통 빵
		},
		-- 1장 보스를 이기면 풍차 초원이 되살아난다 (먹구름이 걷히고 무지개)
		{ id = "Chapter1", final = "c1_boss", island = "WindmillMeadow", spots = {} },
	},

	Residents = {
		{ id = "Pip", island = "Skyhaven", x = 28, z = 34, yaw = 210, color = { 120, 170, 230 } },
		{ id = "Momo", island = "Skyhaven", x = -44, z = 18, yaw = 120, color = { 240, 170, 150 } },
		{ id = "Rhea", island = "WindmillMeadow", x = -36, z = 22, yaw = 160, color = { 170, 140, 220 } },
		{ id = "Bram", island = "WindmillMeadow", x = -4, z = 34, yaw = 150, color = { 214, 180, 110 } },
		{ id = "Wren", island = "WindmillMeadow", x = 66, z = 8, yaw = 90, color = { 110, 200, 170 } },
	},

	Requests = {
		{
			id = "tut_letters",
			chapter = 0,
			resident = "Pip",
			type = "Collect",
			points = {
				{ surface = { -66, 46, 3 } },
				{ surface = { 62, 58, 3 } },
				{ surface = { -24, -84, 3 } },
				{ surface = { 84, -44, 3 } },
			},
			gold = 45,
			silver = 75,
			minTime = 10,
		},
		{
			id = "tut_lanterns",
			chapter = 0,
			resident = "Momo",
			type = "Beacons",
			points = {
				{ surface = { -112, 30, 0 } },
				{ surface = { 104, 92, 0 } },
				{ surface = { 22, -122, 0 } },
			},
			gold = 35,
			silver = 60,
			minTime = 6,
		},
		{
			id = "tut_dive",
			chapter = 0,
			resident = "Pip",
			type = "Rings",
			requires = { "tut_letters" },
			-- 구름 계단 꼭대기에서 뛰어내리며 통과한다
			points = {
				{ air = { 128, 158, 56 } },
				{ air = { 136, 122, 48 } },
				{ air = { 144, 86, 40 } },
				{ air = { 150, 50, 32 } },
			},
			gold = 30,
			silver = 50,
			minTime = 4,
		},
		{
			id = "c1_delivery",
			chapter = 1,
			resident = "Rhea",
			type = "Delivery",
			-- 스톰프하면 화분이 깨진다
			target = { surface = { 58, -70, 0 } },
			gold = 25,
			silver = 45,
			minTime = 5,
		},
		{
			id = "c1_beacons",
			chapter = 1,
			resident = "Rhea",
			type = "Beacons",
			points = {
				{ satellite = { 2, 0 } },
				{ satellite = { 4, 0 } },
				{ satellite = { 6, 0 } },
			},
			gold = 70,
			silver = 120,
			minTime = 15,
		},
		{
			id = "c1_dive",
			chapter = 1,
			resident = "Rhea",
			type = "Rings",
			requires = { "c1_beacons" },
			-- 정상(470 m)의 종 옆에서 뛰어내려 섬까지 내려오는 다이빙
			points = {
				{ air = { 10, 420, 36 } },
				{ air = { 24, 340, 56 } },
				{ air = { 36, 260, 70 } },
				{ air = { 46, 180, 78 } },
				{ air = { 52, 100, 80 } },
			},
			gold = 110,
			silver = 180,
			minTime = 12,
		},
		{
			id = "c1_laundry",
			chapter = 1,
			resident = "Bram",
			type = "Collect",
			item = "Laundry",
			-- 지붕, 나선 섬 정원, 상승 기류 속, 퍼플링 줄 끝, 바운스 꽃 위
			points = {
				{ surface = { -66, 58, 3 } },
				{ surface = { 58, -70, 3 } },
				{ satellite = { 1, 3 } },
				{ satellite = { 2, 3 } },
				{ satellite = { 3, 3 } },
				{ air = { -38, 170, -52 } },
				{ air = { 124, 186, 40 } },
				{ air = { -20, 100, 90 } },
			},
			gold = 90,
			silver = 150,
			minTime = 25,
		},
		{
			id = "c1_murk",
			chapter = 1,
			resident = "Bram",
			type = "Murk",
			requires = { "c1_laundry" },
			-- 집 지붕에서 시작해 마을 위를 감아 오른다. 땅에 닿으면 터뜨린 머크가 다시 뭉친다
			points = {
				{ surface = { -66, 58, 5 } },
				{ air = { -46, 48, 78 } },
				{ air = { -17, 60, 70 } },
				{ air = { -4, 72, 42 } },
				{ air = { -17, 84, 14 } },
				{ air = { -46, 96, 6 } },
				{ air = { -71, 108, 24 } },
			},
			gold = 22,
			silver = 40,
			minTime = 8,
		},
		{
			id = "c1_flour",
			chapter = 1,
			resident = "Bram",
			type = "Delivery",
			item = "Flour",
			requires = { "c1_murk" },
			-- 징검다리 섬을 건너 허브 빵집(모모)까지
			target = { surface = { -54, 30, 0 }, island = "Skyhaven" },
			gold = 32,
			silver = 55,
			minTime = 14,
		},
		{
			id = "c1_ribbons",
			chapter = 1,
			resident = "Wren",
			type = "Collect",
			item = "Ribbon",
			-- 풍차 꼭대기, 바운스 꽃 위, 퍼플링 줄, 상승 기류 끝, 5·6번 나선 섬
			points = {
				{ air = { 22, 118, -18 } },
				{ air = { 96, 95, -10 } },
				{ air = { 84, 110, 40 } },
				{ air = { -38, 240, -52 } },
				{ satellite = { 5, 3 } },
				{ satellite = { 6, 3 } },
			},
			gold = 60,
			silver = 100,
			minTime = 18,
		},
		{
			id = "c1_kite_race",
			chapter = 1,
			resident = "Wren",
			type = "Race",
			requires = { "c1_ribbons" },
			-- 지름길: 바운스 꽃(높이 약 12)에서 튀어 오른 뒤 2·3단을 퍼펙트로 뛰면 4번 정원(208)보다 약 42 높이 올라
			-- 여유 있게 닿는다 (2026-11-04 Studio 실측, 금 4.7초). 퍼펙트가 없으면 약 9만 넘어 가장자리에 아슬아슬하게 걸쳐야 한다.
			-- 정원 바로 밑에서 뛰면 정원 바닥에 머리를 부딪힌다. 돌아가는 길은 3번 정원을 거친다
			points = {
				{ air = { 90, 70, -20 } },
				{ air = { 100, 150, -50 } },
			},
			target = { satellite = { 4, 0 } },
			kiteTime = 18,
			gold = 8,
			silver = 12,
			minTime = 4,
		},
		{
			id = "c1_kite_murk",
			chapter = 1,
			resident = "Wren",
			type = "Murk",
			requires = { "c1_kite_race" },
			-- 퍼플링 줄 옆 연줄에 엉긴 머크. 퍼플링을 밟아 이어 가도 된다
			points = {
				{ air = { 28, 14, 56 } },
				{ air = { 50, 44, 56 } },
				{ air = { 72, 74, 56 } },
				{ air = { 94, 104, 56 } },
				{ air = { 116, 134, 56 } },
				{ air = { 128, 172, 46 } },
			},
			gold = 16,
			silver = 28,
			minTime = 6,
		},
		{
			id = "c1_summit_race",
			chapter = 1,
			resident = "Wren",
			type = "Race",
			requires = { "c1_kite_murk" },
			-- 연은 나선 섬을 따라 정상(월드 높이 470)의 종까지 오른다. 상승 기류·바운스 꽃·퍼펙트로 앞질러야 한다
			points = {
				{ satellite = { 4, 20 } },
				{ satellite = { 6, 20 } },
				{ satellite = { 8, 20 } },
			},
			target = { air = { 0, 446, 0 } },
			kiteTime = 55,
			gold = 30,
			silver = 42,
			minTime = 12,
		},
		{
			id = "c1_boss",
			chapter = 1,
			boss = true,
			name = "Boss_Thunderhead",
			island = "WindmillMeadow",
			type = "Boss",
			-- 썬더헤드 (GDD 6.3): 정상(월드 470) 위 먹구름. 구름 발판 7개를 감아 올라 꼭대기 피뢰침 3개를 스톰프한다.
			-- 오르는 동안 번개가 떨어질 자리가 먼저 빛난다. 좌표는 섬 윗면(월드 24) 기준, 정상 윗면은 air 446
			gate = { air = { 20, 446, -8 } }, -- 정상의 폭풍 받침대 (도전 프롬프트)
			center = { air = { 0, 592, 0 } }, -- 먹구름 몸통 중심
			points = { -- 반경 48 나선, 28씩 오른다
				{ air = { 48, 476, 0 } },
				{ air = { 27.5, 504, 39.3 } },
				{ air = { -16.4, 532, 45.1 } },
				{ air = { -46.4, 560, 12.4 } },
				{ air = { -36.8, 588, -30.9 } },
				{ air = { 4.2, 616, -47.8 } },
				{ air = { 41.6, 644, -24 } },
			},
			rods = { -- 몸통 위 피뢰침 발판
				{ air = { 20, 672, 10 } },
				{ air = { -14, 690, 18 } },
				{ air = { -6, 708, -20 } },
			},
			fallBelow = 420, -- 발이 이 air 높이보다 내려가면 실패 (정상 아래로 떨어짐)
			gold = 45,
			silver = 75,
			minTime = 15,
		},
	},
}

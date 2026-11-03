-- 의뢰와 주민 (GDD 6.4~6.6). 좌표는 섬 중심 기준.
-- surface 좌표 {x, z, 높이}: 그 자리 맨 위 표면(지붕·땅) 위로 높이만큼 띄운다. 이 지점 주변엔 나무를 심지 않는다
-- air 좌표 {x, y, z}: 섬 윗면 높이 기준의 고정 위치
-- satellite 좌표 {n, 높이}: 그 섬의 n번째 나선 섬 윗면 위
-- 시간은 초. minTime보다 빨리 끝난 보고는 서버가 거절한다
return {
	MedalCoins = { bronze = 15, silver = 25, gold = 40 },

	Chapters = {
		[1] = { island = "WindmillMeadow", bossAt = 6 },
	},

	Residents = {
		{ id = "Pip", island = "Skyhaven", x = 28, z = 34, yaw = 210, color = { 120, 170, 230 } },
		{ id = "Momo", island = "Skyhaven", x = -44, z = 18, yaw = 120, color = { 240, 170, 150 } },
		{ id = "Rhea", island = "WindmillMeadow", x = -36, z = 22, yaw = 160, color = { 170, 140, 220 } },
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
	},
}

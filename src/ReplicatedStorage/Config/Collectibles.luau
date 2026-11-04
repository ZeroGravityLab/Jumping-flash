-- 숨은 별조각 (완성도 작업, GDD 9.6의 "섬의 비밀 장소"를 앞당긴 것). 목표 표시를 띄우지 않는다: 찾는 재미가 핵심이다.
-- air 좌표 {x, y, z}는 섬 윗면 중심 기준 (Config Requests의 air와 같다). 서버가 이 위치로 줍기를 확인한다
-- 한 섬의 별조각을 다 모으면 reward(Config Shop의 unlock 물건)를 준다
return {
	ShardCoins = 25,
	CollectRadius = 6, -- 루트가 이 안에 들어오면 줍는다
	-- 서버가 확인하는 루트-별조각 거리. 서버가 보는 위치는 지연만큼 늦다: 낙하 속도 160으로 0.25초면 40 차이
	ServerReach = 45,

	Sets = {
		{ island = "Skyhaven", reward = "trail_stardust" },
		{ island = "WindmillMeadow", reward = "boots_meadow" },
	},

	Shards = {
		-- 스카이헤이븐
		{ id = "hub_bell", island = "Skyhaven", air = { 0, 44, 0 } }, -- 광장 종 위
		{ id = "hub_flower", island = "Skyhaven", air = { -96, 108, -14 } }, -- 서쪽 바운스 꽃 위 하늘 (꽃 윗면 15 + 반동 약 102)
		{ id = "hub_clouds", island = "Skyhaven", air = { 104, 228, 40 } }, -- 구름 계단 꼭대기(211) 옆
		{ id = "hub_puff", island = "Skyhaven", air = { -10, 62, 104 } }, -- 퍼플링 줄 끝 너머
		{ id = "hub_rim", island = "Skyhaven", air = { 88, -30, -152 } }, -- 남동쪽 가장자리(반경 168) 아래: 뛰어내려야 닿는다
		-- 풍차 초원
		{ id = "mead_windmill", island = "WindmillMeadow", air = { 22, 112, -18 } }, -- 풍차 꼭대기(106)
		{ id = "mead_updraft", island = "WindmillMeadow", air = { -24, 246, -52 } }, -- 상승 기류 끝(232) 옆
		{ id = "mead_puff", island = "WindmillMeadow", air = { 140, 196, 40 } }, -- 다섯째 퍼플링(162) 너머
		{ id = "mead_garden", island = "WindmillMeadow", air = { 117, 192, 16 } }, -- 5번 하늘 정원(윗면 260) 밑
		{ id = "mead_summit", island = "WindmillMeadow", air = { 0, 520, 0 } }, -- 정상의 종(475) 위
		{ id = "mead_rim", island = "WindmillMeadow", air = { -147, -28, 53 } }, -- 서쪽 가장자리(반경 148) 아래
		{ id = "mead_flower", island = "WindmillMeadow", air = { 96, 116, -10 } }, -- 동쪽 바운스 꽃 위 하늘
	},
}

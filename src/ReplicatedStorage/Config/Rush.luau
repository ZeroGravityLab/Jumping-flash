-- 클라우드 러시 (GDD 7.2, 8.1). 시간은 초, 길이는 studs (고도 1 stud = 1 m).
return {
	-- 라운드 흐름
	LobbySeconds = 20, -- 허브에서 참가를 받는 시간
	CountdownSeconds = 3,
	MaxRoundSeconds = 240,
	EndGraceSeconds = 3, -- 누군가 종을 울린 뒤 라운드가 끝나기까지
	ResultsSeconds = 8,
	ServerTick = 0.2, -- 서버가 탈락·종·높이를 보는 간격

	-- 탑 (허브 서쪽 하늘). 청크 하나의 높이가 ChunkHeight이고, 맨 위에 종이 있다
	TowerOrigin = { -380, 0, -40 },
	ChunkHeight = 150,
	ChunkCountMin = 8,
	ChunkCountMax = 12,
	RestEvery = 4, -- 이 번째마다 쉬는 청크
	MaxHardInRow = 2, -- 난이도 4 이상 연속 상한
	StartRadius = 30, -- 출발 발판 반경
	SummitRadius = 18,
	BellRadius = 14,

	-- 구름 해일: TideDelay초 뒤 탑 바닥에서 출발해 점점 빨라진다
	TideDelay = 30,
	TideStartSpeed = 3,
	TideAccel = 0.04,
	TideGrace = 2, -- 발이 해일 윗면보다 이만큼 아래로 잠기면 탈락

	-- 보상 (EconomyService가 지급)
	MetersPerCoin = 20,
	RankBonus = { 30, 20, 10 },
	RankBonusMinPlayers = 2, -- 혼자 하면 늘 1위라 순위 보너스를 주지 않는다
	BellBonus = 25,

	-- 라이벌 밟기 (GDD 7.2): 밟힌 쪽은 휘청이고 공중 점프를 잃는다. 그 뒤 잠깐 무적
	StompWobble = 0.6,
	StompJumpsLost = 1,
	StompImmunity = 1.5,
	-- 서버 확인 범위: 밟은 쪽 루트가 밟힌 쪽 루트보다 StompMinRise~StompMaxRise 위, 수평 StompMaxReach 안 (네트워크 지연 여유 포함)
	StompMinRise = -2,
	StompMaxRise = 14,
	StompMaxReach = 10,

	-- MovementGuard (GDD 14.2): 새 최고 높이는 한 번에 GuardRiseBurst까지, 평균 GuardRiseRate(초당)로 회복.
	-- GuardMaxRiseTime초 넘게 쉬지 않고 오르면 비행으로 본다 (정상 플레이의 가장 긴 연속 상승은 약 4초)
	GuardRiseBurst = 300,
	GuardRiseRate = 40,
	GuardMaxRiseTime = 8,
	GuardRisingStep = 0.5, -- 한 번 볼 때 이만큼 넘게 오르면 "오르는 중"

	-- 도달 가능성 린트 (GDD 14.3): 퍼펙트 없는 3단 점프 기준에 여유를 둔 값
	LintMaxRise = 100, -- 3단 점프 합계 약 125
	LintPadRise = 200, -- 바운스 패드 약 102 + 공중 점프 2번
	LintPuffRise = 75, -- 퍼플링 반동 약 41 + 공중 점프 1번
	LintMaxGap = 60, -- 발판 가장자리 사이 수평 거리
}

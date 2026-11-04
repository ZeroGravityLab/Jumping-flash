-- 이동 물리 초안 (GDD 5.6). 단위: studs, 초. W1 토이에서 조정한다.
return {
	Gravity = 110,
	WalkSpeed = 20,
	AirSpeed = 28,
	JumpVelocity = { 70, 90, 120 }, -- 1단(지면) · 2단 · 3단
	PerfectMultiplier = 1.15,
	PerfectWindow = 0.10, -- 정점 기준 ±초
	-- 연속 퍼펙트 연출 단계 (GDD 5.2). 연출만 커지고 초속은 그대로다. 문구는 Strings PerfectTier1..
	PerfectStreakTiers = {
		{ from = 1, color = { 255, 205, 60 } },
		{ from = 2, color = { 255, 150, 50 } },
		{ from = 4, color = { 255, 95, 170 } },
		{ from = 6, color = { 175, 110, 255 } },
		{ from = 10, color = { 90, 220, 255 } },
	},
	PerfectStreakGroundGrace = 1.0, -- 땅에 이보다 오래 머물면 연속이 끊긴다
	TerminalFall = 160,
	StompDive = 180,
	StompBounce = 95,
	StompRestoreJumps = 1,
	BuddyBounceMult = 1.4,
	BouncePadVelocity = 150,
	UpdraftVelocity = 60,
	PufflingRespawn = 3,

	-- 관대함 장치 (GDD 5.5)
	CoyoteTime = 0.12,
	JumpBuffer = 0.12,

	-- 입력·판정 내부값
	JumpPressGap = 0.15, -- JumpRequest가 한 번 누를 때 여러 번 오는 것을 한 번으로 묶는 간격
	GroundLockTime = 0.12, -- 발사 직후 지면 판정을 무시하는 시간
	LaunchOvershootTolerance = 1, -- Humanoid가 덧붙인 초속이 이보다 크면 Config 초속으로 되돌린다
	LandingMaxVy = 1, -- 이보다 빠르게 올라가는 중이면 바닥이 감지돼도 착지가 아니다 (구름 통과)
	ProbeRadius = 1.5, -- 밟기 판정 구체 반경
	ProbeLookahead = 1,
	CloudSnap = 0.75, -- 발이 구름 윗면에서 이만큼 아래까지는 착지 허용

	BellRadius = 14,
	BellCooldown = 3,
	AltitudeZeroY = 0, -- 고도 0 m 기준 높이 (광장 윗면)
	FallResetY = -600, -- 구름 바다(World.CloudSeaY) 속. 길게 떨어지는 동안의 아찔함이 연출의 일부다
}

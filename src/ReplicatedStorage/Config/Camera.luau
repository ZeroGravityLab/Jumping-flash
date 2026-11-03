-- 카메라 초안 (GDD 5.4). 각도는 도, 거리는 studs.
return {
	DefaultMode = "Sky", -- "Sky" | "First" (W1 A/B 대상)

	Distance = 16,
	SkyDistanceBonus = 10, -- SkyCamAltitude에 이르면 이만큼 더 뒤로 빠진다
	SkyCamAltitude = 500,
	Fov = 70,
	FovMax = 82,
	FocusHeight = 2,
	FirstPersonHeight = 1.5,

	DefaultPitch = -15,
	PitchMin = -80,
	PitchMax = 60,

	-- 다이브 캠: 하강 중이고 발밑이 DiveMinDrop보다 깊으면 시선을 DiveAngle만큼 내린다
	DiveAngle = 55, -- 35에서는 높이 떨어질 때 바로 아래 착지점이 화면 밖으로 나갔다 (2026-11-03 플레이테스트)
	DiveMinFallSpeed = 8,
	DiveMinDrop = 10,
	DiveInRate = 5,
	DiveOutRate = 7,

	MouseSensitivity = 0.3, -- 도/픽셀
	TouchSensitivity = 0.4,
	GamepadSpeed = 200, -- 도/초
	StickDeadzone = 0.2,
	ZoomMin = 6,
	ZoomMax = 40,
	ZoomStep = 2,

	MarkerEnabled = true,
	MarkerPredictSeconds = 4,
	MarkerStep = 0.05,

	-- 아찔함 (사용자 요청 2026-11-04: 높이 뛰면 고소공포가 느껴질 만큼)
	-- fall은 낙하 속도(종단 속도에서 1), void는 발밑 깊이(VoidDepthFull에서 1)
	FallFovBonus = 16, -- 종단 속도로 떨어질 때 넓어지는 시야(도)
	FallShake = 0.16, -- 최대 화면 흔들림(studs). 설정에서 끌 수 있게 한다
	FallShakeFrom = 0.55, -- fall이 이 값을 넘으면 흔들리기 시작
	VoidDepthFull = 600,
	VoidMinDepth = 40, -- 발밑이 이보다 얕으면 아찔함 연출을 하지 않는다
	EdgeProbeDistance = 6, -- 바라보는 방향으로 이만큼 앞이 허공이면 "가장자리"
	EdgeIntensity = 0.45,
	WindVolumeMin = 0.03,
	WindVolumeMax = 0.9,
	VignetteMax = 0.5,
	SpeedLineRate = 160,
	DropMeterMin = 60, -- 발밑이 이보다 깊을 때만 "아래로 n m"를 보여 준다
}

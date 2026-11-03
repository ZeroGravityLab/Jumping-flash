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
}

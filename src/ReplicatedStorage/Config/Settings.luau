-- 플레이어 설정 (GDD 13장 설정·접근성). 프로필에 저장되어 기기를 바꿔도 따라온다.
-- 볼륨은 0~1을 VolumeStep 단위로, view는 Views 중 하나
return {
	Defaults = {
		music = 1,
		sounds = 1, -- 효과음과 바람·새소리
		shake = true, -- 빠르게 떨어질 때 화면 흔들림
		marker = false, -- 착지 예상 링 (그림자는 늘 보인다)
		view = "Sky",
	},
	Views = { "Sky", "First" },
	VolumeStep = 0.1,
	SaveDelay = 0.6, -- 버튼을 연달아 눌러도 마지막 값만 한 번 보낸다
}

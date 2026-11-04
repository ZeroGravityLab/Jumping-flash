-- 배경음악과 환경음 (GDD 13장). Roblox Creator Store의 공식 라이선스 음원(APM Music, Pro Sound Effects)만 쓴다.
-- id는 음원 에셋 번호, volume은 최대 음량. 섬 음악 키는 Config World의 섬 id와 같다
return {
	Music = {
		Skyhaven = { id = 1842285620, volume = 0.3 }, -- "Pleasure Trip": 가볍고 밝은 곡
		WindmillMeadow = { id = 1839885864, volume = 0.3 }, -- "Silly Things": 익살스러운 민속풍
		Rush = { id = 9043170481, volume = 0.35 }, -- "Dancing for Joy": 경쾌한 관현악 (클라우드 러시)
		Boss = { id = 9043602056, volume = 0.4 }, -- "Ghost Ship": 판타지 모험 관현악 (장 보스)
	},
	Birds = { id = 9116969794, volume = 0.22 }, -- "Morning Birds 5": 섬 위 새소리

	MusicFadeSeconds = 2,
	BirdsFadeHeight = 150, -- 섬 윗면에서 이만큼 오르면 새소리가 사라진다
	BirdsRangeScale = 1.3, -- 섬 반경의 이 배수 안에서만 새소리가 들린다
}

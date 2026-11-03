-- 플레이어에게 보이는 문자열 (기본 영어 + 한국어). 형식 지정자는 string.format 규칙.
local LANGUAGES = {
	en = {
		Perfect = "PERFECT!",
		StompCombo = "STOMP x%d",
		BouncePad = "BOING!",
		Buddy = "BUDDY BOUNCE!",
		Bell = "DING! You rang the bell",
		Altitude = "%d m",
		Best = "BEST %d m",
		ViewSky = "View: Sky cam",
		ViewFirst = "View: First person",
		MarkerOn = "Landing marker: on",
		MarkerOff = "Landing marker: off",
		ControlsKeyboard = "Space x3: triple jump (press at the top for Perfect) · Shift: stomp · Right-drag: look · V: view · M: marker · F2: stats",
		ButtonStomp = "STOMP",
		ButtonView = "VIEW",
		ButtonStats = "STATS",
		StatsTitle = "Toy stats",
		StatsTime = "Play time %s",
		StatsJumps = "Air jumps %d · Perfect %s",
		StatsTrend = "Perfect: first 3 min %s → last 3 min %s",
		StatsStomps = "Stomps %d · Bells %d",
		StatsHighest = "Highest %d m",
		StatsView = "Sky cam %s · First person %s",
		NoData = "–",
	},
	ko = {
		Perfect = "퍼펙트!",
		StompCombo = "밟기 x%d",
		BouncePad = "띠용!",
		Buddy = "친구 점프!",
		Bell = "딩! 종을 울렸어요",
		Altitude = "%d m",
		Best = "최고 %d m",
		ViewSky = "시점: 스카이 캠",
		ViewFirst = "시점: 1인칭",
		MarkerOn = "착지 마커: 켬",
		MarkerOff = "착지 마커: 끔",
		ControlsKeyboard = "Space x3: 3단 점프 (정점에서 누르면 퍼펙트) · Shift: 스톰프 · 우클릭 드래그: 시점 · V: 시점 전환 · M: 마커 · F2: 기록",
		ButtonStomp = "밟기",
		ButtonView = "시점",
		ButtonStats = "기록",
		StatsTitle = "토이 기록",
		StatsTime = "플레이 시간 %s",
		StatsJumps = "공중 점프 %d · 퍼펙트 %s",
		StatsTrend = "퍼펙트율: 처음 3분 %s → 최근 3분 %s",
		StatsStomps = "밟기 %d · 종 %d",
		StatsHighest = "최고 고도 %d m",
		StatsView = "스카이 캠 %s · 1인칭 %s",
		NoData = "–",
	},
}

local Strings = { languages = LANGUAGES }

function Strings.language(locale: string?): string
	local code = string.lower(string.sub(locale or "", 1, 2))
	return if LANGUAGES[code] then code else "en"
end

function Strings.get(locale: string?, key: string, ...: any): string
	local text = LANGUAGES[Strings.language(locale)][key] or LANGUAGES.en[key] or key
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end

return Strings

-- 코인 상점 (GDD 9.4~9.5, 12장): 다른 플레이어에게도 보이는 외형만 판다. 실력에 영향을 주는 것은 없다.
-- 코인으로만 산다 (Robux 상품·확률형 없음). 이름은 Strings의 Item_<id>
-- 색은 {r, g, b}. 궤적 colors는 꼬리 앞에서 뒤로 이어지는 색들이다
-- 부츠: body 몸통, sole 밑창, accent 발목 띠. glow면 띠가 빛나고, metal이면 몸통이 금속 재질이다
return {
	Categories = { "Trail", "Boots" },

	Items = {
		{ id = "trail_cloud", category = "Trail", price = 150, colors = { { 255, 255, 255 }, { 190, 225, 255 } } },
		{ id = "trail_mint", category = "Trail", price = 250, colors = { { 170, 255, 210 }, { 60, 200, 190 } } },
		{ id = "trail_sunset", category = "Trail", price = 350, colors = { { 255, 200, 90 }, { 255, 110, 140 } } },
		{ id = "trail_berry", category = "Trail", price = 350, colors = { { 255, 140, 200 }, { 160, 100, 240 } } },
		{
			id = "trail_aurora",
			category = "Trail",
			price = 700,
			colors = { { 120, 255, 170 }, { 90, 220, 255 }, { 190, 120, 255 } },
		},
		{
			id = "trail_rainbow",
			category = "Trail",
			price = 1200,
			colors = {
				{ 255, 96, 96 },
				{ 255, 180, 70 },
				{ 255, 235, 90 },
				{ 110, 225, 110 },
				{ 90, 170, 255 },
				{ 180, 110, 240 },
			},
		},

		{
			id = "boots_sky",
			category = "Boots",
			price = 200,
			body = { 110, 175, 245 },
			sole = { 250, 250, 250 },
			accent = { 255, 210, 80 },
		},
		{
			id = "boots_cherry",
			category = "Boots",
			price = 300,
			body = { 230, 70, 80 },
			sole = { 250, 245, 240 },
			accent = { 255, 255, 255 },
		},
		{
			id = "boots_lemon",
			category = "Boots",
			price = 300,
			body = { 255, 215, 70 },
			sole = { 120, 90, 60 },
			accent = { 255, 255, 255 },
		},
		{
			id = "boots_mint",
			category = "Boots",
			price = 300,
			body = { 120, 225, 180 },
			sole = { 255, 255, 255 },
			accent = { 255, 150, 190 },
		},
		{
			id = "boots_night",
			category = "Boots",
			price = 800,
			body = { 40, 46, 80 },
			sole = { 20, 22, 36 },
			accent = { 90, 230, 255 },
			glow = true,
		},
		{
			id = "boots_gold",
			category = "Boots",
			price = 1500,
			body = { 232, 168, 40 }, -- 더 옅으면 반사광에 크림색처럼 보였다
			sole = { 120, 80, 40 },
			accent = { 255, 226, 130 },
			glow = true,
			metal = true,
		},
	},
}

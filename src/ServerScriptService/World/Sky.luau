-- 하늘과 빛. 늦은 오후의 부드러운 햇살, 먼 섬이 푸르게 바래는 대기, 따뜻한 색감
local Lighting = game:GetService("Lighting")

local Sky = {}

local function ensure(className: string, parent: Instance): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Parent = parent
	return inst
end

function Sky.apply()
	Lighting.ClockTime = 15.4
	Lighting.GeographicLatitude = 32
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(118, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 186)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.ColorShift_Top = Color3.fromRGB(255, 238, 216)
	-- LightingStyle(Realistic)은 스크립트로 못 바꿔 default.project.json과 place에 둔다 (ASSETS.md)

	-- 먼 곳이 푸르게 바래야 높이와 거리가 느껴진다
	local atmosphere = ensure("Atmosphere", Lighting)
	-- 너무 짙으면 발밑 구름 바다가 묻혀 높이 감이 사라진다 (2026-11-04 플레이테스트)
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.04
	atmosphere.Color = Color3.fromRGB(202, 218, 240)
	atmosphere.Decay = Color3.fromRGB(150, 164, 196)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.0

	local bloom = ensure("BloomEffect", Lighting)
	-- 흰 구름이 번쩍이지 않게 문턱을 높게 둔다
	bloom.Intensity = 0.22
	bloom.Size = 24
	bloom.Threshold = 1.9

	local rays = ensure("SunRaysEffect", Lighting)
	rays.Intensity = 0.06
	rays.Spread = 0.55

	local color = ensure("ColorCorrectionEffect", Lighting)
	color.Brightness = 0.03
	color.Contrast = 0.08
	color.Saturation = 0.15
	color.TintColor = Color3.fromRGB(255, 249, 240)

	local depth = ensure("DepthOfFieldEffect", Lighting)
	depth.FarIntensity = 0.06
	depth.FocusDistance = 80
	depth.InFocusRadius = 300
	depth.NearIntensity = 0

	-- 머리 위 흘러가는 입체 구름
	local clouds = ensure("Clouds", workspace.Terrain)
	clouds.Cover = 0.55
	clouds.Density = 0.5
	clouds.Color = Color3.fromRGB(255, 255, 255)

	-- 움직이는 잔디(Terrain.Decoration)는 스크립트에서 바꿀 수 없어 place에 켜 둔다 (ASSETS.md)
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(118, 186, 88))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 118, 88))
	terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(224, 188, 142))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 140, 136))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(206, 196, 182))
end

return Sky

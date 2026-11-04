-- 장 보스 (GDD 6.3): 섬을 되살리기 전까지 정상 위에 먹구름(썬더헤드)이 떠 있고, 정상의 폭풍 받침대에서 도전한다.
-- 종 게이지가 덜 찼으면 받침대가 남은 칸을 알려 준다. 이기면 그 플레이어에게서 먹구름이 걷힌다(이 클라이언트에만).
-- 싸움 자체는 Objectives의 Boss 유형이고, 이긴 뒤의 섬 복구 연출은 Stories(Chapter1)가 맡는다
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Requests = require(ReplicatedStorage.Config.Requests)
local RequestLogic = require(ReplicatedStorage.Shared.RequestLogic)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Objectives = require(script.Parent.Objectives)

local player = Players.LocalPlayer

local COLOR = {
	Stone = Color3.fromRGB(70, 72, 92),
	Glow = Color3.fromRGB(255, 220, 90),
}

local Boss = {}

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function progress(): RequestLogic.Progress
	local raw = player:GetAttribute("RequestProgress")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then decoded else {}
end

-- 정상의 폭풍 받침대: 어두운 돌기둥 위 번쩍이는 구슬, 도전 프롬프트
local function gate(position: Vector3, request, parent: Instance)
	local base = Instance.new("Part")
	base.Name = "StormGate"
	base.Shape = Enum.PartType.Cylinder
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.Material = Enum.Material.Slate
	base.Color = COLOR.Stone
	base.Size = Vector3.new(4, 5, 5)
	base.CFrame = CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Parent = parent
	local orb = Instance.new("Part")
	orb.Name = "StormOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.Material = Enum.Material.Neon
	orb.Color = COLOR.Glow
	orb.Size = Vector3.new(2.6, 2.6, 2.6)
	orb.CFrame = CFrame.new(position + Vector3.new(0, 5.4, 0))
	orb.Parent = parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = t("BossChallenge")
	prompt.ObjectText = t(request.name)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Boss", request.id)
	prompt.Parent = base
end

function Boss.start(_hop, ui, requestController)
	local folder = Instance.new("Folder")
	folder.Name = "BossLocal"
	folder.Parent = workspace
	local worldFolder = workspace:WaitForChild("World")

	local bosses = {}
	for _, spec in Requests.Chapters do
		local request = RequestLogic.find(Requests, spec.boss)
		if request then
			worldFolder:WaitForChild(request.island)
			local gatePosition = Objectives.resolve(request.gate, request.island, {})
			if gatePosition then
				gate(gatePosition, request, folder)
			end
			table.insert(bosses, { request = request, chapter = request.chapter })
		end
	end

	-- 평소 먹구름: 아직 섬을 되살리지 않았고 그 보스와 싸우는 중이 아닐 때만
	local function refresh(firstTime: boolean)
		if type(player:GetAttribute("RequestProgress")) ~= "string" and not firstTime then
			return
		end
		local current = progress()
		for _, boss in bosses do
			local restored = RequestLogic.isRestored(Requests, boss.chapter, current)
			if restored and boss.idle then
				Objectives.dispelStorm(boss.idle)
				boss.idle = nil
			elseif not restored and not boss.idle then
				local center = Objectives.resolve(boss.request.center, boss.request.island, {})
				if center then
					boss.idle = Objectives.stormBody(center, folder)
				end
			end
		end
	end
	refresh(true)
	player:GetAttributeChangedSignal("RequestProgress"):Connect(function()
		refresh(false)
	end)
	RunService.Heartbeat:Connect(function()
		local activeId = requestController.activeId()
		for _, boss in bosses do
			if boss.idle then
				boss.idle.Parent = if activeId == boss.request.id then nil else folder
			end
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("Boss")
		if type(id) ~= "string" or requestController.isActive() then
			return
		end
		local request = RequestLogic.find(Requests, id)
		if not request then
			return
		end
		local current = progress()
		if not RequestLogic.isAvailable(request, current, Requests) then
			local done, needed = RequestLogic.bellGauge(Requests, request.chapter, current)
			ui.toast(t("BossLocked", done, needed))
			return
		end
		ui.showDialog(t(request.name), request, current[request.id], function()
			requestController.begin(request, request.island)
		end)
	end)
end

return Boss

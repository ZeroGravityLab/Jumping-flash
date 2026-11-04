-- 클라우드 러시 라운드 (GDD 7.2): 허브 대기 → 탑으로 이동 → 카운트다운 → 해일 → 종·탈락 → 결과·보상.
-- 탈락·종·최고 높이·순위는 모두 서버가 위치를 보고 정한다. 진행 상태는 ReplicatedStorage.RushState 속성으로 알린다
--   Phase: "Lobby" | "Countdown" | "Running" | "Results", PhaseEndsAt·StartedAt: 서버 시간(GetServerTimeNow)
--   TowerBaseY·TowerTopY, Alive(남은 사람 수), Total(참가자 수), Rang(종을 울린 사람 수)
-- 플레이어 속성: RushJoined(다음 판 참가 신청), RushRunning(지금 탑 위에 있음)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chunks = require(ReplicatedStorage.Config.Chunks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rush = require(ReplicatedStorage.Config.Rush)
local RushLogic = require(ReplicatedStorage.Shared.RushLogic)
local TowerGen = require(ReplicatedStorage.Shared.TowerGen)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Net)
local TowerBuilder = require(script.Parent.Parent.World.TowerBuilder)

local RoundService = {}

local JOIN_INTERVAL = 0.3
local FEET_OFFSET = 3 -- 루트 파트 중심에서 발까지 (R15 기본 체형 기준 근삿값)

type Runner = { maxHeight: number, rangAt: number?, out: boolean }

local state: Folder
local resultRemote: RemoteEvent
local joined: { [Player]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setPhase(phase: string, seconds: number)
	state:SetAttribute("Phase", phase)
	state:SetAttribute("PhaseEndsAt", now() + seconds)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function sendHome(player: Player)
	local character = player.Character
	local spawn = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Spawn")
	if character and spawn then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
	end
end

local function runRound(entrants: { Player })
	local seed = Random.new():NextInteger(1, 2147483646)
	local layout = TowerGen.generate(seed, Chunks, Rush)
	local tower, info = TowerBuilder.build(layout, Rush)
	state:SetAttribute("TowerBaseY", info.origin.Y)
	state:SetAttribute("TowerTopY", info.top.Y)
	state:SetAttribute("Total", #entrants)
	state:SetAttribute("Rang", 0)

	local runners: { [Player]: Runner } = {}
	for i, player in entrants do
		-- 출발 발판 위에 둥글게 세우고 탑 가운데를 보게 한다
		local angle = i / #entrants * math.pi * 2
		local spot = info.origin + Vector3.new(math.cos(angle) * 14, 5, math.sin(angle) * 14)
		local character = player.Character
		if character then
			character:PivotTo(CFrame.lookAt(spot, Vector3.new(info.origin.X, spot.Y, info.origin.Z)))
		end
		runners[player] = { maxHeight = 0, out = false }
		player:SetAttribute("RushRunning", true)
	end
	state:SetAttribute("Alive", #entrants)

	setPhase("Countdown", Rush.CountdownSeconds)
	task.wait(Rush.CountdownSeconds)
	local startedAt = now()
	state:SetAttribute("StartedAt", startedAt)
	setPhase("Running", Rush.MaxRoundSeconds)

	local firstRingAt: number? = nil
	local rang = 0
	while true do
		task.wait(Rush.ServerTick)
		local elapsed = now() - startedAt
		local tideY = info.origin.Y + RushLogic.tideHeight(Rush, elapsed)
		local alive = 0
		for player, run in runners do
			if run.out then
				continue
			end
			local root = player.Parent == Players and rootOf(player)
			if not root then
				run.out = true
				player:SetAttribute("RushRunning", false)
				continue
			end
			local feetY = root.Position.Y - FEET_OFFSET
			run.maxHeight = math.max(run.maxHeight, feetY - info.origin.Y)
			if not run.rangAt and (root.Position - info.bell).Magnitude <= Rush.BellRadius then
				run.rangAt = elapsed
				firstRingAt = firstRingAt or elapsed
				rang += 1
				state:SetAttribute("Rang", rang)
			end
			if feetY < tideY - Rush.TideGrace then
				-- 해일에 잠겼다: 탈락하고 허브로 (GDD의 돌풍 관전은 v1.0)
				run.out = true
				player:SetAttribute("RushRunning", false)
				sendHome(player)
			else
				alive += 1
			end
		end
		state:SetAttribute("Alive", alive)
		if alive == 0 then
			break
		elseif firstRingAt and elapsed - firstRingAt >= Rush.EndGraceSeconds then
			break
		elseif elapsed >= Rush.MaxRoundSeconds or tideY >= info.top.Y then
			break
		end
	end

	local entries = {}
	for player, run in runners do
		table.insert(entries, { id = player, maxHeight = run.maxHeight, rangAt = run.rangAt })
	end
	local ranked = RushLogic.rank(entries)
	for rank, entry in ranked do
		local player = entry.id :: Player
		if player.Parent == Players then
			local meters = math.max(0, math.floor(entry.maxHeight))
			local rangBell = entry.rangAt ~= nil
			local coins = RushLogic.coins(Rush, meters, rank, #ranked, rangBell)
			EconomyService.addCoins(player, coins)
			resultRemote:FireClient(player, {
				rank = rank,
				total = #ranked,
				height = meters,
				coins = coins,
				rang = rangBell,
			})
		end
	end

	setPhase("Results", Rush.ResultsSeconds)
	task.wait(Rush.ResultsSeconds)
	for player, run in runners do
		if player.Parent == Players then
			player:SetAttribute("RushRunning", false)
			if not run.out then
				sendHome(player)
			end
		end
	end
	tower:Destroy()
end

local function loop()
	while true do
		setPhase("Lobby", Rush.LobbySeconds)
		task.wait(Rush.LobbySeconds)
		local entrants = {}
		for player in joined do
			if player.Parent == Players and rootOf(player) then
				table.insert(entrants, player)
			end
			player:SetAttribute("RushJoined", false)
		end
		-- 참가는 한 판씩 받는다 (의뢰 중에 다음 판으로 끌려가지 않게)
		table.clear(joined)
		if #entrants > 0 then
			local ok, err = pcall(runRound, entrants)
			if not ok then
				warn("[RoundService] round failed:", err)
				local leftover = workspace:FindFirstChild("RushTower")
				if leftover then
					leftover:Destroy()
				end
				for _, player in entrants do
					if player.Parent == Players then
						player:SetAttribute("RushRunning", false)
					end
				end
			end
		end
	end
end

function RoundService.start()
	state = Instance.new("Folder")
	state.Name = "RushState"
	state.Parent = ReplicatedStorage
	resultRemote = Net.event(Remotes.RushResult)
	Net.handleEvent(Remotes.RushJoin, JOIN_INTERVAL, function(player, wants)
		if type(wants) ~= "boolean" then
			return
		end
		joined[player] = if wants then true else nil
		player:SetAttribute("RushJoined", wants)
	end)
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
	end)
	task.spawn(loop)
end

return RoundService

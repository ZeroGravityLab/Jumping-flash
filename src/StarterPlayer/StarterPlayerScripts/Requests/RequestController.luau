-- 의뢰 흐름 (GDD 6.4): 주민에게 말 걸기 → 대화 → 시작(서버 확인) → 목표 수행 → 완료 보고(서버가 시간·메달·보상 판정)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Requests = require(ReplicatedStorage.Config.Requests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RequestLogic = require(ReplicatedStorage.Shared.RequestLogic)
local Objectives = require(script.Parent.Objectives)

local player = Players.LocalPlayer

local RequestController = {}

local active: { request: any, startedAt: number, cleanup: () -> () }? = nil

local function progress(): RequestLogic.Progress
	local raw = player:GetAttribute("RequestProgress")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then decoded else {}
end

local function islandOf(residentId: string): string?
	for _, resident in Requests.Residents do
		if resident.id == residentId then
			return resident.island
		end
	end
	return nil
end

-- 새 의뢰가 있는 주민 머리 위에 "!"
local function updateMarkers(markers: { [string]: BillboardGui })
	local current = progress()
	for residentId, marker in markers do
		local request = RequestLogic.nextFor(Requests, residentId, current)
		marker.Enabled = request ~= nil and current[request.id] == nil and active == nil
	end
end

function RequestController.start(hop, ui)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local startRemote = remotes:WaitForChild(Remotes.RequestStart) :: RemoteFunction
	local completeRemote = remotes:WaitForChild(Remotes.RequestComplete) :: RemoteFunction
	local cancelRemote = remotes:WaitForChild(Remotes.RequestCancel) :: RemoteEvent

	local markers: { [string]: BillboardGui } = {}

	local function stopActive()
		if active then
			active.cleanup()
			active = nil
		end
		ui.hideTracker()
		updateMarkers(markers)
	end

	local function begin(request, islandId: string)
		local ok = startRemote:InvokeServer(request.id)
		if not ok then
			ui.toast(ui.text("FailServer"))
			return
		end
		ui.showTracker(request)
		local cleanup = Objectives.run(request, islandId, hop, {
			progress = ui.setProgress,
			countdown = ui.setCountdown,
			success = function()
				stopActive()
				local result = completeRemote:InvokeServer(request.id)
				if result then
					ui.showResult(result)
				else
					ui.toast(ui.text("FailServer"))
				end
				updateMarkers(markers)
			end,
			fail = function(reasonKey)
				stopActive()
				cancelRemote:FireServer(request.id)
				ui.toast(ui.text(reasonKey))
			end,
			notice = function(key)
				ui.toast(ui.text(key))
			end,
		})
		active = { request = request, startedAt = os.clock(), cleanup = cleanup }
		updateMarkers(markers)
	end

	local function attachPrompt(prompt: ProximityPrompt)
		local residentId = prompt:GetAttribute("Resident")
		if type(residentId) ~= "string" then
			return
		end
		prompt.ActionText = ui.text("Talk")
		local root = prompt.Parent
		if root and root:IsA("BasePart") and not markers[residentId] then
			local marker = Instance.new("BillboardGui")
			marker.Size = UDim2.fromOffset(40, 50)
			marker.StudsOffset = Vector3.new(0, 5.5, 0)
			marker.AlwaysOnTop = true
			marker.MaxDistance = 250
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.Text = "!"
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 210, 70)
			label.TextStrokeTransparency = 0.2
			label.Parent = marker
			marker.Adornee = root
			marker.Parent = hop.localFolder
			markers[residentId] = marker
			updateMarkers(markers)
		end
	end

	for _, prompt in workspace:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			attachPrompt(prompt)
		end
	end
	workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("ProximityPrompt") then
			attachPrompt(inst)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local residentId = prompt:GetAttribute("Resident")
		if type(residentId) ~= "string" or active then
			return
		end
		local current = progress()
		local request = RequestLogic.nextFor(Requests, residentId, current)
		local islandId = islandOf(residentId)
		ui.showDialog(residentId, request, request and current[request.id], function()
			if request and islandId then
				begin(request, islandId)
			end
		end)
	end)

	player:GetAttributeChangedSignal("RequestProgress"):Connect(function()
		updateMarkers(markers)
	end)

	RunService.Heartbeat:Connect(function()
		if active then
			ui.setTime(os.clock() - active.startedAt)
		end
	end)
end

return RequestController

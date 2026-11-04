-- 주민에게 다가가 대화 프롬프트가 뜨면 주민이 손을 흔든다. 이 클라이언트에서만 튼다 (복제하지 않는다)
local ProximityPromptService = game:GetService("ProximityPromptService")

local WAVE_ANIMATION = "rbxassetid://507770239" -- Roblox 기본 R15 손 흔들기
local COOLDOWN = 8

local Greeting = {}

function Greeting.start()
	local tracks: { [Model]: AnimationTrack } = {}
	local lastWave: { [Model]: number } = {}
	local animation = Instance.new("Animation")
	animation.AnimationId = WAVE_ANIMATION

	ProximityPromptService.PromptShown:Connect(function(prompt)
		if not prompt:GetAttribute("Resident") then
			return
		end
		local model = prompt:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not (model and animator) then
			return
		end
		local now = os.clock()
		if now - (lastWave[model] or -math.huge) < COOLDOWN then
			return
		end
		lastWave[model] = now
		local track = tracks[model]
		if not track then
			local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
			if not ok then
				return
			end
			track = loaded
			track.Priority = Enum.AnimationPriority.Action
			tracks[model] = track
		end
		track:Play(0.2)
	end)
end

return Greeting

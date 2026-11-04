-- Remote 인스턴스 생성과 요청 빈도 제한. 클라이언트가 보내는 것은 "의도"뿐이고 판단은 서비스가 한다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"
folder.Parent = ReplicatedStorage

local lastCall: { [Player]: { [string]: number } } = {}

local function allowed(player: Player, name: string, minInterval: number): boolean
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local now = os.clock()
	if now - (calls[name] or -math.huge) < minInterval then
		return false
	end
	calls[name] = now
	return true
end

function Net.handleFunction(name: string, minInterval: number, handler: (Player, ...any) -> ...any)
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	remote.OnServerInvoke = function(player, ...)
		if not allowed(player, name, minInterval) then
			return nil
		end
		return handler(player, ...)
	end
end

function Net.handleEvent(name: string, minInterval: number, handler: (Player, ...any) -> ())
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	remote.OnServerEvent:Connect(function(player, ...)
		if allowed(player, name, minInterval) then
			handler(player, ...)
		end
	end)
end

-- 서버가 보내기만 하는 이벤트 (클라이언트가 보내는 것은 받지 않는다)
function Net.event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

function Net.forget(player: Player)
	lastCall[player] = nil
end

return Net

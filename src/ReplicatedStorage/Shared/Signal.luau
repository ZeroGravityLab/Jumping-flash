-- 최소 시그널. 연결 해제는 토이 단계에서 필요 없어 두지 않았다.
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	table.insert(self.handlers, handler)
end

function Signal:Fire(...: any)
	for _, handler in self.handlers do
		handler(...)
	end
end

return Signal

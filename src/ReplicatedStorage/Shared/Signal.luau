-- 최소 시그널. Connect는 Disconnect를 가진 연결을 돌려준다
local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: () -> () }

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local handlers = self.handlers
	table.insert(handlers, handler)
	return {
		Disconnect = function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...: any)
	-- 핸들러 안에서 연결을 끊어도 순회가 꼬이지 않게 복사본을 돈다
	for _, handler in table.clone(self.handlers) do
		handler(...)
	end
end

return Signal

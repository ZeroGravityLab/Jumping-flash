-- 단언 헬퍼
local check = {}

function check.near(actual: number, expected: number, tolerance: number)
	if math.abs(actual - expected) > tolerance then
		error(string.format("expected %s ± %s, got %s", tostring(expected), tostring(tolerance), tostring(actual)), 2)
	end
end

function check.equal(actual: any, expected: any)
	if actual ~= expected then
		error(string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
	end
end

function check.truthy(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

return check

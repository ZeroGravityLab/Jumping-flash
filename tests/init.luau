-- lune run tests: 모든 spec을 실행하고 실패가 있으면 종료 코드 1
local process = require("@lune/process")

local specs = {
	MovementLogic = require("@self/MovementLogic.spec"),
	RequestLogic = require("@self/RequestLogic.spec"),
	Strings = require("@self/Strings.spec"),
	ToyStats = require("@self/ToyStats.spec"),
	WorldGen = require("@self/WorldGen.spec"),
}

local passed, failed = 0, 0
for specName, cases in specs do
	for caseName, run in cases do
		local ok, err = pcall(run)
		if ok then
			passed += 1
		else
			failed += 1
			print(string.format("FAIL %s / %s: %s", specName, caseName, tostring(err)))
		end
	end
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end

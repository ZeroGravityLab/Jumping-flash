local Strings = require("../src/ReplicatedStorage/Shared/Strings")
local check = require("./check")

local function formatCount(text: string): number
	local _, count = string.gsub(text, "%%[ds]", "")
	return count
end

return {
	["모든 언어가 같은 키를 갖는다"] = function()
		for code, table_ in Strings.languages do
			for otherCode, other in Strings.languages do
				for key in table_ do
					check.truthy(other[key] ~= nil, string.format("%s has %s but %s does not", code, key, otherCode))
				end
			end
		end
	end,

	["형식 지정자 수가 언어마다 같다"] = function()
		for key, text in Strings.languages.en do
			for code, table_ in Strings.languages do
				check.truthy(
					formatCount(table_[key]) == formatCount(text),
					string.format("%s.%s has a different number of format specifiers", code, key)
				)
			end
		end
	end,

	["로캘에 맞는 언어를 고르고, 모르면 영어"] = function()
		check.equal(Strings.get("ko-kr", "Perfect"), "퍼펙트!")
		check.equal(Strings.get("en-us", "Perfect"), "PERFECT!")
		check.equal(Strings.get("fr-fr", "Perfect"), "PERFECT!")
		check.equal(Strings.get(nil, "Perfect"), "PERFECT!")
	end,

	["형식 인자를 채운다"] = function()
		check.equal(Strings.get("en-us", "StompCombo", 3), "STOMP x3")
	end,
}

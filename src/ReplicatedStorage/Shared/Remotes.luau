-- Remote 이름 목록 (CLAUDE.md: Remote는 이 파일 한 곳에 정의).
-- 인스턴스는 서버 Services/Net이 ReplicatedStorage.Remotes 아래에 만들고, 모두 요청 빈도를 제한한다
return table.freeze({
	RequestStart = "RequestStart", -- RemoteFunction(requestId) -> ok
	RequestComplete = "RequestComplete", -- RemoteFunction(requestId) -> 결과 표 또는 nil
	RequestCancel = "RequestCancel", -- RemoteEvent(requestId)
	RushJoin = "RushJoin", -- RemoteEvent(wantsToJoin: boolean). 다음 클라우드 러시 참가·취소
	RushResult = "RushResult", -- 서버 → 클라이언트 RemoteEvent({ rank, total, height, coins, rang })
	RushStomp = "RushStomp", -- RemoteEvent(victim: Player). 러시 중 다른 참가자의 머리를 밟았다는 보고
	RushStomped = "RushStomped", -- 서버 → 밟힌 클라이언트 RemoteEvent(wobbleSeconds, jumpsLost)
	ShopBuy = "ShopBuy", -- RemoteFunction(itemId) -> ok, reasonKey?. 사면 바로 장착한다
	ShopEquip = "ShopEquip", -- RemoteFunction(category, itemId?) -> ok. itemId가 nil이면 그 칸을 비운다
	ShardCollect = "ShardCollect", -- RemoteEvent(shardId). 숨은 별조각에 닿았다는 보고. 결과는 Shards 속성으로 알린다
	SettingsSave = "SettingsSave", -- RemoteEvent(settings 표). 서버가 SettingsLogic으로 걸러 저장한다
})

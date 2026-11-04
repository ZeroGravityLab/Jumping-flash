-- Remote 이름 목록 (CLAUDE.md: Remote는 이 파일 한 곳에 정의).
-- 인스턴스는 서버 Services/Net이 ReplicatedStorage.Remotes 아래에 만들고, 모두 요청 빈도를 제한한다
return table.freeze({
	RequestStart = "RequestStart", -- RemoteFunction(requestId) -> ok
	RequestComplete = "RequestComplete", -- RemoteFunction(requestId) -> 결과 표 또는 nil
	RequestCancel = "RequestCancel", -- RemoteEvent(requestId)
	RushJoin = "RushJoin", -- RemoteEvent(wantsToJoin: boolean). 다음 클라우드 러시 참가·취소
	RushResult = "RushResult", -- 서버 → 클라이언트 RemoteEvent({ rank, total, height, coins, rang })
})

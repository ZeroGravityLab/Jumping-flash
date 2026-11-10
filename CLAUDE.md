# SKYHOP — Claude 작업 규칙

Roblox 수직 하이점프 3D 플랫포머 (글로벌 출시, 기본 영어). 1인 개발 + Claude Code + Roblox Studio MCP.
기획 전체는 [GDD.md](GDD.md) (v0.2). 설계 의도가 궁금하면 GDD의 해당 장을 먼저 읽는다.

## 현재 단계

- **W3 진행 중** (2026-11-04, 사용자 요청 "계속 개발 진행해줘"). W2(떠 있는 섬 월드, 아찔함 연출, 의뢰 시스템, 모바일 UI 배치, ProfileStore 저장, 연속 퍼펙트 연출)는 끝났다. W3 순서: ① 1장 의뢰 10개·유형 6종 (완료: 주민 렌 + 경주 유형) → ② 하늘 지도 (완료: UI/SkyMap, 허브 지도 탁자, 길 안내 빛기둥) → ③ 주민 이야기 끝 연출 (완료: 브람 → 허브 빵집, Requests/Stories, Config Requests.Stories) → ④ 클라우드 러시(해일·종·라이벌 밟기·청크 15개). ④는 1·2단계 완료(탑·해일·종·결과, 라이벌 밟기, MovementGuard — GDD 7.2·14.2). W3 코드 항목은 모두 끝났다. 남은 것: 2인 이상 러시 실제 테스트(밟기 장면 미확인), W3 완료 기준인 지인 3~5명 테스트. 아이콘은 아트 작업이라 코드 범위 밖.
- **완성도 작업 중** (2026-11-04, 사용자 요청 "테스트는 미루고 컨텐츠·볼륨·재미·모델링 등 완성도를 높여줘"). 순서: ① 1장 보스 썬더헤드 + 섬 복구 (완료·Studio 확인: Requests/Boss, Objectives Boss 유형, Stories Chapter1 무지개, 하늘 지도 보스 핀·복구 표시 — GDD 6.3) → ② 주민 외형 모델링 + 레아·렌 이야기 끝 (완료·Studio 확인: World/ResidentLooks, Requests/Greeting, Stories Lighthouse·Kites — GDD 6.6. 연 계단·큰 연 바운스·전망대는 수치로, 외형·손 흔들기·카드·길 안내는 화면으로 확인) → ③ 코인 상점(코스메틱, 코인만. 완료·Studio 확인: 구매/장착/벗기/코인 부족/재생성, 상점 화면·부츠·궤적 모습. Config Shop, ShopService, CosmeticService, UI/ShopUi — GDD 9.4. 휴대폰 화면은 미확인) → ④ 숨은 수집품·러시 청크 추가 (완료·Studio 확인: 별조각 12개(허브 5, 초원 7), 섬마다 다 모으면 상점 전용 외형, 하늘 지도 ★ 개수, 러시 청크 21종 — GDD 9.6·8.1. 별조각 자리까지 실제로 뛰어서 가는 손맛 확인은 미실행) → ⑤ 배경음악·환경음 (완료·Studio 확인: Config Audio, Movement/Soundscape. 음원 5개 로드·섬 전환·러시 전환·높이별 새소리를 수치로 확인. 실제로 들어 본 곡 느낌은 미확인 — GDD 13장, ASSETS.md). 부츠·데일리 어센트·2장은 여전히 요청 전에 만들지 않는다.
- **완성도 2차** (2026-11-10, 사용자 요청 "개발 진행해줘"): ① 설정 화면(볼륨·흔들림·착지 링·시점, 프로필 저장 — GDD 13장. 완료·Studio 확인: 버튼·O 키·V/L 키 저장, 1인칭에서 창 열면 마우스 풀림, 폰 가로·세로 배치. 세로 시뮬레이터에서 실제 탭은 입력이 안 들어가 미확인). 창(설정·상점·지도·대화)을 새로 만들면 닫기 버튼에 `Modal = true`를 켠다 — SkyCamera가 보고 1인칭 마우스 고정을 푼다.
- 보스 테스트: 서버가 종 게이지(1장 의뢰 6개)를 확인하므로 의뢰 6개를 실제로 끝내야 도전할 수 있다. 빠른 순서: 레아 배달 → 브람 빨래(4초 간격, minTime 25) → 브람 머크 → 렌 리본(4초 간격) → 렌 연 경주(5초 뒤 결승점으로) → 렌 연줄 머크. 피뢰침은 발판 위 공중으로 옮긴 뒤 LeftShift(스톰프). Studio 창이 최소화되거나 다른 창(Studio 시작 화면 포함)에 가려지면 화면이 하얗게 나오고 프롬프트가 뜨지 않는다. 플레이 중 원하는 각도로 찍으려면 SkyCamera가 카메라를 덮어쓰므로 Client에서 `BindToRenderStep`(우선순위 Last+10)으로 카메라를 고정한 뒤 `screen_capture`한다.
- 러시 테스트: 대기 20초 동안 왼쪽 위 작은 버튼(`SkyhopRush.RushPill`)을 누른다(MCP 실행 스레드는 Remote를 못 쏜다). 이 버튼은 튜토리얼을 끝낸 뒤에만 보이므로, 새 플레이 세션에서는 먼저 Client에서 `RequestProgress`에 튜토리얼 의뢰 3개를 써 둔다. 클라이언트에서 루트를 Anchored로 고정하면 서버가 떨어진 것으로 보고 탈락시키므로, 실제 발판 위에 세워서 본다. 러시 중 300보다 높이 순간이동하면 MovementGuard가 되돌린다(출력 창 `[MovementGuard]`) — 테스트에서 높은 곳을 볼 때는 낮은 발판부터 차례로 옮기거나 경고를 감안한다.
- place가 게시 전이라 Studio에서는 ProfileStore가 메모리 저장소로 돈다(실제 저장 확인은 게시하고 API 접근을 켠 뒤). 플레이를 다시 시작하면 의뢰 진행이 비므로, 선행 의뢰가 있는 의뢰는 앞 의뢰부터 다시 끝내고 확인한다. UI만 볼 때는 Client `execute_luau`로 `RequestProgress` 속성을 이 클라이언트에서만 바꿔 써도 된다(서버 데이터는 그대로). 이야기 끝 연출도 이렇게 띄운다(예: `c1_dive`를 넣으면 등대, `c1_summit_race`면 연 축제). 상점 테스트 코인은 Server `execute_luau`로 플레이어에 `StudioGrantCoins` 속성(숫자)을 쓰면 EconomyService가 준다(Studio에서만 연결된다).
- 모바일 점검은 Studio Test → Device Simulator로 한다. 플레이를 다시 시작하면 가로로 돌아가고, 프롬프트는 카메라 화면 안에 있어야 뜬다.
- 개발자 본인 손맛 테스트는 2026-11-04 통과("손맛 좋다"). 테스터 5명 기준 토이 게이트(GDD 15장)는 아직 남아 있다. W4 이후 기능(데일리 어센트, 리그, 부츠 등)은 요청 전에 만들지 않는다. 단계가 바뀌면 이 섹션을 갱신한다.
- 외부 에셋은 [ASSETS.md](ASSETS.md)의 규칙(정화·배율·place 저장)을 따른다.

## 오리지널리티

- 참고 장르의 특정 원작 이름·캐릭터·아이템·음악·스테이지를 쓰지 않는다. 게임 안 문자열과 스토어 문구에도 원작 이름을 쓰지 않는다 (GDD 2장).

## 진실의 원천

1. **`src/ReplicatedStorage/Config/*.luau`** — 모든 물리·밸런스 값 (점프 초속, 중력, 판정창, 카메라 각도).
2. **GDD.md** — 설계 의도와 규칙.
3. 둘이 다르면 **Config가 우선**. 다른 걸 발견하면 조용히 넘기지 말고 사용자에게 알린다.

수치 변경 요청(예: "3단 점프 120→130")의 처리 순서:
1. Config만 수정한다. 다른 코드에 숫자를 쓰지 않는다.
2. `lune run tests`를 돌린다.
3. GDD의 해당 표(5.6 등)를 같이 고친다.

## 언어

- 사용자와의 대화는 한국어.
- 식별자·파일명·Config 키는 영어.
- 주석은 한국어로 짧게. 코드가 말해 주는 내용은 주석으로 반복하지 않는다.
- 플레이어에게 보이는 문자열은 `Shared/Strings.luau`의 키로 관리한다 (기본 영어 + 한국어). 숫자·단위(`150 m`)만 예외.

## 폴더 구조 (Rojo)

```
default.project.json          Rojo 매핑. servePort 34873 (34872는 다른 프로젝트의 rojo serve가 쓴다),
                              StarterPlayer.EnableMouseLockOption = false (카메라는 SkyCamera가 맡는다),
                              Lighting.LightingStyle, Workspace.FallenPartsDestroyHeight (ASSETS.md 참고)
rokit.toml                    도구 버전 고정 (rojo, lune, stylua, selene)
.mcp.json                     Roblox Studio 내장 MCP 서버 (Studio에서 Enable Studio as MCP server를 켜야 동작)
src/
  ReplicatedStorage/
    Config/                   Movement, Camera, World(섬 배치), Requests(주민·의뢰), Rush(러시 라운드·해일·보상),
                              Chunks(러시 청크 21종 발판 데이터), Shop(코인 상점 상품), Collectibles(숨은 별조각), Audio(음악·환경음 에셋 번호), Settings(플레이어 설정 기본값) — 순수 데이터 테이블만
    Shared/                   MovementLogic, WorldGen, RequestLogic, ToyStats, TowerGen(시드→탑·도달 가능성 린트),
                              RushLogic(해일·순위·코인·밟기 판정), GuardLogic(MovementGuard 규칙), ShopLogic(구매·장착 규칙), CollectibleLogic(별조각 줍기 확인), SettingsLogic(설정 값 거르기) (순수 함수),
                              Strings, Tags, Signal, Remotes(이름만, 인스턴스는 Services/Net이 만든다)
  ServerScriptService/
    Main.server.luau          부트스트랩: 서비스 시작 → 월드 생성 → 캐릭터 생성 허용
    World/                    WorldBuilder(조립), IslandTerrain, Decor(무료 에셋 배치), Features(이동 장치),
                              Clouds, Sky(조명·대기), Residents(주민 NPC·대기 동작), ResidentLooks(주민 소품),
                              TowerBuilder(러시 탑)
    Services/                 Net(Remote·빈도 제한), DataService(ProfileStore), EconomyService, RequestService,
                              RoundService(클라우드 러시 라운드), ShopService(상점 구매·장착), CosmeticService(궤적·부츠 입히기),
                              CollectibleService(별조각 줍기 확인·보상), SettingsService(설정 저장)
    Packages/                 외부 라이브러리 원본 (ProfileStore). 고치지 않는다, selene·stylua 제외
  StarterPlayer/StarterPlayerScripts/
    Main.client.luau          클라이언트 부트스트랩
    Movement/                 HopController, SkyCamera, LandingMarker, Effects, Vertigo(아찔함), Ambience(풍경 움직임),
                              Soundscape(배경음악·새소리), AudioGroups(음악·효과음 SoundGroup)
    Requests/                 RequestController(대화·서버 확인), Objectives(유형별 목표·보스 싸움), Stories(이야기 끝·허브 변화·섬 복구),
                              Boss(정상 위 먹구름·도전 받침대), Greeting(다가가면 주민이 손 흔들기),
                              StarShards(숨은 별조각)
    UI/                       Hud, RequestUi, SkyMap(하늘 지도), RushHud(러시 띠·해일·결과),
                              Waypoints(의뢰 목표 아이콘·거리·화면 밖 화살표), ShopUi(코인 상점), SettingsUi(설정 화면)
ServerStorage.Assets          무료 에셋. Rojo 밖, place 파일에만 있다 (ASSETS.md)
third_party/                  외부 라이브러리의 출처·커밋·라이선스
tests/
  init.luau                   러너 (`lune run tests`)
  check.luau                  단언 헬퍼
  *.spec.luau
```

- Studio에서 스크립트를 직접 고치지 않는다. **파일이 원본**이고 Rojo가 Studio로 동기화한다. Studio MCP는 실행·관찰·플레이테스트에 쓴다.
- Config와 Shared 모듈은 `game`, `Instance`, Roblox 서비스를 건드리지 않는다. 그래야 Lune에서 테스트할 수 있다.
- require 방식 (2026-11-02 Lune 0.11.1에서 확인):
  - Roblox 스크립트는 Instance 경로 (`require(ReplicatedStorage.Config.Movement)`).
  - Shared 모듈은 다른 모듈을 require하지 않는다. Config가 필요하면 인자로 받는다.
  - 테스트의 spec 파일은 파일 기준 상대 경로 (`require("../src/ReplicatedStorage/Shared/MovementLogic")`), `tests/init.luau`만 `@self/...`.

## 아키텍처 규칙

- 로컬 캐릭터 물리는 클라이언트 소유다. 이동은 클라이언트(`HopController`)가 즉시 처리한다. 토이 단계에는 서버 검증이 없고, 경쟁 요소가 생기는 W2부터 `MovementGuard`를 둔다 (GDD 14.2).
- 착지 마커, 이펙트, 퍼플링 터짐, 일방향 구름의 충돌 전환은 클라이언트 로컬 처리다. 복제하지 않는다.
- 저장·재화·Remote가 생기면 Bakeria와 같은 규칙을 따른다: 프로필은 DataService만, 재화는 EconomyService만, Remote는 `Shared/Remotes.luau` 한 곳에 정의하고 모두 빈도 제한, 시간은 서버 `os.time()`.

## 컴플라이언스·수익화 원칙 (GDD 12장)

- 실력에 영향을 주는 것(점프력, 점프 횟수, 퍼펙트 판정창, 체크포인트, 해일 속도)을 Robux로 팔지 않는다.
- 확률형 상품을 만들지 않는다. 코인을 Robux로 팔지 않는다.
- 다른 플레이어에게 보이는 텍스트는 `TextService:FilterStringAsync`로 필터링한다. 알림 문구에 유저 이름을 넣지 않는다.
- 아바타는 R15 Only, 스케일 범위 고정 (Studio Game Settings → Avatar). 경쟁 공정성과 착지 판정 때문.

## 테스트와 검증

- `lune run tests`: MovementLogic(점프 높이, 퍼펙트 판정, 탄도), WorldGen(섬 모양·배치·나선 섬 도달 거리), RequestLogic(메달·종 게이지·보상), Strings(언어별 키·형식 일치), ToyStats, TowerGen(결정성·탑 규칙·**도달 가능성 린트**: 청크를 바꾸면 반드시 통과해야 한다), RushLogic(해일·순위·코인·밟기 판정), GuardLogic(상승 예산·비행 판정), ShopLogic(상품 데이터·구매·장착 규칙), CollectibleLogic(별조각 배치·세트 보상·줍기 확인), SettingsLogic(설정 범위·형식).
- `selene src`, `stylua --check src tests`, `rojo build -o build/check.rbxlx`.
- **`build/Skyhop.rbxlx`는 작업용 place다.** 에셋이 이 파일에만 있으므로 `rojo build`로 덮어쓰지 않는다. Studio에서 바꾼 뒤에는 Ctrl+S로 저장하고, git에 포함되어 있으니(.gitignore 예외) 함께 커밋한다.
- 기능 완료 체크리스트:
  1. 수치는 Config에 있다
  2. 린트·테스트·빌드 통과
  3. Studio MCP로 플레이테스트 — 출력 창 에러 0, 스크린샷 확인
  4. 모바일 해상도(세로·가로)에서 조작·UI 확인
  5. GDD와 달라진 점이 있으면 보고
- 못 돌린 검증은 "통과"라고 하지 말고 "미실행"이라고 보고한다.

## 작업 범위

- 현재 단계의 산출물을 우선한다. 다음 단계 기능은 요청 없이 미리 만들지 않는다. 작게 만들어 재미를 먼저 검증하고 키우는 것이 핵심 전략이다.
- 여러 파일에 걸친 큰 변경은 시작 전에 계획을 짧게 공유한다.

## 명령어

```bash
rokit install
```

```bash
rojo serve
```

```bash
lune run tests
```

```bash
selene src
```

```bash
stylua src tests
```

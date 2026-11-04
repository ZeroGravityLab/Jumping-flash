# SKYHOP — Claude 작업 규칙

Roblox 수직 하이점프 3D 플랫포머 (글로벌 출시, 기본 영어). 1인 개발 + Claude Code + Roblox Studio MCP.
기획 전체는 [GDD.md](GDD.md) (v0.2). 설계 의도가 궁금하면 GDD의 해당 장을 먼저 읽는다.

## 현재 단계

- **W2 진행 중** (2026-11-04, 사용자 요청으로 토이 게이트 전에 착수). 떠 있는 섬 월드(허브·1장), 아찔함 연출, 의뢰 시스템(튜토리얼 3 + 1장 6, 유형 5종: 수집·봉화·고리 다이빙·배달·머크 청소), 모바일 세로·가로 UI 배치까지 만들었다. 남은 것: ProfileStore 전환, 사람 테스트.
- 모바일 점검은 Studio Test → Device Simulator로 한다. 플레이를 다시 시작하면 가로로 돌아가고, 프롬프트는 카메라 화면 안에 있어야 뜬다.
- 토이 게이트(사람 손맛 테스트, GDD 15장)는 아직 남아 있다. W3 기능(클라우드 러시, 청크)은 요청 전에 만들지 않는다. 단계가 바뀌면 이 섹션을 갱신한다.
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
    Config/                   Movement, Camera, World(섬 배치), Requests(주민·의뢰) — 순수 데이터 테이블만
    Shared/                   MovementLogic, WorldGen, RequestLogic, ToyStats (순수 함수),
                              Strings, Tags, Signal, Remotes(이름만, 인스턴스는 Services/Net이 만든다)
  ServerScriptService/
    Main.server.luau          부트스트랩: 서비스 시작 → 월드 생성 → 캐릭터 생성 허용
    World/                    WorldBuilder(조립), IslandTerrain, Decor(무료 에셋 배치), Features(이동 장치),
                              Clouds, Sky(조명·대기), Residents(주민 NPC)
    Services/                 Net(Remote·빈도 제한), DataService, EconomyService, RequestService
  StarterPlayer/StarterPlayerScripts/
    Main.client.luau          클라이언트 부트스트랩
    Movement/                 HopController, SkyCamera, LandingMarker, Effects, Vertigo(아찔함), Ambience(풍경 움직임)
    Requests/                 RequestController(대화·서버 확인), Objectives(유형별 목표)
    UI/                       Hud, RequestUi
ServerStorage.Assets          무료 에셋. Rojo 밖, place 파일에만 있다 (ASSETS.md)
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

- `lune run tests`: MovementLogic(점프 높이, 퍼펙트 판정, 탄도), WorldGen(섬 모양·배치·나선 섬 도달 거리), RequestLogic(메달·종 게이지·보상), Strings(언어별 키·형식 일치), ToyStats.
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

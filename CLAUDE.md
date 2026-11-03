# SKYHOP — Claude 작업 규칙

Roblox 수직 하이점프 3D 플랫포머 (글로벌 출시, 기본 영어). 1인 개발 + Claude Code + Roblox Studio MCP.
기획 전체는 [GDD.md](GDD.md) (v0.1). 설계 의도가 궁금하면 GDD의 해당 장을 먼저 읽는다.

## 현재 단계

- **W1 토이 프로토타입** (2026-11-02 착수). 그레이박스에서 이동만으로 재미를 판정한다 (GDD 15장 토이 게이트).
- 토이 범위: 3단 점프·정점 퍼펙트·스톰프·반동, 스카이 캠/1인칭 전환, 다이브 캠, 착지 마커, HUD, 그레이박스 놀이터. 저장·재화·라운드·서버 검증은 없다.
- 토이 게이트를 통과하기 전에는 W2 기능(청크, 클라우드 러시)을 만들지 않는다. 단계가 바뀌면 이 섹션을 갱신한다.

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
                              StarterPlayer.EnableMouseLockOption = false (카메라는 SkyCamera가 맡는다)
rokit.toml                    도구 버전 고정 (rojo, lune, stylua, selene)
.mcp.json                     Roblox Studio 내장 MCP 서버 (Studio에서 Enable Studio as MCP server를 켜야 동작)
src/
  ReplicatedStorage/
    Config/                   Movement, Camera — 순수 데이터 테이블만
    Shared/                   MovementLogic, ToyStats (순수 함수), Strings, Tags, Signal
  ServerScriptService/
    Main.server.luau          중력 적용, 놀이터 생성
    Toy/Playground.luau       토이 전용 그레이박스. W2에 청크 시스템(GDD 8.1)으로 대체
  StarterPlayer/StarterPlayerScripts/
    Main.client.luau          클라이언트 부트스트랩
    Movement/                 HopController, SkyCamera, LandingMarker, Effects
    UI/Hud.luau
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

- `lune run tests`: MovementLogic(점프 높이, 퍼펙트 판정, 탄도), Strings(언어별 키·형식 일치), ToyStats.
- `selene src`, `stylua --check src tests`, `rojo build -o build/Skyhop.rbxlx`.
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

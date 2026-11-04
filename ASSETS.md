# 외부 에셋 기록

배경·개체 모델은 Roblox Creator Store의 무료 모델을 쓴다. 모델은 Studio place의 `ServerStorage.Assets`에 들어 있고 **Rojo가 관리하지 않는다.**
place 파일(`build/Skyhop.rbxlx`)을 저장해야 유지된다. **`rojo build -o build/Skyhop.rbxlx`로 덮어쓰지 말 것** (검증 빌드는 다른 파일 이름으로).
이 파일은 에셋의 유일한 사본이라 git에 넣는다(.gitignore 예외, 2026-11-04부터). 에셋이나 place 설정을 바꾸면 Studio에서 저장한 뒤 함께 커밋한다.

## 정화 규칙 (가져올 때마다)
1. 허용 클래스 외(Script, LocalScript, ModuleScript, RemoteEvent/Function, GUI, Sound 등)는 모두 삭제
2. 모든 파트 Anchored, 조인트 삭제, 기준점을 바닥 중앙으로, `Height`·`Footprint`·`SourceAssetId` 속성 기록
3. 크기는 `model:ScaleTo(model:GetScale() * 배율)`로만 바꾼다 (원래 배율이 1이 아닌 에셋이 있다)

2026-11-04: "No scripts"라고 소개된 구름 모델 3개(126537751554292, 82104402255370, 87864903442112, 모두 삭제된 계정)에 숨은 Script·LocalScript·RemoteFunction·GUI 56개 묶음이 있었다. 쓰지 않는다. 인증 제작자 에셋을 우선한다.

## 사용 중인 에셋

| Assets 경로 | 원본 ID | 비고 |
|---|---|---|
| Trees/Tree_Tree1~10(F,T) | 96193157220829 | 30종. 1 초록 2 진초록 3 연두 4 청록 5 파랑 6 보라 7 자주 8 분홍 9 장미 10 빨강 |
| Plants/Pine, Flower_Small, Rocks/Rock_1~6, Islets/Islet_1~3 | 111768096290717 | 바위는 배치 때 돌색으로 칠함 |
| Plants/FlowerBush | 10842648544 | |
| Buildings/House_LowPoly | 91447454268215 | |
| Buildings/House_Euro | 1848359291 | 원본의 Seat·Fire·Smoke 삭제 |
| Buildings/House_Village | 15485395576 | |
| Buildings/Windmill | 15675216202 | 원본 Script·Sound 삭제. Fan을 클라이언트가 돌림 |
| Sky/Balloon | 166871533 | |
| Sky/Birds | 130457575 | |
| Sky/Cloud | 14343104543 | 인증 제작자. 구름 바다·구름 덩어리에 반복 사용 |

## 음원 (place에 넣지 않고 Config `Audio`의 에셋 번호로 튼다)
인증 제작자의 공식 라이선스 음원만 쓴다(APMOfficial, ProSoundEffects). 2026-11-04 Studio에서 모두 로드되는 것을 확인했다.

| 용도 | 원본 ID | 이름 |
|---|---|---|
| 허브 음악 | 1842285620 | Pleasure Trip (APM) |
| 풍차 초원 음악 | 1839885864 | Silly Things (APM) |
| 클라우드 러시 음악 | 9043170481 | Dancing for Joy 60 A (APM) |
| 장 보스 음악 | 9043602056 | Ghost Ship (a 60) (APM) |
| 섬 새소리 | 9116969794 | Morning Birds 5 (Pro Sound Effects) |

## place에 저장되는 설정 (게임 스크립트로 못 바꿈)
- `Terrain.Decoration` = 켬 (움직이는 잔디). 스크립트에서는 속성이 보이지도 않아 Studio 속성 창에서만 켤 수 있다. 2026-11-04 적용.
- `Lighting.LightingStyle` = Realistic, `PrioritizeLightingQuality` = 끔 (저사양 기기에서 엔진이 품질을 낮출 수 있게). 예전 `Technology`(Future)를 대신하는 속성이다. 게임 스크립트는 쓸 수 없지만(PluginOrOpenCloud) Rojo 프로젝트에 적어 두었다. 2026-11-04 적용.
- `Workspace.FallenPartsDestroyHeight` = -2000. 기본값 -500이면 낙하 복귀 높이(Config `FallResetY` -600)에 닿기 전에 캐릭터가 죽는다. Rojo 프로젝트에도 적어 두었다.
- `rojo serve` 중에 default.project.json의 `$properties`를 바꾸면 Studio에 바로 반영되지 않았다. Studio에서도 같은 값으로 맞추고 저장한다.

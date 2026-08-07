# Cue

액션 버튼 한 번으로 여러 액션을 순환하고, **무엇이 실행될지를 다이나믹 아일랜드로 보여주는** iOS 앱.

> 저장소 이름은 `MyAction`, 앱 이름은 **Cue**다.

| | |
|---|---|
| 최소 버전 | iOS 18.0 (`ControlWidget` 요구사항) |
| 개발 환경 | Xcode 26.6 / iOS 26.5 SDK |
| 액션 버튼 | iPhone 15 Pro 이상 (시뮬레이터에는 없다) |

## 왜 이걸 만들었나

액션 버튼의 가장 큰 실제 불만은 "동작을 하나만 할당할 수 있다"이다. 이걸 푸는 앱은 이미 있다 —
[Action Button Pro](https://apps.apple.com/app/id6471029467), ActionMate,
[MultiButton 단축어](https://www.macstories.net/ios/introducing-multibutton-assign-two-shortcuts-to-the-same-action-button-press-on-iphone-15-pro/).

하지만 **누른 뒤 피드백이 없다.** 눌렸는지, 무엇이 실행됐는지, 다음에 누르면 뭐가 될지 알 수 없다.
Action Button Pro의 App Store 기능 목록을 확인한 결과 Live Activity · 다이나믹 아일랜드 ·
제어 센터 컨트롤이 전부 없다(2026-08-07 확인). UI 표면은 잠금화면 위젯과 홈 아이콘 롱프레스뿐이다.

Cue는 그 피드백 레이어가 본체다.

## 동작

```
1번째 누름   ( 🔦 손전등   0:02 )   ← 다이나믹 아일랜드
2번째 누름   ( 📍 순간기록 0:02 )   2초 안에 누르면 다음 항목으로 순환
2초 경과     ( ✓ 실행됨 )
```

확정되는 경로는 두 가지다.

| 경로 | 동작 |
|---|---|
| **2초 방치** | 마지막 입력에서 2초가 지나면 선택된 항목이 자동 실행된다 |
| **항목 더블 탭** | 액션 스트립에서 같은 항목을 두 번 탭하면 기다리지 않고 그 항목으로 확정된다 |

첫 탭은 선택을 그 항목으로 옮기고 창을 다시 연다. 즉 아무 항목이나 두 번 탭하면 순환을 거치지 않고
원하는 액션을 바로 실행할 수 있다. 창이 지난 뒤 누르면 처음(0번)으로 리셋된다.

잠금화면 Live Activity와 다이나믹 아일랜드 확장 뷰에는 세트 전체가 **탭 가능한 스트립**으로 뜨고,
**취소 / 실행** 버튼이 함께 있다. 제어 센터의 두 번째 컨트롤로 액션 세트를 전환한다.

### 액션 종류

백그라운드 인텐트에서 실제로 수행 가능한 것만 넣었다. 시스템 카메라 실행이나 무음 전환처럼
서드파티 앱에 API가 없는 동작은 제외했다.

| 종류 | 동작 |
|---|---|
| `torch` | 손전등 토글 (`AVCaptureDevice`) |
| `mark` | 지금 시각을 로그에 남긴다 |
| `stopwatch` | 스톱워치 시작 / 정지 |
| `openApp` | 결과 화면에 **"열기" 버튼**을 띄운다 — 이것만 앱을 실제로 전면에 올린다 |

## 하나의 AppIntent, 다섯 표면

`CuePressIntent` 하나가 다섯 곳에서 실행된다.

```
CuePressIntent  (LiveActivityIntent)
  ├─ 제어 센터 컨트롤
  ├─ 액션 버튼
  ├─ 잠금화면 컨트롤
  ├─ Live Activity · 다이나믹 아일랜드 안의 버튼
  └─ Siri · 단축어
```

`ControlWidget` 하나(`CuePressControl`)를 만들면 제어 센터 · 잠금화면 · **액션 버튼**에 모두
나타난다. 어디에 붙일지는 사용자가 고른다. watchOS 26부터는 같은 컨트롤이 Apple Watch 제어 센터와
Watch Ultra 액션 버튼에도 올라간다.

`LiveActivityIntent`를 채택했기 때문에 앱이 전면에 없어도 Live Activity를 시작할 수 있다.

## 구조

```
MyAction/
├── MyAction.xcodeproj                    손으로 작성 (외부 생성 도구 없음)
├── Shared/                               앱 · 위젯 확장 양쪽에 컴파일된다
│   ├── CueModels.swift                     액션 · 세트 · 런타임 상태 · 로그
│   ├── CueStore.swift                      App Group UserDefaults
│   ├── CueAttributes.swift                 ActivityAttributes
│   ├── CueEngine.swift                   ★ 순환 / 커밋 상태 기계
│   ├── CueActionRunner.swift               액션 실행
│   ├── CuePresenting.swift                 표시 계층 프로토콜 (테스트 seam)
│   ├── CueLiveActivityController.swift     CuePresenting의 유일한 실제 구현
│   └── CueIntents.swift                    인텐트 6개 + AppShortcutsProvider
├── MyAction/                             앱 타깃
│   ├── MyActionApp.swift
│   ├── ContentView.swift                   누름 테스트 · 세트 선택 · 실행 기록 · 설정 안내
│   ├── SetEditorView.swift
│   └── CueViewModel.swift
├── MyActionWidgets/                      위젯 확장 타깃
│   ├── MyActionWidgetsBundle.swift
│   ├── CueLiveActivity.swift               잠금화면 + 다이나믹 아일랜드 3형태
│   └── CueControls.swift                   컨트롤 2개
└── MyActionTests/                        단위 테스트 타깃
    ├── CueTestHarness.swift                SpyPresenter + 격리된 저장소
    └── CueEngineTests.swift                20개
```

| | |
|---|---|
| 앱 번들 ID | `com.keen.cue` |
| 확장 번들 ID | `com.keen.cue.widgets` |
| App Group | `group.com.keen.cue` |

## 핵심 설계

### 순환과 더블 탭을 어떻게 판별하나

액션 버튼 누름도, 항목 탭도 매번 **별개의 인텐트 실행**이다. 프로세스가 유지된다는 보장이 없으므로
"직전 입력"을 App Group에 남긴 값으로 판단한다 — `lastPressAt` · `lastInputWasItemTap` · `generation`.

| 입력 | 판정 |
|---|---|
| 액션 버튼 · 컨트롤 (`press`) | 창이 열려 있으면 다음 항목, 아니면 0번 |
| 항목 첫 탭 (`tapItem`) | 선택을 그 항목으로 옮기고 창을 다시 연다 |
| 같은 항목 두 번째 탭 | `lastInputWasItemTap && selectedIndex == index && 창 안` → 즉시 커밋 |

Live Activity의 버튼은 **단일 탭만 전달된다** — 더블 탭 제스처 자체가 없다. 그래서 두 번의 단일 탭을
위 조건으로 판별한다. 앱 안의 스트립도 같은 `CueSelectIntent` → 같은 `CueEngine.tapItem` 경로를 타므로
동작이 어디서든 동일하다.

`press()`와 `tapItem()`은 모두 `arm(index:isItemTap:set:)`으로 수렴한다. 선택을 옮기고 Live Activity를
띄운 뒤 창이 닫히기를 기다려 커밋하는 부분이 한 곳에만 있다.

### 커밋 대기 — 이 설계의 가장 약한 고리

커밋 대기는 `perform()` 안에서 `Task.sleep(2s)`으로 기다린다. 인텐트가 반환되면 프로세스가 곧 정지될 수
있으므로, 반환을 늦춰 실행 시점까지 살려 두는 것이다. 대기 중 다시 입력이 오면 `generation`이 올라가고
먼저 대기하던 호출은 조용히 물러난다 — 커밋은 마지막 입력이 책임진다.

**이 방식은 iOS가 인텐트 프로세스에 주는 백그라운드 실행 시간에 의존한다.** 로직은 테스트로 검증됐지만,
"2초를 살아서 그 코드에 도달하는가"는 런타임이 결정하는 문제라 실기기에서만 확인할 수 있다. 그래서
Live Activity에 **실행 / 취소 버튼**을 두고 **항목 더블 탭**을 넣었다. 자동 커밋이 실기기에서 무너져도
확정 경로가 남는다.

### 앱 열기를 왜 분리했나

`LiveActivityIntent`는 앱을 전면으로 못 올린다. 반대로 `openAppWhenRun = true`인 인텐트는 앱을 열 수
있지만 Live Activity를 시작할 수 없다. 하나의 인텐트가 둘 다 할 수 없다.

그래서 둘로 나눴다. 액션 실행은 백그라운드에서 끝내고, **여는 것만** `CueOpenAppIntent`가 맡는다.
`openApp` 액션을 확정하면 결과 카드에 "열기" 버튼이 붙고, 앱이 뜨는 것은 사용자의 탭 한 번 뒤다.
버튼이 붙은 카드는 탭할 틈이 있도록 20초간 남는다(보통 결과는 2.5초).

## 빌드

```bash
xcodebuild -project MyAction.xcodeproj -scheme MyAction -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

시뮬레이터에는 액션 버튼이 없다. 앱 안의 **"Cue 누르기"** 버튼이나 단축어 앱으로 같은 인텐트를 실행해
확인한다.

실기기에 올리려면 Xcode에서 **팀을 지정**하고 App Group을 프로비저닝해야 한다. 자동 서명이 팀
`6DBY9BSZQ2`를 찾아 시뮬레이터용 entitlement는 이미 생성된다.

## 테스트

```bash
xcodebuild test -project MyAction.xcodeproj -scheme MyAction \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Swift Testing 20개, 약 2초, 경고 0건.

상태 기계가 Live Activity 권한이나 시스템 UI에 매달리지 않도록 seam 세 개를 뒀다.

| seam | 테스트에서 |
|---|---|
| `CueEngine.presenter` | `SpyPresenter`로 교체. 엔진이 **무엇을 보여주려 했는지**만 기록한다 — 문구, "열기" 버튼 유무, 해제 시각까지 |
| `CueStore.defaults` | 별도 suite로 교체. 앱의 실제 App Group을 건드리지 않는다 |
| `CueEngine.cycleWindow` | 0.08초로 줄여 실시간 대기를 없앤다. 더블 탭을 볼 때는 반대로 5초로 **늘려서**, 실행이 자동 커밋일 수 없는 상태를 만든 뒤 확정을 확인한다 |

셋 다 `var`인 것은 이 목적뿐이고 앱 코드에서는 바꾸지 않는다. `CueStore`·`CueEngine`이 정적 상태를
공유하므로 스위트는 `.serialized`다.

| 묶음 | 덮는 것 |
|---|---|
| 순환 | 첫 누름 = 0번 / 창 안 연타가 0→1→2→3→0 / 창 만료 후 0번 리셋 |
| 자동 커밋 | 창 닫히면 선택 항목 실행 · 무장 해제 · `.executed` 표시 / **대기 중 추가 입력이 오면 앞선 누름은 커밋하지 않음**(중복 실행 방지) |
| 항목 탭 | 첫 탭은 선택만 이동 / 같은 항목 두 번째 탭은 즉시 확정 / 다른 항목 탭은 확정 아님 / 액션 버튼으로 고른 뒤의 한 번 탭은 더블 탭 아님 / 창 지난 뒤의 탭은 더블 탭 아님 / 범위 밖 인덱스 무시 |
| 취소 · 세트 | 취소는 실행 없이 무장 해제 / 세트 전환은 선택 리셋, 액션 실행 안 함 / 빈 세트에서 누름 무시 |
| 액션 결과 | 스톱워치 시작↔정지 / `openApp`이 "열기" 버튼을 붙이고 해제 시각을 늘림 / 다른 경로에는 안 붙음 / 실패한 액션도 실패로 기록 |
| 로그 | 최신 우선 · 상한(30) 유지 |

## 검증 현황

2026-08-07 기준, iPhone 17 Pro 시뮬레이터 / Xcode 26.6.

### 확인됨

| 항목 | 근거 |
|---|---|
| 빌드 · 확장 임베드 | 클린 빌드 경고 0건, `MyAction.app/PlugIns/MyActionWidgets.appex` |
| App Group entitlement | `MyAction.app-Simulated.xcent`에 `group.com.keen.cue` |
| 순환과 창 만료 리셋 | 앱 내 `1/4` → 연타 후 `2/4`, 느린 연타는 0번으로 되돌아감 |
| 자동 커밋 + 로그 | 실행 기록에 `스톱워치 · 시작` 등이 남음 |
| **항목 더블 탭 즉시 확정** | 타일 좌표를 0.668초 간격으로 2회 탭 → 두 번째 탭 후 0.546초 시점에 이미 실행 완료. 자동 커밋 시점(첫 탭 + 2.0초)보다 앞서므로 더블 탭이 만든 실행임이 확정 |
| 스트립 항목이 탭 대상으로 노출 | 접근성 트리에 액션 4개가 각각 button으로 잡힘 |
| 다이나믹 아일랜드 컴팩트 | 선택 액션 아이콘 + 카운트다운, 실행 후 녹색 체크 (스크린샷) |
| 잠금화면 Live Activity | 세트명 · 카운트다운 · 액션 스트립 · 취소/실행 버튼 (스크린샷) |
| `openApp` → "열기" 버튼 렌더링 | 결과 카드 옆 파란 "열기" 버튼 (스크린샷) |
| **"열기" 버튼 탭 → 앱이 전면에 뜸** | 잠금 상태에서 탭 → Cue 화면 전환, 동시에 다이나믹 아일랜드가 비워짐(`endAll()`) |
| 유휴 시 오작동 없음 | 재설치 후 30초 · 40초 유휴 두 번, 로그 비어 있음 |
| 컨트롤 · 인텐트 등록 | appex에 컨트롤 kind 2개, 두 타깃의 `Metadata.appintents`에 인텐트 6개 |
| 상태 기계 로직 | 단위 테스트 20개 |

### 검증되지 않음

- **액션 버튼 실제 누름** — iPhone 15 Pro 이상 실기기 전용.
- **`Task.sleep(2s)` 커밋이 실기기 백그라운드에서 버티는지** — 위 "커밋 대기" 참조. 시뮬레이터는
  백그라운드 제약이 훨씬 느슨해서, 여기서 통과한 것이 실기기 통과를 보장하지 않는다.
- **제어 센터 · 액션 버튼 갤러리에 실제로 뜨는지** — 시뮬레이터에서 제어 센터가 열리지 않아 눈으로
  확인하지 못했다. 등록은 바이너리 수준에서만 확인했다.
- **Live Activity 안의 스트립을 직접 두 번 탭하는 것** — 렌더링은 확인했으나 탭은 못 했다. 카드가
  몇 초만 살아 있고 잠금화면 시스템 UI라 자동화가 어렵다. 앱 안의 스트립이 같은 경로를 타고 그쪽은
  검증됐다.
- **다이나믹 아일랜드 확장(롱프레스) 뷰** — 코드는 있으나 캡처하지 못했다.
- **손전등 액션** — 시뮬레이터에 토치가 없어 실패로 기록된다.

## 알려진 제약

- **Live Activity는 최대 8시간** 후 시스템이 자동 종료한다(12시간 후 완전 제거). "항상 떠 있는
  다이나믹 아일랜드"는 불가능하다. Cue는 누름 직후 몇 초만 띄우므로 영향받지 않는다.
- **`ControlWidgetToggle` + `LiveActivityIntent`** 조합은 토글 상태가 되돌아가는 문제가 개발자
  포럼에 보고돼 있다. 그래서 두 컨트롤 모두 `ControlWidgetButton`으로 만들었다.
- 앱 열기는 인텐트를 둘로 나눠야 한다. 위 "앱 열기를 왜 분리했나" 참조.

## 다음에 할 만한 것

**1. 실기기 검증** — 미검증 항목 대부분이 한 번에 풀린다.

- `Task.sleep(2s)` 커밋이 백그라운드에서 버티는지 (가장 중요)
- 설정 > 액션 버튼 > 제어에 `Cue 누르기`가 뜨는지
- 2초가 적절한 창인지 — 엄지로 연타해 봐야 안다

**2. 다듬기**

- 순환 창을 사용자가 조절 (1.5s ~ 3s)
- 세트 자동 전환 — 시간대 · 위치 기반 (Action Button Pro가 하는 것 + 피드백)

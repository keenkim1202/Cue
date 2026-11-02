# 액션 버튼의 작동 규칙 — 자료 조사

Cue가 실기기에서 순환하지 않았다. 몇 번을 눌러도 늘 1번 액션만 실행됐다.
원인을 짚기 위해 액션 버튼이 실제로 어떻게 발동되는지 조사한 기록이다.

조사일 2026-08-14. 출처를 **공식 문서**와 **커뮤니티·블로그**로 나누고,
각 항목에 어디까지 직접 확인했는지 검증 수준을 적었다.

---

## 1. 공식 문서 (Apple)

### 1-1. WWDC24 — Extend your app's controls across the system

<https://developer.apple.com/videos/play/wwdc2024/10157/>

**검증 수준: 원문 직접 확인.** 이 조사에서 가장 신뢰도 높은 근거다.

- 액션 버튼에 할당된 컨트롤은 **hold 제스처로 호출된다.**
- 시스템이 **동작을 수행하기 전에** 액션 힌트를 먼저 보여준다.
  힌트는 동사로 시작해야 하고, 타이머 컨트롤 예시로 `Hold to Start` / `Hold to Stop`이 제시된다.
- 힌트는 컨트롤의 값 텍스트에서 시스템이 합성하거나 `controlWidgetActionHint`로 지정한다.

  ```swift
  Label(isOn ? "Running" : "Stopped",
        systemImage: isOn ? "hourglass" : "hourglass.bottomhalf.filled")
      .controlWidgetActionHint(isOn ? "Start" : "Stop")
  ```

- 컨트롤 상태가 다시 읽히는 계기는 세 가지다.
  1. 컨트롤 동작이 수행됐을 때 — **인텐트의 `perform()`이 반환된 뒤** 시스템이 자동으로 리로드한다.
  2. 앱이 `ControlCenter.shared.reloadControls(ofKind:)`로 요청했을 때.
  3. 푸시 알림으로 무효화됐을 때.
- `previewValue`는 미리 정해져 있고 빠르게 반환돼야 하며 "꺼짐" 상태를 대표해야 한다.
  컨트롤 갤러리, 잠금화면 사용자화, **액션 버튼 설정 화면**의 미리보기에 쓰인다.

**Cue에 직접 걸리는 부분**

> "The system displays action hints **before** the action is performed."

발동 전에 시스템 UI가 먼저 개입한다는 뜻이다. 짧게 눌러서는 인텐트가 돌지 않는다.

### 1-2. Human Interface Guidelines — Action button

<https://developer.apple.com/design/human-interface-guidelines/action-button>

**검증 수준: 검색 요약 경유.** 페이지가 JS로 렌더링돼 직접 가져오지 못했다.
아래 문구는 검색 엔진이 요약한 것이라 **원문 대조가 필요하다.**

- 액션 버튼은 지원 기종에서 즐겨 쓰는 기능에 빠르게 접근하게 해 준다.
- **"첫 버튼 누름으로 시작할 동작을 고를 수 있도록, 필수 동작들의 집합을 제공하라."**
- **"단지 앱을 여는 것에 불과한 액션 버튼 동작은 피하라."** 앱 아이콘이 이미 그 일을 한다.
- **"보조 기능을 고려하라. 사람들은 화면을 보지 않고 액션 버튼을 쓰는 경우가 많으므로,
  이어지는 누름은 첫 누름에서 논리적으로 이어져야 하고 현재 맥락에서도 말이 돼야 한다."**

**주의 — watchOS 한정 항목이 섞여 있다.** "누르고 있어도 앱이 반응하지 않는다,
watchOS가 이 제스처를 긴급 SOS에 예약해 뒀기 때문"이라는 문장은 **Apple Watch 얘기다.**
iPhone의 액션 버튼과 반대되는 규칙이므로 혼동하지 않아야 한다.

**Cue에 직접 걸리는 부분**

Apple이 "여러 동작 중에서 고르는" 모델과 "이어지는 누름"을 **명시적으로 지지한다.**
Cue의 컨셉 자체는 HIG와 어긋나지 않는다. 문제는 컨셉이 아니라 타이밍이다.

다만 "사람들은 화면을 보지 않고 쓴다"는 단서는 뼈아프다.
Cue의 핵심 주장이 "다이나믹 아일랜드로 피드백을 준다"인데,
Apple은 이 버튼의 주 사용 맥락을 **화면을 보지 않는 상황**으로 상정하고 있다.
시각 피드백만으로는 부족하고 햅틱·사운드가 동등하게 중요하다는 뜻이다.

### 1-3. Apple 사용 설명서 — 액션 버튼 사용 및 사용자화

<https://support.apple.com/guide/iphone/use-and-customize-the-action-button-iphe89d61d66/ios>

**검증 수준: 미확인.** 본문을 가져오지 못했고 내비게이션만 나왔다.
URL만 기록해 둔다. 홀드 시간에 대한 공식 서술이 있는지 **직접 열어 확인해야 한다.**

---

## 2. 커뮤니티 · 블로그

공식 문서가 답하지 않는 실무 수치는 여기밖에 없다. 다만 전부 2차 자료이고,
**대부분 단축어(Shortcuts) 경로에서 관찰된 것**이라 컨트롤 경로에 그대로 적용되는지는 확인되지 않았다.

### 2-1. MacStories — MultiButton (가장 중요한 근거)

<https://www.macstories.net/ios/introducing-multibutton-assign-two-shortcuts-to-the-same-action-button-press-on-iphone-15-pro/>

**검증 수준: 검색 요약 경유. 원문은 403으로 직접 확인 실패.**

Federico Viticci가 만든 단축어로, 액션 버튼을 빠르게 여러 번 눌러 두 단축어를 번갈아 실행한다.
Cue의 README가 선행 사례로 참조하는 바로 그것이다.

- 한 번 누르면 주 단축어가 실행된다.
- **첫 누름으로부터 7초 안에** 다시 누르면 보조 단축어가 실행된다.
- 7초가 지나면 다시 주 단축어로 돌아간다.

**왜 이게 결정적인가.** 실기기에서 실제로 튜닝된 유일한 수치다.
같은 문제를 먼저 푼 사람이 창을 7초로 잡았다는 것은,
두 번 연속 발동에 **그 정도 여유가 필요했다**는 뜻이다.
Cue는 같은 자리에 2초를 넣었다.

7초가 물리적 하한인지, 안전 여유를 크게 잡은 값인지는 이 자료만으로 알 수 없다.
실측이 필요한 이유가 여기 있다.

### 2-2. "앞선 실행이 끝나기 전에는 다음 누름이 전달되지 않는다"

출처: MacStories, 9to5Mac, MacRumors의 MultiButton 관련 서술 (검색 요약 경유)

- 첫 단축어가 아직 실행 중이면 액션 버튼이 두 번째 누름을 등록하지 못한다.
  주 단축어가 끝날 때까지 기다려야 한다.
- 단축어 앱은 액션 버튼에서 두 단축어를 동시에 실행하는 것을 지원하지 않는다.

DESIGN.md에 "문서화되지 않았지만 널리 확인된 동작"으로 적어 둔 내용과 일치한다.
`CueCommitScheduling`이 존재하는 이유이기도 하다.

**남는 의문:** 이 관찰은 **단축어 경로**의 것이다.
Cue는 `ControlWidgetButton` + `LiveActivityIntent` 경로를 쓴다.
`perform()`이 즉시 반환되는 지금 구조에서도 같은 제약이 걸리는지는 확인되지 않았다.
WWDC24가 "`perform()`이 반환된 뒤 리로드한다"고 말한 것을 보면
시스템이 반환 시점을 경계로 삼는 것은 분명하다.

### 2-3. press-and-hold를 요구하는 이유

<https://9to5mac.com/2023/09/26/iphone-15-pro-action-button-press-and-hold/>

**검증 수준: 원문 직접 확인.**

- 오발동 방지를 위한 의도적 설계다. 이 글은 그 판단이 옳다고 평가한다.
- **정확한 홀드 시간은 이 글에 없다.** 발동이 홀드 도중인지 손을 뗄 때인지도 서술하지 않는다.
- 저자가 "더블 클릭 설정이 있으면 좋겠다"고 적었다 — 즉 그런 기능은 없다.

### 2-4. 홀드 시간 "약 1초"

출처: SlashGear, iDownloadBlog, CASEBX, XDA 등 다수 (검색 요약 경유)

- 지정한 동작을 실행하려면 **약 1초** 정도 누르고 있어야 한다.
- 그냥 짧게 누르면 iOS가 "누르고 있으라"고 안내한다.
- **짧게 한 번 누르면 다이나믹 아일랜드에 현재 설정만 표시되고 동작은 실행되지 않는다.**

**검증 수준 주의:** 여러 매체가 비슷하게 말하지만 전부 체감치이고 Apple 공식 수치가 아니다.
"약 1초"는 근사값으로만 다뤄야 한다.

### 2-5. 신뢰도 낮음 — 두 번 눌러야 동작한다는 보고

<https://discussions.apple.com/thread/255806709>

iPhone 16 Pro Max에서 한 번 눌러도 아무 일이 없고 두 번째 누름에 실행된다는 사용자 보고가 있다.
개별 하드웨어 문제일 가능성이 높아 **설계 근거로 쓰지 않는다.** 존재만 기록해 둔다.

---

## 3. 확인하지 못한 것

조사로 답이 나오지 않았고, **실측하거나 원문을 직접 열어야** 하는 항목이다.

| 항목 | 상태 |
|---|---|
| 정확한 홀드 임계값 (ms) | 공개 문서에 없음. 검색으로 확인 실패 |
| 발동 시점 — 홀드 임계 도달 시점인가, 손을 뗄 때인가 | 어떤 자료도 명시하지 않음 |
| 두 번 연속 발동의 실제 최소 간격 | **실측 필요. 이번 설계의 핵심 수치** |
| "실행 중 누름 폐기"가 컨트롤 경로에도 적용되는가 | 단축어 경로에서만 관찰됨 |
| 홀드 중 뜨는 시스템 HUD와 Live Activity의 표시 우선순위 | 미확인. 카드가 가려질 가능성 |
| 사용 설명서(1-3)의 공식 서술 | 본문 미확인 |

---

## 4. Cue에 대한 함의

`CueEngine.cycleWindow = 2.0`을 놓고 위 규칙을 적용하면 이렇게 된다.

```
홀드 (약 1초) ──→ 1번 액션 발동, 카드 뜸, 2초 타이머 시작
              릴리스
              다시 누름
              홀드 (약 1초) ──→ 여기서 이미 2초가 지나 있다
                               자동 확정이 먼저 끝나 버렸다
```

두 번째 발동이 창 안에 들어올 수 없다.
`press()`의 `isContinuing`이 거짓이 되어 `index = 0`으로 리셋되고,
**순환은 일어나지 않으며 1번 액션만 반복 실행된다.**
실기기에서 관찰된 증상과 정확히 일치한다.

원인은 상태 기계가 아니다. `generation` 무효화도, 커밋을 인텐트 밖으로 뺀 것도 다 옳다.
**2초라는 상수 하나가 물리적으로 도달 불가능한 값**이었을 뿐이다.
시뮬레이터의 화면 버튼은 홀드가 필요 없어서 이 벽이 드러나지 않았다.

부수적으로 함께 무너지는 것들:

- **`resultLinger = 2.5초`** — 자동 확정 후 결과 카드가 2.5초 남는다.
  창을 늘리면 이 값도 같이 재검토해야 한다.
- **"손을 떼면 실행"이라는 문구** — 창을 늘리면 사실과 멀어진다. UI 문구 전반이 영향받는다.
- **더블 탭 즉시 확정** — 액션 버튼으로는 도달할 수 없는 경로다.
  화면을 봐야만 쓸 수 있으니, HIG의 "화면을 보지 않고 쓴다"와 어긋난다.

---

## 5. 다음 — 실측 설계

7초를 그대로 베끼지 않는다. 추측으로 상수만 바꾸면 같은 실수를 반복한다.
**기기에서 실제 발동 간격을 재고, 그 분포를 보고 정한다.**

**구현 — `Shared/CuePressProbe.swift`, `Cue/PressProbeView.swift`**

표본마다 네 가지를 남긴다. 저장 키(`cue.pressprobe`)는 순환 상태와 완전히 분리했다.

| 필드 | 무엇을 답하나 |
|---|---|
| `at` | `press()` 진입 시각. 인접 표본의 차가 **발동 간격**이다 |
| `performSeconds` | `press()`가 끝나기까지 걸린 시간 |
| `continued` | 순환으로 인정됐는지. 0이면 진단이 확인된 것 |
| `source` | 인텐트 경로냐 앱 내 버튼이냐 |

**`performSeconds`를 같이 재는 이유.** `arm()`이 `showCycling`을 `await`하므로
**ActivityKit이 `perform()` 시간에 포함된다.** 시스템은 `perform()`이 반환된 뒤에야
컨트롤을 리로드하고(1-1), 실행 중에는 다음 누름을 전달하지 않는 것으로 보고돼 있다(2-2).
Live Activity 시작이 느리면 **그것만으로 누름이 버려진다** — 창 길이와 무관한
**독립된 두 번째 원인**이다. 이 경우 상수를 고쳐서는 안 풀리고,
카드 표시를 기다리지 않도록 표시 경로를 떼어내야 한다.

표본 기록은 **측정 구간이 끝난 뒤**에 한다. 인코딩 비용이 `performSeconds`에 섞이지 않는다.
다만 실제 `perform()` 시간에는 얹히므로 표본 상한을 200개로 뒀다.

**측정 절차** (앱의 `발동 간격 실측` 화면에도 같은 안내가 있다)

1. `순간 기록`만 담긴 세트로 바꾼다. 손전등이 계속 켜지는 것을 막는다.
2. 실기기에서 최대한 빠르게 10회 연속 홀드한다. 손에 익도록 몇 세트 반복한다.
3. **화면을 보지 않고 누르는 세트도 따로 잰다.** HIG가 말한 실제 사용 맥락이다.
4. 앱에서 숫자를 읽는다. 10초 넘게 쉬면 다른 묶음으로 나뉜다.
5. CSV로 복사해 기기 밖으로 옮긴다.

**읽는 법**

- **현재 창(2초) 안에 들어온 비율** — 낮을수록 진단이 맞다는 뜻이다.
- **순환 인정 횟수** — 0이면 실기기에서 본 증상이 그대로 재현된 것이다.
- **제안 창** — 가장 느렸던 간격 + 0.5초를 0.5초 단위로 올린 값.
  중앙값이 아니라 최대값을 쓴다. 놓친 누름은 불편이 아니라 **원치 않는 액션의 실행**이다.
- **`perform()` 소요** — 이 값이 크면 위에 적은 두 번째 원인이다.

**이 값으로 정할 것**

- `cycleWindow` — 중앙값이 아니라 **상위 구간을 덮는 값**이어야 한다.
  놓친 누름은 원치 않는 액션 실행으로 이어지므로 관대한 쪽이 안전하다.
- 자동 확정 지연을 창과 분리할지. 지금은 같은 상수를 쓴다.
  창이 6초가 되면 확정도 6초를 기다려야 해서 체감이 나빠진다.
- 실측 간격이 3초를 넘는다면, 상수 조정으로는 답이 안 나온다는 신호다.
  **누를 때마다 즉시 실행하고 다음으로 회전하는 모델**을 검토해야 한다 —
  지연이 사라지고 액션 버튼 규칙과 충돌하지 않는다.

---

## 참고 링크

**공식**

- [WWDC24 — Extend your app's controls across the system](https://developer.apple.com/videos/play/wwdc2024/10157/)
- [HIG — Action button](https://developer.apple.com/design/human-interface-guidelines/action-button)
- [Apple 사용 설명서 — 액션 버튼 사용 및 사용자화](https://support.apple.com/guide/iphone/use-and-customize-the-action-button-iphe89d61d66/ios)

**커뮤니티 · 블로그**

- [MacStories — Introducing MultiButton](https://www.macstories.net/ios/introducing-multibutton-assign-two-shortcuts-to-the-same-action-button-press-on-iphone-15-pro/)
- [9to5Mac — Why Apple made the right call requiring a press and hold](https://9to5mac.com/2023/09/26/iphone-15-pro-action-button-press-and-hold/)
- [9to5Mac — How to double the power of the new Action button](https://9to5mac.com/2023/09/28/iphone-15-pro-how-to-double-the-power-of-the-new-action-button/)
- [MacRumors — Assign two functions to the Action button](https://www.macrumors.com/how-to/iphone-15-pro-assign-two-shortcuts-action-button/)
- [XDA — Action button on iPhone: a guide](https://www.xda-developers.com/action-button-iphone-guide/)
- [Apple 커뮤니티 — 두 번 눌러야 동작한다는 보고](https://discussions.apple.com/thread/255806709) (신뢰도 낮음)

import AppIntents
import Foundation

/// 액션 버튼 한 번.
///
/// 같은 인텐트가 다섯 곳에서 실행된다 — 액션 버튼, 제어 센터, 잠금화면 컨트롤,
/// Live Activity 안의 버튼, 단축어/Siri. `LiveActivityIntent`를 채택했기 때문에
/// 앱이 전면에 없어도 Live Activity를 시작할 수 있다.
struct CuePressIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cue 누르기"
    static let description = IntentDescription("현재 세트의 다음 액션으로 순환하고, 손을 떼면 실행합니다.")
    static let isDiscoverable = true
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await CueEngine.press()
        return .result()
    }
}

/// 액션 스트립의 항목 하나를 탭했을 때.
///
/// 첫 탭은 선택을 그 항목으로 옮기고 2초 창을 다시 연다. 같은 항목을 한 번 더 탭하면
/// 기다리지 않고 바로 확정된다 — Live Activity의 버튼은 단일 탭만 전달되므로,
/// 더블 탭은 `CueEngine`에서 두 번의 단일 탭으로 판별한다.
///
/// 인덱스가 아니라 **액션 식별자**를 실어 나른다. 카드는 만들어진 시점의 스냅샷이라,
/// 그 사이 세트가 바뀌면 같은 인덱스가 다른 액션을 가리킨다 — 보이는 것과 다른 것이
/// 실행되는 일을 막는다.
struct CueSelectIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cue 항목 선택"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "액션 식별자")
    var actionID: String

    init() {}

    init(actionID: String) {
        self.actionID = actionID
    }

    func perform() async throws -> some IntentResult {
        await CueEngine.tapItem(actionID: actionID)
        return .result()
    }
}

/// 대기 없이 즉시 실행.
struct CueConfirmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "선택한 액션 실행"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await CueEngine.commit()
        return .result()
    }
}

/// 실행하지 않고 닫기.
struct CueCancelIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cue 취소"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await CueEngine.cancel()
        return .result()
    }
}

/// 다음 액션 세트로 전환. 제어 센터의 두 번째 컨트롤용.
struct CueNextSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "다음 Cue 세트"
    static let description = IntentDescription("액션 버튼이 순환할 액션 묶음을 바꿉니다.")
    static let isDiscoverable = true
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await CueEngine.nextSet()
        return .result()
    }
}

// 결과 화면의 "열기"는 인텐트가 아니라 딥링크다.
//
// 예전에는 `openAppWhenRun = true`인 `CueOpenAppIntent`·`CueOpenURLIntent`를 카드의 버튼에
// 걸었다. 동작하지 않는다 — Apple DTS는 "Live Activity로는 앱을 열 수 없다. LiveActivityIntent는
// 백그라운드 실행용으로 설계됐고 이는 의도된 설계다"라고 답했고, `openAppWhenRun` 자체도
// iOS 26에서 deprecated다. 공식 경로인 `widgetURL`·`Link`로 옮기고 두 인텐트는 지웠다.
// `CueOpenTarget.deepLink`와 `CueDeepLink` 참조.

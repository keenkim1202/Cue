import AppIntents
import Foundation

/// 액션 버튼 한 번.
///
/// 같은 인텐트가 다섯 곳에서 실행된다 — 액션 버튼, 제어 센터, 잠금화면 컨트롤,
/// Live Activity 안의 버튼, 단축어/Siri. `LiveActivityIntent`를 채택했기 때문에
/// 앱이 전면에 없어도 Live Activity를 시작할 수 있다.
struct CuePressIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cue 누르기"
    static var description = IntentDescription("현재 세트의 다음 액션으로 순환하고, 손을 떼면 실행합니다.")
    static var isDiscoverable = true
    static var openAppWhenRun = false

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
struct CueSelectIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cue 항목 선택"
    static var isDiscoverable = false
    static var openAppWhenRun = false

    @Parameter(title: "항목 번호")
    var index: Int

    init() {}

    init(index: Int) {
        self.index = index
    }

    func perform() async throws -> some IntentResult {
        await CueEngine.tapItem(at: index)
        return .result()
    }
}

/// 대기 없이 즉시 실행.
struct CueConfirmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "선택한 액션 실행"
    static var isDiscoverable = false
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await CueEngine.commit()
        return .result()
    }
}

/// 실행하지 않고 닫기.
struct CueCancelIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cue 취소"
    static var isDiscoverable = false
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await CueEngine.cancel()
        return .result()
    }
}

/// 다음 액션 세트로 전환. 제어 센터의 두 번째 컨트롤용.
struct CueNextSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "다음 Cue 세트"
    static var description = IntentDescription("액션 버튼이 순환할 액션 묶음을 바꿉니다.")
    static var isDiscoverable = true
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await CueEngine.nextSet()
        return .result()
    }
}

/// 결과 화면의 "열기" 버튼.
///
/// `LiveActivityIntent`는 앱을 전면으로 못 올린다. 반대로 `openAppWhenRun = true`인 인텐트는
/// 앱을 열 수 있지만 Live Activity를 시작할 수 없다. 하나의 인텐트가 둘 다 할 수 없어서,
/// 액션 실행은 백그라운드에서 끝내고 **여는 것만** 이 인텐트가 맡는다.
struct CueOpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Cue에서 앱 열기"
    static var isDiscoverable = false
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // 앱이 떴으면 카드는 쓸모가 없다.
        await CueEngine.presenter.endAll()
        return .result()
    }
}

/// 단축어 앱과 액션 버튼 설정 화면에 노출시킨다.
struct CueShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CuePressIntent(),
            phrases: ["\(.applicationName) 누르기", "\(.applicationName) 실행"],
            shortTitle: "Cue 누르기",
            systemImageName: "button.horizontal.top.press"
        )
        AppShortcut(
            intent: CueNextSetIntent(),
            phrases: ["\(.applicationName) 세트 바꾸기"],
            shortTitle: "다음 세트",
            systemImageName: "square.stack.3d.up"
        )
    }
}

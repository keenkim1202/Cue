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

/// 결과 화면의 "열기" 버튼.
///
/// `LiveActivityIntent`는 앱을 전면으로 못 올린다. 반대로 `openAppWhenRun = true`인 인텐트는
/// 앱을 열 수 있지만 Live Activity를 시작할 수 없다. 하나의 인텐트가 둘 다 할 수 없어서,
/// 액션 실행은 백그라운드에서 끝내고 **여는 것만** 이 인텐트가 맡는다.
struct CueOpenAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Cue에서 앱 열기"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // 앱이 떴으면 카드는 쓸모가 없다.
        await CueEngine.presenter.endAll()
        return .result()
    }
}

/// 결과 화면의 "열기" 버튼 — 링크 판.
///
/// `OpenURLIntent`는 **https 링크만** 연다. 커스텀 스킴은 열리지 않는다
/// (Apple 개발자 포럼 762586). 유니버설 링크라면 해당 앱이, 아니면 Safari가 뜬다.
///
/// 검증은 `CueURL.openable`로 통일한다 — 실행 쪽과 여는 쪽이 따로 판단하면 어긋난다.
struct CueOpenURLIntent: AppIntent {
    static let title: LocalizedStringResource = "Cue에서 링크 열기"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "주소")
    var urlString: String

    init() {}

    init(urlString: String) {
        self.urlString = urlString
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = CueURL.openable(urlString) else {
            throw CueIntentError.unopenableURL(urlString)
        }
        await CueEngine.presenter.endAll()
        return .result(opensIntent: OpenURLIntent(url))
    }
}

enum CueIntentError: Error, CustomLocalizedStringResourceConvertible {
    case unopenableURL(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unopenableURL(let raw):
            return "열 수 없는 주소입니다: \(raw)"
        }
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

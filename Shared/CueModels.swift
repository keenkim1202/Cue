import Foundation

// MARK: - Action

/// 액션 버튼 한 번에 실행될 수 있는 단위 동작.
struct CueAction: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var symbol: String
    var kind: Kind
    /// `.openURL`일 때만 쓰인다. https 링크만 열 수 있다 (커스텀 스킴은 `OpenURLIntent`가 거부한다).
    var urlString: String

    init(id: UUID = UUID(), title: String, symbol: String, kind: Kind, urlString: String = "https://") {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.kind = kind
        self.urlString = urlString
    }

    /// 백그라운드 인텐트 프로세스에서 실제로 수행 가능한 동작만 담는다.
    /// 시스템 카메라 실행이나 무음 전환처럼 서드파티 앱에 API가 없는 동작은 넣지 않았다.
    enum Kind: String, Codable, Hashable, CaseIterable {
        /// 손전등 토글. 토치가 없는 기기·시뮬레이터에서는 실패로 기록된다.
        case torch
        /// 지금 시각을 로그에 남긴다.
        case mark
        /// 스톱워치 시작 / 정지 토글.
        case stopwatch
        /// 앱을 전면으로 띄운다.
        case openApp
        /// https 링크를 연다.
        case openURL

        var label: String {
            switch self {
            case .torch: return String(localized: "손전등 토글")
            case .mark: return String(localized: "순간 기록")
            case .stopwatch: return String(localized: "스톱워치")
            case .openApp: return String(localized: "앱 열기")
            case .openURL: return String(localized: "링크 열기")
            }
        }

        var defaultSymbol: String {
            switch self {
            case .torch: return "flashlight.on.fill"
            case .mark: return "mappin.and.ellipse"
            case .stopwatch: return "stopwatch"
            case .openApp: return "arrow.up.forward.app"
            case .openURL: return "safari"
            }
        }
    }
}

/// 결과 카드에 붙는 "열기" 버튼이 무엇을 여는지.
///
/// 백그라운드 인텐트는 앱도 링크도 열 수 없다. 여는 것은 항상 사용자의 탭 한 번을 거친다.
enum CueOpenTarget: Codable, Hashable {
    case app
    case url(String)
}

// MARK: - Set

/// 액션 버튼 한 번에 순환될 액션들의 묶음.
struct CueSet: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var actions: [CueAction]

    init(id: UUID = UUID(), name: String, actions: [CueAction]) {
        self.id = id
        self.name = name
        self.actions = actions
    }
}

// MARK: - Config

struct CueConfig: Codable, Equatable {
    var sets: [CueSet]
    var activeSetID: UUID

    var activeSet: CueSet {
        sets.first { $0.id == activeSetID } ?? sets[0]
    }

    /// 첫 실행용 기본 구성.
    ///
    /// 식별자를 **고정**해 둔다. 앱과 위젯 확장이 각자 시드를 만들어도 같은 id를 갖게 하려는 것이다.
    /// `UUID()`로 매번 새로 만들면 카드에 찍힌 액션 id가 다른 프로세스에서 안 맞아
    /// 항목 탭이 조용히 무시된다.
    static var seed: CueConfig {
        func id(_ suffix: String) -> UUID {
            UUID(uuidString: "00000000-0000-4000-8000-0000000000\(suffix)")!
        }
        let basic = CueSet(id: id("01"), name: String(localized: "기본"), actions: [
            CueAction(id: id("11"), title: String(localized: "손전등"), symbol: "flashlight.on.fill", kind: .torch),
            CueAction(id: id("12"), title: String(localized: "순간 기록"), symbol: "mappin.and.ellipse", kind: .mark),
            CueAction(id: id("13"), title: String(localized: "스톱워치"), symbol: "stopwatch", kind: .stopwatch),
            CueAction(id: id("14"), title: String(localized: "앱 열기"), symbol: "arrow.up.forward.app", kind: .openApp)
        ])
        let night = CueSet(id: id("02"), name: String(localized: "야간"), actions: [
            CueAction(id: id("21"), title: String(localized: "순간 기록"), symbol: "moon.stars", kind: .mark),
            CueAction(id: id("22"), title: String(localized: "손전등"), symbol: "flashlight.on.fill", kind: .torch)
        ])
        return CueConfig(sets: [basic, night], activeSetID: basic.id)
    }
}

// MARK: - Runtime state

/// 순환 중인 누름 상태. 액션 버튼 누름은 매번 별개의 인텐트 실행이므로
/// "직전에 눌렸는지"를 판단할 근거를 App Group에 남겨야 한다.
struct CueState: Codable, Equatable {
    var selectedIndex: Int = 0
    var lastPressAt: Date = .distantPast
    /// 누름마다 증가. 커밋 시점에 값이 그대로인지 확인해 "더 눌렸는지"를 판별한다.
    var generation: Int = 0
    var isArmed: Bool = false
    /// 마지막 입력이 항목 직접 탭이었는지. 같은 항목을 연달아 탭한 것을
    /// 더블 탭으로 볼지 판단하는 데 쓴다. 액션 버튼 순환은 여기에 해당하지 않는다.
    var lastInputWasItemTap: Bool = false

    static let empty = CueState()
}

// MARK: - Log

struct CueLogEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var at: Date
    var actionTitle: String
    var detail: String
    var succeeded: Bool
}

// MARK: - Stopwatch

struct CueStopwatch: Codable, Equatable {
    var startedAt: Date?

    var isRunning: Bool { startedAt != nil }

    static let idle = CueStopwatch(startedAt: nil)
}

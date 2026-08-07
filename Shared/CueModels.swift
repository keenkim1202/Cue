import Foundation

// MARK: - Action

/// 액션 버튼 한 번에 실행될 수 있는 단위 동작.
struct CueAction: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var symbol: String
    var kind: Kind

    init(id: UUID = UUID(), title: String, symbol: String, kind: Kind) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.kind = kind
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

        var label: String {
            switch self {
            case .torch: return "손전등 토글"
            case .mark: return "순간 기록"
            case .stopwatch: return "스톱워치"
            case .openApp: return "앱 열기"
            }
        }

        var defaultSymbol: String {
            switch self {
            case .torch: return "flashlight.on.fill"
            case .mark: return "mappin.and.ellipse"
            case .stopwatch: return "stopwatch"
            case .openApp: return "arrow.up.forward.app"
            }
        }
    }
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

struct CueConfig: Codable {
    var sets: [CueSet]
    var activeSetID: UUID

    var activeSet: CueSet {
        sets.first { $0.id == activeSetID } ?? sets[0]
    }

    static var seed: CueConfig {
        let basic = CueSet(name: "기본", actions: [
            CueAction(title: "손전등", symbol: "flashlight.on.fill", kind: .torch),
            CueAction(title: "순간 기록", symbol: "mappin.and.ellipse", kind: .mark),
            CueAction(title: "스톱워치", symbol: "stopwatch", kind: .stopwatch),
            CueAction(title: "앱 열기", symbol: "arrow.up.forward.app", kind: .openApp)
        ])
        let night = CueSet(name: "야간", actions: [
            CueAction(title: "순간 기록", symbol: "moon.stars", kind: .mark),
            CueAction(title: "손전등", symbol: "flashlight.on.fill", kind: .torch)
        ])
        return CueConfig(sets: [basic, night], activeSetID: basic.id)
    }
}

// MARK: - Runtime state

/// 순환 중인 누름 상태. 액션 버튼 누름은 매번 별개의 인텐트 실행이므로
/// "직전에 눌렸는지"를 판단할 근거를 App Group에 남겨야 한다.
struct CueState: Codable {
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

struct CueStopwatch: Codable {
    var startedAt: Date?

    var isRunning: Bool { startedAt != nil }

    static let idle = CueStopwatch(startedAt: nil)
}

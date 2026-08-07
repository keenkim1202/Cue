import Foundation
@testable import MyAction

/// `CuePresenting`의 테스트 대역. Live Activity 권한·시스템 UI 없이
/// 엔진이 무엇을 보여주려 했는지만 기록한다.
final class SpyPresenter: CuePresenting {
    struct Shown: Equatable {
        var setName: String
        var selectedIndex: Int
    }

    struct Finished: Equatable {
        var phase: CueAttributes.ContentState.Phase
        var resultText: String
        var showsOpenButton: Bool
        var dismissAfter: TimeInterval
    }

    var isEnabled = true
    private(set) var shown: [Shown] = []
    private(set) var finished: [Finished] = []
    private(set) var endAllCount = 0

    func showCycling(set: CueSet, selectedIndex: Int, commitAt: Date) async {
        shown.append(Shown(setName: set.name, selectedIndex: selectedIndex))
    }

    func finish(
        phase: CueAttributes.ContentState.Phase,
        resultText: String,
        showsOpenButton: Bool,
        dismissAfter seconds: TimeInterval
    ) async {
        finished.append(Finished(
            phase: phase,
            resultText: resultText,
            showsOpenButton: showsOpenButton,
            dismissAfter: seconds
        ))
    }

    func endAll() async {
        endAllCount += 1
    }
}

/// 테스트 한 건의 격리된 환경.
///
/// `CueStore`·`CueEngine`은 정적 상태를 쓰므로 스위트를 `.serialized`로 돌리고,
/// 각 테스트가 이 하네스로 저장소와 표시 계층을 갈아끼운다.
@MainActor
final class CueHarness {
    let presenter = SpyPresenter()
    let suiteName = "com.keen.cue.tests"

    /// 실시간으로 기다리지 않도록 창을 짧게 잡는다.
    /// `init`의 기본 인자에서 읽히므로 액터 격리 밖에 둔다.
    nonisolated static let shortWindow: TimeInterval = 0.08
    /// 창이 닫히기를 기다릴 때 쓰는 여유.
    nonisolated static let settle: TimeInterval = 0.12

    private let savedDefaults: UserDefaults
    private let savedPresenter: CuePresenting
    private let savedWindow: TimeInterval

    init(window: TimeInterval = CueHarness.shortWindow, actionKinds: [CueAction.Kind] = [.mark, .mark, .mark, .mark]) {
        savedDefaults = CueStore.defaults
        savedPresenter = CueEngine.presenter
        savedWindow = CueEngine.cycleWindow

        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        CueStore.defaults = defaults
        CueEngine.presenter = presenter
        CueEngine.cycleWindow = window

        // 항목마다 제목이 달라야 무엇이 실행됐는지 로그로 구분할 수 있다.
        let actions = actionKinds.enumerated().map { index, kind in
            CueAction(title: "A\(index)", symbol: kind.defaultSymbol, kind: kind)
        }
        let set = CueSet(name: "테스트", actions: actions)
        CueStore.config = CueConfig(sets: [set], activeSetID: set.id)
        CueStore.state = .empty
        CueStore.clearLog()
        CueStore.stopwatch = .idle
    }

    func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        CueStore.defaults = savedDefaults
        CueEngine.presenter = savedPresenter
        CueEngine.cycleWindow = savedWindow
    }

    // MARK: 편의

    var state: CueState { CueStore.state }
    var log: [CueLogEntry] { CueStore.log }
    var committedTitles: [String] { CueStore.log.map(\.actionTitle) }

    /// 커밋을 기다리지 않고 "무장만" 시킨다.
    /// 실제 액션 버튼 연타처럼, 창이 닫히기 전에 다음 입력을 넣기 위한 것이다.
    @discardableResult
    func pressWithoutWaiting() -> Task<Bool, Never> {
        let task = Task { await CueEngine.press() }
        return task
    }

    @discardableResult
    func tapWithoutWaiting(at index: Int) -> Task<Bool, Never> {
        Task { await CueEngine.tapItem(at: index) }
    }

    /// 무장이 끝날 만큼만 기다린다. 창보다 짧아야 한다.
    func settleArm() async {
        try? await Task.sleep(nanoseconds: 25_000_000)
    }

    /// 창이 닫히고 자동 커밋이 끝날 만큼 기다린다.
    func settleCommit() async {
        try? await Task.sleep(nanoseconds: UInt64(Self.settle * 1_000_000_000))
    }
}

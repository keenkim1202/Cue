import Foundation
@testable import Cue

/// `CuePresenting`의 테스트 대역. Live Activity 권한·시스템 UI 없이
/// 엔진이 무엇을 보여주려 했는지만 기록한다.
/// `CuePresenting`은 `Sendable`이고 `isEnabled`는 동기 요구사항이라, MainActor 격리로는
/// 준수할 수 없다. 테스트 대역이므로 자물쇠 하나로 직접 보호한다.
final class SpyPresenter: CuePresenting, @unchecked Sendable {
    struct Shown: Equatable {
        var setName: String
        var selectedIndex: Int
    }

    struct Finished: Equatable {
        var phase: CueAttributes.ContentState.Phase
        var resultText: String
        var openTarget: CueOpenTarget?
        var dismissAfter: TimeInterval
    }

    struct Notice: Equatable {
        var setName: String
        var text: String
        var dismissAfter: TimeInterval
    }

    private let lock = NSLock()
    private var _isEnabled = true
    private var _shown: [Shown] = []
    private var _finished: [Finished] = []
    private var _notices: [Notice] = []
    private var _endAllCount = 0

    var isEnabled: Bool {
        get { lock.withLock { _isEnabled } }
        set { lock.withLock { _isEnabled = newValue } }
    }

    var shown: [Shown] { lock.withLock { _shown } }
    var finished: [Finished] { lock.withLock { _finished } }
    var notices: [Notice] { lock.withLock { _notices } }
    var endAllCount: Int { lock.withLock { _endAllCount } }

    func showCycling(set: CueSet, selectedIndex: Int, commitAt: Date) async {
        lock.withLock { _shown.append(Shown(setName: set.name, selectedIndex: selectedIndex)) }
    }

    func finish(
        phase: CueAttributes.ContentState.Phase,
        resultText: String,
        openTarget: CueOpenTarget?,
        dismissAfter seconds: TimeInterval
    ) async {
        lock.withLock {
            _finished.append(Finished(
                phase: phase,
                resultText: resultText,
                openTarget: openTarget,
                dismissAfter: seconds
            ))
        }
    }

    func showNotice(setName: String, text: String, dismissAfter seconds: TimeInterval) async {
        lock.withLock {
            _notices.append(Notice(setName: setName, text: text, dismissAfter: seconds))
        }
    }

    func endAll() async {
        lock.withLock { _endAllCount += 1 }
    }
}

/// `CueCommitScheduling`의 테스트 대역.
///
/// 실제 예약은 잡지 않고 generation만 들고 있다가, 테스트가 `fire()`로 깨운다.
/// 창이 닫히기를 실시간으로 기다리지 않으려는 것 — 그리고 "예약이 걸렸는가"와
/// "예약이 실행됐는가"를 따로 단언할 수 있게 하려는 것이다.
final class SpyScheduler: CueCommitScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var _pending: Int?
    private var _scheduleCount = 0
    private var _cancelCount = 0

    /// 예약이 걸려 있으면 그 generation.
    var pendingGeneration: Int? { lock.withLock { _pending } }
    var scheduleCount: Int { lock.withLock { _scheduleCount } }
    var cancelCount: Int { lock.withLock { _cancelCount } }

    func schedule(after seconds: TimeInterval, generation: Int) {
        lock.withLock {
            _pending = generation
            _scheduleCount += 1
        }
    }

    func cancel() {
        lock.withLock {
            _pending = nil
            _cancelCount += 1
        }
    }

    /// 창이 닫힌 것처럼 예약된 커밋을 깨운다. 예약이 없으면 아무 일도 없다.
    @MainActor
    func fire() async {
        guard let generation = lock.withLock({ _pending }) else { return }
        await CueEngine.commitIfCurrent(generation: generation)
    }
}

/// 테스트 한 건의 격리된 환경.
///
/// `CueStore`·`CueEngine`은 정적 상태를 쓰므로 스위트를 `.serialized`로 돌리고,
/// 각 테스트가 이 하네스로 저장소와 표시 계층을 갈아끼운다.
@MainActor
final class CueHarness {
    let presenter = SpyPresenter()
    let scheduler = SpyScheduler()
    let suiteName = "com.keen.cue.tests"

    /// 실시간으로 기다리지 않도록 창을 짧게 잡는다.
    /// `init`의 기본 인자에서 읽히므로 액터 격리 밖에 둔다.
    nonisolated static let shortWindow: TimeInterval = 0.08
    /// 창이 닫히기를 기다릴 때 쓰는 여유.
    nonisolated static let settle: TimeInterval = 0.12

    private let savedDefaults: UserDefaults
    private let savedPresenter: CuePresenting
    private let savedScheduler: CueCommitScheduling
    private let savedWindow: TimeInterval

    init(window: TimeInterval = CueHarness.shortWindow, actionKinds: [CueAction.Kind] = [.mark, .mark, .mark, .mark]) {
        savedDefaults = CueStore.defaults
        savedPresenter = CueEngine.presenter
        savedScheduler = CueEngine.scheduler
        savedWindow = CueEngine.cycleWindow

        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        CueStore.defaults = defaults
        CueEngine.presenter = presenter
        CueEngine.scheduler = scheduler
        CueEngine.cycleWindow = window

        // 항목마다 제목이 달라야 무엇이 실행됐는지 로그로 구분할 수 있다.
        let actions = actionKinds.enumerated().map { index, kind in
            CueAction(title: "A\(index)", symbol: kind.defaultSymbol, kind: kind,
                      urlString: "https://example.com/\(index)")
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
        CueEngine.scheduler = savedScheduler
        CueEngine.cycleWindow = savedWindow
    }

    // MARK: 편의

    var state: CueState { CueStore.state }
    var log: [CueLogEntry] { CueStore.log }
    var committedTitles: [String] { CueStore.log.map(\.actionTitle) }

    /// 누른 뒤 창이 닫힌 것처럼 예약된 커밋까지 실행한다.
    ///
    /// `press()`는 이제 예약만 걸고 즉시 돌아온다 — 액션 버튼이 앞선 인텐트 실행 중에는
    /// 다음 누름을 전달하지 않기 때문이다. 그래서 "눌렀더니 실행됐다"를 보려면
    /// 창이 닫히는 것까지 여기서 대신 해줘야 한다.
    func pressAndCommit() async {
        await CueEngine.press()
        await scheduler.fire()
    }

    /// 탭한 뒤 창이 닫힌 것처럼 예약된 커밋까지 실행한다.
    func tapAndCommit(at index: Int) async {
        await CueEngine.tapItem(actionID: actionID(at: index))
        await scheduler.fire()
    }

    /// 커밋을 기다리지 않고 "무장만" 시킨다.
    /// 실제 액션 버튼 연타처럼, 창이 닫히기 전에 다음 입력을 넣기 위한 것이다.
    @discardableResult
    func pressWithoutWaiting() -> Task<Bool, Never> {
        let task = Task { await CueEngine.press() }
        return task
    }

    @discardableResult
    func tapWithoutWaiting(at index: Int) -> Task<Bool, Never> {
        let id = actionID(at: index)
        return Task { await CueEngine.tapItem(actionID: id) }
    }

    /// 세트의 index번째 액션 식별자. 탭은 인덱스가 아니라 이 값으로 전달된다.
    func actionID(at index: Int) -> String {
        let actions = CueStore.activeSet.actions
        guard actions.indices.contains(index) else { return UUID().uuidString }
        return actions[index].id.uuidString
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

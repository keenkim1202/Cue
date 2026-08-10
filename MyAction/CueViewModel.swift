import Combine
import SwiftUI

/// App Group 저장소를 화면에 물려 주는 얇은 래퍼.
/// 상태의 SoT는 `CueStore`이고, 이 객체는 그것을 다시 읽어 뿌리기만 한다.
@MainActor
final class CueViewModel: ObservableObject {
    @Published private(set) var config: CueConfig
    @Published private(set) var state: CueState
    @Published private(set) var log: [CueLogEntry]
    @Published private(set) var stopwatch: CueStopwatch

    private var ticker: AnyCancellable?

    init() {
        config = CueStore.config
        state = CueStore.state
        log = CueStore.log
        stopwatch = CueStore.stopwatch
    }

    var activeSet: CueSet { config.activeSet }

    /// 순환 창이 아직 열려 있는지.
    var isCycling: Bool {
        state.isArmed && Date().timeIntervalSince(state.lastPressAt) < CueEngine.cycleWindow
    }

    /// 저장소를 다시 읽되 **값이 실제로 달라졌을 때만 발행**한다.
    ///
    /// 폴링은 다른 프로세스(액션 버튼·컨트롤의 인텐트)가 바꾼 상태를 알아채려고 도는 것이다.
    /// 그냥 대입하면 값이 그대로여도 `objectWillChange`가 나가 List 전체가 초당 4회 다시
    /// 그려진다. 조건부 대입이라 유휴 상태에서는 리렌더가 0이 된다.
    func reload() {
        let newConfig = CueStore.config
        if newConfig != config { config = newConfig }

        let newState = CueStore.state
        if newState != state { state = newState }

        let newLog = CueStore.log
        if newLog != log { log = newLog }

        let newStopwatch = CueStore.stopwatch
        if newStopwatch != stopwatch { stopwatch = newStopwatch }
    }

    /// 다른 프로세스가 바꾼 상태를 알아채기 위한 폴링. App Group에는 변경 알림이 없다.
    func startTicking() {
        guard ticker == nil else { return }
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.reload() }
    }

    func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    // MARK: 조작

    func press() {
        Task { @MainActor in
            await CueEngine.press()
            reload()
        }
    }

    /// 액션 스트립 항목 탭. 같은 항목을 두 번 탭하면 즉시 확정된다.
    /// Live Activity의 버튼과 같은 경로를 타므로 동작이 어디서든 동일하다.
    func tapItem(_ action: CueAction) {
        Task { @MainActor in
            await CueEngine.tapItem(actionID: action.id.uuidString)
            reload()
        }
    }

    func nextSet() {
        Task { @MainActor in
            await CueEngine.nextSet()
            reload()
        }
    }

    func selectSet(_ set: CueSet) {
        var updated = CueStore.config
        updated.activeSetID = set.id
        CueStore.config = updated
        // 대기 중인 커밋은 옛 세트의 인덱스를 들고 있다.
        CueEngine.invalidateCycleIfArmed()
        reload()
    }

    func update(_ set: CueSet) {
        var updated = CueStore.config
        guard let index = updated.sets.firstIndex(where: { $0.id == set.id }) else { return }
        updated.sets[index] = set
        CueStore.config = updated
        // 액션을 지우거나 순서를 바꾸면 인덱스가 밀린다.
        CueEngine.invalidateCycleIfArmed()
        reload()
    }

    func addSet() {
        var updated = CueStore.config
        let new = CueSet(name: String(localized: "새 세트 \(updated.sets.count + 1)"), actions: [
            CueAction(title: String(localized: "순간 기록"), symbol: "mappin.and.ellipse", kind: .mark)
        ])
        updated.sets.append(new)
        updated.activeSetID = new.id
        CueStore.config = updated
        reload()
    }

    func deleteSet(_ set: CueSet) {
        var updated = CueStore.config
        guard updated.sets.count > 1 else { return }
        updated.sets.removeAll { $0.id == set.id }
        if updated.activeSetID == set.id {
            updated.activeSetID = updated.sets[0].id
        }
        CueStore.config = updated
        reload()
    }

    func clearLog() {
        CueStore.clearLog()
        reload()
    }

    func resetToSeed() {
        CueStore.config = CueConfig.seed
        CueStore.clearLog()
        CueStore.stopwatch = .idle
        // `.empty`를 그대로 대입하면 generation이 0으로 되돌아간다.
        CueStore.clearRuntimeState()
        Task { await CueEngine.presenter.endAll() }
        reload()
    }
}

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

    func reload() {
        config = CueStore.config
        state = CueStore.state
        log = CueStore.log
        stopwatch = CueStore.stopwatch
    }

    /// 순환 중에는 화면도 같이 움직여야 하므로 잠깐 동안만 자주 갱신한다.
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
    func tapItem(at index: Int) {
        Task { @MainActor in
            await CueEngine.tapItem(at: index)
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
        reload()
    }

    func update(_ set: CueSet) {
        var updated = CueStore.config
        guard let index = updated.sets.firstIndex(where: { $0.id == set.id }) else { return }
        updated.sets[index] = set
        CueStore.config = updated
        reload()
    }

    func addSet() {
        var updated = CueStore.config
        let new = CueSet(name: "새 세트 \(updated.sets.count + 1)", actions: [
            CueAction(title: "순간 기록", symbol: "mappin.and.ellipse", kind: .mark)
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
        CueStore.state = .empty
        Task { await CueEngine.presenter.endAll() }
        reload()
    }
}

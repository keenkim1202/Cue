import Foundation

/// 순환 창이 닫힌 뒤의 커밋을 예약하는 창구.
///
/// **왜 인텐트 밖으로 뺐나.** 예전에는 `perform()` 안에서 `Task.sleep(2s)`으로 기다렸다.
/// 시간 예산은 문제가 아니었다 — App Intents는 30초를 준다. 문제는 **재진입**이다.
/// 액션 버튼은 앞선 실행이 끝나기 전에는 다음 누름을 전달하지 않는다(문서화되지 않은 동작이지만
/// 널리 확인돼 있다). 2초를 붙잡고 있으면 그 2초 안의 누름이 전부 시스템에서 버려져,
/// 카드가 뜨는 것까지만 되고 순환도 자동 실행도 죽는다.
///
/// 그래서 인텐트는 상태를 쓰고 카드를 띄운 뒤 **즉시 반환**하고, 커밋은 이쪽이 맡는다.
protocol CueCommitScheduling: Sendable {
    /// `seconds` 뒤에 커밋을 예약한다. 앞선 예약은 버린다.
    ///
    /// - Parameter generation: 예약 시점의 무효화 토큰. 깨어났을 때 값이 달라져 있으면
    ///   그 사이 다른 입력이 있었다는 뜻이므로 커밋하지 않는다.
    func schedule(after seconds: TimeInterval, generation: Int)

    /// 예약을 버린다. 이미 확정됐거나 구성이 바뀌었을 때.
    func cancel()
}

/// 실행 시간을 따로 확보하지 않는 기본 구현.
///
/// 앱이 전면에 있을 때는 이것으로 충분하다. 백그라운드에서는 프로세스가 정지되면 그대로
/// 사라진다 — 앱 타깃이 시작 시 `UIApplication.beginBackgroundTask`를 쓰는 구현으로
/// 갈아끼운다(`CueBackgroundCommitScheduler`). 위젯 확장에는 그 API가 없으므로 여기에 둘 수 없다.
final class CueDetachedCommitScheduler: CueCommitScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: Task<Void, Never>?

    func schedule(after seconds: TimeInterval, generation: Int) {
        let task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await CueEngine.commitIfCurrent(generation: generation)
        }
        replace(with: task)
    }

    func cancel() {
        replace(with: nil)
    }

    private func replace(with task: Task<Void, Never>?) {
        let previous = lock.withLock {
            let old = pending
            pending = task
            return old
        }
        previous?.cancel()
    }
}

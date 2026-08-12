import Foundation
import UIKit

/// 백그라운드 실행 시간을 확보한 뒤 커밋을 예약한다. **앱 타깃 전용** —
/// `UIApplication`은 앱 확장에서 쓸 수 없어 `Shared/`에 둘 수 없다.
///
/// 인텐트가 반환되면 앱 프로세스는 곧 정지될 수 있다. `beginBackgroundTask`로 유예를 요청해
/// 2초 뒤의 커밋까지 살아 있게 한다. 유예 시각은 iOS가 정하며 **보장은 아니다** — 만료되면
/// 예약을 버릴 뿐 뒤늦게 실행하지 않는다. 사용자가 잊은 뒤에 손전등이 켜지는 편보다 낫다.
///
/// 예약을 걸기 전에 assertion을 **동기적으로** 잡는 것이 핵심이다. `Task`를 띄운 뒤에 잡으면
/// 그 사이에 프로세스가 정지될 수 있다.
final class CueBackgroundCommitScheduler: CueCommitScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: Task<Void, Never>?
    private var assertion: UIBackgroundTaskIdentifier = .invalid
    /// 이미 놓아 준 유예. 취소와 작업 종료가 같은 것을 두 번 끝내지 않게 한다.
    private var finished: Set<UIBackgroundTaskIdentifier> = []

    func schedule(after seconds: TimeInterval, generation: Int) {
        cancel()

        let assertion = UIApplication.shared.beginBackgroundTask(withName: "cue.commit") { [weak self] in
            // 유예가 끝났다. 실행하지 않고 물러난다.
            self?.cancel()
        }

        // 자기 assertion만 끝내야 한다. 그냥 "현재 assertion"을 끝내면, 이 예약이 취소된 뒤
        // 뒤늦게 깨어나 **다음 예약의** 유예를 끊어 버린다.
        let task = Task { @MainActor in
            defer { self.end(assertion) }
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await CueEngine.commitIfCurrent(generation: generation)
        }

        lock.withLock {
            self.assertion = assertion
            self.pending = task
        }
    }

    func cancel() {
        let (previous, assertion): (Task<Void, Never>?, UIBackgroundTaskIdentifier) = lock.withLock {
            let task = pending
            let identifier = self.assertion
            pending = nil
            self.assertion = .invalid
            return (task, identifier)
        }
        previous?.cancel()
        end(assertion)
    }

    /// 이 식별자의 유예만 놓는다. 두 번 불려도 안전하다.
    private func end(_ identifier: UIBackgroundTaskIdentifier) {
        guard identifier != .invalid else { return }
        let shouldEnd = lock.withLock { () -> Bool in
            if assertion == identifier { assertion = .invalid }
            return finished.insert(identifier).inserted
        }
        guard shouldEnd else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }
}

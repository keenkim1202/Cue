import ActivityKit
import Foundation

/// Live Activity 하나를 만들고 갱신하고 끝낸다. 동시에 두 개가 뜨지 않도록 항상 재사용한다.
struct CueLiveActivityController: CuePresenting {
    /// **살아 있는** 카드만 센다.
    ///
    /// `end(_:dismissalPolicy:)`로 끝낸 액티비티는 화면에서 치워질 때까지 `activities`에 남아
    /// 있고, 그 상태에서 `update(_:)`는 조용히 무시된다. 예전에는 상태를 보지 않고 첫 번째를
    /// 집었다 — 결과 카드가 남아 있는 동안 들어온 누름이 갱신도 생성도 되지 않아 다이나믹
    /// 아일랜드에 아무것도 뜨지 않았다. "앱 열기"처럼 `openPromptLinger`가 붙는 액션 뒤에는
    /// 그 구간이 20초였다. 액션은 실행되는데 화면만 비는, 가장 알아채기 어려운 형태였다.
    private var current: Activity<CueAttributes>? {
        Activity<CueAttributes>.activities.first { $0.activityState == .active }
    }

    var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func showCycling(set: CueSet, selectedIndex: Int, commitAt: Date) async {
        let state = CueAttributes.ContentState(
            setName: set.name,
            items: set.actions.map { .init(id: $0.id.uuidString, title: $0.title, symbol: $0.symbol) },
            selectedIndex: selectedIndex,
            phase: .cycling,
            resultText: nil,
            commitAt: commitAt
        )

        if let activity = current {
            await activity.update(ActivityContent(state: state, staleDate: commitAt.addingTimeInterval(30)))
            return
        }

        _ = await start(state: state, staleDate: commitAt.addingTimeInterval(30))
    }

    func showNotice(setName: String, text: String, dismissAfter seconds: TimeInterval) async {
        let state = CueAttributes.ContentState(
            setName: setName,
            items: [],
            selectedIndex: 0,
            phase: .executed,
            resultText: text,
            commitAt: nil
        )
        let content = ActivityContent(state: state, staleDate: nil)
        let dismissal = ActivityUIDismissalPolicy.after(Date().addingTimeInterval(seconds))

        // 순환 중이었다면 그 카드를 이 내용으로 마무리한다.
        if let activity = current {
            await activity.end(content, dismissalPolicy: dismissal)
            return
        }

        guard let activity = await start(state: state, staleDate: nil) else { return }
        await activity.end(content, dismissalPolicy: dismissal)
    }

    func finish(
        phase: CueAttributes.ContentState.Phase,
        resultText: String,
        openTarget: CueOpenTarget?,
        dismissAfter seconds: TimeInterval
    ) async {
        guard let activity = current else { return }

        var state = activity.content.state
        state.phase = phase
        state.resultText = resultText
        state.commitAt = nil
        state.openTarget = openTarget

        // 여기서 기다리지 않는다. `end(_:dismissalPolicy:)`가 내용을 함께 갱신하고,
        // 화면에서 치우는 시점은 시스템에 맡긴다. 백그라운드 인텐트를 붙잡아 둘 이유가 없다.
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(seconds))
        )
    }

    func endAll() async {
        for activity in Activity<CueAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: 시작

    /// 새 카드를 띄운다. 끝났지만 아직 화면에 남아 있는 카드는 먼저 치운다 —
    /// 그러지 않으면 결과 카드와 새 순환 카드가 두 장 겹친다.
    private func start(state: CueAttributes.ContentState, staleDate: Date?) async -> Activity<CueAttributes>? {
        guard isEnabled else { return nil }
        await dismissLingering()

        // 남은 카드를 치우는 동안 이 함수가 멈춰 있었다. 그 사이 다음 누름이 먼저 카드를
        // 만들었을 수 있다 — 확인하지 않고 요청하면 두 장이 뜨고, 나중의 finish()는 그중
        // 하나만 끝내서 나머지가 순환 상태로 남는다. 이미 있으면 그것을 갱신해 재사용한다.
        if let activity = current {
            await activity.update(ActivityContent(state: state, staleDate: staleDate))
            return activity
        }

        do {
            return try Activity.request(
                attributes: CueAttributes(sessionName: "cue"),
                content: ActivityContent(state: state, staleDate: staleDate),
                pushType: nil
            )
        } catch {
            print("[Cue] Live Activity 시작 실패: \(error)")
            return nil
        }
    }

    /// 이미 끝났는데 해제 시각을 기다리며 남아 있는 카드를 즉시 치운다.
    private func dismissLingering() async {
        for activity in Activity<CueAttributes>.activities where activity.activityState != .active {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

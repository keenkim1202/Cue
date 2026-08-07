import ActivityKit
import Foundation

/// Live Activity 하나를 만들고 갱신하고 끝낸다. 동시에 두 개가 뜨지 않도록 항상 재사용한다.
struct CueLiveActivityController: CuePresenting {
    private var current: Activity<CueAttributes>? {
        Activity<CueAttributes>.activities.first
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

        guard isEnabled else { return }
        do {
            _ = try Activity.request(
                attributes: CueAttributes(sessionName: "cue"),
                content: ActivityContent(state: state, staleDate: commitAt.addingTimeInterval(30)),
                pushType: nil
            )
        } catch {
            print("[Cue] Live Activity 시작 실패: \(error)")
        }
    }

    func finish(
        phase: CueAttributes.ContentState.Phase,
        resultText: String,
        showsOpenButton: Bool,
        dismissAfter seconds: TimeInterval
    ) async {
        guard let activity = current else { return }

        var state = activity.content.state
        state.phase = phase
        state.resultText = resultText
        state.commitAt = nil
        state.showsOpenButton = showsOpenButton

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
}

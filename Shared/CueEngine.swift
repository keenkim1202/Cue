import Foundation

/// Cue의 핵심 상태 기계.
///
/// 액션 버튼 누름은 매번 **별개의 인텐트 실행**이다. 따라서
/// "직전 누름으로부터 얼마나 지났는지"를 App Group에 남긴 값으로 판단한다.
///
/// - 첫 누름: 0번 항목 선택 + Live Activity 시작
/// - 창(window) 안의 추가 누름: 다음 항목으로 순환
///
/// 확정되는 경로는 두 가지다.
/// - **2초 방치**: 창이 지나면 선택된 항목이 자동 실행된다.
/// - **항목 더블 탭**: Live Activity·다이나믹 아일랜드·앱의 액션 스트립에서 같은 항목을
///   두 번 탭하면 기다리지 않고 그 항목으로 확정된다. 첫 탭은 선택을 옮기고 창을 다시 연다.
///
/// 커밋 대기는 `perform()` 안에서 `Task.sleep`으로 기다린다. 인텐트가 반환되면
/// 프로세스가 곧 정지될 수 있으므로, 반환을 늦춰 실행 시점까지 살려 두는 것이다.
@MainActor
enum CueEngine {
    /// 다음 입력을 기다리는 시간. 이 시간이 지나면 선택된 항목이 실행된다.
    /// 같은 항목의 두 번째 탭을 더블 탭으로 인정하는 창도 같다 —
    /// 이보다 늦은 탭은 이미 자동 실행이 끝난 뒤이므로 구분할 의미가 없다.
    ///
    /// `var`인 것은 테스트가 창을 짧게 줄여 실시간으로 기다리지 않게 하려는 것뿐이다.
    /// 앱에서 바꾸지 않는다.
    static var cycleWindow: TimeInterval = 2.0

    /// 상태를 바깥에 보여주는 창구. 테스트에서만 교체한다.
    static var presenter: CuePresenting = CueLiveActivityController()

    /// 실행 결과를 보여주고 치우기까지의 시간.
    static let resultLinger: TimeInterval = 2.5
    /// "열기" 버튼이 붙은 결과는 사용자가 탭할 틈이 있어야 하므로 더 오래 남긴다.
    static let openPromptLinger: TimeInterval = 20

    /// 액션 버튼 · 컨트롤 · 앱 내 테스트 버튼이 모두 이 하나를 호출한다.
    /// 창이 열려 있으면 다음 항목으로, 아니면 처음부터.
    /// - Returns: 결과 화면에 "열기" 버튼이 붙었으면 `true`.
    @discardableResult
    static func press() async -> Bool {
        let set = CueStore.activeSet
        guard !set.actions.isEmpty else { return false }

        let state = CueStore.state
        let isContinuing = state.isArmed && Date().timeIntervalSince(state.lastPressAt) < cycleWindow
        let index = isContinuing ? (state.selectedIndex + 1) % set.actions.count : 0

        return await arm(index: index, isItemTap: false, set: set)
    }

    /// 액션 스트립에서 항목을 직접 탭했을 때.
    /// 같은 항목의 두 번째 탭이면 기다리지 않고 확정한다.
    ///
    /// 카드에 찍힌 인덱스가 아니라 액션 식별자로 찾는다. 카드가 만들어진 뒤 세트가 바뀌었다면
    /// 그 액션은 더 이상 없을 수 있고, 그때는 아무것도 하지 않는다 — 화면에 보이던 것과
    /// 다른 액션을 실행하는 편보다 낫다.
    /// - Returns: 결과 화면에 "열기" 버튼이 붙었으면 `true`.
    @discardableResult
    static func tapItem(actionID: String) async -> Bool {
        let set = CueStore.activeSet
        guard let index = set.actions.firstIndex(where: { $0.id.uuidString == actionID }) else {
            return false
        }

        let state = CueStore.state
        let isDoubleTap = state.isArmed
            && state.lastInputWasItemTap
            && state.selectedIndex == index
            && Date().timeIntervalSince(state.lastPressAt) < cycleWindow

        guard !isDoubleTap else {
            // 대기 중인 자동 커밋 무효화는 `commit()` 안의 `disarm()`이 한다.
            return await commit()
        }

        return await arm(index: index, isItemTap: true, set: set)
    }

    /// 선택을 옮기고 Live Activity를 띄운 뒤, 창이 닫히기를 기다려 커밋한다.
    private static func arm(index: Int, isItemTap: Bool, set: CueSet) async -> Bool {
        let now = Date()
        var state = CueStore.state
        state.selectedIndex = index
        state.isArmed = true
        state.lastPressAt = now
        state.lastInputWasItemTap = isItemTap
        state.generation += 1
        CueStore.state = state

        CueHaptics.cycled()

        let generation = state.generation
        let commitAt = now.addingTimeInterval(cycleWindow)
        await presenter.showCycling(
            set: set,
            selectedIndex: index,
            commitAt: commitAt
        )

        // 창이 닫히기를 기다린다. 그 사이 다시 입력이 오면 generation이 올라가고,
        // 이 호출은 조용히 물러난다 — 커밋은 마지막 입력이 책임진다.
        //
        // **취소는 "창이 지났다"가 아니다.** 다음 누름이 들어오면 iOS가 앞선 인텐트 실행을
        // 정리하면서 이 sleep을 취소한다. 예전에는 `try?`로 삼키고 그대로 commit()까지
        // 내려가, 두 번째 누름이 순환 대신 **첫 항목을 즉시 실행**시켰다. 화면에서는 카드가
        // 열렸다가 닫히는 것처럼 보였다. generation 검사도 이걸 못 잡는다 — 다음 누름이
        // 아직 자기 generation을 쓰기 전이라 값이 그대로일 수 있다.
        let remaining = commitAt.timeIntervalSince(Date())
        if remaining > 0 {
            do {
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            } catch {
                return false
            }
        }
        guard !Task.isCancelled else { return false }
        guard CueStore.state.generation == generation else { return false }

        return await commit()
    }

    /// 대기 없이 지금 실행한다. Live Activity의 "실행" 버튼용.
    @discardableResult
    static func commit() async -> Bool {
        let set = CueStore.activeSet
        let state = CueStore.state
        guard set.actions.indices.contains(state.selectedIndex) else {
            // 조용히 삼키면 사용자도 테스트도 알 수 없다. 실패로 남긴다.
            CueStore.appendLog(CueLogEntry(
                at: Date(),
                actionTitle: String(localized: "실행 취소됨"),
                detail: String(localized: "선택한 액션이 사라졌습니다"),
                succeeded: false
            ))
            CueStore.disarm()
            await presenter.endAll()
            return false
        }

        let action = set.actions[state.selectedIndex]
        let outcome = CueActionRunner.run(action)

        CueStore.appendLog(CueLogEntry(
            at: Date(),
            actionTitle: action.title,
            detail: outcome.detail,
            succeeded: outcome.succeeded
        ))
        CueStore.disarm()
        CueHaptics.committed(succeeded: outcome.succeeded)

        await presenter.finish(
            phase: .executed,
            resultText: "\(action.title) · \(outcome.detail)",
            openTarget: outcome.openTarget,
            dismissAfter: outcome.openTarget == nil ? resultLinger : openPromptLinger
        )
        return outcome.openTarget != nil
    }

    /// 아무것도 실행하지 않고 물러난다. Live Activity의 "취소" 버튼용.
    static func cancel() async {
        CueStore.disarm()
        await presenter.finish(phase: .cancelled, resultText: String(localized: "취소됨"), openTarget: nil, dismissAfter: 1.0)
    }

    /// 무장을 풀고 선택을 처음으로 되돌린다. **카드는 건드리지 않는다** —
    /// 무엇을 대신 보여줄지는 부르는 쪽이 안다.
    private static func resetCycle() {
        var state = CueStore.state
        state.selectedIndex = 0
        CueStore.state = state
        CueStore.disarm()
    }

    /// 구성이 바뀌었을 때 대기 중인 순환을 버린다.
    ///
    /// 선택 인덱스는 **바뀐 세트에서 다른 액션을 가리킨다.** 무효화하지 않으면 대기 중이던
    /// `arm()`이 깨어나 화면에 보이던 것과 다른 액션을 실행한다. 세트 전환·편집·초기화가
    /// 모두 이 문을 통과해야 한다.
    ///
    /// 카드까지 여기서 마무리한다. generation만 올리면 대기 중이던 `arm()`은 조용히 물러나고
    /// **아무도 카드를 끝내지 않는다** — 실행되지 않을 액션을 가리킨 채 `.cycling` 상태로
    /// 화면에 남는다. staleDate가 지나도 저절로 사라지지 않는다.
    static func invalidateCycleIfArmed() async {
        guard CueStore.state.isArmed else { return }
        resetCycle()
        await presenter.finish(
            phase: .cancelled,
            resultText: String(localized: "구성이 바뀌어 중단됨"),
            openTarget: nil,
            dismissAfter: 1.0
        )
    }

    /// 다음 세트로 전환한다. 순환 중이었다면 되돌린다.
    static func nextSet() async {
        let next = CueStore.advanceSet()
        // 여기서는 `invalidateCycleIfArmed()`를 쓰지 않는다. 카드를 "중단됨"으로 끝낸 직후
        // 아래에서 세트 이름 카드를 다시 띄우면 두 번 깜빡인다. 상태만 되돌리고 표시는 한 번만.
        resetCycle()

        // `finish()`는 떠 있는 카드를 마무리하는 것이라, 순환 중이 아니면 아무것도 보여주지
        // 못한다. 제어 센터에서 세트를 바꾸는 시점에는 보통 카드가 없어서 전환이 조용히
        // 일어났다 — 사용자는 세트가 바뀌었는지 알 수 없었다.
        await presenter.showNotice(
            setName: next.name,
            text: String(localized: "세트: \(next.name)"),
            dismissAfter: 1.2
        )
    }
}

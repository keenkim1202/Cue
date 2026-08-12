import Foundation
import Testing
@testable import Cue

/// `CueStore`·`CueEngine`이 정적 상태를 공유하므로 직렬로 돌린다.
@MainActor
@Suite("CueEngine 상태 기계", .serialized)
struct CueEngineTests {

    // MARK: 순환

    @Test("첫 누름은 0번을 고르고 무장한다")
    func firstPressSelectsZero() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        h.pressWithoutWaiting()
        await h.settleArm()

        #expect(h.state.selectedIndex == 0)
        #expect(h.state.isArmed)
        #expect(h.state.lastInputWasItemTap == false)
        #expect(h.presenter.shown == [.init(setName: "테스트", selectedIndex: 0)])
        #expect(h.log.isEmpty, "창이 열려 있는 동안에는 아직 실행되지 않는다")
    }

    @Test("창 안에서 연달아 누르면 다음 항목으로 순환한다")
    func pressWithinWindowCycles() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        for expected in 0..<4 {
            h.pressWithoutWaiting()
            await h.settleArm()
            #expect(h.state.selectedIndex == expected)
        }

        // 4개 세트이므로 다섯 번째는 0으로 돌아온다.
        h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.selectedIndex == 0)
        #expect(h.log.isEmpty)
    }

    @Test("창이 지난 뒤 누르면 0번으로 리셋된다")
    func pressAfterWindowResets() async {
        let h = CueHarness()
        defer { h.tearDown() }

        // 두 번 눌러 1번을 고른 뒤 창이 닫히기를 기다린다 → 1번이 자동 실행된다.
        h.pressWithoutWaiting()
        await h.settleArm()
        h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.selectedIndex == 1)
        await h.settleCommit()
        #expect(h.committedTitles == ["A1"])

        // 창이 닫힌 뒤의 누름은 순환을 잇지 않는다.
        h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.selectedIndex == 0)
    }

    // MARK: 자동 커밋 (2초 방치)

    @Test("창이 닫히면 선택된 항목이 실행된다")
    func autoCommitRunsSelection() async {
        let h = CueHarness()
        defer { h.tearDown() }

        await CueEngine.press()

        #expect(h.committedTitles == ["A0"])
        #expect(h.state.isArmed == false)
        #expect(h.state.lastInputWasItemTap == false)
        #expect(h.presenter.finished.count == 1)
        #expect(h.presenter.finished.first?.phase == .executed)
    }

    @Test("대기 중 다시 입력이 오면 앞선 누름은 커밋하지 않는다")
    func supersededPressDoesNotCommit() async {
        let h = CueHarness()
        defer { h.tearDown() }

        h.pressWithoutWaiting()
        await h.settleArm()
        h.pressWithoutWaiting()
        await h.settleArm()
        await h.settleCommit()

        #expect(h.log.count == 1, "두 번 눌렀지만 실행은 마지막 하나뿐이어야 한다")
        #expect(h.committedTitles == ["A1"])
    }

    // MARK: 항목 탭

    @Test("항목 첫 탭은 선택만 옮기고 실행하지 않는다")
    func firstItemTapOnlySelects() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        h.tapWithoutWaiting(at: 2)
        await h.settleArm()

        #expect(h.state.selectedIndex == 2)
        #expect(h.state.isArmed)
        #expect(h.state.lastInputWasItemTap)
        #expect(h.log.isEmpty)
        #expect(h.presenter.shown.last == .init(setName: "테스트", selectedIndex: 2))
    }

    @Test("같은 항목을 두 번 탭하면 기다리지 않고 그 항목이 실행된다")
    func doubleTapCommitsImmediately() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        h.tapWithoutWaiting(at: 2)
        await h.settleArm()
        #expect(h.log.isEmpty)

        await CueEngine.tapItem(actionID: h.actionID(at: 2))

        // 창은 5초인데 이미 실행됐다 — 자동 커밋이 아니라 더블 탭이 만든 실행이다.
        #expect(h.committedTitles == ["A2"])
        #expect(h.state.isArmed == false)
    }

    @Test("다른 항목을 탭하면 확정이 아니라 선택 이동이다")
    func tapDifferentItemDoesNotCommit() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        h.tapWithoutWaiting(at: 1)
        await h.settleArm()
        h.tapWithoutWaiting(at: 3)
        await h.settleArm()

        #expect(h.state.selectedIndex == 3)
        #expect(h.log.isEmpty)
    }

    @Test("액션 버튼으로 고른 항목을 한 번 탭한 것은 더블 탭이 아니다")
    func tapAfterButtonPressIsNotDoubleTap() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        h.pressWithoutWaiting()          // 0번 선택, lastInputWasItemTap = false
        await h.settleArm()
        h.tapWithoutWaiting(at: 0)       // 같은 0번이지만 직전 입력이 항목 탭이 아니었다
        await h.settleArm()

        #expect(h.log.isEmpty, "항목 탭의 첫 번째로 취급되어야 한다")
        #expect(h.state.lastInputWasItemTap)
        #expect(h.state.selectedIndex == 0)
    }

    @Test("창이 지난 뒤의 두 번째 탭은 더블 탭이 아니다")
    func tapAfterWindowIsNotDoubleTap() async {
        let h = CueHarness()
        defer { h.tearDown() }

        await CueEngine.tapItem(actionID: h.actionID(at: 1))   // 첫 탭 → 창이 닫히며 자동 실행
        #expect(h.committedTitles == ["A1"])

        await CueEngine.tapItem(actionID: h.actionID(at: 1))   // 다시 첫 탭 → 또 자동 실행
        #expect(h.committedTitles == ["A1", "A1"])
        #expect(h.presenter.finished.count == 2)
    }

    @Test("세트에 없는 액션 식별자 탭은 아무 일도 하지 않는다")
    func tapUnknownActionIsIgnored() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        let result = await CueEngine.tapItem(actionID: UUID().uuidString)

        #expect(result == false)
        #expect(h.state.isArmed == false)
        #expect(h.log.isEmpty)
        #expect(h.presenter.shown.isEmpty)
    }

    @Test("카드가 만들어진 뒤 세트가 바뀌면 그 카드의 탭은 무시된다")
    func staleCardTapIsIgnored() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        // 카드가 떠 있는 동안 사용자가 본 액션의 식별자.
        let shownActionID = h.actionID(at: 2)

        // 그 사이 세트가 통째로 교체된다 — 인덱스 2는 이제 다른 액션이다.
        let replaced = CueSet(name: "교체됨", actions: [
            CueAction(title: "X0", symbol: "star", kind: .mark),
            CueAction(title: "X1", symbol: "star", kind: .mark),
            CueAction(title: "X2", symbol: "star", kind: .mark)
        ])
        CueStore.config = CueConfig(sets: [replaced], activeSetID: replaced.id)

        let result = await CueEngine.tapItem(actionID: shownActionID)

        #expect(result == false)
        #expect(h.log.isEmpty, "보이던 것과 다른 액션(X2)이 실행되면 안 된다")
        #expect(h.state.isArmed == false)
    }

    // MARK: 대기 중 외부 변경 — 리뷰에서 드러난 공백

    @Test("실행 버튼으로 먼저 확정하면 대기 중인 자동 커밋은 다시 실행되지 않는다")
    func externalCommitDuringWindowRunsOnce() async {
        let h = CueHarness()
        defer { h.tearDown() }

        // 누름이 창을 열고 대기에 들어간다.
        h.pressWithoutWaiting()
        await h.settleArm()

        // Live Activity의 "실행" 버튼 = CueEngine.commit() 직접 호출.
        await CueEngine.commit()
        #expect(h.committedTitles == ["A0"])

        // 대기 태스크가 깨어날 시간을 준다. generation이 올라갔으므로 다시 커밋하면 안 된다.
        await h.settleCommit()
        #expect(h.log.count == 1, "같은 누름이 두 번 실행됐다")
    }

    @Test("대기 중 세트를 바꾸면 옛 인덱스로 실행되지 않는다")
    func selectingAnotherSetDuringWindowCancelsCommit() async {
        let h = CueHarness()
        defer { h.tearDown() }

        // 액션이 하나뿐인 두 번째 세트를 준비한다 — 옛 인덱스(1)는 여기서 범위 밖이다.
        var config = CueStore.config
        let short = CueSet(name: "짧은 세트", actions: [CueAction(title: "B0", symbol: "star", kind: .mark)])
        config.sets.append(short)
        CueStore.config = config

        h.pressWithoutWaiting()
        await h.settleArm()
        h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.selectedIndex == 1)

        // 구성이 바뀌었다 → 대기 중인 순환을 버려야 한다.
        var switched = CueStore.config
        switched.activeSetID = short.id
        CueStore.config = switched
        await CueEngine.invalidateCycleIfArmed()

        #expect(h.presenter.finished.last?.phase == .cancelled, "실행되지 않을 카드를 화면에 남기면 안 된다")

        await h.settleCommit()
        #expect(h.log.isEmpty, "옛 세트의 인덱스로 무언가 실행됐다")
        #expect(h.state.isArmed == false)
    }

    @Test("ViewModel의 세트 선택이 대기 중인 순환을 버린다")
    func viewModelSelectSetInvalidatesCycle() async {
        let h = CueHarness()
        defer { h.tearDown() }

        var config = CueStore.config
        let short = CueSet(name: "짧은 세트", actions: [CueAction(title: "B0", symbol: "star", kind: .mark)])
        config.sets.append(short)
        CueStore.config = config

        let model = CueViewModel()
        h.pressWithoutWaiting()
        await h.settleArm()
        h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.selectedIndex == 1)

        // 엔진 헬퍼를 직접 부르지 않는다 — 화면이 쓰는 경로를 그대로 탄다.
        model.selectSet(short)

        await h.settleCommit()
        #expect(h.log.isEmpty, "세트를 바꿨는데 옛 인덱스로 무언가 실행됐다")
    }

    @Test("런타임 초기화는 generation을 되돌리지 않는다")
    func clearingRuntimeStateKeepsGenerationMonotonic() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        h.pressWithoutWaiting()
        await h.settleArm()
        let armed = h.state.generation

        CueStore.clearRuntimeState()

        #expect(h.state.generation > armed, "generation이 되돌아가면 나중 누름과 충돌한다")
        #expect(h.state.isArmed == false)
    }

    @Test("선택이 범위를 벗어나면 조용히 삼키지 않고 실패로 남긴다")
    func outOfRangeCommitIsLogged() async {
        let h = CueHarness()
        defer { h.tearDown() }

        // 선택을 범위 밖으로 만든 뒤 확정을 시도한다.
        var state = CueStore.state
        state.selectedIndex = 99
        state.isArmed = true
        CueStore.state = state

        let result = await CueEngine.commit()

        #expect(result == false)
        #expect(h.log.count == 1, "실행되지 않았다는 사실이 기록에 남아야 한다")
        #expect(h.log.first?.succeeded == false)
    }

    // MARK: 취소

    @Test("취소는 실행하지 않고 무장을 푼다")
    func cancelDoesNotCommit() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        h.pressWithoutWaiting()
        await h.settleArm()
        await CueEngine.cancel()
        await h.settleCommit()

        #expect(h.log.isEmpty)
        #expect(h.state.isArmed == false)
        #expect(h.presenter.finished.last?.phase == .cancelled)
    }

    // MARK: 세트

    @Test("세트 전환은 선택을 되돌리고 무장을 푼다")
    func nextSetResetsSelection() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        // 두 번째 세트를 추가한다.
        var config = CueStore.config
        let second = CueSet(name: "둘째", actions: [CueAction(title: "B0", symbol: "star", kind: .mark)])
        config.sets.append(second)
        CueStore.config = config

        h.pressWithoutWaiting()
        await h.settleArm()
        h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.selectedIndex == 1)

        await CueEngine.nextSet()

        #expect(CueStore.activeSet.name == "둘째")
        #expect(h.state.selectedIndex == 0)
        #expect(h.state.isArmed == false)
        #expect(h.log.isEmpty, "세트 전환은 액션을 실행하지 않는다")
    }

    @Test("빈 세트에서는 누름이 무시된다")
    func pressOnEmptySetIsIgnored() async {
        let h = CueHarness()
        defer { h.tearDown() }

        let empty = CueSet(name: "빈 세트", actions: [])
        CueStore.config = CueConfig(sets: [empty], activeSetID: empty.id)

        let result = await CueEngine.press()

        #expect(result == false)
        #expect(h.state.isArmed == false)
        #expect(h.log.isEmpty)
        #expect(h.presenter.shown.isEmpty)
    }

    // MARK: 실행 결과

    @Test("스톱워치는 시작과 정지를 번갈아 한다")
    func stopwatchToggles() async {
        let h = CueHarness(actionKinds: [.stopwatch])
        defer { h.tearDown() }

        await CueEngine.press()
        #expect(CueStore.stopwatch.isRunning)
        // 로케일에 따라 문구가 달라지므로 현지화된 값과 비교한다.
        #expect(h.log.first?.detail == String(localized: "시작"))

        await CueEngine.press()
        #expect(CueStore.stopwatch.isRunning == false)
        #expect(h.log.first?.detail.contains(CueActionRunner.format(0).prefix(2)) == true,
                "정지 기록에는 경과 시간이 들어간다")
    }

    @Test("앱 열기 액션은 결과 화면에 '열기' 버튼을 붙인다")
    func openAppShowsOpenButton() async {
        let h = CueHarness(actionKinds: [.openApp])
        defer { h.tearDown() }

        let offersLaunch = await CueEngine.press()

        #expect(offersLaunch)
        #expect(h.committedTitles == ["A0"])
        #expect(h.presenter.finished.last?.openTarget == .app)
        // 사용자가 탭할 틈이 있어야 하므로 보통 결과보다 오래 남는다.
        #expect(h.presenter.finished.last?.dismissAfter == CueEngine.openPromptLinger)
    }

    @Test("다른 액션은 '열기' 버튼을 붙이지 않는다")
    func ordinaryActionHasNoOpenButton() async {
        let h = CueHarness(actionKinds: [.mark])
        defer { h.tearDown() }

        let offersLaunch = await CueEngine.press()

        #expect(offersLaunch == false)
        #expect(h.presenter.finished.last?.openTarget == nil)
        #expect(h.presenter.finished.last?.dismissAfter == CueEngine.resultLinger)
    }

    @Test("취소와 세트 전환에는 '열기' 버튼이 붙지 않는다")
    func cancelAndNextSetHaveNoOpenButton() async {
        let h = CueHarness(window: 5, actionKinds: [.openApp, .openApp])
        defer { h.tearDown() }

        h.pressWithoutWaiting()
        await h.settleArm()
        await CueEngine.cancel()
        #expect(h.presenter.finished.last?.openTarget == nil)

        await CueEngine.nextSet()
        #expect(h.presenter.finished.allSatisfy { $0.openTarget == nil })
    }

    @Test("링크 열기는 주소를 실은 '열기' 버튼을 붙인다")
    func openURLCarriesAddress() async {
        let h = CueHarness(actionKinds: [.openURL])
        defer { h.tearDown() }

        let offersOpen = await CueEngine.press()

        #expect(offersOpen)
        #expect(h.presenter.finished.last?.openTarget == .url("https://example.com/0"))
        #expect(h.presenter.finished.last?.dismissAfter == CueEngine.openPromptLinger)
        #expect(h.log.first?.succeeded == true)
    }

    @Test("https만 열 수 있다고 판정한다")
    func onlyHTTPSIsOpenable() {
        #expect(CueURL.openable("https://example.com") != nil)
        #expect(CueURL.openable("http://example.com") == nil, "OpenURLIntent는 http를 열지 못한다")
        #expect(CueURL.openable("httpx://example.com") == nil, "hasPrefix(\"http\")가 통과시켰던 형태")
        #expect(CueURL.openable("myapp://x") == nil)
        #expect(CueURL.openable("https://") == nil, "호스트가 없으면 열 수 없다")
        #expect(CueURL.openable("") == nil)
    }

    @Test("https가 아닌 주소는 실패로 기록되고 버튼도 안 붙는다")
    func nonHTTPURLFails() async {
        let h = CueHarness(actionKinds: [.openURL])
        defer { h.tearDown() }

        // 커스텀 스킴은 OpenURLIntent가 열지 못한다.
        var config = CueStore.config
        config.sets[0].actions[0].urlString = "myapp://something"
        CueStore.config = config

        let offersOpen = await CueEngine.press()

        #expect(offersOpen == false)
        #expect(h.log.first?.succeeded == false)
        #expect(h.presenter.finished.last?.openTarget == nil)
    }

    @Test("실패한 액션도 기록되지만 실패로 표시된다")
    func failedActionIsLoggedAsFailure() async {
        // 시뮬레이터·테스트 런너에는 토치가 없으므로 손전등은 실패한다.
        let h = CueHarness(actionKinds: [.torch])
        defer { h.tearDown() }

        await CueEngine.press()

        #expect(h.log.count == 1)
        #expect(h.log.first?.succeeded == false)
    }

    // MARK: 로그

    // MARK: 카운트다운 (위젯 확장 크래시 방지)

    @Test("지나간 commitAt으로는 카운트다운 구간을 만들지 않는다")
    func expiredCountdownReturnsNil() {
        // Date()...commitAt을 그대로 쓰면 여기서 트랩된다:
        // "Fatal error: Range requires lowerBound <= upperBound".
        // 커밋이 돌지 못해 카드가 .cycling인 채로 굳으면 반드시 이 상태가 된다.
        let now = Date()
        let state = CueAttributes.ContentState(
            setName: "테스트",
            items: [.init(id: UUID().uuidString, title: "A0", symbol: "star")],
            selectedIndex: 0,
            phase: .cycling,
            resultText: nil,
            commitAt: now.addingTimeInterval(-5)
        )

        #expect(state.remainingCountdown(now: now) == nil)
    }

    @Test("아직 남은 commitAt은 유효한 구간을 돌려준다")
    func liveCountdownReturnsRange() {
        let now = Date()
        let commitAt = now.addingTimeInterval(2)
        let state = CueAttributes.ContentState(
            setName: "테스트",
            items: [.init(id: UUID().uuidString, title: "A0", symbol: "star")],
            selectedIndex: 0,
            phase: .cycling,
            resultText: nil,
            commitAt: commitAt
        )

        let range = state.remainingCountdown(now: now)
        #expect(range?.lowerBound == now)
        #expect(range?.upperBound == commitAt)
    }

    @Test("commitAt이 없으면 카운트다운도 없다")
    func missingCommitAtHasNoCountdown() {
        let state = CueAttributes.ContentState(
            setName: "테스트",
            items: [],
            selectedIndex: 0,
            phase: .executed,
            resultText: "끝",
            commitAt: nil
        )

        #expect(state.remainingCountdown() == nil)
    }

    // MARK: 취소

    /// 다음 누름이 들어오면 iOS가 앞선 인텐트 실행을 정리한다. 그때 sleep이 취소되는데,
    /// 예전에는 `try?`로 삼키고 커밋까지 내려가 두 번째 누름이 순환 대신 즉시 실행이 됐다.
    @Test("취소된 대기는 커밋하지 않는다")
    func cancelledArmDoesNotCommit() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        let pending = h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.isArmed)

        pending.cancel()
        let committed = await pending.value

        #expect(committed == false)
        #expect(h.log.isEmpty, "취소는 창이 지난 것이 아니다")
        #expect(h.state.isArmed, "다음 누름이 순환을 이어받을 수 있어야 한다")
    }

    // MARK: 구성 변경이 대기 중인 순환에 미치는 영향

    /// `CueEngine.invalidateCycleIfArmed()`의 계약 — 세트 전환·편집·초기화가 모두
    /// 이 문을 통과해야 한다. 예전에는 `addSet`·`deleteSet`이 빠져 있었다.
    @Test("세트 추가는 활성 세트를 바꾸므로 대기 중인 순환을 무효화한다")
    func addSetInvalidatesPendingCycle() async {
        let h = CueHarness(window: 0.5)
        defer { h.tearDown() }

        let pending = h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.isArmed)

        CueViewModel().addSet()
        await h.settleArm()

        #expect(h.state.isArmed == false, "활성 세트가 새 세트로 옮겨갔다")
        #expect(h.presenter.finished.last?.phase == .cancelled, "실행되지 않을 카드를 남기면 안 된다")
        _ = await pending.value
        #expect(h.log.isEmpty, "옛 세트의 인덱스로 새 세트의 액션을 실행하면 안 된다")
    }

    @Test("활성 세트 삭제는 대기 중인 순환을 무효화한다")
    func deleteActiveSetInvalidatesPendingCycle() async {
        let h = CueHarness(window: 0.5)
        defer { h.tearDown() }

        var config = CueStore.config
        let active = config.activeSet
        config.sets.append(CueSet(name: "둘째", actions: [
            CueAction(title: "B0", symbol: "star", kind: .mark)
        ]))
        CueStore.config = config

        let pending = h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.isArmed)

        CueViewModel().deleteSet(active)
        await h.settleArm()

        #expect(h.state.isArmed == false, "선택이 남은 세트로 옮겨갔다")
        _ = await pending.value
        #expect(h.log.isEmpty)
    }

    /// 무효화는 필요한 만큼만 해야 한다. 과하면 사용자가 골라 둔 액션이 이유 없이 사라진다.
    @Test("상관없는 세트를 지우는 것은 순환을 건드리지 않는다")
    func deletingInactiveSetKeepsCycle() async {
        let h = CueHarness(window: 0.5)
        defer { h.tearDown() }

        var config = CueStore.config
        let other = CueSet(name: "안 쓰는 세트", actions: [
            CueAction(title: "B0", symbol: "star", kind: .mark)
        ])
        config.sets.append(other)
        CueStore.config = config

        let pending = h.pressWithoutWaiting()
        await h.settleArm()
        #expect(h.state.isArmed)

        CueViewModel().deleteSet(other)
        await h.settleArm()

        #expect(h.state.isArmed, "활성 세트도 인덱스도 그대로다 — 취소할 이유가 없다")
        _ = await pending.value
        #expect(h.committedTitles == ["A0"], "고른 액션이 예정대로 실행돼야 한다")
    }

    @Test("세트 전환은 떠 있는 카드가 없어도 알림을 띄운다")
    func nextSetShowsNoticeWithoutActiveCard() async {
        let h = CueHarness(window: 5)
        defer { h.tearDown() }

        var config = CueStore.config
        config.sets.append(CueSet(name: "둘째", actions: [
            CueAction(title: "B0", symbol: "star", kind: .mark)
        ]))
        CueStore.config = config

        await CueEngine.nextSet()

        #expect(h.presenter.notices.count == 1)
        #expect(h.presenter.notices.last?.setName == "둘째")
        #expect(h.presenter.finished.isEmpty, "카드가 없으면 finish로는 아무것도 보여줄 수 없다")
    }

    // MARK: 로그

    @Test("로그는 최신이 먼저이고 상한을 넘지 않는다")
    func logIsNewestFirstAndCapped() async {
        let h = CueHarness()
        defer { h.tearDown() }

        for index in 0..<(CueStore.logLimit + 5) {
            CueStore.appendLog(CueLogEntry(at: Date(), actionTitle: "L\(index)", detail: "", succeeded: true))
        }

        #expect(h.log.count == CueStore.logLimit)
        #expect(h.log.first?.actionTitle == "L\(CueStore.logLimit + 4)")
    }
}

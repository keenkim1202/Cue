import Foundation

/// `CueEngine`이 상태를 바깥에 보여주는 창구.
///
/// 실제 구현은 `CueLiveActivityController`(ActivityKit) 하나뿐이다. 프로토콜로 뽑아 둔 이유는
/// 상태 기계 테스트가 Live Activity 권한·시스템 UI에 매달리지 않게 하려는 것뿐이다.
///
/// `@MainActor`가 아니라 `Sendable`이다. `Activity`는 Sendable이 아니라서, MainActor에서
/// 붙잡아 두고 `await activity.update(...)`를 호출하면 액터 밖으로 내보내는 셈이 되어
/// Swift 6가 막는다. 구현이 스스로 액티비티를 찾아 같은 컨텍스트에서 쓰게 둔다.
protocol CuePresenting: Sendable {
    /// Live Activity가 켜져 있는지.
    var isEnabled: Bool { get }

    /// 순환 중 상태를 띄우거나 갱신한다.
    func showCycling(set: CueSet, selectedIndex: Int, commitAt: Date) async

    /// 순환과 무관한 짧은 알림. 세트 전환처럼 "바뀌었다"만 알리면 되는 경우에 쓴다.
    ///
    /// `finish(...)`는 **이미 떠 있는** 카드를 마무리하는 것이라 카드가 없으면 아무것도 하지
    /// 않는다. 제어 센터에서 세트를 바꾸는 시점에는 보통 카드가 없어서, 전환에 아무 피드백도
    /// 없었다. 이쪽은 없으면 새로 띄운다.
    func showNotice(setName: String, text: String, dismissAfter seconds: TimeInterval) async

    /// 결과를 보여주고 닫는다. 대기하지 않고 시스템에 해제 시각만 맡긴다.
    func finish(
        phase: CueAttributes.ContentState.Phase,
        resultText: String,
        openTarget: CueOpenTarget?,
        dismissAfter seconds: TimeInterval
    ) async

    /// 남아 있는 액티비티를 즉시 모두 닫는다.
    func endAll() async
}

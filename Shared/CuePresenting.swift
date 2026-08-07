import Foundation

/// `CueEngine`이 상태를 바깥에 보여주는 창구.
///
/// 실제 구현은 `CueLiveActivityController`(ActivityKit) 하나뿐이다. 프로토콜로 뽑아 둔 이유는
/// 상태 기계 테스트가 Live Activity 권한·시스템 UI에 매달리지 않게 하려는 것뿐이다.
protocol CuePresenting {
    /// Live Activity가 켜져 있는지.
    var isEnabled: Bool { get }

    /// 순환 중 상태를 띄우거나 갱신한다.
    func showCycling(set: CueSet, selectedIndex: Int, commitAt: Date) async

    /// 결과를 보여주고 닫는다. 대기하지 않고 시스템에 해제 시각만 맡긴다.
    func finish(
        phase: CueAttributes.ContentState.Phase,
        resultText: String,
        showsOpenButton: Bool,
        dismissAfter seconds: TimeInterval
    ) async

    /// 남아 있는 액티비티를 즉시 모두 닫는다.
    func endAll() async
}

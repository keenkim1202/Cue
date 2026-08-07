#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// 순환과 확정에 촉각 피드백을 준다.
///
/// 이 앱의 전제가 "화면을 보지 않고 누른다"이므로, 몇 번째 항목인지 손으로 셀 수 있어야 한다.
///
/// **다만 앱이 전면에 있을 때만 울린다.** iOS는 백그라운드 프로세스의 햅틱 요청을 무시하므로,
/// 액션 버튼이나 컨트롤에서 인텐트가 돌 때는 발동하지 않는다. 그때 나는 진동은 시스템이
/// 액션 버튼 자체에 대해 주는 것이지 이 코드가 만든 것이 아니다.
///
/// 전면 여부를 직접 확인하지는 않는다. `UIApplication.shared`가 앱 확장에서 막혀 있고,
/// iOS가 알아서 무시하므로 결과는 같다.
enum CueHaptics {
    /// 다음 항목으로 넘어갔을 때 — 가볍게.
    static func cycled() {
        #if canImport(UIKit)
        Task { @MainActor in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }

    /// 액션이 실행됐을 때 — 성공과 실패를 다른 패턴으로.
    static func committed(succeeded: Bool) {
        #if canImport(UIKit)
        Task { @MainActor in
            UINotificationFeedbackGenerator().notificationOccurred(succeeded ? .success : .warning)
        }
        #endif
    }
}

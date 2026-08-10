import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity 배선만 담당한다. 실제 뷰는 `Shared/CueActivityViews.swift`에 있어
/// 앱 · 확장 · 테스트가 같은 것을 본다.
struct CueLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CueAttributes.self) { context in
            CueLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 확장 — 세트 전체를 보여주고 직접 확정할 수 있게 한다.
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.setName, systemImage: "square.stack.3d.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.phase == .cycling {
                        Text(context.state.positionText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CueExpandedBody(state: context.state)
                }
            } compactLeading: {
                Image(systemName: CueActivityStyle.compactSymbol(context.state))
                    .foregroundStyle(CueActivityStyle.tint(context.state))
            } compactTrailing: {
                CueCompactTrailing(state: context.state)
            } minimal: {
                Image(systemName: CueActivityStyle.compactSymbol(context.state))
                    .foregroundStyle(CueActivityStyle.tint(context.state))
            }
            .keylineTint(CueActivityStyle.tint(context.state))
        }
    }
}

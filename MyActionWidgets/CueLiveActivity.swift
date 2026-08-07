import ActivityKit
import SwiftUI
import WidgetKit

struct CueLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CueAttributes.self) { context in
            LockScreenView(state: context.state)
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
                    ExpandedBody(state: context.state)
                }
            } compactLeading: {
                Image(systemName: compactSymbol(context.state))
                    .foregroundStyle(tint(context.state))
            } compactTrailing: {
                CompactTrailing(state: context.state)
            } minimal: {
                Image(systemName: compactSymbol(context.state))
                    .foregroundStyle(tint(context.state))
            }
            .keylineTint(tint(context.state))
        }
    }

    private func compactSymbol(_ state: CueAttributes.ContentState) -> String {
        switch state.phase {
        case .cycling: return state.selected?.symbol ?? "button.horizontal.top.press"
        case .executed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    private func tint(_ state: CueAttributes.ContentState) -> Color {
        switch state.phase {
        case .cycling: return .yellow
        case .executed: return .green
        case .cancelled: return .secondary
        }
    }
}

// MARK: - 컴팩트 트레일링

/// 순환 중에는 남은 시간을, 끝난 뒤에는 위치 표시를 지운다.
private struct CompactTrailing: View {
    let state: CueAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .cycling:
            if let countdown = state.remainingCountdown() {
                Text(timerInterval: countdown, countsDown: true, showsHours: false)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 34)
                    .foregroundStyle(.yellow)
            } else {
                Text(state.positionText)
                    .font(.caption2.monospacedDigit())
            }
        case .executed, .cancelled:
            EmptyView()
        }
    }
}

// MARK: - 확장 영역

private struct ExpandedBody: View {
    let state: CueAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .cycling:
            VStack(spacing: 8) {
                ActionStrip(state: state)
                HStack(spacing: 8) {
                    Text("두 번 탭하면 바로 실행")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(intent: CueCancelIntent()) {
                        Label("취소", systemImage: "xmark")
                            .font(.caption)
                    }
                    .tint(.secondary)

                    Button(intent: CueConfirmIntent()) {
                        Label("실행", systemImage: "play.fill")
                            .font(.caption)
                    }
                    .tint(.green)
                }
                .buttonStyle(.bordered)
            }
        case .executed, .cancelled:
            HStack(spacing: 6) {
                Image(systemName: state.phase == .executed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(state.phase == .executed ? .green : .secondary)
                Text(state.resultText ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                if state.showsOpenButton {
                    OpenAppButton()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 앱을 실제로 여는 유일한 지점. `openAppWhenRun = true`라 탭하면 Cue가 전면으로 뜬다.
private struct OpenAppButton: View {
    var body: some View {
        Button(intent: CueOpenAppIntent()) {
            Label("열기", systemImage: "arrow.up.forward.app")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
    }
}

/// 세트의 액션들을 한 줄로 늘어놓고 현재 선택을 강조한다.
/// 이 앱의 존재 이유 — 손을 떼면 무엇이 실행될지 눈으로 확인시키는 부분.
///
/// 각 항목은 버튼이다. 한 번 탭하면 선택이 그 항목으로 옮겨지고, 같은 항목을
/// 한 번 더 탭하면 기다리지 않고 확정된다.
private struct ActionStrip: View {
    let state: CueAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(state.items.enumerated()), id: \.offset) { index, item in
                Button(intent: CueSelectIntent(actionID: item.id)) {
                    ActionTile(item: item, isSelected: index == state.selectedIndex)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityHint("두 번 탭하면 바로 실행합니다")
            }
        }
    }
}

private struct ActionTile: View {
    let item: CueAttributes.ContentState.Item
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: item.symbol)
                .font(.system(size: 15))
                .frame(height: 18)
            Text(item.title)
                .font(.system(size: 9))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? .primary : .tertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.yellow.opacity(0.22) : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.yellow : Color.clear, lineWidth: 1)
        }
    }
}

// MARK: - 잠금화면 / 배너

private struct LockScreenView: View {
    let state: CueAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(state.setName, systemImage: "square.stack.3d.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                switch state.phase {
                case .cycling:
                    if let countdown = state.remainingCountdown() {
                        Text(timerInterval: countdown, countsDown: true, showsHours: false)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.yellow)
                    }
                case .executed, .cancelled:
                    EmptyView()
                }
            }

            switch state.phase {
            case .cycling:
                HStack(spacing: 8) {
                    Image(systemName: state.selected?.symbol ?? "questionmark")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.selected?.title ?? "—")
                            .font(.headline)
                        Text("\(state.positionText) · 한 번 더 누르면 다음")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                ActionStrip(state: state)
                HStack(spacing: 8) {
                    Text("항목을 두 번 탭하면 바로 실행")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(intent: CueCancelIntent()) {
                        Text("취소").font(.caption)
                    }
                    .tint(.secondary)
                    Button(intent: CueConfirmIntent()) {
                        Label("실행", systemImage: "play.fill").font(.caption)
                    }
                    .tint(.green)
                }
                .buttonStyle(.bordered)

            case .executed, .cancelled:
                HStack(spacing: 8) {
                    Image(systemName: state.phase == .executed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(state.phase == .executed ? .green : .secondary)
                    Text(state.resultText ?? "")
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    if state.showsOpenButton {
                        OpenAppButton()
                    }
                }
            }
        }
        .padding(14)
    }
}

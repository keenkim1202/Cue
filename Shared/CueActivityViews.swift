import AppIntents
import SwiftUI
import WidgetKit

/// Live Activity · 다이나믹 아일랜드가 쓰는 뷰들.
///
/// 위젯 확장 안에 두면 테스트에서 닿지 않는다. Shared로 내려 두면 앱 · 확장 · 테스트가 모두
/// 같은 뷰를 본다. 위젯 타깃에는 `ActivityConfiguration` 배선만 남는다.

// MARK: - 표현 규칙

/// 상태에서 화면 표현을 끌어내는 순수 함수들. 이미지 비교 없이도 단언할 수 있게 떼어 뒀다.
enum CueActivityStyle {
    static func compactSymbol(_ state: CueAttributes.ContentState) -> String {
        switch state.phase {
        case .cycling: return state.selected?.symbol ?? "button.horizontal.top.press"
        case .executed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    static func tint(_ state: CueAttributes.ContentState) -> Color {
        switch state.phase {
        case .cycling: return .yellow
        case .executed: return .green
        case .cancelled: return .secondary
        }
    }

    static func resultSymbol(_ phase: CueAttributes.ContentState.Phase) -> String {
        phase == .executed ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
}

// MARK: - 액션 스트립

/// 세트의 액션들을 한 줄로 늘어놓고 현재 선택을 강조한다.
/// 이 앱의 존재 이유 — 손을 떼면 무엇이 실행될지 눈으로 확인시키는 부분.
///
/// 각 항목은 버튼이다. 한 번 탭하면 선택이 그 항목으로 옮겨지고, 같은 항목을
/// 한 번 더 탭하면 기다리지 않고 확정된다.
struct CueActionStrip: View {
    let state: CueAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(state.items.enumerated()), id: \.offset) { index, item in
                Button(intent: CueSelectIntent(actionID: item.id)) {
                    CueActionTile(item: item, isSelected: index == state.selectedIndex)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(CueID.tile(index))
                .accessibilityLabel(item.title)
                .accessibilityHint("두 번 탭하면 바로 실행합니다")
            }
        }
    }
}

struct CueActionTile: View {
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

// MARK: - 여는 버튼

/// 실제로 무언가를 여는 유일한 지점. `openAppWhenRun = true`라 탭해야 열린다.
struct CueOpenButton: View {
    let target: CueOpenTarget

    var body: some View {
        Group {
            switch target {
            case .app:
                Button(intent: CueOpenAppIntent()) {
                    Label("열기", systemImage: "arrow.up.forward.app").font(.caption)
                }
            case .url(let urlString):
                Button(intent: CueOpenURLIntent(urlString: urlString)) {
                    Label("열기", systemImage: "safari").font(.caption)
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .accessibilityIdentifier(CueID.openButton)
    }
}

// MARK: - 컴팩트 트레일링 (다이나믹 아일랜드)

/// 순환 중에는 남은 시간을, 끝난 뒤에는 위치 표시를 지운다.
struct CueCompactTrailing: View {
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

// MARK: - 다이나믹 아일랜드 확장 영역

struct CueExpandedBody: View {
    let state: CueAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .cycling:
            VStack(spacing: 8) {
                CueActionStrip(state: state)
                HStack(spacing: 8) {
                    Text("두 번 탭하면 바로 실행")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(intent: CueCancelIntent()) {
                        Label("취소", systemImage: "xmark").font(.caption)
                    }
                    .tint(.secondary)
                    .accessibilityIdentifier(CueID.cancel)

                    Button(intent: CueConfirmIntent()) {
                        Label("실행", systemImage: "play.fill").font(.caption)
                    }
                    .tint(.green)
                    .accessibilityIdentifier(CueID.confirm)
                }
                .buttonStyle(.bordered)
            }
        case .executed, .cancelled:
            HStack(spacing: 6) {
                Image(systemName: CueActivityStyle.resultSymbol(state.phase))
                    .foregroundStyle(state.phase == .executed ? .green : .secondary)
                Text(state.resultText ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                if let target = state.openTarget {
                    CueOpenButton(target: target)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 잠금화면 / 배너

struct CueLockScreenView: View {
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
                CueActionStrip(state: state)
                HStack(spacing: 8) {
                    Text("항목을 두 번 탭하면 바로 실행")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(intent: CueCancelIntent()) {
                        Text("취소").font(.caption)
                    }
                    .tint(.secondary)
                    .accessibilityIdentifier(CueID.cancel)
                    Button(intent: CueConfirmIntent()) {
                        Label("실행", systemImage: "play.fill").font(.caption)
                    }
                    .tint(.green)
                    .accessibilityIdentifier(CueID.confirm)
                }
                .buttonStyle(.bordered)

            case .executed, .cancelled:
                HStack(spacing: 8) {
                    Image(systemName: CueActivityStyle.resultSymbol(state.phase))
                        .font(.title2)
                        .foregroundStyle(state.phase == .executed ? .green : .secondary)
                    Text(state.resultText ?? "")
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    if let target = state.openTarget {
                        CueOpenButton(target: target)
                    }
                }
            }
        }
        .padding(14)
    }
}

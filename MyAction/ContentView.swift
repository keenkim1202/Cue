import ActivityKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = CueViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List {
                pressSection
                setSection
                logSection
                setupSection
                resetSection
            }
            .navigationTitle("Cue")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("세트 편집") { showingEditor = true }
                }
            }
            .sheet(isPresented: $showingEditor) {
                SetEditorView(model: model)
            }
        }
        .onAppear {
            model.reload()
            model.startTicking()
        }
        .onDisappear { model.stopTicking() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.reload()
            }
        }
    }

    // MARK: 누름

    private var pressSection: some View {
        Section {
            Button(action: model.press) {
                HStack(spacing: 14) {
                    Image(systemName: "button.horizontal.top.press")
                        .font(.system(size: 26))
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cue 누르기")
                            .font(.headline)
                        Text("액션 버튼 대신 — 시뮬레이터 테스트용")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if model.isCycling {
                cyclingPreview
            }
        } header: {
            Text("누름")
        } footer: {
            Text("연속으로 누르면 \(Int(CueEngine.cycleWindow))초 안에 다음 액션으로 순환합니다. 확정되는 방법은 두 가지 — 손을 떼고 \(Int(CueEngine.cycleWindow))초 기다리거나, 아래 액션 항목을 두 번 탭하면 즉시 실행됩니다.")
        }
    }

    /// 다이나믹 아일랜드에 뜨는 것과 같은 내용을 앱 안에서도 보여준다.
    private var cyclingPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(model.activeSet.actions.enumerated()), id: \.element.id) { index, action in
                    let isSelected = index == model.state.selectedIndex
                    Button {
                        model.tapItem(at: index)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.symbol)
                                .font(.system(size: 16))
                            Text(action.title)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isSelected ? Color.yellow.opacity(0.22) : Color.clear)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(isSelected ? Color.yellow : Color.clear, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("\(model.state.selectedIndex + 1)/\(model.activeSet.actions.count) · 손을 떼면 실행 · 항목을 두 번 탭하면 바로 실행")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: 세트

    private var setSection: some View {
        Section {
            ForEach(model.config.sets) { set in
                Button {
                    model.selectSet(set)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(set.name)
                            Text(set.actions.map(\.title).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if set.id == model.activeSet.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("액션 세트")
        } footer: {
            Text("제어 센터의 'Cue 세트 전환' 컨트롤로도 바꿀 수 있습니다.")
        }
    }

    // MARK: 로그

    private var logSection: some View {
        Section {
            if model.log.isEmpty {
                Text("아직 실행 기록이 없습니다.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(model.log) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(entry.succeeded ? .green : .orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.actionTitle)
                                .font(.callout)
                            Text(entry.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.at, format: .dateTime.hour().minute().second())
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            HStack {
                Text("실행 기록")
                Spacer()
                if !model.log.isEmpty {
                    Button("지우기", action: model.clearLog)
                        .font(.caption)
                        .textCase(nil)
                }
            }
        }
    }

    // MARK: 안내

    private var setupSection: some View {
        Section {
            if !ActivityAuthorizationInfo().areActivitiesEnabled {
                Label("설정 > MyAction 에서 '실시간 현황'을 켜야 Live Activity가 뜹니다.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            row("1", "설정 > 액션 버튼 > 제어", "제어 갤러리에서 'Cue 누르기'를 고릅니다. (iPhone 15 Pro 이상)")
            row("2", "제어 센터", "우상단에서 아래로 쓸어내려 편집 > 제어 추가 > Cue")
            row("3", "잠금화면", "잠금화면 길게 누르기 > 사용자화 > 하단 컨트롤 교체")
            row("4", "Apple Watch", "watchOS 26부터 같은 컨트롤이 워치 제어 센터와 Ultra 액션 버튼에도 올라갑니다.")
        } header: {
            Text("어디에 붙이나")
        } footer: {
            Text("액션 버튼은 iPhone 15 Pro 이상 실기기 전용입니다. 시뮬레이터에서는 위의 'Cue 누르기' 버튼이나 단축어 앱으로 같은 인텐트를 실행해 확인하세요.")
        }
    }

    private func row(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 초기화

    private var resetSection: some View {
        Section {
            if model.stopwatch.isRunning, let startedAt = model.stopwatch.startedAt {
                HStack {
                    Label("스톱워치 진행 중", systemImage: "stopwatch")
                    Spacer()
                    Text(CueActionRunner.format(Date().timeIntervalSince(startedAt)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Button("기본값으로 되돌리기", role: .destructive, action: model.resetToSeed)
        }
    }
}

#Preview {
    ContentView()
}

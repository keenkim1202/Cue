import SwiftUI

/// 실측 결과를 읽는 화면.
///
/// 기기에서 액션 버튼을 연타한 뒤 여기서 숫자를 본다. `cycleWindow`를 얼마로 잡을지가
/// 이 화면의 유일한 목적이다. 자세한 배경은 `docs/action-button.ko.md`.
struct PressProbeView: View {
    @State private var stats = CuePressStats(samples: [])
    @State private var copied = false

    var body: some View {
        List {
            howToSection
            if stats.isEmpty {
                Section {
                    Text("아직 표본이 없습니다. 실기기에서 액션 버튼을 빠르게 여러 번 눌러 주세요.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                verdictSection
                intervalSection
                performSection
                burstSection
            }
            manageSection
        }
        .navigationTitle("발동 간격 실측")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
        .refreshable { refresh() }
    }

    private func refresh() {
        stats = CuePressProbe.stats
        copied = false
    }

    // MARK: 재는 방법

    private var howToSection: some View {
        Section {
            step("1", "실행만 하는 세트로 바꾸세요", "손전등이 계속 켜지지 않도록 '순간 기록'만 담긴 세트를 쓰는 편이 낫습니다.")
            step("2", "액션 버튼을 최대한 빠르게 10번", "매번 실행될 때까지 확실히 누르고 있다가 떼세요. 손에 익도록 몇 세트 반복합니다.")
            step("3", "화면을 보지 않고도 한 세트", "Apple은 사람들이 화면을 보지 않고 이 버튼을 쓴다고 봅니다. 그 조건도 재야 합니다.")
            step("4", "여기로 돌아와 숫자를 봅니다", "\(Int(CuePressStats.burstGap))초 넘게 쉬면 다른 묶음으로 나뉩니다.")
        } header: {
            Text("재는 방법")
        } footer: {
            Text("앱 안의 'Cue 누르기' 버튼은 홀드 제스처가 없어 간격의 의미가 다릅니다. 기록은 되지만 통계에서는 빠집니다.")
        }
    }

    private func step(_ number: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
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

    // MARK: 판정

    /// 이 화면에서 제일 중요한 두 줄. 현재 창이 왜 안 되는지와, 얼마로 바꿔야 하는지.
    private var verdictSection: some View {
        Section {
            if let ratio = stats.ratioWithin(CueEngine.cycleWindow) {
                LabeledContent {
                    Text(ratio, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(ratio < 0.5 ? .red : .primary)
                        .fontWeight(.semibold)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("현재 창 \(CueEngine.cycleWindow, format: .number)초 안에 들어온 비율")
                        Text("낮을수록 순환이 죽는다는 뜻입니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            LabeledContent {
                Text("\(stats.continuedCount) / \(stats.continuableCount)")
                    .monospacedDigit()
                    .foregroundStyle(stats.continuedCount == 0 ? .red : .primary)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("순환으로 인정된 횟수")
                    Text("0이면 늘 1번 액션만 실행됩니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let recommended = stats.recommendedWindow {
                LabeledContent {
                    Text("\(recommended, format: .number)초")
                        .monospacedDigit()
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("제안 창")
                        Text("가장 느렸던 간격 + 0.5초")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("판정")
        } footer: {
            Text("놓친 누름은 원치 않는 액션의 실행으로 이어집니다. 중앙값이 아니라 최대값을 기준으로 관대하게 잡습니다.")
        }
    }

    // MARK: 간격

    private var intervalSection: some View {
        Section {
            metric(
                "표본",
                "\(stats.sampleCount)",
                detail: stats.inAppCount > 0 ? String(localized: "앱 내 버튼 \(stats.inAppCount)회 제외") : nil
            )
            metric("가장 빠름", seconds(stats.fastest))
            metric("중앙값", seconds(stats.median))
            metric("p90", seconds(stats.p90))
            metric("가장 느림", seconds(stats.slowest))
        } header: {
            Text("발동 간격")
        }
    }

    // MARK: perform 소요

    private var performSection: some View {
        Section {
            metric("중앙값", seconds(stats.performMedian))
            metric("최대", seconds(stats.performSlowest))
        } header: {
            Text("perform() 소요")
        } footer: {
            Text("Live Activity 시작·갱신이 포함된 시간입니다. 시스템은 perform()이 반환된 뒤에야 다음 누름을 전달하므로, 이 값이 크면 창 길이와 무관하게 누름이 버려집니다. 그때는 상수가 아니라 카드 표시를 기다리지 않도록 고쳐야 합니다.")
        }
    }

    // MARK: 묶음별

    private var burstSection: some View {
        Section {
            ForEach(stats.bursts) { burst in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(burst.startedAt, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(burst.intervals.count + 1)회")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if burst.intervals.isEmpty {
                        Text("연속 누름 없음")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(burst.intervals.map { String(format: "%.2f", $0) }.joined(separator: " · "))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        } header: {
            Text("묶음별 간격 (초)")
        }
    }

    // MARK: 관리

    private var manageSection: some View {
        Section {
            Button {
                UIPasteboard.general.string = stats.csv()
                copied = true
            } label: {
                Label(copied ? "복사됨" : "CSV로 복사", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .disabled(stats.isEmpty)
            .accessibilityIdentifier(CueID.probeCopy)

            Button("표본 지우기", role: .destructive) {
                CuePressProbe.clear()
                refresh()
            }
            .accessibilityIdentifier(CueID.probeClear)
        } footer: {
            Text("기기에서 숫자를 옮기려면 복사가 유일한 통로입니다. 표본은 최대 \(CuePressProbe.sampleLimit)개까지 남습니다.")
        }
    }

    // MARK: 조각

    private func metric(_ title: LocalizedStringKey, _ value: String, detail: String? = nil) -> some View {
        LabeledContent {
            Text(value).monospacedDigit()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// 단위까지 로컬라이즈한다. `String(format:)`로 "초"를 붙이면 영어에서도 한국어가 남는다.
    private func seconds(_ value: TimeInterval?) -> String {
        guard let value else { return "—" }
        return String(localized: "\(String(format: "%.2f", value))초")
    }
}

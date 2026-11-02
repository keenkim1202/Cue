import Foundation

/// 눌림 하나에 대한 계측 표본.
struct CuePressSample: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    /// `CueEngine.press()`에 들어온 시각. 인접 표본의 차가 **발동 간격**이다.
    var at: Date
    /// `press()`가 끝나기까지 걸린 시간.
    ///
    /// **Live Activity 시작·갱신이 여기 포함된다.** `arm()`이 `showCycling`을 `await`하므로
    /// ActivityKit이 느리면 그만큼 `perform()`이 늦게 반환된다. 시스템은 `perform()`이
    /// 반환된 뒤에야 컨트롤을 리로드하고, 실행 중에는 다음 누름을 전달하지 않는 것으로
    /// 보고돼 있다 — 그렇다면 이 값 자체가 순환을 막는 원인일 수 있다.
    var performSeconds: TimeInterval
    /// 순환으로 인정됐는지. 거짓이면 창 밖이라 0번으로 리셋됐다는 뜻이다.
    var continued: Bool
    var selectedIndex: Int
    var source: Source

    enum Source: String, Codable, Hashable {
        /// 인텐트 경로 — 액션 버튼 · 제어 센터 · 잠금화면 · 단축어.
        case intent
        /// 앱 안의 'Cue 누르기' 버튼. 홀드 제스처가 없으므로
        /// **간격 통계에 섞으면 안 된다.** 기록은 하되 계산에서 걸러낸다.
        case inApp
    }
}

/// 액션 버튼이 두 번 연속 발동되는 데 실제로 몇 초가 걸리는지 재는 계측기.
///
/// **왜 필요한가.** `CueEngine.cycleWindow = 2.0`은 시뮬레이터의 화면 버튼으로만 정해진 값이다.
/// 실기기의 액션 버튼은 약 1초의 홀드를 요구하고, 앞선 인텐트가 끝나기 전에는 다음 누름을
/// 전달하지 않는다. 그래서 두 번째 발동이 2초 창 안에 들어오지 못하고 순환이 죽는다.
/// 같은 문제를 먼저 푼 MacStories의 MultiButton은 창을 7초로 잡았다.
///
/// 7초를 그대로 베끼지 않는다. **기기에서 실제 간격을 재고 그 분포를 보고 정한다.**
/// 자세한 조사 기록은 `docs/action-button.ko.md`.
///
/// 저장 키를 순환 상태와 **완전히 분리**한다. 측정이 측정 대상을 바꾸면 안 된다.
@MainActor
enum CuePressProbe {
    /// 표본 상한. 기록은 `press()` 안에서 동기적으로 일어나므로 무한정 쌓으면
    /// 인코딩 비용이 그대로 `perform()` 시간에 붙는다.
    static let sampleLimit = 200

    private static let key = "cue.pressprobe"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// 오래된 것이 앞. 간격 계산이 시간순을 전제한다.
    static var samples: [CuePressSample] {
        get {
            guard let data = CueStore.defaults.data(forKey: key),
                  let decoded = try? decoder.decode([CuePressSample].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let trimmed = Array(newValue.suffix(sampleLimit))
            CueStore.defaults.set(try? encoder.encode(trimmed), forKey: key)
        }
    }

    static func record(_ sample: CuePressSample) {
        samples = samples + [sample]
    }

    static func clear() {
        CueStore.defaults.removeObject(forKey: key)
    }

    static var stats: CuePressStats {
        CuePressStats(samples: samples)
    }
}

// MARK: - 통계

/// 표본에서 뽑아낸 수치. **순수 계산이라 저장소 없이 테스트할 수 있다.**
struct CuePressStats: Equatable {
    /// 이보다 오래 쉬면 다른 연타 묶음으로 본다.
    /// 연타 세션 사이의 긴 공백은 "발동 간격"이 아니다.
    ///
    /// `CuePressProbe`가 아니라 여기 있는 것은 격리 때문이다. 계측기는 저장소를 만지느라
    /// `@MainActor`인데 통계는 순수 계산이라 격리가 없다. 상수를 저쪽에 두면
    /// Swift 6에서 nonisolated 컨텍스트가 MainActor 값을 참조하는 오류가 된다.
    static let burstGap: TimeInterval = 10

    /// 쉼 없이 이어진 한 묶음.
    struct Burst: Equatable, Identifiable {
        var id: Int
        var startedAt: Date
        /// 묶음 안의 인접 발동 간격. 표본 n개면 n-1개다.
        var intervals: [TimeInterval]
    }

    /// 인텐트 경로 표본만. 앱 내 버튼은 홀드가 없어 간격의 의미가 다르다.
    let sampleCount: Int
    /// 앱 내 버튼으로 누른 횟수. 걸러졌다는 것을 화면에서 알려주려고 센다.
    let inAppCount: Int
    let bursts: [Burst]
    /// 모든 묶음의 간격을 합친 것.
    let intervals: [TimeInterval]
    let performSeconds: [TimeInterval]
    /// 순환으로 인정된 횟수. 묶음의 첫 누름은 원래 인정되지 않으므로 제외하고 센다.
    let continuedCount: Int
    /// 인정될 기회가 있었던 횟수 = 간격의 개수.
    var continuableCount: Int { intervals.count }

    init(samples: [CuePressSample]) {
        let ordered = samples.filter { $0.source == .intent }.sorted { $0.at < $1.at }
        sampleCount = ordered.count
        inAppCount = samples.count - ordered.count
        performSeconds = ordered.map(\.performSeconds)

        var bursts: [Burst] = []
        var currentStart: Date?
        var currentIntervals: [TimeInterval] = []
        var previous: CuePressSample?
        var continued = 0

        for sample in ordered {
            defer { previous = sample }
            guard let last = previous else {
                currentStart = sample.at
                continue
            }
            let gap = sample.at.timeIntervalSince(last.at)
            if gap > Self.burstGap {
                if let start = currentStart {
                    bursts.append(Burst(id: bursts.count, startedAt: start, intervals: currentIntervals))
                }
                currentStart = sample.at
                currentIntervals = []
                continue
            }
            currentIntervals.append(gap)
            if sample.continued { continued += 1 }
        }
        if let start = currentStart {
            bursts.append(Burst(id: bursts.count, startedAt: start, intervals: currentIntervals))
        }

        self.bursts = bursts
        intervals = bursts.flatMap(\.intervals)
        continuedCount = continued
    }

    var isEmpty: Bool { intervals.isEmpty }

    // MARK: 간격

    var fastest: TimeInterval? { intervals.min() }
    var slowest: TimeInterval? { intervals.max() }
    var median: TimeInterval? { Self.percentile(intervals, 0.5) }
    var p90: TimeInterval? { Self.percentile(intervals, 0.9) }

    // MARK: perform() 소요

    var performMedian: TimeInterval? { Self.percentile(performSeconds, 0.5) }
    var performSlowest: TimeInterval? { performSeconds.max() }

    /// 주어진 창 안에 들어온 간격의 비율. 지금 값(2초)을 넣으면 왜 순환이 죽었는지 바로 보인다.
    func ratioWithin(_ window: TimeInterval) -> Double? {
        guard !intervals.isEmpty else { return nil }
        return Double(intervals.filter { $0 < window }.count) / Double(intervals.count)
    }

    /// 실측에서 뽑은 창 제안값.
    ///
    /// **중앙값이 아니라 최대값을 기준으로 삼는다.** 놓친 누름은 단순한 불편이 아니라
    /// *원치 않는 액션의 실행*으로 이어진다 — 순환하려다 손전등이 켜진다.
    /// 관대한 쪽으로 틀리는 편이 안전하므로 가장 느렸던 간격에 0.5초를 얹고 0.5초 단위로 올린다.
    var recommendedWindow: TimeInterval? {
        guard let slowest else { return nil }
        return (slowest + 0.5).roundedUp(toNearest: 0.5)
    }

    /// 최근접 순위 방식. 표본이 적을 때 보간법보다 읽기 쉽다.
    private static func percentile(_ values: [TimeInterval], _ q: Double) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let rank = Int((q * Double(sorted.count)).rounded(.up))
        return sorted[Swift.max(0, Swift.min(sorted.count - 1, rank - 1))]
    }

    /// 실기기에서 기기 밖으로 옮길 유일한 통로. 화면을 옮겨 적을 수는 없다.
    func csv() -> String {
        var lines = ["burst,index,interval_s"]
        for burst in bursts {
            for (index, interval) in burst.intervals.enumerated() {
                lines.append("\(burst.id),\(index),\(String(format: "%.3f", interval))")
            }
        }
        lines.append("")
        lines.append("perform_s")
        for value in performSeconds {
            lines.append(String(format: "%.3f", value))
        }
        return lines.joined(separator: "\n")
    }
}

private extension TimeInterval {
    func roundedUp(toNearest step: Double) -> Double {
        (self / step).rounded(.up) * step
    }
}

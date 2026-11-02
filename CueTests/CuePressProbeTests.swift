import Foundation
import Testing
@testable import Cue

/// `CuePressStats`는 순수 계산이라 저장소 없이 검증할 수 있다.
/// 계측이 틀리면 그 값으로 정한 창도 틀린다 — 여기가 실측 전체의 유일한 안전장치다.
@Suite("발동 간격 통계")
struct CuePressStatsTests {

    private let origin = Date(timeIntervalSince1970: 1_000_000)

    /// `offsets` 초 지점마다 인텐트 경로 표본을 하나씩 만든다.
    private func samples(
        at offsets: [TimeInterval],
        continued: [Bool]? = nil,
        performSeconds: TimeInterval = 0.1,
        source: CuePressSample.Source = .intent
    ) -> [CuePressSample] {
        offsets.enumerated().map { index, offset in
            CuePressSample(
                at: origin.addingTimeInterval(offset),
                performSeconds: performSeconds,
                continued: continued?[index] ?? false,
                selectedIndex: 0,
                source: source
            )
        }
    }

    // MARK: 묶음 나누기

    @Test("쉼 없이 이어진 누름은 한 묶음이다")
    func consecutivePressesFormOneBurst() {
        let stats = CuePressStats(samples: samples(at: [0, 2, 4.5]))

        #expect(stats.bursts.count == 1)
        #expect(stats.intervals.count == 2, "표본 3개면 간격은 2개다")
        #expect(stats.intervals[0] == 2)
        #expect(stats.intervals[1] == 2.5)
    }

    @Test("burstGap보다 오래 쉬면 다른 묶음으로 나뉜다")
    func longPauseSplitsBursts() {
        let gap = CuePressStats.burstGap
        let stats = CuePressStats(samples: samples(at: [0, 2, 2 + gap + 1, 2 + gap + 3]))

        #expect(stats.bursts.count == 2)
        #expect(stats.bursts[0].intervals == [2])
        #expect(stats.bursts[1].intervals == [2])
        #expect(stats.intervals.count == 2, "묶음 사이의 공백은 발동 간격이 아니다")
    }

    @Test("한 번만 누른 묶음은 간격을 만들지 않는다")
    func singlePressHasNoInterval() {
        let stats = CuePressStats(samples: samples(at: [0]))

        #expect(stats.sampleCount == 1)
        #expect(stats.bursts.count == 1)
        #expect(stats.isEmpty, "간격이 없으면 통계도 없다")
        #expect(stats.fastest == nil)
        #expect(stats.recommendedWindow == nil)
    }

    @Test("표본이 없으면 비어 있다")
    func emptySamples() {
        let stats = CuePressStats(samples: [])

        #expect(stats.isEmpty)
        #expect(stats.bursts.isEmpty)
        #expect(stats.ratioWithin(2.0) == nil)
    }

    // MARK: 경로 구분

    @Test("앱 내 버튼 표본은 통계에서 빠진다")
    func inAppSamplesAreExcluded() {
        // 홀드 제스처가 없어 간격의 의미가 다르다. 섞이면 창이 과소평가된다.
        let intent = samples(at: [0, 3])
        let inApp = samples(at: [1, 1.2], source: .inApp)
        let stats = CuePressStats(samples: inApp + intent)

        #expect(stats.sampleCount == 2)
        #expect(stats.inAppCount == 2)
        #expect(stats.intervals == [3], "인텐트 표본끼리의 간격만 남는다")
    }

    @Test("시간순이 아니어도 정렬해서 센다")
    func samplesAreSortedByTime() {
        let stats = CuePressStats(samples: samples(at: [4, 0, 2]))

        #expect(stats.intervals == [2, 2])
    }

    // MARK: 수치

    @Test("최소·중앙값·최대를 뽑는다")
    func summaryValues() {
        let stats = CuePressStats(samples: samples(at: [0, 1, 3, 6, 10]))

        #expect(stats.intervals == [1, 2, 3, 4])
        #expect(stats.fastest == 1)
        #expect(stats.slowest == 4)
        #expect(stats.median == 2, "최근접 순위 방식 — 4개의 0.5분위는 두 번째 값")
        #expect(stats.p90 == 4)
    }

    @Test("현재 창 안에 들어온 비율을 센다")
    func ratioWithinWindow() {
        let stats = CuePressStats(samples: samples(at: [0, 1, 3, 6]))

        #expect(stats.intervals == [1, 2, 3])
        // 2초 창에 들어오는 것은 1초짜리 하나뿐이다. 실기기에서 순환이 죽은 이유다.
        #expect(stats.ratioWithin(2.0) == 1.0 / 3.0)
        #expect(stats.ratioWithin(10) == 1.0)
    }

    @Test("제안 창은 가장 느린 간격에 여유를 얹어 0.5초 단위로 올린다")
    func recommendedWindowRoundsUp() {
        // 가장 느린 간격 2.6초 → 2.6 + 0.5 = 3.1 → 3.5
        #expect(CuePressStats(samples: samples(at: [0, 2.6])).recommendedWindow == 3.5)
        // 정확히 눈금에 걸리면 올리지 않는다. 2.0 + 0.5 = 2.5
        #expect(CuePressStats(samples: samples(at: [0, 2.0])).recommendedWindow == 2.5)
    }

    @Test("중앙값이 아니라 최대값으로 제안한다")
    func recommendationUsesSlowest() {
        // 놓친 누름은 원치 않는 액션의 실행이 된다. 관대한 쪽으로 틀려야 한다.
        let stats = CuePressStats(samples: samples(at: [0, 1, 2, 8]))

        #expect(stats.median == 1)
        #expect(stats.slowest == 6)
        #expect(stats.recommendedWindow == 6.5, "중앙값을 썼다면 1.5가 나왔을 것이다")
    }

    // MARK: 순환 인정

    @Test("순환으로 인정된 횟수는 묶음의 첫 누름을 빼고 센다")
    func continuedCountExcludesFirstPress() {
        // 첫 누름은 원래 인정되지 않는다. 분모도 간격 개수여야 비율이 맞는다.
        let stats = CuePressStats(
            samples: samples(at: [0, 1, 2], continued: [false, true, true])
        )

        #expect(stats.continuedCount == 2)
        #expect(stats.continuableCount == 2)
    }

    @Test("창 밖이라 전부 리셋되면 인정 횟수가 0이다")
    func noneContinuedWhenAllResets() {
        // 실기기에서 관찰된 증상 — 몇 번을 눌러도 늘 1번 액션만 실행된다.
        let stats = CuePressStats(
            samples: samples(at: [0, 2.5, 5], continued: [false, false, false])
        )

        #expect(stats.continuedCount == 0)
        #expect(stats.continuableCount == 2)
    }

    // MARK: perform 소요

    @Test("perform 소요는 인텐트 표본에서만 뽑는다")
    func performStats() {
        let fast = samples(at: [0], performSeconds: 0.2)
        let slow = samples(at: [2], performSeconds: 0.8)
        let inApp = samples(at: [1], performSeconds: 5, source: .inApp)
        let stats = CuePressStats(samples: fast + slow + inApp)

        #expect(stats.performSeconds.count == 2)
        #expect(stats.performSlowest == 0.8)
    }

    // MARK: 내보내기

    @Test("CSV에 묶음별 간격이 담긴다")
    func csvContainsIntervals() {
        let stats = CuePressStats(samples: samples(at: [0, 1.5]))
        let csv = stats.csv()

        #expect(csv.hasPrefix("burst,index,interval_s"))
        #expect(csv.contains("0,0,1.500"))
        #expect(csv.contains("perform_s"))
    }
}

import SwiftUI
import Testing
import UIKit
@testable import Cue

/// Live Activity · 다이나믹 아일랜드 뷰 검증 (L3).
///
/// 시뮬레이터를 띄우지 않고 뷰를 직접 렌더한다. 이 층이 겨냥하는 것:
///
/// - **렌더 중 트랩** — 실제로 있었던 `Date()...commitAt` 크래시가 여기서 잡힌다.
///   `ImageRenderer`가 `body`를 평가하므로 뷰 안의 트랩이 테스트 실패로 나온다.
/// - **상태가 화면에 반영되는지** — 서로 다른 상태가 같은 그림을 내면 뭔가 끊긴 것이다.
/// - **빈 화면** — 레이아웃이 무너져 아무것도 안 그려지는 경우.
///
/// 기준 이미지와의 픽셀 비교는 하지 않는다. OS·폰트 버전에 따라 깨지는 대신 얻는 것이 적고,
/// 정작 이 프로젝트에서 깨졌던 것들은 위 세 가지였다. 표현 규칙은 아래 `CueActivityStyle`
/// 테스트에서 값으로 직접 단언한다.
@MainActor
@Suite("Live Activity 뷰")
struct CueActivityViewTests {

    // MARK: 렌더 도우미

    /// 뷰를 비트맵으로 그린다. `body` 평가 중 트랩이 있으면 여기서 죽는다.
    private func render<V: View>(_ view: V, width: CGFloat = 360) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: width).background(.black))
        renderer.scale = 2
        return renderer.uiImage
    }

    /// 완전히 같은 그림인지. 상태가 반영되는지 보려면 "다름"을 확인해야 한다.
    private func pngData(_ image: UIImage?) -> Data? {
        image?.pngData()
    }

    private func state(
        phase: CueAttributes.ContentState.Phase = .cycling,
        selectedIndex: Int = 0,
        commitAt: Date? = Date().addingTimeInterval(2),
        resultText: String? = nil,
        openTarget: CueOpenTarget? = nil,
        itemCount: Int = 4
    ) -> CueAttributes.ContentState {
        let symbols = ["flashlight.on.fill", "mappin.and.ellipse", "stopwatch", "arrow.up.forward.app"]
        let items = (0..<itemCount).map {
            CueAttributes.ContentState.Item(
                id: "id-\($0)",
                title: "A\($0)",
                symbol: symbols[$0 % symbols.count]
            )
        }
        return CueAttributes.ContentState(
            setName: "테스트",
            items: items,
            selectedIndex: selectedIndex,
            phase: phase,
            resultText: resultText,
            commitAt: commitAt,
            openTarget: openTarget
        )
    }

    // MARK: 잠금화면

    @Test("순환 상태를 그린다")
    func lockScreenCyclingRenders() {
        let image = render(CueLockScreenView(state: state()))

        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
        #expect((image?.size.height ?? 0) > 0)
    }

    @Test("실행 완료 상태를 그린다")
    func lockScreenExecutedRenders() {
        let image = render(CueLockScreenView(
            state: state(phase: .executed, commitAt: nil, resultText: "A0 · 켜짐")
        ))

        #expect(image != nil)
    }

    @Test("'열기' 버튼이 붙은 상태를 그린다")
    func lockScreenWithOpenButtonRenders() {
        let app = render(CueLockScreenView(
            state: state(phase: .executed, commitAt: nil, resultText: "앱 열기", openTarget: .app)
        ))
        let url = render(CueLockScreenView(
            state: state(phase: .executed, commitAt: nil, resultText: "링크 열기",
                         openTarget: .url("https://example.com"))
        ))

        #expect(app != nil)
        #expect(url != nil)
    }

    /// 이 프로젝트에서 실제로 있었던 크래시.
    ///
    /// 커밋이 돌지 못해 카드가 `.cycling`인 채로 굳으면 `commitAt`이 과거가 된다.
    /// 예전 코드는 `Date()...commitAt`을 그대로 만들어 트랩됐다
    /// (`Range requires lowerBound <= upperBound`). 렌더 테스트가 있었다면 여기서 잡혔다.
    @Test("지나간 commitAt으로도 트랩 없이 그려진다")
    func lockScreenWithExpiredCommitAtRenders() {
        let image = render(CueLockScreenView(
            state: state(commitAt: Date().addingTimeInterval(-30))
        ))

        #expect(image != nil, "지나간 카운트다운에서 트랩되지 않아야 한다")
    }

    @Test("선택이 다르면 그림도 달라진다")
    func selectionIsReflected() {
        let first = pngData(render(CueLockScreenView(state: state(selectedIndex: 0))))
        let third = pngData(render(CueLockScreenView(state: state(selectedIndex: 2))))

        #expect(first != nil)
        #expect(first != third, "선택된 항목이 화면에 반영되지 않고 있다")
    }

    @Test("단계가 다르면 그림도 달라진다")
    func phaseIsReflected() {
        let cycling = pngData(render(CueLockScreenView(state: state())))
        let executed = pngData(render(CueLockScreenView(
            state: state(phase: .executed, commitAt: nil, resultText: "A0 · 켜짐")
        )))

        #expect(cycling != executed)
    }

    // MARK: 다이나믹 아일랜드

    @Test("확장 영역이 두 단계 모두 그려진다")
    func expandedBodyRenders() {
        let cycling = render(CueExpandedBody(state: state()))
        let executed = render(CueExpandedBody(
            state: state(phase: .executed, commitAt: nil, resultText: "A0 · 켜짐")
        ))

        #expect(cycling != nil)
        #expect(executed != nil)
        #expect(pngData(cycling) != pngData(executed))
    }

    @Test("컴팩트 트레일링이 지나간 카운트다운에서도 그려진다")
    func compactTrailingRenders() {
        let live = render(CueCompactTrailing(state: state()), width: 60)
        let expired = render(CueCompactTrailing(state: state(commitAt: Date().addingTimeInterval(-5))), width: 60)

        #expect(live != nil)
        #expect(expired != nil)
    }

    @Test("액션 스트립이 항목 수에 따라 그려진다")
    func actionStripRenders() {
        for count in [1, 2, 4, 6] {
            let image = render(CueActionStrip(state: state(itemCount: count)))
            #expect(image != nil, "항목 \(count)개에서 렌더 실패")
        }
    }

    // MARK: 표현 규칙 — 값으로 직접 단언

    @Test("컴팩트 심볼은 단계를 따른다")
    func compactSymbolFollowsPhase() {
        #expect(CueActivityStyle.compactSymbol(state()) == "flashlight.on.fill")
        #expect(CueActivityStyle.compactSymbol(state(selectedIndex: 2)) == "stopwatch")
        #expect(CueActivityStyle.compactSymbol(state(phase: .executed)) == "checkmark.circle.fill")
        #expect(CueActivityStyle.compactSymbol(state(phase: .cancelled)) == "xmark.circle.fill")
    }

    @Test("항목이 없으면 대체 심볼을 쓴다")
    func compactSymbolFallsBack() {
        #expect(CueActivityStyle.compactSymbol(state(itemCount: 0)) == "button.horizontal.top.press")
    }

    @Test("결과 심볼은 성공과 취소를 구분한다")
    func resultSymbolDistinguishesPhases() {
        #expect(CueActivityStyle.resultSymbol(.executed) == "checkmark.circle.fill")
        #expect(CueActivityStyle.resultSymbol(.cancelled) == "xmark.circle.fill")
    }

    @Test("색조는 단계를 따른다")
    func tintFollowsPhase() {
        #expect(CueActivityStyle.tint(state()) == .yellow)
        #expect(CueActivityStyle.tint(state(phase: .executed)) == .green)
        #expect(CueActivityStyle.tint(state(phase: .cancelled)) == .secondary)
    }

    // MARK: 자동화 손잡이

    @Test("스트립 타일 식별자는 언어와 무관하게 안정적이다")
    func tileIdentifiersAreStable() {
        #expect(CueID.tile(0) == "cue.tile.0")
        #expect(CueID.tile(3) == "cue.tile.3")
        // 세트 행은 순서가 아니라 식별자로 잡는다 — 순서가 바뀌어도 같은 손잡이를 가리킨다.
        let id = UUID()
        #expect(CueID.setRow(id) == "cue.set.\(id.uuidString)")
    }
}

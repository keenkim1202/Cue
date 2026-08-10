import XCTest

/// 통합 스모크 (L4).
///
/// 앱을 실제로 띄워, 단위 테스트와 렌더 테스트가 **원리적으로** 볼 수 없는 것만 확인한다.
///
/// - 인텐트 배선이 실제 탭에서 끝까지 도는가
/// - 현지화가 실제 화면에 적용되는가 — `Text(String)`은 현지화되지 않는데,
///   이 버그는 영어로 실행해봐야만 드러난다
///
/// 셀렉터는 전부 `CueID` 식별자다. 라벨로 잡으면 로케일을 바꾸는 순간 조용히 빗나가고,
/// 아무 일도 일어나지 않은 것을 통과로 오독하게 된다.
@MainActor
final class CueSmokeUITests: XCTestCase {

    override func setUp() async throws {
        continueAfterFailure = false
    }

    // MARK: 실행 도우미

    private enum Locale: String, CaseIterable {
        case ko, en

        /// 이 로케일에서 누름 행에 보여야 하는 문구의 일부.
        var pressLabelFragment: String {
            switch self {
            case .ko: return "Cue 누르기"
            case .en: return "Press Cue"
            }
        }
    }

    private func launch(_ locale: Locale) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(locale.rawValue))", "-AppleLocale", locale.rawValue]
        app.launch()
        return app
    }

    /// 기본 구성으로 되돌려 시작점을 고정한다. 앱에 테스트 전용 코드를 넣지 않으려고
    /// 화면의 초기화 버튼을 쓴다.
    private func resetState(_ app: XCUIApplication) {
        let reset = app.buttons[CueID.reset]
        // 목록 맨 아래에 있으므로 보일 때까지 스크롤한다.
        var tries = 0
        while !reset.isHittable && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        if reset.isHittable { reset.tap() }

        // SwiftUI List는 지연 로딩이라, 아래로 스크롤한 상태에서는 위쪽 행이 접근성 트리에서
        // 사라진다. 맨 위로 돌아가야 `cue.press`를 다시 찾을 수 있다.
        for _ in 0..<8 where !app.buttons[CueID.press].exists {
            app.swipeDown()
        }
    }

    private func strip(_ app: XCUIApplication) -> [XCUIElement] {
        (0..<4).map { app.buttons[CueID.tile($0)] }
    }

    // MARK: 실행 · 배선

    func test_press배선이_액션스트립을_띄운다() {
        for locale in Locale.allCases {
            let app = launch(locale)
            let press = app.buttons[CueID.press]
            XCTAssertTrue(press.waitForExistence(timeout: 10), "[\(locale)] 누름 버튼이 없다")

            press.tap()

            let tiles = strip(app)
            XCTAssertTrue(tiles[0].waitForExistence(timeout: 3), "[\(locale)] 액션 스트립이 뜨지 않았다")
            for (index, tile) in tiles.enumerated() {
                XCTAssertTrue(tile.exists, "[\(locale)] 타일 \(index)이 없다")
            }
            app.terminate()
        }
    }

    func test_창이_지나면_자동_실행된다() {
        for locale in Locale.allCases {
            let app = launch(locale)
            resetState(app)

            let press = app.buttons[CueID.press]
            XCTAssertTrue(press.waitForExistence(timeout: 10))
            press.tap()
            XCTAssertTrue(strip(app)[0].waitForExistence(timeout: 3))

            // 창(2초)이 닫히기를 기다린다.
            XCTAssertTrue(
                waitForDisappearance(of: strip(app)[0], timeout: 6),
                "[\(locale)] 창이 닫혔는데도 스트립이 남아 있다"
            )

            // 로그 지우기 버튼은 기록이 있을 때만 나타난다 — 로케일과 무관한 실행 증거다.
            XCTAssertTrue(
                app.buttons[CueID.clearLog].waitForExistence(timeout: 3),
                "[\(locale)] 실행 기록이 남지 않았다"
            )
            app.terminate()
        }
    }

    func test_같은_타일을_두_번_탭하면_기다리지_않고_실행된다() {
        let app = launch(.ko)
        resetState(app)

        let press = app.buttons[CueID.press]
        XCTAssertTrue(press.waitForExistence(timeout: 10))
        press.tap()

        let tile = app.buttons[CueID.tile(2)]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))

        tile.tap()
        let secondTapAt = Date()
        tile.tap()

        // 자동 커밋이라면 마지막 탭 + 2.0초에 일어난다. 그보다 빨리 사라지면 더블 탭이 만든 실행이다.
        //
        // 두 탭 사이가 2초를 넘어가면(느린 기기) 첫 탭이 자동 실행되고 두 번째 탭이 창을
        // 다시 열어 이 단언이 깨진다. 그때는 실패가 아니라 측정 실패이므로 간격을 함께 남긴다.
        let gap = Date().timeIntervalSince(secondTapAt)
        let disappeared = waitForDisappearance(of: tile, timeout: 1.5)
        XCTAssertTrue(
            disappeared,
            "더블 탭으로 즉시 확정되지 않았다 (두 번째 탭 이후 경과 \(String(format: "%.2f", gap))초)"
        )

        XCTAssertTrue(app.buttons[CueID.clearLog].waitForExistence(timeout: 3), "실행 기록이 없다")
        app.terminate()
    }

    // MARK: 현지화 — 통합만이 볼 수 있는 것

    func test_로케일에_따라_실제_화면_문구가_바뀐다() {
        for locale in Locale.allCases {
            let app = launch(locale)
            let press = app.buttons[CueID.press]
            XCTAssertTrue(press.waitForExistence(timeout: 10))

            // 식별자로 찾고, 라벨은 내용 검증에만 쓴다.
            let label = press.label
            XCTAssertTrue(
                label.contains(locale.pressLabelFragment),
                "[\(locale)] 문구가 현지화되지 않았다: \(label)"
            )
            app.terminate()
        }
    }

    /// `Text(String)`은 현지화되지 않는다. 「어디에 붙이나」 안내가 이 함정에 걸렸던 자리라
    /// 영어 실행에서 한국어가 남아 있지 않은지 본다.
    func test_안내_문구도_현지화된다() {
        let app = launch(.en)
        XCTAssertTrue(app.buttons[CueID.press].waitForExistence(timeout: 10))

        var tries = 0
        while !app.staticTexts["Control Center"].exists && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(
            app.staticTexts["Control Center"].exists,
            "영어 실행에서 안내 문구가 현지화되지 않았다"
        )
        app.terminate()
    }

    // MARK: 유틸

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            usleep(80_000)
        }
        return !element.exists
    }
}


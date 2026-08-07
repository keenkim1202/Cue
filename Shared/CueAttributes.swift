import ActivityKit
import Foundation

/// Live Activity · 다이나믹 아일랜드가 그리는 내용.
///
/// 순환 중에는 "지금 손을 떼면 무엇이 실행될지"를 보여주는 것이 이 앱의 핵심이다.
struct CueAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var setName: String
        var items: [Item]
        var selectedIndex: Int
        var phase: Phase
        /// 실행 결과 한 줄. `phase == .executed`일 때만 채워진다.
        var resultText: String?
        /// 이 시각이 지나면 자동 실행된다. 컴팩트 뷰의 카운트다운에 쓴다.
        var commitAt: Date?
        /// 결과 화면에 "열기" 버튼을 띄울지. `.openApp` 액션을 실행했을 때만 참이다.
        ///
        /// `LiveActivityIntent`는 앱을 전면으로 못 올린다. 그래서 실행 자체는 백그라운드에서
        /// 끝내고, 앱을 여는 것만 `openAppWhenRun = true`인 별도 인텐트 버튼으로 넘긴다.
        var showsOpenButton: Bool = false

        struct Item: Codable, Hashable {
            /// `CueAction.id`의 문자열 표현.
            ///
            /// 카드는 만들어진 시점의 스냅샷이다. 세트가 바뀌면 인덱스는 다른 액션을 가리키게
            /// 되므로, 탭은 인덱스가 아니라 이 식별자로 실어 나른다.
            var id: String
            var title: String
            var symbol: String
        }

        enum Phase: String, Codable, Hashable {
            /// 누름이 계속될 수 있는 상태. 한 번 더 누르면 다음 항목.
            case cycling
            /// 실행 완료. 잠시 결과를 보여주고 사라진다.
            case executed
            /// 취소됨.
            case cancelled
        }

        var selected: Item? {
            items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
        }

        var positionText: String { "\(selectedIndex + 1)/\(items.count)" }

        /// 카운트다운으로 그릴 남은 구간. 이미 지났으면 `nil`.
        ///
        /// `Date()...commitAt`을 그대로 쓰면 `commitAt`이 과거일 때 범위 생성이 트랩된다
        /// (`Range requires lowerBound <= upperBound`). 커밋이 돌지 못해 카드가 `.cycling`인
        /// 채로 굳으면 반드시 그 상황이 되므로, 시각을 한 번만 읽어 비교하고 넘긴다.
        func remainingCountdown(now: Date = Date()) -> ClosedRange<Date>? {
            guard let commitAt, commitAt > now else { return nil }
            return now...commitAt
        }
    }

    /// 액티비티를 다시 찾기 위한 식별자. 세트가 바뀌어도 액티비티는 하나만 유지한다.
    var sessionName: String
}

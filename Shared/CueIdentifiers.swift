import Foundation

/// UI 자동화가 붙잡을 손잡이.
///
/// 라벨로 요소를 찾으면 **번역되는 순간 조용히 깨진다**. 실제로 이 프로젝트에 로컬라이제이션을
/// 넣자 한국어 라벨 셀렉터가 전부 빗나갔고, 아무 일도 일어나지 않은 것을 "회귀 없음"으로
/// 잘못 읽을 뻔했다. 부분 일치도 위험하다 — `스톱워치`는 액션 타일뿐 아니라
/// `기본, 손전등 · 순간 기록 · 스톱워치 · 앱 열기`라는 세트 행에도 걸린다.
///
/// 그래서 언어와 무관한 식별자를 따로 붙인다.
/// SwiftUI 주의: 컨테이너에 `accessibilityIdentifier`를 붙이면 **자식들의 식별자를 전부
/// 덮어쓴다**. 실제로 순환 프리뷰 컨테이너에 붙였다가 타일 4개가 모두 컨테이너 식별자로
/// 나와 UI 테스트가 타일을 못 찾았다. 손잡이는 잡을 요소에 직접 붙인다.
enum CueID {
    // 앱
    static let press = "cue.press"
    static let clearLog = "cue.clearLog"
    static let reset = "cue.reset"
    static let editSets = "cue.editSets"
    static let addSet = "cue.addSet"
    static let doneEditing = "cue.doneEditing"

    /// 액션 세트 행. 순서가 아니라 세트 식별자로 잡는다.
    static func setRow(_ id: UUID) -> String { "cue.set.\(id.uuidString)" }

    // 액션 스트립 — 앱과 Live Activity가 같은 값을 쓴다
    static func tile(_ index: Int) -> String { "cue.tile.\(index)" }

    // Live Activity / 다이나믹 아일랜드
    static let cancel = "cue.cancel"
    /// 카드의 빈 곳 — 탭하면 중단된다. 명시적인 취소 버튼과 구분해야 UI 테스트가 헷갈리지 않는다.
    static let cancelBackdrop = "cue.cancelBackdrop"
    static let confirm = "cue.confirm"
    static let openButton = "cue.open"
}

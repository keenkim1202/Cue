import Foundation

/// UI 자동화가 붙잡을 손잡이.
///
/// 라벨로 요소를 찾으면 **번역되는 순간 조용히 깨진다**. 실제로 이 프로젝트에 로컬라이제이션을
/// 넣자 한국어 라벨 셀렉터가 전부 빗나갔고, 아무 일도 일어나지 않은 것을 "회귀 없음"으로
/// 잘못 읽을 뻔했다. 부분 일치도 위험하다 — `스톱워치`는 액션 타일뿐 아니라
/// `기본, 손전등 · 순간 기록 · 스톱워치 · 앱 열기`라는 세트 행에도 걸린다.
///
/// 그래서 언어와 무관한 식별자를 따로 붙인다.
enum CueID {
    // 앱
    static let press = "cue.press"
    static let cyclingPreview = "cue.cyclingPreview"
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
    static let confirm = "cue.confirm"
    static let openButton = "cue.open"
}

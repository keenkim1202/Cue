import AppIntents
import SwiftUI
import WidgetKit

/// 제어 센터 · 잠금화면 · **액션 버튼**에 동시에 올라가는 컨트롤.
/// 하나를 만들면 세 표면을 모두 얻는다. 어디에 붙일지는 사용자가 고른다.
struct CuePressControl: ControlWidget {
    static let kind = "com.keen.cue.control.press"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: CuePressIntent()) {
                Label("Cue", systemImage: "button.horizontal.top.press")
            }
        }
        .displayName("Cue 누르기")
        .description("현재 세트의 다음 액션으로 순환합니다.")
    }
}

/// 두 번째 컨트롤 — 액션 세트 전환.
///
/// `ControlWidgetToggle`은 `LiveActivityIntent`와 함께 쓰면 상태가 되돌아가는
/// 문제가 보고돼 있어(Apple 개발자 포럼 757271 계열) 버튼으로 만들었다.
struct CueSetControl: ControlWidget {
    static let kind = "com.keen.cue.control.set"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: CueNextSetIntent()) {
                Label("Cue 세트", systemImage: "square.stack.3d.up")
            }
        }
        .displayName("Cue 세트 전환")
        .description("액션 버튼이 순환할 액션 묶음을 바꿉니다.")
    }
}

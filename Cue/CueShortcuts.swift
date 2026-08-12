import AppIntents

/// 단축어 앱과 액션 버튼 설정 화면에 노출시킨다.
///
/// **앱 타깃에만 둔다.** 인텐트 정의(`Shared/CueIntents.swift`)는 Live Activity의 버튼이
/// 참조해야 해서 위젯 확장에도 함께 컴파일되지만, `AppShortcutsProvider`까지 양쪽에 들어가면
/// 시스템이 같은 앱에 대해 제공자를 두 벌 보게 된다. 그러면 액션 버튼에 걸어 둔 단축어가
/// 위젯 확장 쪽 사본으로 풀려 앱 프로세스 대신 확장에서 실행된다 — 확장에는 카메라 사용
/// 설명이 없어 손전등 액션이 조용히 실패한다. 실제로 첫 TestFlight 빌드가 그렇게 깨졌다.
struct CueShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CuePressIntent(),
            phrases: ["\(.applicationName) 누르기", "\(.applicationName) 실행"],
            shortTitle: "Cue 누르기",
            systemImageName: "button.horizontal.top.press"
        )
        AppShortcut(
            intent: CueNextSetIntent(),
            phrases: ["\(.applicationName) 세트 바꾸기"],
            shortTitle: "다음 세트",
            systemImageName: "square.stack.3d.up"
        )
    }
}

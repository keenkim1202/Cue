import SwiftUI

@main
struct CueApp: App {
    init() {
        // 기본 구성을 심는 것은 앱의 책임이다. 위젯 확장은 읽기만 한다.
        CueStore.bootstrapIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

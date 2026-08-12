import SwiftUI
import UIKit

@main
struct CueApp: App {
    init() {
        // 기본 구성을 심는 것은 앱의 책임이다. 위젯 확장은 읽기만 한다.
        CueStore.bootstrapIfNeeded()
        // 백그라운드 유예를 쓰는 구현으로 갈아끼운다. `UIApplication`이 앱 확장에서
        // 막혀 있어 기본값은 유예를 확보하지 못한다.
        CueEngine.scheduler = CueBackgroundCommitScheduler()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task { await open(url) }
                }
        }
    }

    /// 카드가 넘긴 딥링크를 처리한다.
    ///
    /// 앱만 여는 링크면 뜬 것으로 끝이다. 주소가 실려 있으면 여기서 연다 —
    /// `widgetURL`은 https를 줘도 Safari가 아니라 이 앱을 열기 때문에, 실제로 여는 것은
    /// 전면에 올라온 앱의 몫이다.
    @MainActor
    private func open(_ url: URL) async {
        guard url.scheme == CueDeepLink.scheme else { return }
        // 앱이 떴으면 카드는 쓸모가 없다.
        await CueEngine.presenter.endAll()
        guard let target = CueDeepLink.targetURL(from: url) else { return }
        await UIApplication.shared.open(target)
    }
}

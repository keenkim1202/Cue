import SwiftUI
import WidgetKit

@main
struct MyActionWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CueLiveActivity()
        CuePressControl()
        CueSetControl()
    }
}

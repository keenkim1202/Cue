import SwiftUI
import WidgetKit

@main
struct CueWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CueLiveActivity()
        CuePressControl()
        CueSetControl()
    }
}

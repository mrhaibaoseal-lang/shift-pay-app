import WidgetKit
import SwiftUI

@main
struct ShiftPayWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShiftPayHomeWidget()
        #if canImport(ActivityKit)
        ShiftLiveActivityWidget()
        #endif
    }
}

import QuickSummaryShared
import SwiftData
import SwiftUI

@main
struct QuickSummaryApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(SharedDataContainer.shared)
  }
}

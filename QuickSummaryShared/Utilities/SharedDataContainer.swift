import Foundation
import SwiftData

public struct SharedDataContainer {
  public static let shared: ModelContainer = {
    let schema = Schema([
      SummaryItem.self,
      ChatMessage.self,
    ])

    let groupID = AppConstants.AppGroups.identifier
    let storeURL = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: groupID)!
      .appendingPathComponent("QuickSummary.sqlite")
    print("[QuickSummary] Using shared SwiftData store at: \(storeURL.path)")

    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      groupContainer: .identifier(groupID)
    )

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()
}

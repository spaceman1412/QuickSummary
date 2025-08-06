import Combine
import Foundation

public class UsageTrackerService: ObservableObject {
  public static let shared = UsageTrackerService()

  private let userDefaults: UserDefaults

  // Published properties for UI updates
  @Published public var totalMinutesSaved: Double = 0
  @Published public var totalSummariesCreated: Int = 0
  @Published public var totalAPICallsCount: Int = 0

  // Keys for UserDefaults
  private enum Keys {
    static let totalMinutesSaved = "totalMinutesSaved"
    static let totalSummariesCreated = "totalSummariesCreated"
    static let totalAPICallsCount = "totalAPICallsCount"
    static let lastUsedDate = "lastUsedDate"
  }

  private init() {
    // Use shared container for App Groups when available
    let appGroupID = "group.com.catboss.quicksummary"
    self.userDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    // Load existing values from UserDefaults
    self.totalMinutesSaved = userDefaults.double(forKey: Keys.totalMinutesSaved)
    self.totalSummariesCreated = userDefaults.integer(forKey: Keys.totalSummariesCreated)
    self.totalAPICallsCount = userDefaults.integer(forKey: Keys.totalAPICallsCount)
  }

  // MARK: - Minutes Saved Tracking

  public func addToTotalMinutesSaved(_ minutes: Double) {
    totalMinutesSaved += minutes
    userDefaults.set(totalMinutesSaved, forKey: Keys.totalMinutesSaved)
    incrementSummariesCreated()
    updateLastUsedDate()
  }

  // MARK: - Summary Statistics

  private func incrementSummariesCreated() {
    totalSummariesCreated += 1
    userDefaults.set(totalSummariesCreated, forKey: Keys.totalSummariesCreated)
  }

  // MARK: - API Usage Tracking (for developer analytics)

  public func incrementAPICallCount() {
    totalAPICallsCount += 1
    userDefaults.set(totalAPICallsCount, forKey: Keys.totalAPICallsCount)
  }

  // MARK: - Usage Patterns

  public var lastUsedDate: Date? {
    get {
      userDefaults.object(forKey: Keys.lastUsedDate) as? Date
    }
    set {
      userDefaults.set(newValue, forKey: Keys.lastUsedDate)
    }
  }

  private func updateLastUsedDate() {
    lastUsedDate = Date()
  }

  // MARK: - Formatted Metrics

  public var formattedMinutesSaved: String {
    let minutes = totalMinutesSaved

    if minutes >= 60 {
      let hours = minutes / 60
      return String(format: "%.1f hours", hours)
    } else {
      return String(format: "%.0f minutes", minutes)
    }
  }

  public var dailyAverageMinutesSaved: Double {
    guard let firstUse = lastUsedDate else { return 0 }

    let daysSinceFirstUse =
      Calendar.current.dateComponents([.day], from: firstUse, to: Date()).day ?? 1
    return totalMinutesSaved / Double(max(daysSinceFirstUse, 1))
  }
}

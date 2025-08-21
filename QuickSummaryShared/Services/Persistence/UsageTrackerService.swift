import Combine
import CoreFoundation
import Foundation

@MainActor
public class UsageTrackerService: ObservableObject {
  public static let shared = UsageTrackerService()

  private let userDefaults: UserDefaults
  private let appGroupID = "group.com.catboss.quicksummary"

  // Darwin notification for cross-process sync
  private let darwinNotificationName = "group.com.catboss.quicksummary.usageUpdated"
  private var darwinObserverAdded = false

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
    self.userDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    // Load existing values from UserDefaults
    self.totalMinutesSaved = userDefaults.double(forKey: Keys.totalMinutesSaved)
    self.totalSummariesCreated = userDefaults.integer(forKey: Keys.totalSummariesCreated)
    self.totalAPICallsCount = userDefaults.integer(forKey: Keys.totalAPICallsCount)

    // Observe cross-process updates via Darwin notifications
    addDarwinObserverIfNeeded()
  }

  // Note: Singleton lives for app lifetime; explicit removal not required

  // MARK: - Minutes Saved Tracking

  public func addToTotalMinutesSaved(_ minutes: Double) {
    totalMinutesSaved += minutes
    userDefaults.set(totalMinutesSaved, forKey: Keys.totalMinutesSaved)
    incrementSummariesCreated()
    updateLastUsedDate()
    postDarwinNotification()
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
    postDarwinNotification()
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

  // MARK: - Cross-process sync helpers

  public func reloadFromStore() {
    // Re-read values from the shared UserDefaults and publish
    let minutes = userDefaults.double(forKey: Keys.totalMinutesSaved)
    let summaries = userDefaults.integer(forKey: Keys.totalSummariesCreated)
    let apiCalls = userDefaults.integer(forKey: Keys.totalAPICallsCount)

    // Assign to @Published properties
    totalMinutesSaved = minutes
    totalSummariesCreated = summaries
    totalAPICallsCount = apiCalls
  }

  private func postDarwinNotification() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterPostNotification(
      center, CFNotificationName(darwinNotificationName as CFString), nil, nil, true)
  }

  private func addDarwinObserverIfNeeded() {
    guard !darwinObserverAdded else { return }
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
    CFNotificationCenterAddObserver(
      center, observer,
      { (_, observer, name, _, _) in
        guard let observer = observer else { return }
        let instance = Unmanaged<UsageTrackerService>.fromOpaque(observer).takeUnretainedValue()
        Task { @MainActor in
          instance.reloadFromStore()
        }
      }, darwinNotificationName as CFString, nil, .deliverImmediately)
    darwinObserverAdded = true
  }

  private func removeDarwinObserverIfNeeded() {
    guard darwinObserverAdded else { return }
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
    CFNotificationCenterRemoveEveryObserver(center, observer)
    darwinObserverAdded = false
  }
}

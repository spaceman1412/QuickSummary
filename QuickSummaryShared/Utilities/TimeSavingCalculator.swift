import Foundation

public struct TimeSavingCalculator {
  /// Average reading speed in words per minute (as defined in spec)
  private static let averageReadingSpeedWPM: Double = 225

  /// Calculates the minutes saved by reading a summary instead of the original text
  public static func calculateMinutesSaved(originalText: String, summaryText: String) -> Double {
    let originalReadingTime = calculateReadingTime(for: originalText)
    let summaryReadingTime = calculateReadingTime(for: summaryText)

    let timeSaved = originalReadingTime - summaryReadingTime
    return max(timeSaved, 0)  // Ensure we never return negative time saved
  }

  /// Calculates reading time in minutes for given text
  public static func calculateReadingTime(for text: String) -> Double {
    let wordCount = countWords(in: text)
    return Double(wordCount) / averageReadingSpeedWPM
  }

  /// Counts the number of words in a given text
  public static func countWords(in text: String) -> Int {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else { return 0 }

    // Split by whitespace and filter out empty strings
    let words = trimmedText.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }

    return words.count
  }

  /// Formats time in minutes to a human-readable string
  public static func formatTime(minutes: Double) -> String {
    if minutes < 1 {
      let seconds = Int(minutes * 60)
      return "\(seconds) second\(seconds == 1 ? "" : "s")"
    } else if minutes < 60 {
      let roundedMinutes = Int(round(minutes))
      return "\(roundedMinutes) minute\(roundedMinutes == 1 ? "" : "s")"
    } else {
      let hours = Int(minutes / 60)
      let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))

      if remainingMinutes == 0 {
        return "\(hours) hour\(hours == 1 ? "" : "s")"
      } else {
        return "\(hours)h \(remainingMinutes)m"
      }
    }
  }

  /// Calculates estimated reading time for text and returns formatted string
  public static func estimatedReadingTime(for text: String) -> String {
    let minutes = calculateReadingTime(for: text)
    return formatTime(minutes: minutes)
  }

  /// Provides reading speed context for users
  public static var readingSpeedInfo: String {
    return "Based on an average reading speed of \(Int(averageReadingSpeedWPM)) words per minute"
  }
}

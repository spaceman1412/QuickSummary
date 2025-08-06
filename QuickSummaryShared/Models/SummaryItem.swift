import Foundation
import SwiftData

@Model
public final class SummaryItem {
	@Attribute(.unique) public var id: UUID
	public var originalText: String
	public var summaryText: String
	public var createdAt: Date
	public var minutesSaved: Double
	public var chatMessages: [ChatMessage]
	public var title: String?
	
	public init(
		originalText: String, summaryText: String, minutesSaved: Double,
		chatMessages: [ChatMessage] = [], title: String? = nil
	) {
		self.id = UUID()
		self.originalText = originalText
		self.summaryText = summaryText
		self.createdAt = Date()
		self.minutesSaved = minutesSaved
		self.chatMessages = chatMessages
		self.title = title
	}
}

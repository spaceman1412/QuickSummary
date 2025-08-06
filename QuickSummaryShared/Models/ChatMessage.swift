import Foundation
import SwiftData

@Model
public final class ChatMessage {
  public var id: UUID
  public var content: String
  public var isFromUser: Bool
  public var timestamp: Date

  public init(content: String, isFromUser: Bool) {
    self.id = UUID()
    self.content = content
    self.isFromUser = isFromUser
    self.timestamp = Date()
  }
}

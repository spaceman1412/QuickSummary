import SwiftUI

struct ErrorView: View {
  let title: String
  let message: String
  let actionTitle: String
  let action: () -> Void

  init(
    title: String = "Error",
    message: String,
    actionTitle: String = "Try Again",
    action: @escaping () -> Void = {}
  ) {
    self.title = title
    self.message = message
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 50))
        .foregroundColor(.orange)

      Text(title)
        .font(.headline)
        .foregroundColor(.primary)

      Text(message)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      Button(action: action) {
        Text(actionTitle)
          .frame(minWidth: 120)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(10)
      }
    }
    .padding(24)
    .frame(maxWidth: 300)
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct CenteredErrorView: View {
  let title: String
  let message: String
  let actionTitle: String
  let action: () -> Void

  init(
    title: String = "Error",
    message: String,
    actionTitle: String = "Try Again",
    action: @escaping () -> Void = {}
  ) {
    self.title = title
    self.message = message
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    VStack {
      Spacer()
      ErrorView(
        title: title,
        message: message,
        actionTitle: actionTitle,
        action: action
      )
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.clear)
  }
}

#Preview {
  ErrorView(
    message: "Something went wrong. Please try again.",
    action: {}
  )
}

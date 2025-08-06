import SwiftUI

struct LoadingView: View {
  let message: String

  init(message: String = "Loading...") {
    self.message = message
  }

  var body: some View {
    VStack(spacing: 16) {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
        .scaleEffect(1.2)

      Text(message)
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .padding(24)
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct CenteredLoadingView: View {
  let message: String

  init(message: String = "Loading...") {
    self.message = message
  }

  var body: some View {
    VStack {
      Spacer()
      LoadingView(message: message)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.clear)
  }
}

#Preview {
  LoadingView(message: "Generating summary...")
}

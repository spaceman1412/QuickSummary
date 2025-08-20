import SwiftUI

struct WhatsNewView: View {
    let version: String
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var textScale: CGFloat = 1.0
    @State private var iconScale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 8.0

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Close") { onDismiss() }
                    .foregroundColor(.secondary)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.accentColor)
                    .shadow(
                        color: Color.accentColor.opacity(0.7), radius: showContent ? glowRadius : 0,
                        y: 6
                    )
                    .scaleEffect(showContent ? iconScale : 0.9)
                    .opacity(showContent ? 1 : 0)

                VStack(spacing: 10) {
                    Text("What’s New in \(version)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .scaleEffect(showContent ? textScale : 0.9)

                    VStack(alignment: .center, spacing: 12) {
                        // Auto Detect Language
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                            (Text("Auto‑Detect ") + Text("Language").bold()
                                + Text(" – respond in the same language as the content."))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.body)
                        .foregroundColor(.secondary)

                        // Bring Your Own API Key
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.blue)
                            (Text("Your ") + Text("Gemini API key").bold()
                                + Text(" – use your own free key to avoid overload."))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.body)
                        .foregroundColor(.secondary)

                        // Performance
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.blue)
                            (Text("Performance – ") + Text("improved speed at processing").bold()
                                + Text(" in the share extension."))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.body)
                        .foregroundColor(.secondary)

                        // Bug Fixes
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.blue)
                            Text(
                                "Bug fixes and stability improvements across share sheet, settings, and streaming."
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: 560)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                }
                .padding(.horizontal)
            }

            Spacer()

            Button("Continue") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 40)

            Spacer(minLength: 8)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear(perform: handleAnimations)
    }

    private func handleAnimations() {
        withAnimation(.interpolatingSpring(stiffness: 100, damping: 12).delay(0.1)) {
            showContent = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                textScale = 1.03
                iconScale = 1.05
                glowRadius = 25.0
            }
        }
    }
}

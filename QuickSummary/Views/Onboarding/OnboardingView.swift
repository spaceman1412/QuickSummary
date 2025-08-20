import AVKit
import QuickSummaryShared
import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var settingsService = SettingsService.shared
    @Namespace private var animation

    // Animations for AI info page (to sync with other pages)
    @State private var aiShowContent = false
    @State private var aiTextScale: CGFloat = 1.0
    @State private var aiIconScale: CGFloat = 1.0
    @State private var aiGlowRadius: CGFloat = 8.0

    // Check if this is opened from settings (when user already completed onboarding)
    private var isReviewMode: Bool {
        settingsService.hasCompletedOnboarding
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if isReviewMode {
                    Button("Close") {
                        hasCompletedOnboarding = false
                    }
                    .padding()
                    .foregroundColor(.secondary)
                } else {
                    Button("Skip") {
                        withAnimation {
                            settingsService.markOnboardingCompleted()
                        }
                    }
                    .padding()
                    .foregroundColor(.secondary)
                }
            }

            TabView(selection: $viewModel.selectedTab) {
                // Screen 1: Welcome
                welcomePage.tag(0)

                // Screen 2: Summarize from anywhere (Video)
                VideoOnboardingPage(
                    videoName: "share",
                    title: "Summarize From Anywhere",
                    description:
                        "Find a long article, YouTube video or PDF File? Tap the Share button and choose QuickSummary to get a concise summary in seconds.",
                    isVisible: viewModel.selectedTab == 1
                ).tag(1)

                // Screen 3: Pin for speed (Video)
                VideoOnboardingPage(
                    videoName: "pin",
                    title: "Pin It for One-Tap Access",
                    description:
                        "For the fastest experience, add QuickSummary to your Favorites in the Share Sheet and drag it to the front.",
                    isVisible: viewModel.selectedTab == 2
                ).tag(2)

                // Screen 4: AI Service Info (styled)
                aiServiceInfoPage.tag(3)

                // Screen 5: All Set
                finalPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    if viewModel.selectedTab == index {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 8)
                            .cornerRadius(4)
                            .matchedGeometryEffect(id: "pageIndicator", in: animation)
                    } else {
                        Circle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .animation(.spring(), value: viewModel.selectedTab)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }

    // MARK: - Page Views

    private var welcomePage: some View {
        VStack {
            Spacer()
            OnboardingPageView(
                imageName: "bolt.fill",
                title: "Insight in a Flash",
                description:
                    "From long content to key insights, instantly. Speed is our specialty.",
                isVisible: viewModel.selectedTab == 0,
                iconColor: .yellow
            )
            Spacer()
            Spacer()
        }
    }

    private func standardPage(imageName: String, title: String, description: String) -> some View {
        VStack {
            Spacer()
            OnboardingPageView(
                imageName: imageName,
                title: title,
                description: description,
                isVisible: viewModel.selectedTab == 3
            )
            Spacer()
            Spacer()
        }
    }

    private var aiServiceInfoPage: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "bolt.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.accentColor)
                    .shadow(
                        color: Color.accentColor.opacity(0.7),
                        radius: aiShowContent ? aiGlowRadius : 0, y: 6
                    )
                    .scaleEffect(aiShowContent ? aiIconScale : 0.9)
                    .opacity(aiShowContent ? 1 : 0)

                VStack(spacing: 10) {
                    Text("About AI Service")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .scaleEffect(aiShowContent ? aiTextScale : 0.9)

                    VStack(alignment: .center, spacing: 12) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                            Text("QuickSummary uses ") + Text("Gemini AI").bold()
                            Text(".")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.body)
                        .foregroundColor(.secondary)

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Shared usage can sometimes cause temporary ")
                                + Text("overload").bold()
                            Text(".")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.body)
                        .foregroundColor(.secondary)

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "switch.2")
                                .foregroundColor(.blue)
                            Text("Tip: switch to another ") + Text("model").bold()
                                + Text(" to avoid it.")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.body)
                        .foregroundColor(.secondary)

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.blue)
                            Text("You can also bring your own free ")
                                + Text("Gemini API key").bold() + Text(" to avoid overload.")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: 560)
                    .multilineTextAlignment(.center)
                    .opacity(aiShowContent ? 1 : 0)
                }
                .padding(.horizontal)
            }

            Spacer()
            Spacer()
        }
        .onAppear(perform: handleAIPageAnimations)
        .onChange(of: viewModel.selectedTab) { _, _ in handleAIPageAnimations() }
    }

    private func handleAIPageAnimations() {
        let visible = (viewModel.selectedTab == 3)
        withAnimation(.interpolatingSpring(stiffness: 100, damping: 12).delay(0.1)) {
            aiShowContent = visible
        }
        if visible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    aiTextScale = 1.03
                    aiIconScale = 1.05
                    aiGlowRadius = 25.0
                }
            }
        } else {
            withAnimation(.spring()) {
                aiTextScale = 1.0
                aiIconScale = 1.0
                aiGlowRadius = 8.0
            }
        }
    }

    private var finalPage: some View {
        VStack {
            Spacer()
            OnboardingPageView(
                imageName: "checkmark.circle.fill",
                title: "You're Ready to Go!",
                description: "Start saving time and get to the point faster.",
                isVisible: viewModel.selectedTab == 4
            )
            Spacer()
            Button("Start Summarizing") {
                withAnimation {
                    if isReviewMode {
                        hasCompletedOnboarding = false
                    } else {
                        settingsService.markOnboardingCompleted()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 60)
            Spacer()
        }
    }
}

struct OnboardingPageView: View {
    let imageName: String
    let title: String
    let description: String
    let isVisible: Bool
    var iconColor: Color = .accentColor

    @State private var showContent = false
    @State private var textScale: CGFloat = 1.0
    @State private var iconScale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 8.0

    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(iconColor)
                .shadow(color: iconColor.opacity(0.7), radius: showContent ? glowRadius : 0, y: 5)
                .scaleEffect(showContent ? iconScale : 0.9)
                .opacity(showContent ? 1 : 0)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .scaleEffect(showContent ? textScale : 0.9)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal)
            .opacity(showContent ? 1 : 0)
        }
        .padding()
        .onAppear(perform: handleAnimations)
        .onChange(of: isVisible) {
            handleAnimations()
        }
    }

    private func handleAnimations() {
        withAnimation(.interpolatingSpring(stiffness: 100, damping: 12).delay(0.1)) {
            showContent = isVisible
        }

        if isVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    textScale = 1.03
                    iconScale = 1.05
                    glowRadius = 25.0
                }
            }
        } else {
            withAnimation(.spring()) {
                textScale = 1.0
                iconScale = 1.0
                glowRadius = 8.0
            }
        }
    }
}

struct VideoOnboardingPage: View {
    let videoName: String
    let title: String
    let description: String
    let isVisible: Bool

    @State private var showContent = false
    @State private var textScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 30) {
            LoopingVideoPlayer(videoName: videoName, isVisible: isVisible)
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                .padding(.horizontal)
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.95)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .scaleEffect(showContent ? textScale : 1.0)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)

            }
            .padding(.horizontal)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer()
        }
        .onAppear(perform: handleAnimations)
        .onChange(of: isVisible) {
            handleAnimations()
        }
    }

    private func handleAnimations() {
        withAnimation(.easeOut(duration: 0.5)) {
            showContent = isVisible
        }

        if isVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    textScale = 1.03
                }
            }
        } else {
            withAnimation(.spring()) {
                textScale = 1.0
            }
        }
    }
}

// MARK: - Looping Video Player

private struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let isVisible: Bool

    func makeUIView(context: Context) -> PlayerUIView {
        return PlayerUIView(videoName: videoName)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        if isVisible {
            uiView.restart()
        } else {
            uiView.pause()
        }
    }
}

private class PlayerUIView: UIView {
    private var playerLooper: AVPlayerLooper?
    private var player: AVQueuePlayer?
    private let playerLayer = AVPlayerLayer()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    init(videoName: String) {
        super.init(frame: .zero)

        // Setup placeholder
        backgroundColor = UIColor.secondarySystemGroupedBackground
        activityIndicator.color = .gray
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        activityIndicator.startAnimating()

        // Defer the expensive player setup to a background thread.
        DispatchQueue.global(qos: .background).async {
            guard let fileUrl = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
                DispatchQueue.main.async {
                    print("Error: Video file '\(videoName).mp4' not found in bundle.")
                    self.activityIndicator.stopAnimating()
                    // Optionally show an error icon
                }
                return
            }

            let asset = AVAsset(url: fileUrl)
            let item = AVPlayerItem(asset: asset)
            let player = AVQueuePlayer(playerItem: item)
            let playerLooper = AVPlayerLooper(player: player, templateItem: item)

            // switch back to the main thread to update the UI.
            DispatchQueue.main.async {
                self.player = player
                self.playerLooper = playerLooper
                self.playerLayer.player = player
                self.playerLayer.videoGravity = .resizeAspectFill
                self.layer.insertSublayer(self.playerLayer, at: 0)

                self.activityIndicator.stopAnimating()
                self.backgroundColor = .clear
                player.isMuted = true
                self.setNeedsLayout()  // Ensure layoutSubviews is called
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    /// Restarts the video from the beginning.
    func restart() {
        player?.seek(to: .zero)
        player?.play()
    }

    /// Pauses the video.
    func pause() {
        player?.pause()
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(hasCompletedOnboarding: .constant(false))
    }
}

import QuickSummaryShared
import SwiftData
import SwiftUI

struct ContentView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.scenePhase) private var scenePhase
	@StateObject private var settingsService = SettingsService.shared
	@State private var showWhatsNew = false

	var body: some View {
		TabView {
			PasteView()
				.tabItem {
					Label("Summarize", systemImage: "wand.and.rays")
				}

			HistoryView()
				.tabItem {
					Label("History", systemImage: "clock")
				}

			SettingsView()
				.tabItem {
					Label("Settings", systemImage: "gear")
				}
		}
		.tint(.blue)
		.fullScreenCover(
			isPresented: .constant(!settingsService.hasCompletedOnboarding)
		) {
			OnboardingView(hasCompletedOnboarding: $settingsService.hasCompletedOnboarding)
		}
		.onAppear {
			let version = Bundle.main.appVersion ?? "1.1.0"
			if shouldShowWhatsNew(version: version)
				&& SettingsService.shared.hasCompletedOnboarding
			{
				showWhatsNew = true
			}
		}
		.onChange(of: scenePhase) { _, newPhase in
			#if canImport(UIKit)
				guard newPhase == .active else { return }
				if let scene = UIApplication.shared.connectedScenes
					.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
				{
					ReviewRequestService.shared.tryPromptInAppIfEligible(windowScene: scene)
				}
			#endif
		}
		.fullScreenCover(isPresented: $showWhatsNew) {
			let version = Bundle.main.appVersion ?? "1.1.0"
			WhatsNewView(version: version) {
				markWhatsNewShown(version: version)
				showWhatsNew = false
			}
		}
	}
}

#Preview {
	ContentView()
		.modelContainer(for: SummaryItem.self, inMemory: true)
}

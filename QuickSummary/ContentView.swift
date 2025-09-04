import QuickSummaryShared
import SwiftData
import SwiftUI

struct ContentView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.scenePhase) private var scenePhase
	@StateObject private var settingsService = SettingsService.shared
	@StateObject private var usageTracker = UsageTrackerService.shared

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
		.onChange(of: scenePhase) {
			#if canImport(UIKit)
				guard scenePhase == .active else { return }
				// Reload usage stats from shared store to reflect extension updates
				UsageTrackerService.shared.reloadFromStore()
				if let scene = UIApplication.shared.connectedScenes
					.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
				{
					ReviewRequestService.shared.tryPromptInAppIfEligible(windowScene: scene)
				}
			#endif
		}
	}
}

#Preview {
	ContentView()
		.modelContainer(for: SummaryItem.self, inMemory: true)
}

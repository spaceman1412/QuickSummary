import QuickSummaryShared
import SwiftData
import SwiftUI

struct ContentView: View {
	@Environment(\.modelContext) private var modelContext
	@StateObject private var settingsService = SettingsService.shared

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
			isPresented: .constant(!settingsService.hasCompletedOnboarding)) {
			OnboardingView(hasCompletedOnboarding: $settingsService.hasCompletedOnboarding)
		}
	}
}

#Preview {
	ContentView()
		.modelContainer(for: SummaryItem.self, inMemory: true)
}

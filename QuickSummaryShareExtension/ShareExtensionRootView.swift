import QuickSummaryShared
import SwiftData
import SwiftUI

// Content type enum for better UI representation
extension InputType {
	var icon: String {
		switch self {
		case .text:
			return "doc.text"
		case .url:
			return "link"
		case .pdf:
			return "doc.fill"
		case .youtube:
			return "play.rectangle.fill"
		}
	}

	var title: String {
		switch self {
		case .text:
			return "Text Content"
		case .url:
			return "Web Page"
		case .pdf:
			return "PDF Document"
		case .youtube:
			return "YouTube Video"
		}
	}

	var color: Color {
		switch self {
		case .text:
			return .blue
		case .url:
			return .green
		case .pdf:
			return .red
		case .youtube:
			return .red
		}
	}
}

struct ShareExtensionRootView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	@State private var showSummaryScreen = false
	@State private var animatedCircle = false
	@State private var isLoading = false
	@State private var isShowError = false
	@State private var error: Error?
	@State private var extractedText: String?
	@State private var fetchedTitle: String?
	@State private var summaryViewModel: SummaryViewModel?
	let onDone: () -> Void
	private let setting = SettingsService.shared
	let initialText: String
	let initialTitle: String?

	init(
		initialText: String, initialTitle: String?, onDone: @escaping () -> Void
	) {
		self.onDone = onDone
		self.initialText = initialText
		self.initialTitle = initialTitle
	}

	func onSave() {
		onDone()
	}

	func onCancel() {
		onDone()
	}

	var body: some View {
		NavigationStack {
			processingScreen
				.alert("Error", isPresented: $isShowError) {
					Button("OK", role: .cancel) {}
				} message: {
					if let error = error {
						Text(error.localizedDescription)
					}
				}
				.navigationDestination(isPresented: $showSummaryScreen) {
					let _ = print("MyView body is being re-evaluated.")

					if let viewModel = summaryViewModel {
						SummaryView(
							viewModel: viewModel,
							onSave: onSave, onCancel: onCancel, modelContext: modelContext
						)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.padding(.top, 8)
						.ignoresSafeArea(.container, edges: .bottom)
					}
				}
		}
		.frame(
			maxWidth: .infinity, idealHeight: showSummaryScreen ? 700 : 350,
			maxHeight: showSummaryScreen ? 750 : 400
		)
		.animation(.easeInOut(duration: 0.3), value: showSummaryScreen)
		.task {
			// Refresh settings to get latest values from main app
			SettingsService.shared.refreshSettings()

			Task {
				do {
					isLoading = true

					// Fetch title if not provided and content is URL
					if initialTitle == nil
						&& (getInputType(initialText) == .url
							|| getInputType(initialText) == .youtube)
					{
						fetchedTitle = await fetchURLTitle(from: initialText)
					}

					extractedText = try await SummaryGenerator.processInput(
						input: initialText)

					if let text = extractedText {
						if summaryViewModel == nil {
							summaryViewModel = SummaryViewModel(
								initialText: text,
								initialTitle: effectiveTitle,
								inputType: detectedContentType)
						}
						showSummaryScreen = true
					} else {
						throw NSError(domain: "com.catboss.QuickSummary.QuickSummaryShareExtension", code: 101, userInfo: [NSLocalizedDescriptionKey: ErrorMessages.parsingFailed])
					}
				} catch let error {
					self.error = error
					isShowError = true
					isLoading = false
				}
			}
		}
	}

	private var processingScreen: some View {
		VStack(spacing: 12) {
			contentTypeSection

			// Show current AI model
			HStack(spacing: 6) {
				Label(setting.selectedAIModel.title, systemImage: "bolt.circle")
					.font(.caption)
					.foregroundColor(.secondary)
				Spacer()
			}

			HStack(spacing: 6) {
				Label(setting.selectedSummaryStyle.title, systemImage: "doc.text.fill")
					.font(.caption)
					.foregroundColor(.secondary)
				Spacer()
			}

			HStack(spacing: 6) {
				Label(languageDisplayText, systemImage: "globe")
					.font(.caption)
					.foregroundColor(.secondary)
				Spacer()
			}

			VStack(alignment: .leading, spacing: 12) {
				Picker("Summary Length", selection: .constant(setting.selectedSummaryLength)) {
					ForEach(SummaryLength.allCases, id: \.self) { preset in
						Text(preset.title).tag(preset)
					}
				}
				.pickerStyle(SegmentedPickerStyle())
				.disabled(true)
			}

			if isLoading {
				loadingSection
			}
			Spacer()
		}
		.padding()
		.padding(.top, 24)
	}

	private var contentTypeSection: some View {
		VStack(spacing: 16) {
			// Content type indicator
			HStack(spacing: 12) {
				Image(systemName: detectedContentType.icon)
					.font(.system(size: 24, weight: .medium))
					.foregroundColor(detectedContentType.color)
					.frame(width: 48, height: 48)
					.background(
						RoundedRectangle(cornerRadius: 12)
							.fill(detectedContentType.color.opacity(0.1))
					)

				VStack(alignment: .leading, spacing: 4) {
					Text(detectedContentType.title)
						.font(.headline)
						.foregroundColor(.primary)
					Text(initialText)
						.font(.subheadline)
						.foregroundColor(.secondary)
						.lineLimit(2)
				}

				Spacer()
			}
			.padding(16)
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(Color(.systemBackground))
					.shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
			)
		}
	}

	private var loadingSection: some View {
		VStack(spacing: 16) {
			// Animated loading indicator
			ZStack {
				Circle()
					.stroke(Color.blue.opacity(0.2), lineWidth: 4)
					.frame(width: 30, height: 30)

				Circle()
					.trim(from: 0, to: 0.7)
					.stroke(
						LinearGradient(
							colors: [.blue, .purple],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						style: StrokeStyle(lineWidth: 4, lineCap: .round)
					)
					.frame(width: 30, height: 30)
					.rotationEffect(.degrees(animatedCircle ? 360 : 0))
					.onAppear {
						if isLoading {
							withAnimation(
								.easeInOut(duration: 1).repeatForever(
									autoreverses: false)
							) {
								animatedCircle.toggle()
							}
						}
					}
			}

			VStack(spacing: 8) {
				Text("Generating Summary")
					.font(.headline)
					.fontWeight(.semibold)
				Text("Please wait while we analyze your content...")
					.font(.subheadline)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
			}
		}
		.padding(.top, 32)
	}

	private var summaryConfigurationDisplay: some View {
		VStack(alignment: .leading, spacing: 8) {
			Picker("Summary Length", selection: .constant(setting.selectedSummaryLength)) {
				ForEach(SummaryLength.allCases, id: \.self) { length in
					Text(length.title).tag(length)
				}
			}
			.pickerStyle(SegmentedPickerStyle())
			.disabled(true)
		}
		.padding(.vertical, 4)
	}

	// MARK: - Helper Computed Properties

	private var effectiveTitle: String? {
		initialTitle ?? fetchedTitle
	}

	private var detectedContentType: InputType {
		getInputType(initialText)
	}

	private var languageDisplayText: String {
		if setting.summaryLanguage == "auto" {
			return "Language: Auto Detect"
		}
		let name =
			Locale.current.localizedString(forLanguageCode: setting.summaryLanguage)
			?? setting.summaryLanguage
		return "Language: \(name)"
	}
}

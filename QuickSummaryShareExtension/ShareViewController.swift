import DeviceCheck
import FirebaseAppCheck
import FirebaseCore
import QuickSummaryShared
import SwiftUI
import UIKit
import UniformTypeIdentifiers

class YourSimpleAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
	func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
		return DeviceCheckProvider(app: app)
	}
}

class ShareViewController: UIViewController {
	private var extractedText: String?
	private var extractedURL: URL?

	override func viewDidLoad() {
		super.viewDidLoad()

		if FirebaseApp.app() == nil {
			#if DEBUG
				let providerFactory = AppCheckDebugProviderFactory()
				AppCheck.setAppCheckProviderFactory(providerFactory)
			#else
				let providerFactory = YourSimpleAppCheckProviderFactory()
				AppCheck.setAppCheckProviderFactory(providerFactory)
			#endif

			print("Configuring Firebase for Share Extension...")
			FirebaseApp.configure()
		}

		Task {
			await extractSharedContent()
		}
	}

	private func presentSwiftUIRootView(
		with text: String, title: String?
	) {
		let rootView: some View = ShareExtensionRootView(
			initialText: text, initialTitle: title
		) {
			[weak self] in
			self?.extensionContext?.completeRequest(returningItems: nil)
		}
		.modelContainer(SharedDataContainer.shared)

		let hostingController = UIHostingController(rootView: rootView)
		hostingController.sizingOptions = .intrinsicContentSize  // Enable dynamic sizing
		addChild(hostingController)

		// Create container for sheet appearance
		let containerView = UIView()
		containerView.backgroundColor = .systemBackground
		containerView.layer.cornerRadius = 16
		containerView.layer.maskedCorners = [
			.layerMinXMinYCorner, .layerMaxXMinYCorner,
		]  // Top corners only
		containerView.layer.shadowColor = UIColor.black.cgColor
		containerView.layer.shadowOpacity = 0.3
		containerView.layer.shadowOffset = CGSize(width: 0, height: -2)
		containerView.layer.shadowRadius = 8

		view.addSubview(containerView)
		containerView.translatesAutoresizingMaskIntoConstraints = false

		// Sheet-like constraints: bottom pinned, flexible height
		NSLayoutConstraint.activate([
			containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			containerView.trailingAnchor.constraint(
				equalTo: view.trailingAnchor),
			containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			// Ensure it doesn't go beyond safe area top
			containerView.topAnchor.constraint(
				greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor,
				constant: 50),
		])

		// Add hosting controller to container
		containerView.addSubview(hostingController.view)
		hostingController.view.translatesAutoresizingMaskIntoConstraints = false
		hostingController.view.backgroundColor = .clear
		hostingController.view.layer.cornerRadius = 16
		hostingController.view.clipsToBounds = true

		// Add sheet indicator (handle bar)
		let indicator = UIView()
		indicator.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(
			0.4)
		indicator.layer.cornerRadius = 2
		indicator.translatesAutoresizingMaskIntoConstraints = false
		containerView.addSubview(indicator)
		NSLayoutConstraint.activate([
			indicator.topAnchor.constraint(
				equalTo: containerView.topAnchor, constant: 8),
			indicator.centerXAnchor.constraint(
				equalTo: containerView.centerXAnchor),
			indicator.widthAnchor.constraint(equalToConstant: 36),
			indicator.heightAnchor.constraint(equalToConstant: 4),
		])

		NSLayoutConstraint.activate([
			hostingController.view.topAnchor.constraint(
				equalTo: containerView.topAnchor),
			hostingController.view.leadingAnchor.constraint(
				equalTo: containerView.leadingAnchor),
			hostingController.view.trailingAnchor.constraint(
				equalTo: containerView.trailingAnchor),
			hostingController.view.bottomAnchor.constraint(
				equalTo: containerView.bottomAnchor),
		])

		hostingController.didMove(toParent: self)
	}

	@MainActor
	private func extractSharedContent() async {
		guard
			let extensionItems = extensionContext?.inputItems
				as? [NSExtensionItem]
		else {
			presentSwiftUIRootView(with: "", title: nil)
			return
		}

		for item in extensionItems {
			// Extract title from extension item
			var extractedTitle: String? = nil
			guard let attachments = item.attachments else { continue }

			for provider in attachments {
				// Handle file-based input (PDF only)
				if provider.hasItemConformingToTypeIdentifier(
					UTType.pdf.identifier)
				{
					do {
						let fileURL: URL =
							try await withCheckedThrowingContinuation {
								continuation in
								provider.loadItem(
									forTypeIdentifier: UTType.data.identifier,
									options: nil
								) {
									(item, error) in
									if let error = error {
										continuation.resume(throwing: error)
									} else if let url = item as? URL {
										continuation.resume(returning: url)
									} else if let data = item as? Data {
										// Save data to temp file
										let tempURL = FileManager.default
											.temporaryDirectory
											.appendingPathComponent(
												UUID().uuidString)
										do {
											try data.write(to: tempURL)
											continuation.resume(
												returning: tempURL)
										} catch {
											continuation.resume(throwing: error)
										}
									} else {
										continuation.resume(
											throwing: NSError(
												domain: "ShareExtension",
												code: -1,
												userInfo: [
													NSLocalizedDescriptionKey:
														"Failed to load file"
												]))
									}
								}
							}

						// Parse document
						presentSwiftUIRootView(
							with: fileURL.absoluteString,
							title: extractedTitle)
						return
					} catch {
						presentSwiftUIRootView(
							with: error.localizedDescription,
							title: extractedTitle)
						return
					}
				}

				// Check for URL first (more specific)
				if provider.hasItemConformingToTypeIdentifier(
					UTType.url.identifier)
				{
					do {
						let urlObject: any NSItemProviderReading =
							try await withCheckedThrowingContinuation {
								continuation in
								provider.loadObject(ofClass: NSURL.self) {
									(object, error) in
									if let error = error {
										continuation.resume(throwing: error)
									} else if let url = object {
										continuation.resume(returning: url)
									} else {
										continuation.resume(
											throwing: NSError(
												domain: "ShareExtension",
												code: -1,
												userInfo: [
													NSLocalizedDescriptionKey:
														"Failed to load URL"
												]))
									}
								}
							}
						if let url = urlObject as? URL {
							// If with URL and success we return the title
							if let attributedContentText = item
								.attributedContentText
							{
								extractedTitle = attributedContentText.string
									.trimmingCharacters(
										in: .whitespacesAndNewlines)
							}
							presentSwiftUIRootView(
								with: url.absoluteString,
								title: extractedTitle)
							return
						}
					} catch {
						print("Error loading URL: \(error)")
					}
				}

				// Check for text
				if provider.hasItemConformingToTypeIdentifier(
					UTType.text.identifier)
				{
					do {
						// Try NSString first
						let textObject: any NSItemProviderReading =
							try await withCheckedThrowingContinuation {
								continuation in
								provider.loadObject(ofClass: NSString.self) {
									(object, error) in
									if let error = error {
										continuation.resume(throwing: error)
									} else if let text = object {
										continuation.resume(returning: text)
									} else {
										continuation.resume(
											throwing: NSError(
												domain: "ShareExtension",
												code: -1,
												userInfo: [
													NSLocalizedDescriptionKey:
														"Failed to load text as NSString"
												]))
									}
								}
							}
						if let text = textObject as? String {
							presentSwiftUIRootView(
								with: text, title: extractedTitle)
							return
						} else if let nsText = textObject as? NSString {
							presentSwiftUIRootView(
								with: nsText as String,
								title: extractedTitle)
							return
						}
					} catch {
						// Fallback: Try to load as Swift String using loadItem
						do {
							let textObject: Any =
								try await withCheckedThrowingContinuation {
									continuation in
									provider.loadItem(
										forTypeIdentifier: UTType.text
											.identifier, options: nil
									) {
										(object, error) in
										if let error = error {
											continuation.resume(throwing: error)
										} else if let text = object {
											continuation.resume(returning: text)
										} else {
											continuation.resume(
												throwing: NSError(
													domain: "ShareExtension",
													code: -1,
													userInfo: [
														NSLocalizedDescriptionKey:
															"Failed to load text item"
													]))
										}
									}
								}
							if let text = textObject as? String {
								presentSwiftUIRootView(
									with: text, title: extractedTitle)
								return
							}
						} catch {
							print("Error loading text: \(error)")
						}
					}
				}
			}
		}

		// No valid content found
		presentSwiftUIRootView(with: "", title: nil)
	}
}

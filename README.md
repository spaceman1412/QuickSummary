<div align="center">
  <img
    width="80"
    src="./docs/icon.png"
    alt="QuickSummary"
  >
   <h1 style="margin-block-start: 0em;">
    QuickSummary
  </h1>
  <p>
    A free & open source AI summary app focus on speed and utility.<br>
    <sub style="color:gray;">Powered by Gemini</sub>
  </p>
  <p>
    <a href="#features">Features</a> •
    <a href="#roadmap">Roadmap</a> •
    <a href="#build-a-project">Build a project</a> •
    <a href="#app-architecture">App Architecture</a> •
    <a href="#contributing">Contributing</a> •
    <a href="#license">License</a> 
  </p>
</div>

## Features

- **Native Performance**: Built with native technology for a fast, lightweight, and responsive experience.
- **Summarize Anywhere**: Instantly get summaries from any app using the native Share Extension.
- **AI-Powered Chat**: Ask questions and get instant insights from your content with an integrated AI chat.
- **Comprehensive History**: Keep track of all your summaries and see how much time you've saved.
- **Versatile Summaries**: Choose from six different summary types to fit your needs perfectly.
- **Optimized Processing**: A smart algorithm pre-processes content before sending it to the AI, delivering faster summaries.

## Roadmap

Here are the exciting features planned for the future of QuickSummary:

- **Expanded File Support**:

  - [ ] **Documents**: Summarize content directly from `.doc` and `.docx` files.
  - [ ] **Multimedia**:
    - [ ] **Audio**: Transcribe and summarize audio files.
    - [ ] **Video**: Transcribe and summarize video content.
    - [ ] **Images**: Extract and summarize text from photos.

- **Cross-Platform Support**:
  - [ ] **Android**: Develop and release a native Android version of the app.

## Build a project

This app uses Firebase to power its AI summarization features with Google's Gemini model. Follow these steps carefully to get the project running.

### 1. Prerequisites

- **Xcode**: 15.0 or later.
- **Firebase Account**: A free account is sufficient.

### 2. Firebase Project Setup & Configuration

1. **Create a Firebase Project**:

   - Go to the [Firebase Console](https://console.firebase.google.com/) and click "Add project".
   - Follow the on-screen instructions to create a new project.

2. **Register the Main App**:

   - In your project settings, click the iOS icon to add your first app.
   - For the **Bundle ID**, use `com.catboss.QuickSummary`.
   - After registering, download the `GoogleService-Info.plist` file.
   - Drag and drop this file into the `QuickSummary/` folder in your Xcode project.

3. **Register the Share Extension**:

   - Go back to your project settings and click "Add app".
   - Select the iOS icon again.
   - For the **Bundle ID**, use `com.catboss.QuickSummary.QuickSummaryShareExtension`.
   - After registering, download the new `GoogleService-Info.plist` file.
   - Drag and drop this file into the `QuickSummaryShareExtension/` folder in Xcode.

   > **Note on Bundle IDs**: The bundle IDs listed above are the project defaults. You can change them to whatever you like. Just ensure that the ID you enter in the Firebase console is an exact match for the bundle ID in your Xcode project's target settings.

4. **Enable Required Service**:
   - In the Firebase console, open the **AI Logic** section (Firebase AI Logic).
   - **Enable Gemini Developer API**: Go to **AI Logic > Gemini** and enable the Gemini API (Developer) for your project.

### 3. Running the App

- **On the Simulator or a Real Device**:

  1. Open the project in Xcode and select the `QuickSummary` scheme.
  2. Build and run the app. If you encounter configuration errors, verify that both `GoogleService-Info.plist` files are added to the correct targets (`QuickSummary` and `QuickSummaryShareExtension`).
  3. If you see App Check warnings in the console, you can ignore them. App Check is not required; only the Gemini Developer API is needed for AI features.

## App architecture

This project follows a modular architecture that separates the main application, the share extension, and shared components into three distinct targets:

- **QuickSummary**: The main application target, containing the user interface and primary app logic.
- **QuickSummaryShareExtension**: The share extension target, enabling users to summarize content from any app.
- **QuickSummaryShared**: A shared framework containing all the business logic, including services, models, and utilities, used by both the main app and the share extension.

This modular design improves code reusability and maintainability by centralizing shared functionality in a single framework.

## Contributing

Feel free to share, open issues and contribute to this project! :heart:

## License

QuickSummary is open source software licensed under the MIT License. See [LICENSE](LICENSE) for details.

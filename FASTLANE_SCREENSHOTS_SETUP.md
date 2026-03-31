# Fastlane Screenshots Setup

This document outlines the fastlane screenshot setup for PaceMark (trailmark) and what needs to be implemented in the app to support automated screenshots.

## Files Created

### 1. Snapfile
- **Location**: `fastlane/Snapfile`
- **Purpose**: Configuration for fastlane snapshot
- **Settings**:
  - Device: iPhone 17 Pro Max (updated for iOS 26 simulator)
  - Language: fr-FR
  - Scheme: trailmark
  - Output: `./screenshots/`

### 2. ScreenshotsUITests.swift
- **Location**: `trailmarkUITests/ScreenshotsUITests.swift`
- **Purpose**: UI test file that navigates through app screens and takes screenshots
- **Screenshots captured**:
  1. `01_liste` - Trail list (home screen)
  2. `02_import` - Import GPX screen
  3. `03_editor` - Editor with elevation profile
  4. `04_run_ready` - Run/guidance screen (pre-run with play button)
  5. `05_run_active` - Run/guidance screen (active with TTS bubble)

### 3. SnapshotHelper.swift
- **Location**: `trailmarkUITests/SnapshotHelper.swift`
- **Purpose**: Bridge between UI tests and fastlane snapshot
- **Source**: Latest from fastlane repository

### 4. Fastfile Lane
- **Location**: `fastlane/Fastfile`
- **Lane**: `screenshots`
- **Purpose**: Runs fastlane snapshot to capture automated screenshots

## App Requirements

To support the screenshot tests, the main app needs to implement the following:

### 1. Launch Arguments Support

The app should detect these launch arguments in `TrailMarkApp.swift`:

```swift
if ProcessInfo.processInfo.arguments.contains("--screenshots") {
    // Screenshot mode configuration
}

if ProcessInfo.processInfo.arguments.contains("--reset-app-state") {
    // Reset app state (skip onboarding, clear database, etc.)
}

if ProcessInfo.processInfo.arguments.contains("--sample-data") {
    // Load sample data for screenshots
}
```

### 2. Sample Data

Create sample trail data that shows well in screenshots:
- At least one trail with interesting elevation profile
- Pre-configured milestones
- Good trail name and stats

### 3. Accessibility Identifiers

Add accessibility identifiers to key UI elements:
- Navigation buttons (import, back, play)
- Trail cells in list
- Editor components
- Run screen buttons

### 4. UI Test Compatibility

Ensure the TCA-based app works well with UI tests:
- Proper navigation timing
- Loading states don't interfere with testing
- Animations complete properly

## Usage

### Run Screenshots
```bash
bundle exec fastlane screenshots
```

### Output Location
Screenshots will be saved in:
```
./screenshots/fr-FR/iPhone 17 Pro Max/
├── iPhone 17 Pro Max-01_liste.png
├── iPhone 17 Pro Max-02_import.png
├── iPhone 17 Pro Max-03_editor.png
├── iPhone 17 Pro Max-04_run_ready.png
└── iPhone 17 Pro Max-05_run_active.png
```

## Xcode Setup Required

The following needs to be done in Xcode (cannot be done via CLI):

1. **Add ScreenshotsUITests.swift to the UI test target**:
   - Open trailmark.xcodeproj in Xcode
   - Add the new test file to the trailmarkUITests target

2. **Add SnapshotHelper.swift to the UI test target**:
   - Ensure it's also added to the trailmarkUITests target

3. **Verify scheme configuration**:
   - The trailmark scheme should include the UI tests
   - Test target should be properly configured

## App Store Connect Integration

Once screenshots are generated, they can be used for:
- App Store listings
- TestFlight beta descriptions
- Marketing materials

The generated images are App Store Connect ready and follow Apple's guidelines for screenshot dimensions and content.

## Next Steps

1. Implement launch argument handling in the app
2. Add sample data generation
3. Add accessibility identifiers
4. Test the UI navigation flow
5. Run the screenshots lane and iterate

The setup is complete and ready for integration with the main app.
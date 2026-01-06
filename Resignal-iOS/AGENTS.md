# Resignal - AI Interview Analysis App

## Project Overview

Resignal is an iOS application that uses AI to analyze interview Q&A transcripts and provide structured feedback. The app follows modern SwiftUI architecture with clean separation of concerns, dependency injection, and comprehensive testing.

**Key Features:**
- Interview transcript analysis using AI (OpenAI-compatible APIs)
- Multiple evaluation rubrics (Software Engineering, Product Management, Data Science, Design, Behavioral, General)
- Persistent session storage using SwiftData
- Comprehensive feedback with strengths, weaknesses, suggested improvements, and follow-up questions
- Mock AI client for development/testing
- Snapshot testing for UI components
- Accessibility support

## Technology Stack

- **Language:** Swift 5.9+
- **Framework:** SwiftUI with iOS 17+ target
- **Architecture:** MVVM with Protocol-Oriented Design
- **Data Persistence:** SwiftData (iOS 17+)
- **Testing:** XCTest with Swift Testing framework
- **Dependencies:** 
  - SnapshotTesting (1.16.1) for UI snapshot tests
  - SwiftSyntax (600.0.1) for testing utilities
- **AI Integration:** OpenAI-compatible API endpoints
- **Security:** Keychain for API key storage

## Project Structure

```
Resignal/
├── App/                    # App entry point
│   └── ResignalApp.swift  # Main app with dependency injection setup
├── Core/                   # Core functionality
│   ├── Constants/         # App-wide constants
│   ├── DI/               # Dependency injection container
│   ├── Extensions/       # Swift extensions
│   ├── Navigation/       # Navigation router
│   ├── Protocols/        # Shared protocols
│   └── State/            # App state management
├── Features/             # Feature modules
│   ├── Editor/          # Interview input editor
│   ├── Home/            # Session list and navigation
│   ├── Result/          # Analysis results display
│   └── Settings/        # App configuration
├── Models/              # Data models
│   └── Session.swift    # Core session model with SwiftData
├── Persistence/         # Data persistence layer
│   └── SessionRepository.swift
├── Services/            # Business logic services
│   ├── AI/             # AI analysis services
│   └── Settings/       # Settings management
└── UI/                 # UI components and theming
    ├── Components/     # Reusable UI components
    └── Theme/          # Design system
```

## Build and Test Commands

### Building the Project
```bash
# Open in Xcode
open Resignal.xcodeproj

# Build using xcodebuild (requires Xcode command line tools)
xcodebuild -project Resignal.xcodeproj -scheme Resignal -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -project Resignal.xcodeproj -scheme Resignal -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test suite
xcodebuild test -project Resignal.xcodeproj -scheme Resignal -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ResignalTests/UnitTests
```

### Test Structure
- **Unit Tests:** `ResignalTests/UnitTests/` - Business logic testing
- **Snapshot Tests:** `ResignalTests/SnapshotTests/` - UI regression testing
- **UI Tests:** `ResignalUITests/` - End-to-end testing

## Code Style Guidelines

### Architecture Principles
1. **Protocol-Oriented Design:** Define protocols for all major components
2. **Dependency Injection:** Use the DependencyContainer for all service access
3. **Actor Isolation:** AI services are actor-isolated for thread safety
4. **Observable Pattern:** Use `@Observable` for state management
5. **Type-Safe Navigation:** Use the Router with enum-based routes

### Swift Conventions
- Use `nonisolated` for pure functions and data structures
- Mark sendable types with `Sendable` conformance
- Use `@MainActor` for UI-related code
- Prefer `let` over `var` where possible
- Use descriptive variable names with full words

### File Organization
- Each file should have a clear header comment explaining its purpose
- Group related functionality in extensions
- Use `// MARK:` comments for section organization
- Keep files focused on a single responsibility

### UI Guidelines
- Use the AppTheme for all styling (colors, spacing, typography)
- Follow the black & white minimalist aesthetic
- Ensure all interactive elements have accessibility identifiers
- Use the cardStyle() modifier for consistent card appearance

## Testing Instructions

### Unit Testing
- Test business logic in isolation using mock dependencies
- Use the MockAIClient for testing without real API calls
- Test error conditions and edge cases
- Verify protocol conformance

### Snapshot Testing
- Record snapshots on iPhone 15 Pro simulator
- Test components in light and dark mode
- Verify accessibility rendering
- Use device-agnostic snapshots where appropriate

### UI Testing
- Test critical user flows (create session, analyze, view results)
- Verify navigation between screens
- Test settings configuration
- Validate error handling

## AI Integration

### Configuration
The app supports any OpenAI-compatible API endpoint. Configure in Settings:
- **API Base URL:** Default is `https://api.openai.com/v1`
- **API Key:** Stored securely in Keychain
- **Model:** Default is `gpt-4o-mini`
- **Mock Mode:** Toggle for development/testing

### Rubric System
Six evaluation rubrics with specific focus areas:
- **Software Engineering:** Technical depth, problem-solving, code quality
- **Product Management:** Product sense, prioritization, metrics
- **Data Science:** Statistical rigor, model selection, business impact
- **Design:** User-centered thinking, design process, accessibility
- **Behavioral:** STAR method, self-awareness, collaboration
- **General:** Communication, structure, engagement

### Prompt Engineering
- Structured system prompt ensures consistent output format
- Rubric-specific guidance appended to user prompt
- Minimum 20 characters required for analysis
- Supports role-specific context

## Security Considerations

### API Key Management
- API keys stored in iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`
- Keys are never stored in UserDefaults or plain text
- Automatic keychain cleanup when keys are removed

### Data Privacy
- All session data stored locally using SwiftData
- No data transmission to external services except AI API calls
- User content never logged or cached beyond local storage

### Network Security
- HTTPS required for all API communications
- Request timeout of 60 seconds
- Proper error handling for network failures

## Development Workflow

### Adding New Features
1. Define protocols in appropriate Core/Protocols location
2. Implement services following existing patterns
3. Create ViewModels with proper state management
4. Build UI components using AppTheme
5. Add comprehensive tests (unit, snapshot, UI)
6. Update accessibility identifiers

### Debugging
- Use `debugLog()` function for conditional debug output
- Check SettingsService for configuration issues
- Verify DependencyContainer initialization
- Test with MockAIClient before real API integration

### Performance Considerations
- AI analysis is performed asynchronously with cancellation support
- Session data is cached in memory by repositories
- SwiftData queries are optimized for main thread usage
- Image assets are minimal for fast loading

## Dependencies and Package Management

### Swift Package Manager
- SnapshotTesting: UI regression testing
- SwiftSyntax: Testing framework support
- All packages managed through Xcode's package resolver

### No CocoaPods/Carthage
- Project uses only Swift Package Manager
- No external binary dependencies
- All code is source-available

## Deployment Notes

### App Store Considerations
- Ensure API key configuration is user-provided
- Include privacy policy for AI data processing
- Test on multiple device sizes and iOS versions
- Verify accessibility compliance

### Configuration for Production
- Users must provide their own AI API credentials
- Default to mock mode for first-time users
- Include clear setup instructions in app
- Provide fallback error handling for API issues
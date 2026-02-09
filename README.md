# Resignal-iOS

An iOS application that uses AI to analyze interview Q&A transcripts and provide structured feedback. Users can type or record interview sessions, attach supporting images, and receive AI-powered analysis with strengths, weaknesses, suggested improvements, and follow-up questions across multiple evaluation rubrics.

## Technology Stack

| Category | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI (iOS 17+) |
| Persistence | SwiftData |
| Concurrency | Swift Concurrency (async/await, actors) |
| Architecture | MVVM + Protocol-Oriented Design |
| Package Manager | Swift Package Manager |
| AI Integration | OpenAI-compatible API endpoints |
| Security | iOS Keychain for API key storage |
| Live Activities | ActivityKit for recording indicator |

## High-Level Architecture

The project follows a **layered architecture** with clear separation of concerns. Each layer communicates through well-defined protocol boundaries.

```
┌─────────────────────────────────────────────────────┐
│                    App Layer                         │
│              ResignalApp + RootView                  │
│         (Entry point, DI setup, deep links)         │
├─────────────────────────────────────────────────────┤
│                 Features Layer                       │
│     Home  │  Editor  │  Recording  │  Result        │
│          (MVVM feature modules)                     │
├──────────────────────┬──────────────────────────────┤
│    UI Layer          │       Core Layer              │
│  Components + Theme  │  DI / Router / State /       │
│  (Reusable views)    │  Protocols / Extensions      │
├──────────────────────┴──────────────────────────────┤
│                  Services Layer                      │
│  AI │ Recording │ Transcription │ Chat │ Attachment  │
│  LiveActivity │ User │ Settings │ ClientContext      │
├─────────────────────────────────────────────────────┤
│              Persistence Layer                       │
│          SessionRepository (SwiftData)               │
├─────────────────────────────────────────────────────┤
│                  Models Layer                        │
│   Session │ ChatMessage │ SessionAttachment          │
│   StructuredFeedback │ User │ RecordingActivity      │
└─────────────────────────────────────────────────────┘
```

## Project Structure

```
Resignal-iOS/
├── Resignal/
│   ├── App/                          # App entry point
│   │   └── ResignalApp.swift         # @main, DI setup, deep link handling, user registration
│   │
│   ├── Core/                         # Cross-cutting concerns
│   │   ├── Constants/                # Validation constants (min input chars, max image size)
│   │   ├── DI/                       # DependencyContainer (protocol-based, @Observable)
│   │   ├── Extensions/               # Date formatting extensions (cached formatters)
│   │   ├── Navigation/               # Router with type-safe Route enum
│   │   ├── Protocols/                # ViewModel protocol definitions
│   │   ├── State/                    # ViewState<T> generic state enum
│   │   └── Utilities/                # PermissionManager (mic, speech, photos)
│   │
│   ├── Features/                     # Feature modules (MVVM)
│   │   ├── Editor/                   # Transcript input, attachment management, AI analysis
│   │   ├── Home/                     # Session list, CRUD operations, navigation hub
│   │   ├── Recording/                # Audio recording with live transcription
│   │   └── Result/                   # AI feedback display with expandable sections
│   │
│   ├── Models/                       # Data models
│   │   ├── Session.swift             # Core entity (@Model, SwiftData)
│   │   ├── SessionAttachment.swift   # File attachments (@Model, SwiftData)
│   │   ├── ChatMessage.swift         # Chat history (@Model, SwiftData)
│   │   ├── StructuredFeedback.swift  # AI analysis result (Codable struct)
│   │   ├── User.swift                # User identity (Codable struct)
│   │   └── RecordingActivityAttributes.swift  # Live Activity data (ActivityKit)
│   │
│   ├── Persistence/                  # Data access layer
│   │   └── SessionRepository.swift   # Repository pattern over SwiftData ModelContext
│   │
│   ├── Services/                     # Business logic services
│   │   ├── AI/                       # AIClient protocol + actor implementations
│   │   ├── Attachment/               # File management, compression, thumbnails
│   │   ├── Chat/                     # Backend-integrated messaging
│   │   ├── ClientContext/            # Device identity (Keychain-persisted client ID)
│   │   ├── Recording/               # AVAudioRecorder + LiveActivity integration
│   │   ├── Settings/                 # Observable UserDefaults wrapper
│   │   ├── Transcription/            # Apple Speech framework with chunking
│   │   └── User/                     # User registration with backend
│   │
│   └── UI/                           # Reusable UI layer
│       ├── Components/               # PrimaryButton, SectionCard, TagChipsView, etc.
│       └── Theme/                    # AppTheme (colors, spacing, typography, modifiers)
│
├── RecordingActivityWidget/          # Live Activity widget extension
│   ├── RecordingLiveActivity.swift   # Lock screen / Dynamic Island UI
│   └── RecordingActivityWidgetBundle.swift
│
└── ResignalTests/                    # Test suite
```

## Design Patterns & Architecture Decisions

### 1. MVVM (Model-View-ViewModel)

Each feature module follows MVVM with a strict separation:

- **View** (`*View.swift`): SwiftUI views that hold a `@State` ViewModel, inject dependencies from `@Environment(DependencyContainer.self)`, and delegate all logic to the ViewModel.
- **ViewModel** (`*ViewModel.swift`): `@Observable @MainActor` classes conforming to ViewModel protocols. They own state, coordinate services, and expose computed properties for the view layer.
- **Model**: SwiftData `@Model` entities and `Codable` structs.

Views lazily initialize ViewModels in `.onAppear` and use `@Bindable` or custom `Binding` wrappers for two-way data binding.

### 2. Protocol-Oriented Design

Every major component is defined by a protocol:

- **Service protocols**: `AIClient`, `RecordingService`, `TranscriptionService`, `ChatService`, `AttachmentService`, `UserClient`, `LiveActivityService`, `SettingsServiceProtocol`
- **ViewModel protocols**: `HomeViewModelProtocol`, `EditorViewModelProtocol`, `ResultViewModelProtocol`
- **Container protocol**: `DependencyContainerProtocol`
- **Repository protocol**: `SessionRepositoryProtocol`

This enables mock implementations for testing/previews and makes the system open for extension while closed for modification.

### 3. Dependency Injection

A centralized `DependencyContainer` (marked `@Observable`) creates and owns all services. It is injected into the view hierarchy via SwiftUI's `.environment()` modifier at the app root:

```swift
RootView()
    .environment(container)
    .environment(router)
    .modelContainer(container.modelContainer)
```

Views access the container via `@Environment(DependencyContainer.self)` and pass specific services into ViewModels during initialization. The container supports a `preview` mode that substitutes all real services with mocks (in-memory SwiftData storage).

### 4. Type-Safe Navigation

A `Router` class (marked `@Observable @MainActor`) manages a `NavigationPath`-compatible `[Route]` array. The `Route` enum uses associated values for type-safe destination parameters:

```swift
enum Route: Hashable {
    case home
    case editor(session: Session?, initialTranscript: String?, audioURL: URL?)
    case result(session: Session)
    case recording(session: Session?)
}
```

Navigation methods: `navigate(to:)`, `pop()`, `popToRoot()`, `replace(with:)`.

### 5. Unified State Management

A generic `ViewState<T: Equatable>` enum models async operation lifecycle:

```swift
enum ViewState<T: Equatable>: Equatable {
    case idle
    case loading
    case success(T)
    case error(String)
}
```

Convenience computed properties (`isLoading`, `hasError`, `value`, `isSuccess`, `isIdle`) simplify conditional rendering in views. A `VoidState` typealias handles operations with no return value.

### 6. Actor-Based Concurrency

Services that perform I/O or background work use Swift **actors** for thread safety:

- `ResignalAIClient`, `MockAIClient` — AI analysis
- `AttachmentServiceImpl` — file operations
- `ChatServiceImpl` — network requests
- `TranscriptionServiceImpl` — speech recognition
- `UserClientImpl` — user registration

UI-bound services use `@MainActor` instead: `RecordingServiceImpl`, `LiveActivityServiceImpl`, `SettingsService`.

### 7. Repository Pattern

`SessionRepository` encapsulates all SwiftData `ModelContext` operations behind `SessionRepositoryProtocol`. It provides:

- CRUD operations for sessions
- Fetch with sorting and pagination via `FetchDescriptor`
- Type-safe predicates via `#Predicate` macro
- Attachment and chat message management
- Version tracking on session updates

### 8. Mock / Real Strategy

Every service has a corresponding mock implementation (e.g., `MockAIClient`, `MockRecordingService`, `MockTranscriptionService`). The `DependencyContainer` switches between real and mock implementations based on an `isPreview` flag. The AI client additionally supports runtime toggling via `SettingsService.useMockAI` with lazy cached re-creation.

## Data Model & Relationships

```
Session (SwiftData @Model)
├──< SessionAttachment (cascade delete)    // Images, files attached to a session
├──< ChatMessage (cascade delete)          // Ask/chat history per session
└──> StructuredFeedback (stored as JSON Data)  // AI analysis result

User (Codable struct)                      // Backend identity, not persisted locally
RecordingActivityAttributes (ActivityKit)   // Live Activity state
```

**Key model design decisions:**

- **String-backed enums**: `Rubric`, `TranscriptionMode`, `ChatRole`, `AttachmentType` are stored as raw `String` values in SwiftData with computed properties for type-safe enum access.
- **File path storage**: URLs (audio files, attachments, thumbnails) are stored as `String` paths and exposed via computed URL properties.
- **JSON embedding**: `StructuredFeedback` is stored as `Data` in `Session.feedbackData` and decoded on access via a computed property.
- **Backend sync fields**: `Session.interviewId` and `ChatMessage.serverId` track server synchronization state.

## Key Features & User Flow

1. **Home** — Browse saved sessions, create new sessions, rename/delete existing ones.
2. **Editor** — Type or paste interview transcript, attach images, select rubric, trigger AI analysis.
3. **Recording** — Record audio with real-time transcription (Apple Speech framework with 50-second chunking strategy). Live Activity displays recording status on lock screen / Dynamic Island.
4. **Result** — View structured AI feedback: overall score, hiring signal, strengths, weaknesses, improvements, follow-up questions, key observations. Expandable `SectionCard` components. Includes an "Ask" chat feature for follow-up questions.

## UI & Design System

The `AppTheme` struct provides a centralized design system:

- **Colors**: Primary, background, surface, text hierarchy, semantic colors (success, warning, error)
- **Spacing**: Consistent spacing scale (xs through xxl)
- **Typography**: Title, headline, body, caption, footnote styles
- **Corner Radius**: Small, medium, large, xl
- **Shadows**: Subtle, medium, strong shadow presets
- **View Modifiers**: `.cardStyle()`, `.subtleShadow()`, `.mediumShadow()` for consistent styling
- **Animation**: Standard spring and easeInOut presets

Reusable UI components include `PrimaryButton` (filled/outlined/text variants with loading state), `SectionCard` (expandable sections), `TagChipsView` (flow layout chips), `EmptyStateView`, `AttachmentPickerView`, and `CreateSessionSheet`.

## Security

- **API keys** stored in iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`
- **Client identity** persisted in Keychain (survives app reinstalls)
- **Session data** stored locally via SwiftData; no external transmission except AI API calls
- **HTTPS** required for all network communication

## Build & Run

```bash
# Open in Xcode
open Resignal-iOS/Resignal.xcodeproj

# Build via command line
xcodebuild -project Resignal-iOS/Resignal.xcodeproj \
  -scheme Resignal \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# Run tests
xcodebuild test -project Resignal-iOS/Resignal.xcodeproj \
  -scheme Resignal \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Dependencies

Managed via Swift Package Manager:

- **SnapshotTesting** (1.16.1) — UI snapshot regression tests
- **SwiftSyntax** (600.0.1) — Testing framework utilities

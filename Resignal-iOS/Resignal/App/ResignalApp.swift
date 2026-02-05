//
//  ResignalApp.swift
//  Resignal
//
//  Main app entry point with dependency injection setup.
//

import SwiftUI
import SwiftData

@main
struct ResignalApp: App {
    
    // MARK: - Properties
    
    @State private var container = DependencyContainer()
    @State private var router = Router()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(router)
                .modelContainer(container.modelContainer)
                .background(AppTheme.Colors.background)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    // MARK: - Deep Link Handling
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "resignal" else { return }
        
        switch url.host {
        case "stopRecording":
            // Post notification to stop recording
            NotificationCenter.default.post(
                name: .stopRecordingFromLiveActivity,
                object: nil
            )
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Notification posted when the Stop button is tapped from Live Activity
    static let stopRecordingFromLiveActivity = Notification.Name("stopRecordingFromLiveActivity")
}

/// Root view with navigation stack
struct RootView: View {
    
    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        @Bindable var router = router
        
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    destinationView(for: route)
                }
        }
        .tint(AppTheme.Colors.primary)
        .background(AppTheme.Colors.background)
        .scrollContentBackground(.hidden)
        .task {
            await registerUserIfNeeded()
        }
    }
    
    /// Registers user with backend on first app launch
    private func registerUserIfNeeded() async {
        // Check if user is already registered
        guard !container.settingsService.hasRegisteredUser else {
            return
        }
        
        do {
            // Attempt registration
            let response = try await container.userClient.registerUser()
            
            if response.success {
                // Mark as registered on success
                container.settingsService.hasRegisteredUser = true
                print("✅ User registration successful: \(response.message ?? "No message")")
            } else {
                // Don't mark as registered if response indicates failure
                print("⚠️ User registration returned unsuccessful response: \(response.message ?? "No message")")
            }
        } catch UserClientError.alreadyRegistered {
            // User already registered on backend, mark as registered locally
            container.settingsService.hasRegisteredUser = true
            print("ℹ️ User already registered on backend")
        } catch {
            // Log error but don't mark as registered - will retry next launch
            print("❌ User registration failed: \(error.localizedDescription)")
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView()
            
        case .editor(let session, let initialTranscript, let audioURL):
            EditorView(existingSession: session, initialTranscript: initialTranscript, audioURL: audioURL)
            
        case .result(let session):
            ResultView(session: session)
            
        case .recording(let session):
            RecordingView(existingSession: session) { url, transcript in
                // Navigate to editor with the recorded transcript and audio URL
                router.replace(with: .editor(session: session, initialTranscript: transcript, audioURL: url))
            }
        }
    }
}


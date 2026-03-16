//
//  ResignalApp.swift
//  Resignal
//
//  Main app entry point with dependency injection setup.
//

import SwiftUI

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
                .background(AppTheme.Colors.background)
                .preferredColorScheme(.light)
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
    
    #if DEBUG
    @State private var showDevSettings = false
    #endif
    
    var body: some View {
        Group {
            if container.settingsService.hasSeenOnboarding {
                mainContent
            } else {
                OnboardingView(
                    viewModel: OnboardingViewModel(
                        settingsService: container.settingsService
                    )
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(AppTheme.Animation.slow, value: container.settingsService.hasSeenOnboarding)
    }
    
    /// The main app content shown after onboarding
    private var mainContent: some View {
        @Bindable var router = router
        
        return NavigationStack(path: $router.path) {
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
        .task {
            await container.subscriptionService.loadProducts()
        }
        .task {
            await container.subscriptionService.listenForTransactions()
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
            showDevSettings = true
        }
        .sheet(isPresented: $showDevSettings) {
            DevSettingsView()
        }
        #endif
    }
    
    /// Registers user with backend on first app launch
    private func registerUserIfNeeded() async {
        guard !container.settingsService.hasRegisteredUser else {
            return
        }
        
        do {
            let response = try await container.userClient.registerUser()
            
            if response.success {
                container.settingsService.hasRegisteredUser = true
                print("✅ User registration successful: \(response.message ?? "No message")")
            } else {
                print("⚠️ User registration returned unsuccessful response: \(response.message ?? "No message")")
            }
        } catch UserClientError.alreadyRegistered {
            container.settingsService.hasRegisteredUser = true
            print("ℹ️ User already registered on backend")
        } catch {
            print("❌ User registration failed: \(error.localizedDescription)")
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView()
            
        case .editor(let initialTranscript, let audioURL):
            EditorView(initialTranscript: initialTranscript, audioURL: audioURL)
            
        case .interviewDetail(let interviewId):
            InterviewDetailView(interviewId: interviewId)
            
        case .recording:
            RecordingView { url, transcript in
                router.replace(with: .editor(initialTranscript: transcript, audioURL: url))
            }
        }
    }
}

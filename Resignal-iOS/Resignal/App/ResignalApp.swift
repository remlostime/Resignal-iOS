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

// MARK: - Auth State

enum AuthState {
    case checking
    case authenticated
    case failed(String)
}

/// Root view with navigation stack
struct RootView: View {
    
    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container
    
    @State private var authState: AuthState = .checking
    
    #if DEBUG
    @State private var showDevSettings = false
    #endif
    
    var body: some View {
        Group {
            if !container.settingsService.hasSeenOnboarding {
                OnboardingView(
                    viewModel: OnboardingViewModel(
                        settingsService: container.settingsService
                    )
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                switch authState {
                case .checking:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.Colors.background)
                case .authenticated:
                    mainContent
                case .failed(let message):
                    authErrorView(message: message)
                }
            }
        }
        .animation(AppTheme.Animation.slow, value: container.settingsService.hasSeenOnboarding)
        .task {
            await ensureAuthenticated()
        }
    }
    
    // MARK: - Auth
    
    private func ensureAuthenticated() async {
        let identity = container.identityManager
        
        if identity.isAuthenticated {
            authState = .authenticated
            return
        }
        
        authState = .checking
        
        do {
            try await identity.register(baseURL: container.settingsService.apiEnvironment.baseURL)
            authState = .authenticated
        } catch {
            authState = .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Views
    
    private func authErrorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Connection Error")
                .font(.title2.bold())
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task { await ensureAuthenticated() }
            } label: {
                Text("Retry")
                    .fontWeight(.semibold)
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
    
    /// The main app content shown after onboarding and authentication
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

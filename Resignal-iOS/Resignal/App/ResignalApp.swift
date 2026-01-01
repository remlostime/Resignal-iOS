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
        }
    }
}

/// Root view with navigation stack
struct RootView: View {
    
    @Environment(Router.self) private var router
    
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
    }
    
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView()
            
        case .editor(let session):
            EditorView(existingSession: session)
            
        case .result(let session):
            ResultView(session: session)
            
        case .settings:
            SettingsView()
        }
    }
}


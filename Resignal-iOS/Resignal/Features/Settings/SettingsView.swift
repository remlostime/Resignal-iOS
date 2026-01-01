//
//  SettingsView.swift
//  Resignal
//
//  Settings screen for app configuration.
//

import SwiftUI

/// Settings screen
struct SettingsView: View {
    
    // MARK: - Properties
    
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: SettingsViewModel?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                settingsContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(
                    settingsService: container.settingsService,
                    sessionRepository: container.sessionRepository
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func settingsContent(viewModel: SettingsViewModel) -> some View {
        List {
            // AI Configuration Section
            Section {
                Toggle("Use Mock AI", isOn: Binding(
                    get: { viewModel.useMockAI },
                    set: { viewModel.useMockAI = $0 }
                ))
                .tint(AppTheme.Colors.primary)
                
                if !viewModel.useMockAI {
                    apiConfigurationSection(viewModel: viewModel)
                }
            } header: {
                Text("AI Configuration")
            } footer: {
                Text(viewModel.useMockAI
                    ? "Using mock AI for testing. Responses are deterministic samples."
                    : "Configure your OpenAI-compatible API endpoint."
                )
            }
            
            // Data Section
            Section {
                Button(role: .destructive) {
                    viewModel.confirmClearAll()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Sessions")
                    }
                }
            } header: {
                Text("Data")
            } footer: {
                Text("This will permanently delete all saved sessions.")
            }
            
            // About Section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(viewModel.appVersion)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Link(destination: URL(string: "https://github.com")!) {
                    HStack {
                        Text("Source Code")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }
                .foregroundStyle(AppTheme.Colors.textPrimary)
            } header: {
                Text("About")
            }
        }
        .listStyle(.insetGrouped)
        .alert("Clear All Sessions?", isPresented: Binding(
            get: { viewModel.showClearConfirmation },
            set: { viewModel.showClearConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                viewModel.clearAllSessions()
            }
        } message: {
            Text("This action cannot be undone. All your interview sessions will be permanently deleted.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.showError },
            set: { viewModel.showError = $0 }
        )) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .overlay {
            if viewModel.showClearedMessage {
                clearedMessageOverlay
            }
        }
    }
    
    @ViewBuilder
    private func apiConfigurationSection(viewModel: SettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Base URL")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            TextField("https://api.openai.com/v1", text: Binding(
                get: { viewModel.apiBaseURL },
                set: { viewModel.apiBaseURL = $0 }
            ))
            .font(AppTheme.Typography.body)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
        }
        .listRowSeparator(.hidden, edges: .bottom)
        
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("API Key")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            SecureField("sk-...", text: Binding(
                get: { viewModel.apiKey },
                set: { viewModel.apiKey = $0 }
            ))
            .font(AppTheme.Typography.body)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        
        if viewModel.isAPIConfigured {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.Colors.success)
                Text("API configured")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    private var clearedMessageOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.Colors.success)
                Text("All sessions cleared")
                    .font(AppTheme.Typography.callout)
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .clipShape(Capsule())
            .subtleShadow()
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(AppTheme.Animation.spring, value: viewModel?.showClearedMessage)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(DependencyContainer.preview())
}


//
//  DevSettingsView.swift
//  Resignal
//
//  Internal settings view for development builds only.
//  Allows switching between API environments.
//

#if DEBUG

import SwiftUI

/// Dev-only settings sheet for internal configuration
struct DevSettingsView: View {
    
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    
    /// The environment the user is attempting to switch to, pending confirmation.
    @State private var pendingEnvironment: APIEnvironment?
    
    private var currentEnvironment: APIEnvironment {
        container.settingsService.apiEnvironment
    }
    
    private var currentModel: AIModel {
        container.settingsService.aiModel
    }
    
    var body: some View {
        NavigationStack {
            List {
                apiEnvironmentSection
                aiModelSection
            }
            .navigationTitle("Internal Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert(
                "Change API Environment",
                isPresented: showRestartAlert,
                actions: {
                    Button("Cancel", role: .cancel) {
                        pendingEnvironment = nil
                    }
                    Button("Restart", role: .destructive) {
                        if let pending = pendingEnvironment {
                            container.settingsService.apiEnvironment = pending
                        }
                        exit(0)
                    }
                },
                message: {
                    if let pending = pendingEnvironment {
                        Text("Switching to \(pending.displayName) (\(pending.baseURL)) requires restarting the app.")
                    }
                }
            )
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var apiEnvironmentSection: some View {
        Section {
            Picker("API Base URL", selection: pickerBinding) {
                ForEach(APIEnvironment.allCases, id: \.self) { environment in
                    Text(environment.displayName)
                        .tag(environment)
                }
            }
            .pickerStyle(.segmented)
            
            HStack {
                Text("Current URL")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                Text(currentEnvironment.baseURL)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        } header: {
            Text("API Environment")
        } footer: {
            Text("Changing the environment requires an app restart. Use Dev when running the backend locally.")
                .font(AppTheme.Typography.caption)
        }
    }
    
    @ViewBuilder
    private var aiModelSection: some View {
        Section {
            Menu {
                Picker("Model", selection: aiModelBinding) {
                    ForEach(AIModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
            } label: {
                HStack {
                    Text("Model")
                    Spacer()
                    Text(currentModel.displayName)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .tint(AppTheme.Colors.textPrimary)
        } header: {
            Text("AI Model")
        } footer: {
            Text("Select the AI model provider used for analysis.")
                .font(AppTheme.Typography.caption)
        }
    }
    
    // MARK: - Bindings
    
    /// Picker binding that intercepts changes to show the restart confirmation alert
    /// instead of applying the change immediately.
    private var pickerBinding: Binding<APIEnvironment> {
        Binding(
            get: { pendingEnvironment ?? currentEnvironment },
            set: { newValue in
                guard newValue != currentEnvironment else { return }
                pendingEnvironment = newValue
            }
        )
    }
    
    private var aiModelBinding: Binding<AIModel> {
        Binding(
            get: { currentModel },
            set: { newValue in
                container.settingsService.aiModel = newValue
            }
        )
    }
    
    private var showRestartAlert: Binding<Bool> {
        Binding(
            get: { pendingEnvironment != nil },
            set: { isPresented in
                if !isPresented {
                    pendingEnvironment = nil
                }
            }
        )
    }
}

#endif

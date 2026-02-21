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
    
    /// The AI model the user is attempting to switch to, pending confirmation.
    @State private var pendingModel: AIModel?
    
    private var currentEnvironment: APIEnvironment {
        container.settingsService.apiEnvironment
    }
    
    private var currentModel: AIModel {
        container.settingsService.aiModel
    }
    
    private var currentAudioAPI: AudioAPI {
        container.settingsService.audioAPI
    }
    
    var body: some View {
        NavigationStack {
            List {
                subscriptionMockSection
                sessionUsageSection
                onboardingSection
                clientIdSection
                apiEnvironmentSection
                aiModelSection
                audioAPISection
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
            .alert(
                "Change AI Model",
                isPresented: showModelRestartAlert,
                actions: {
                    Button("Cancel", role: .cancel) {
                        pendingModel = nil
                    }
                    Button("Restart", role: .destructive) {
                        if let pending = pendingModel {
                            container.settingsService.aiModel = pending
                        }
                        exit(0)
                    }
                },
                message: {
                    if let pending = pendingModel {
                        Text("Switching to \(pending.displayName) requires restarting the app.")
                    }
                }
            )
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var subscriptionMockSection: some View {
        Section {
            Toggle("Enable Mock Subscription", isOn: mockSubscriptionEnabledBinding)
            
            if container.settingsService.mockSubscriptionEnabled {
                HStack {
                    Text("Plan")
                    Spacer()
                    Picker("Plan", selection: mockPlanBinding) {
                        Text("Free").tag(Plan.free)
                        Text("Pro").tag(Plan.pro)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                
                HStack {
                    Text("Current Status")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Spacer()
                    Text(container.featureAccessService.isPro ? "Pro" : "Free")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(
                            container.featureAccessService.isPro
                                ? AppTheme.Colors.success
                                : AppTheme.Colors.textSecondary
                        )
                }
            }
        } header: {
            Text("Subscription (Mock)")
        } footer: {
            Text("When enabled, overrides real StoreKit subscription status. Use this to test Pro features without App Store configuration.")
                .font(AppTheme.Typography.caption)
        }
    }
    
    @ViewBuilder
    private var sessionUsageSection: some View {
        Section {
            Stepper(
                "\(container.featureAccessService.sessionCreationCountThisMonth) / \(container.featureAccessService.maxFreeSessionCreations) used",
                value: sessionUsageBinding,
                in: 0...10
            )
            
            HStack {
                Text("Can Create Session")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                Text(container.featureAccessService.canCreateSession ? "Yes" : "No")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(
                        container.featureAccessService.canCreateSession
                            ? AppTheme.Colors.success
                            : AppTheme.Colors.destructive
                    )
            }
            
            if container.featureAccessService.sessionCreationCountThisMonth > 0 {
                Button("Reset to 0") {
                    container.featureAccessService.overrideSessionCreationCount(0)
                }
                .foregroundStyle(AppTheme.Colors.destructive)
            }
        } header: {
            Text("Session Usage")
        } footer: {
            Text("Override the monthly session creation count to test free-tier limits and paywall gating.")
                .font(AppTheme.Typography.caption)
        }
    }
    
    @ViewBuilder
    private var onboardingSection: some View {
        Section {
            Button("Reset Onboarding") {
                container.settingsService.hasSeenOnboarding = false
                dismiss()
            }
            .foregroundStyle(AppTheme.Colors.destructive)
        } header: {
            Text("Onboarding")
        } footer: {
            Text("Resets the onboarding flag so the welcome screen appears on next launch.")
                .font(AppTheme.Typography.caption)
        }
    }
    
    @ViewBuilder
    private var clientIdSection: some View {
        Section {
            TextField("Override value", text: clientIdOverrideBinding)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(AppTheme.Typography.body)
            
            HStack {
                Text("Effective ID")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                Text(ClientContextService.shared.clientId)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            
            if !container.settingsService.clientIdOverride.isEmpty {
                Button("Clear Override") {
                    container.settingsService.clientIdOverride = ""
                }
                .foregroundStyle(AppTheme.Colors.destructive)
            }
        } header: {
            Text("x-client-id")
        } footer: {
            Text("Override the auto-generated x-client-id for all API requests. Leave empty to use the default.")
                .font(AppTheme.Typography.caption)
        }
    }
    
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
            Text("Changing the AI model requires an app restart.")
                .font(AppTheme.Typography.caption)
        }
    }
    
    @ViewBuilder
    private var audioAPISection: some View {
        Section {
            Menu {
                Picker("Audio API", selection: audioAPIBinding) {
                    ForEach(AudioAPI.allCases, id: \.self) { api in
                        Text(api.displayName).tag(api)
                    }
                }
            } label: {
                HStack {
                    Text("Transcription")
                    Spacer()
                    Text(currentAudioAPI.displayName)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .tint(AppTheme.Colors.textPrimary)
        } header: {
            Text("Audio API")
        } footer: {
            Text("Select the audio transcription provider.")
                .font(AppTheme.Typography.caption)
        }
    }
    
    // MARK: - Bindings
    
    private var mockSubscriptionEnabledBinding: Binding<Bool> {
        Binding(
            get: { container.settingsService.mockSubscriptionEnabled },
            set: { newValue in
                container.settingsService.mockSubscriptionEnabled = newValue
            }
        )
    }
    
    private var mockPlanBinding: Binding<Plan> {
        Binding(
            get: { container.settingsService.mockPlan },
            set: { newValue in
                container.settingsService.mockPlan = newValue
            }
        )
    }
    
    private var sessionUsageBinding: Binding<Int> {
        Binding(
            get: { container.featureAccessService.sessionCreationCountThisMonth },
            set: { newValue in
                container.featureAccessService.overrideSessionCreationCount(newValue)
            }
        )
    }
    
    private var clientIdOverrideBinding: Binding<String> {
        Binding(
            get: { container.settingsService.clientIdOverride },
            set: { newValue in
                container.settingsService.clientIdOverride = newValue
            }
        )
    }
    
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
            get: { pendingModel ?? currentModel },
            set: { newValue in
                guard newValue != currentModel else { return }
                pendingModel = newValue
            }
        )
    }
    
    private var audioAPIBinding: Binding<AudioAPI> {
        Binding(
            get: { currentAudioAPI },
            set: { newValue in
                container.settingsService.audioAPI = newValue
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
    
    private var showModelRestartAlert: Binding<Bool> {
        Binding(
            get: { pendingModel != nil },
            set: { isPresented in
                if !isPresented {
                    pendingModel = nil
                }
            }
        )
    }
}

#endif

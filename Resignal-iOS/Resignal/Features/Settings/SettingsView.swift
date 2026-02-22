//
//  SettingsView.swift
//  Resignal
//
//  User-facing Settings screen with a Legal section for privacy compliance.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @Environment(DependencyContainer.self) private var container
    @State var viewModel: SettingsViewModel
    @State private var safariURL: URL?
    @State private var showMembershipSheet = false
    
    let apiEnvironment: APIEnvironment
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                planStatusSection
                membershipSection
                legalSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showMembershipSheet) {
            Group {
                if container.featureAccessService.isPro {
                    ProBenefitsView()
                } else {
                    PaywallView()
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete All My Data", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task {
                    await viewModel.deleteAllData()
                }
            }
        } message: {
            Text(
                "This will permanently delete all your data from our servers "
                + "and remove all local sessions. This action cannot be undone."
            )
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Data Deleted", isPresented: $viewModel.showDeleteSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("All your data has been successfully deleted.")
        }
    }
    
    // MARK: - Sections
    
    private var planStatusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Text(container.featureAccessService.isPro ? "Pro Plan" : "Free Plan")
                        .font(AppTheme.Typography.title)
                    
                    Spacer()
                    
                    if !container.featureAccessService.isPro {
                        Button {
                            showMembershipSheet = true
                        } label: {
                            Text("Upgrade to Pro")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.background)
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, AppTheme.Spacing.xxs)
                                .background(AppTheme.Colors.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                if container.featureAccessService.isPro {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 4)
                    
                    Text("Unlimited sessions & asks")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                } else {
                    let used = container.featureAccessService.sessionCreationCountThisMonth
                    let total = container.featureAccessService.maxFreeSessionCreations
                    
                    ProgressView(
                        value: Double(min(used, total)),
                        total: Double(total)
                    )
                    .tint(used >= total ? AppTheme.Colors.destructive : AppTheme.Colors.primary)
                    
                    Text("\(used) of \(total) sessions completed this month")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xxs)
        }
    }
    
    private var membershipSection: some View {
        Section("Subscription") {
            Button {
                showMembershipSheet = true
            } label: {
                HStack {
                    Label(membershipRowTitle, systemImage: "star.circle")
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
        }
    }
    
    private var legalSection: some View {
        Section("Legal") {
            Button {
                safariURL = apiEnvironment.privacyPolicyURL
            } label: {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised")
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            
            Button {
                safariURL = apiEnvironment.termsOfServiceURL
            } label: {
                HStack {
                    Label("Terms of Service", systemImage: "doc.text")
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            
            Button(role: .destructive) {
                viewModel.confirmDeleteAllData()
            } label: {
                HStack {
                    Label("Delete All My Data", systemImage: "trash")
                    Spacer()
                    if viewModel.isDeleting {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isDeleting)
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    private var membershipRowTitle: String {
        "Manage subscription"
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            userClient: MockUserClient(),
            sessionRepository: SessionRepository(
                modelContext: DependencyContainer.preview().modelContainer.mainContext
            ),
            settingsService: SettingsService()
        ),
        apiEnvironment: .prod
    )
}

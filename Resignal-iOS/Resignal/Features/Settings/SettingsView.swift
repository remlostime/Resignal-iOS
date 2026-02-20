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
    @State var viewModel: SettingsViewModel
    @State private var safariURL: URL?
    
    private static let privacyPolicyURL = URL(string: "https://resignal.app/privacy")!
    private static let termsOfServiceURL = URL(string: "https://resignal.app/terms")!
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
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
    
    private var legalSection: some View {
        Section("Legal") {
            Button {
                safariURL = Self.privacyPolicyURL
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
                safariURL = Self.termsOfServiceURL
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
        )
    )
}

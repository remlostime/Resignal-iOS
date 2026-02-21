//
//  HomeView.swift
//  Resignal
//
//  Main home screen displaying the session list.
//

import SwiftUI

/// Home screen with session list and navigation
struct HomeView: View {
    
    // MARK: - Properties
    
    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: HomeViewModel?
    @State private var showCreateSessionSheet = false
    @State private var showPaywall = false
    @State private var showSettings = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Resignal")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                viewModel: SettingsViewModel(
                    userClient: container.userClient,
                    sessionRepository: container.sessionRepository,
                    settingsService: container.settingsService
                ),
                apiEnvironment: container.settingsService.apiEnvironment
            )
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HomeViewModel(sessionRepository: container.sessionRepository)
            }
            viewModel?.loadSessions()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func contentView(viewModel: HomeViewModel) -> some View {
        @Bindable var bindableVM = viewModel
        
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            if viewModel.state.isLoading {
                ProgressView()
            } else if viewModel.sessions.isEmpty {
                emptyStateView
            } else if viewModel.filteredSessions.isEmpty {
                noSearchResultsView
            } else {
                sessionListView(viewModel: viewModel)
            }
        }
        .alert("Delete Session?", isPresented: $bindableVM.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("Delete", role: .destructive) {
                viewModel.executePendingDelete()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Rename Session", isPresented: Binding(
            get: { viewModel.sessionToRename != nil },
            set: { if !$0 { viewModel.cancelRename() } }
        )) {
            TextField("Session title", text: $bindableVM.renameText)
            Button("Cancel", role: .cancel) {
                viewModel.cancelRename()
            }
            Button("Save") {
                viewModel.executeRename()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.state.hasError },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.state.error ?? "An error occurred")
        }
        .conditionally(!viewModel.sessions.isEmpty) { view in
            view.searchable(text: $bindableVM.searchText, prompt: "Search sessions")
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: "mic.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Text("No Sessions Yet")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text("Record your interview practice or type your responses to get AI-powered feedback")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                
                // Floating action button
                Button {
                    showCreateSessionSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.Colors.primary)
                        .clipShape(Circle())
                        .mediumShadow()
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
            
            Spacer()
            Spacer()
        }
        .sheet(isPresented: $showCreateSessionSheet) {
            CreateSessionSheet(
                onRecordSelected: {
                    handleNewSession { router.navigate(to: .recording(session: nil)) }
                },
                onTypeSelected: {
                    handleNewSession { router.navigate(to: .editor(session: nil)) }
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier(HomeAccessibility.emptyStateView)
    }
    
    private var noSearchResultsView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("No Matching Sessions")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Try a different search term")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(HomeAccessibility.noSearchResults)
    }
    
    private func sessionListView(viewModel: HomeViewModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                ForEach(viewModel.filteredSessions, id: \.id) { session in
                    SessionRowView(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if session.hasAnalysis {
                                router.navigate(to: .result(session: session))
                            } else {
                                router.navigate(to: .editor(session: session))
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.confirmDelete(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                viewModel.startRename(session)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(AppTheme.Colors.secondary)
                        }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(
                    top: AppTheme.Spacing.xs,
                    leading: AppTheme.Spacing.md,
                    bottom: AppTheme.Spacing.xs,
                    trailing: AppTheme.Spacing.md
                ))
            }
            .listStyle(.plain)
            .refreshable {
                viewModel.loadSessions()
            }
            .accessibilityIdentifier(HomeAccessibility.sessionList)
            
            // Floating Action Button
            Button {
                showCreateSessionSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(AppTheme.Colors.primary)
                    .clipShape(Circle())
                    .mediumShadow()
            }
            .padding(.trailing, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.md)
        }
        .sheet(isPresented: $showCreateSessionSheet) {
            CreateSessionSheet(
                onRecordSelected: {
                    handleNewSession { router.navigate(to: .recording(session: nil)) }
                },
                onTypeSelected: {
                    handleNewSession { router.navigate(to: .editor(session: nil)) }
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Session Creation Gating
    
    private func handleNewSession(navigate: () -> Void) {
        if container.featureAccessService.canCreateSession {
            navigate()
        } else {
            showPaywall = true
        }
    }
}

// MARK: - Accessibility Identifiers

enum HomeAccessibility {
    static let emptyStateView = "emptyStateView"
    static let noSearchResults = "noSearchResults"
    static let sessionList = "sessionList"
    static let sessionRow = "sessionRow"
}

/// Row view for a single session
struct SessionRowView: View {
    
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            // Title and date
            HStack {
                Text(session.displayTitle)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(session.createdAt.relativeFormatted)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            
            // Preview
            if !session.inputPreview.isEmpty {
                Text(session.inputPreview)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            // Tags and status
            HStack(spacing: AppTheme.Spacing.xs) {
                // Audio indicator
                if session.hasAudioRecording {
                    Label("Audio", systemImage: "waveform")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                // Attachment indicator
                if session.hasAttachments {
                    Label("\(session.attachments.count)", systemImage: "paperclip")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                if !session.tags.isEmpty {
                    TagChipsView(tags: Array(session.tags.prefix(3)))
                }
                
                Spacer()
                
                if session.hasAnalysis {
                    Label("Analyzed", systemImage: "checkmark.circle.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.success)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .cardStyle()
        .accessibilityIdentifier(HomeAccessibility.sessionRow)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
    .environment(DependencyContainer.preview())
}

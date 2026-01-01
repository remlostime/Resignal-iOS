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
                    router.navigate(to: .settings)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .accessibilityIdentifier(HomeAccessibility.settingsButton)
            }
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
            } else if viewModel.filteredSessions.isEmpty && viewModel.searchText.isEmpty {
                emptyStateView
            } else if viewModel.filteredSessions.isEmpty {
                noSearchResultsView
            } else {
                sessionListView(viewModel: viewModel)
            }
            
            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    newSessionButton
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .searchable(text: $bindableVM.searchText, prompt: "Search sessions")
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
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "bubble.left.and.bubble.right",
                title: "No Sessions Yet",
                description: "Start analyzing your interview responses to get actionable feedback.",
                actionTitle: "New Session"
            ) {
                router.navigate(to: .editor(session: nil))
            }
            Spacer()
            Spacer()
        }
        .accessibilityIdentifier(HomeAccessibility.emptyStateView)
    }
    
    private var noSearchResultsView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            Text("No Results")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("No sessions match your search.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Spacer()
        }
    }
    
    private func sessionListView(viewModel: HomeViewModel) -> some View {
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
            
            // Bottom spacer for FAB
            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .refreshable {
            viewModel.loadSessions()
        }
        .accessibilityIdentifier(HomeAccessibility.sessionList)
    }
    
    private var newSessionButton: some View {
        Button {
            router.navigate(to: .editor(session: nil))
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AppTheme.Colors.primary)
                .clipShape(Circle())
                .mediumShadow()
        }
        .accessibilityIdentifier(HomeAccessibility.newSessionButton)
    }
}

// MARK: - Accessibility Identifiers

enum HomeAccessibility {
    static let newSessionButton = "newSessionButton"
    static let settingsButton = "settingsButton"
    static let emptyStateView = "emptyStateView"
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

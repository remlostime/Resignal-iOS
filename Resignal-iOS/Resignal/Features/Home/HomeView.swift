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
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.sessions.isEmpty {
                emptyStateView
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
        .alert("Delete Session?", isPresented: Binding(
            get: { viewModel.showDeleteConfirmation },
            set: { if !$0 { viewModel.cancelDelete() } }
        )) {
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
            TextField("Session title", text: Binding(
                get: { viewModel.renameText },
                set: { viewModel.renameText = $0 }
            ))
            Button("Cancel", role: .cancel) {
                viewModel.cancelRename()
            }
            Button("Save") {
                viewModel.executeRename()
            }
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
    }
    
    private func sessionListView(viewModel: HomeViewModel) -> some View {
        List {
            ForEach(viewModel.sessions, id: \.id) { session in
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
    }
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


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
    @State private var showMembershipSheet = false
    
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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showMembershipSheet = true
                } label: {
                    Text(container.featureAccessService.currentPlan.rawValue.capitalized)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xxs)
                        .background(AppTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
            }
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
        .onAppear {
            if viewModel == nil {
                viewModel = HomeViewModel(
                    interviewClient: container.interviewClient,
                    sessionRepository: container.sessionRepository
                )
            }
        }
        .task {
            await viewModel?.loadInterviews()
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
            } else if viewModel.interviews.isEmpty {
                emptyStateView
            } else if viewModel.filteredInterviews.isEmpty {
                noSearchResultsView
            } else {
                interviewListView(viewModel: viewModel)
            }
        }
        .alert("Delete Interview?", isPresented: $bindableVM.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("Delete", role: .destructive) {
                viewModel.executePendingDelete()
            }
        } message: {
            Text("This action cannot be undone.")
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
        .conditionally(!viewModel.interviews.isEmpty) { view in
            view.searchable(text: $bindableVM.searchText, prompt: "Search interviews")
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: "mic.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Text("No Interviews Yet")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text("Record your interview practice or type your responses to get AI-powered feedback")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                
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
            
            Text("No Matching Interviews")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Try a different search term")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(HomeAccessibility.noSearchResults)
    }
    
    private func interviewListView(viewModel: HomeViewModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                ForEach(viewModel.filteredInterviews) { interview in
                    InterviewRowView(interview: interview)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleInterviewTap(interview, viewModel: viewModel)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.confirmDelete(interview)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
                await viewModel.loadInterviews()
            }
            .accessibilityIdentifier(HomeAccessibility.sessionList)
            
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
    
    // MARK: - Navigation
    
    private func handleInterviewTap(_ interview: InterviewDTO, viewModel: HomeViewModel) {
        guard let session = viewModel.findLocalSession(for: interview) else {
            router.navigate(to: .editor(session: nil))
            return
        }
        
        if session.hasAnalysis {
            router.navigate(to: .result(session: session))
        } else {
            router.navigate(to: .editor(session: session))
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
    static let interviewRow = "interviewRow"
}

/// Row view for a single interview from the API
struct InterviewRowView: View {
    
    let interview: InterviewDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Text(interview.displayTitle)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(interview.createdAt.relativeFormatted)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            
            if let summary = interview.summary, !summary.isEmpty {
                Text(summary)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(AppTheme.Spacing.md)
        .cardStyle()
        .accessibilityIdentifier(HomeAccessibility.interviewRow)
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

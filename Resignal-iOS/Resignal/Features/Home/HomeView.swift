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
    @State private var pendingDrafts: [TranscriptionDraft] = []
    
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
                        .font(AppTheme.Typography.caption.weight(.bold))
                }
                .buttonStyle(.borderless)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                viewModel: SettingsViewModel(
                    apiClient: container.apiClient,
                    settingsService: container.settingsService,
                    audioCacheService: container.audioCacheService
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
                    interviewClient: container.interviewClient
                )
            }
        }
        .task {
            await viewModel?.loadInterviews()
            await loadPendingDrafts()
        }
    }
    
    // MARK: - Subviews
    
    private var hasAnyContent: Bool {
        guard let viewModel else { return false }
        return !viewModel.interviews.isEmpty || !pendingDrafts.isEmpty
    }
    
    @ViewBuilder
    private func contentView(viewModel: HomeViewModel) -> some View {
        @Bindable var bindableVM = viewModel
        
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            if viewModel.state.isLoading {
                ProgressView()
            } else if viewModel.interviews.isEmpty && pendingDrafts.isEmpty {
                emptyStateView
            } else if viewModel.filteredInterviews.isEmpty && pendingDrafts.isEmpty {
                noSearchResultsView
            } else {
                mergedListView(viewModel: viewModel)
            }
        }
        .alert("Delete Interview?", isPresented: $bindableVM.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.executePendingDelete()
                }
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
        .conditionally(hasAnyContent) { view in
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
                    handleNewSession { router.navigate(to: .recording) }
                },
                onTypeSelected: {
                    handleNewSession { router.navigate(to: .editor()) }
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
    
    private var mergedItems: [HomeListItem] {
        let interviewItems = (viewModel?.filteredInterviews ?? []).map { HomeListItem.interview($0) }
        let draftItems = pendingDrafts.map { HomeListItem.draft($0) }
        return (interviewItems + draftItems).sorted { $0.createdAt > $1.createdAt }
    }
    
    private func mergedListView(viewModel: HomeViewModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                ForEach(mergedItems) { item in
                    Group {
                        switch item {
                        case .interview(let interview):
                            InterviewRowView(interview: interview)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleInterviewTap(interview)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.confirmDelete(interview)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        case .draft(let draft):
                            DraftRowView(draft: draft)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    router.navigate(to: .draft(recordingId: draft.recordingId))
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task {
                                            await container.audioCacheService.evict(recordingId: draft.recordingId)
                                            pendingDrafts.removeAll { $0.id == draft.id }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
            .contentMargins(.bottom, 80, for: .scrollContent)
            .refreshable {
                await viewModel.loadInterviews()
                await loadPendingDrafts()
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
                    handleNewSession { router.navigate(to: .recording) }
                },
                onTypeSelected: {
                    handleNewSession { router.navigate(to: .editor()) }
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func loadPendingDrafts() async {
        let drafts = await container.audioCacheService.allDrafts()
        pendingDrafts = drafts.filter { $0.status == .failed || $0.status == .uploading || $0.status == .processing }
    }
    
    // MARK: - Navigation
    
    private func handleInterviewTap(_ interview: InterviewDTO) {
        router.navigate(to: .interviewDetail(interviewId: interview.id))
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
            Text(interview.displayTitle)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)
            
            Text(interview.createdAt.relativeFormatted)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
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

// MARK: - Merged List Item

enum HomeListItem: Identifiable {
    case interview(InterviewDTO)
    case draft(TranscriptionDraft)
    
    var id: String {
        switch self {
        case .interview(let dto): return "interview-\(dto.id)"
        case .draft(let draft): return "draft-\(draft.id.uuidString)"
        }
    }
    
    var createdAt: Date {
        switch self {
        case .interview(let dto): return dto.createdAt
        case .draft(let draft): return draft.createdAt
        }
    }
}

// MARK: - Draft Row View

struct DraftRowView: View {
    
    let draft: TranscriptionDraft
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.Colors.destructive)
                    .font(AppTheme.Typography.callout)
                
                Text("Transcription Failed")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            
            Text(draft.createdAt.relativeFormatted)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("Tap to retry — your recording is saved")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(2)
        }
        .padding(AppTheme.Spacing.md)
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.destructive.opacity(0.3), lineWidth: 1)
        )
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

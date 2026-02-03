//
//  AskChatView.swift
//  Resignal
//
//  Chat interface for asking questions about analyzed sessions.
//

import SwiftUI

/// Chat view for interactive Q&A about session analysis
struct AskChatView: View {
    
    @Binding var messages: [ChatMessage]
    @Binding var inputText: String
    @Binding var isSending: Bool
    @Binding var isLoading: Bool
    
    let onSend: () -> Void
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            if isLoading {
                loadingView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.sm) {
                            if messages.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(messages, id: \.id) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                }
                            }
                            
                            if isSending {
                                HStack {
                                    ProgressView()
                                        .padding(AppTheme.Spacing.sm)
                                    Text("Thinking...")
                                        .font(AppTheme.Typography.callout)
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                    Spacer()
                                }
                                .padding(AppTheme.Spacing.sm)
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Divider()
                .background(AppTheme.Colors.divider)
            
            // Input field
            HStack(spacing: AppTheme.Spacing.sm) {
                TextField("Ask a question...", text: $inputText, axis: .vertical)
                    .font(AppTheme.Typography.body)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .padding(AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                    .disabled(isSending)
                
                Button {
                    onSend()
                    isInputFocused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
                                ? AppTheme.Colors.textTertiary
                                : AppTheme.Colors.primary
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.background)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("Ask About Your Analysis")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Ask questions to get more insights about your interview performance")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading messages...")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Individual message bubble
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: AppTheme.Spacing.xxs) {
                Text(message.content)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(message.isUser ? Color.white : AppTheme.Colors.textPrimary)
                    .padding(AppTheme.Spacing.sm)
                    .background(
                        message.isUser
                            ? AppTheme.Colors.primary
                            : AppTheme.Colors.surface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                
                Text(message.timestamp.relativeFormatted)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .padding(.horizontal, AppTheme.Spacing.xs)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AskChatView(
        messages: .constant([
            ChatMessage.sampleUser,
            ChatMessage.sampleAssistant
        ]),
        inputText: .constant(""),
        isSending: .constant(false),
        isLoading: .constant(false),
        onSend: {}
    )
}

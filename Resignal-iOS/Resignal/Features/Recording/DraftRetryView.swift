//
//  DraftRetryView.swift
//  Resignal
//
//  Screen for retrying a previously failed Whisper transcription from a cached recording.
//

import SwiftUI

struct DraftRetryView: View {

    @Environment(Router.self) private var router
    @Environment(DependencyContainer.self) private var container

    let recordingId: UUID

    @State private var isRetrying = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var transcriptText = ""

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "waveform.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Text("Transcription Failed")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Your recording was saved. Tap below to retry transcription.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)

            Spacer()

            if isRetrying {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ProgressView()
                    Text(transcriptText.isEmpty ? "Preparing..." : transcriptText)
                        .font(AppTheme.Typography.callout)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            PrimaryButton(
                "Retry Transcription",
                icon: "arrow.clockwise",
                isLoading: isRetrying
            ) {
                Task { await retry() }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)

            Button("Discard Recording") {
                Task {
                    await container.audioCacheService.evict(recordingId: recordingId)
                    router.pop()
                }
            }
            .font(AppTheme.Typography.callout)
            .foregroundStyle(AppTheme.Colors.destructive)

            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .navigationTitle("Retry")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func retry() async {
        guard let cachedURL = await container.audioCacheService.cachedURL(for: recordingId) else {
            errorMessage = "Recording no longer available."
            showError = true
            return
        }

        isRetrying = true
        defer { isRetrying = false }

        let observeTask = Task { @MainActor in
            let stream = await container.audioUploadService.observeState()
            for await state in stream {
                guard !Task.isCancelled else { break }
                switch state {
                case .preparing: transcriptText = "Preparing audio..."
                case .uploading(let progress): transcriptText = "Uploading audio... \(Int(progress * 100))%"
                case .processing: transcriptText = "Transcribing audio..."
                default: break
                }
            }
        }

        do {
            let transcript = try await container.audioUploadService.uploadInterviewAudio(
                fileURL: cachedURL,
                interviewId: nil
            )

            var draft = await container.audioCacheService.loadDraft(for: recordingId)
            draft?.status = .completed
            draft?.partialTranscript = transcript
            if let draft { try? await container.audioCacheService.saveDraft(draft) }

            observeTask.cancel()
            router.replace(with: .editor(
                initialTranscript: transcript,
                audioURL: cachedURL,
                recordingId: recordingId
            ))
        } catch {
            observeTask.cancel()
            if var draft = await container.audioCacheService.loadDraft(for: recordingId) {
                draft.status = .failed
                draft.lastError = error.localizedDescription
                try? await container.audioCacheService.saveDraft(draft)
            }
            errorMessage = error.localizedDescription
            showError = true
            transcriptText = ""
        }
    }
}

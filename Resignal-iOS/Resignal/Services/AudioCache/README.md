# AudioCache Module

Disk-backed cache for audio recordings awaiting transcription, with draft persistence for retry and app-relaunch recovery.

## Purpose

Prevents audio loss when the Whisper transcription API fails. Recordings are copied to a stable cache directory before upload and retained until the user sees a successful transcript in the Editor. Failed transcriptions are persisted as drafts that survive app kills and restarts.

## Architecture

- **`AudioCacheService`** — protocol defining cache, draft, and storage-metrics operations.
- **`AudioCacheServiceImpl`** — production `actor` implementation backed by `Documents/AudioCache/`.
- **`MockAudioCacheService`** — in-memory mock for previews and tests.
- **`TranscriptionDraft`** — `Codable` model persisted as a JSON sidecar alongside each cached audio file.

## Cache Directory

```
Documents/AudioCache/
  {recordingId}.m4a          ← cached audio copy
  {recordingId}.draft.json   ← TranscriptionDraft metadata
```

- Located in `Documents/` (not `Caches/`) so the system does not purge it under storage pressure.
- `isExcludedFromBackup = true` is set on the directory to avoid bloating iCloud backups.
- Stale drafts older than **7 days** are automatically evicted on service init.

## Draft Lifecycle

| Status | Meaning |
|--------|---------|
| `pending` | Audio cached, upload not yet started |
| `uploading` | Chunk upload in progress |
| `processing` | Server-side Whisper transcription in progress |
| `failed` | Last attempt failed — retryable |
| `completed` | Transcript received successfully |

## Eviction Rules

- **Explicit eviction** by `recordingId`: called from `EditorView.onAppear` after the user sees a successful transcript.
- **Bulk eviction** (`evictAll`): available from the Settings > Storage > Clear Cache button.
- **Staleness eviction**: drafts older than 7 days are cleaned up automatically on service initialization.

## Integration Points

| Consumer | Usage |
|----------|-------|
| `RecordingViewModel` | Caches audio before Whisper upload; saves/updates draft on success or failure; provides retry |
| `EditorView` | Evicts cache when transcript is displayed successfully |
| `HomeView` | Shows pending-draft banner for failed transcriptions |
| `DraftRetryView` | Loads cached audio and retries upload from the `.draft` route |
| `SettingsView` | Displays total cache size; offers Clear Cache button |
| `DependencyContainer` | Registers `AudioCacheServiceImpl` (production) or `MockAudioCacheService` (preview) |

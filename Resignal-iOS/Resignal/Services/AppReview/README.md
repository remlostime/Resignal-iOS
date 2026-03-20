# AppReview Module

Manages the in-app review prompt and feedback collection flow.

## Purpose

Encourages honest App Store reviews from satisfied users while capturing constructive feedback from dissatisfied users through an internal form. The flow is designed to feel like a natural check-in, not a growth hack.

## Architecture

- **`AppReviewServiceProtocol`** — defines gating logic, lifetime counters, and event recording.
- **`AppReviewService`** — production implementation backed by `UserDefaults`.
- **`MockAppReviewService`** — mock for previews and tests.
- **`AppReviewFlowView`** — multi-step SwiftUI sheet (sentiment check → follow-up or feedback form).

## User Flow

```
Trigger → Sentiment Check ("Has Resignal been helpful so far?")
  ├─ "Yes" → Follow-up: "Leave a review" | "Share feedback"
  │            ├─ Leave a review → SKStoreReviewController.requestReview()
  │            └─ Share feedback → Internal feedback form (stubbed)
  └─ "Not really" → Internal feedback form (stubbed)
```

## Trigger Points

| Trigger | Location | Condition |
|---------|----------|-----------|
| Feedback tab scroll | `InterviewDetailView` | Last card visible for 3 seconds, lifetime sessions >= 1 |
| Session completed | `EditorViewModel.analyze()` | Lifetime sessions >= 2 |
| Ask message sent | `InterviewDetailViewModel.sendAskMessage()` | Lifetime Ask messages >= 2 |

## Gating Rules (`shouldPromptReview()`)

- Max **3 prompts** per user lifetime.
- If user already submitted a review → never show again.
- If user dismissed → **14-day** cooldown before retrying.
- If prompt was already shown recently → **14-day** cooldown.

## Persisted State (UserDefaults)

| Key | Type | Description |
|-----|------|-------------|
| `appReview.lifetimeSessionCount` | `Int` | Total sessions completed (all users, never resets) |
| `appReview.lifetimeAskMessageCount` | `Int` | Total Ask messages sent (all users, never resets) |
| `appReview.promptShownCount` | `Int` | Times the sentiment prompt was displayed |
| `appReview.lastPromptDate` | `Date?` | When the prompt was last shown |
| `appReview.reviewSubmitted` | `Bool` | Whether user tapped "Leave a review" |
| `appReview.lastDismissedDate` | `Date?` | When the user last dismissed the prompt |
| `appReview.systemReviewTriggered` | `Bool` | Whether `requestReview()` was called |

## Constants (`AppReviewConstants`)

| Constant | Value | Description |
|----------|-------|-------------|
| `maxLifetimePrompts` | 3 | Maximum prompts shown per user |
| `minSessionsForFirstPrompt` | 1 | Sessions needed for scroll-based trigger |
| `sessionCountForAutoPrompt` | 2 | Sessions needed for auto-trigger on completion |
| `askCountForPrompt` | 2 | Ask messages needed for trigger |
| `dismissCooldownDays` | 14 | Days to wait after dismissal |
| `feedbackReadDelay` | 3.0s | Seconds to wait after scroll-to-bottom |

## Future Work

- Wire the feedback form to a backend API endpoint for collecting user feedback.
- Add analytics events for funnel tracking (prompt shown, sentiment choice, review/feedback submitted).

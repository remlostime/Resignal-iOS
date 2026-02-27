---

## Backend Change Summary

The `x-client-id` header authentication has been replaced with JWT-based auth. The key changes:

- **New auth flow**: iOS generates a UUID (`anonymousId`) on first launch, sends it to `POST /api/auth/register`, and receives a JWT token back. All subsequent requests use `Authorization: Bearer <token>`.
- **No more `x-client-id` header** -- removed from every endpoint.
- **No more `user_id` in request body/query** -- the server derives the user identity from the JWT. The client never sends a userId.
- **StoreKit 2 JWS transaction verification** at `POST /api/billing/verify` -- accepts a `signedTransaction` JWS string (not the legacy Base64 receipt blob).
- **Plan is a string enum** (`"free"` | `"pro"`), not a boolean `isPro`, in the auth response.
- **Standardized error format** across all endpoints.

---

## Client API Spec

### Authentication

All protected endpoints require:

```
Authorization: Bearer <token>
```

---

### Error Format (all endpoints)

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message"
  }
}
```

Common error codes:
| Code | HTTP Status | Meaning |
|------|-------------|---------|
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `USER_NOT_FOUND` | 401 | Token valid but user deleted |
| `PRO_REQUIRED` | 403 | Active Pro subscription required |
| `RATE_LIMITED` | 429 | Too many requests |
| `INVALID_RECEIPT` | 400 | JWS transaction verification failed |
| `INVALID_INPUT` | 400 | Bad request body/params |
| `NOT_FOUND` | 404 | Resource not found |
| `INTERNAL_ERROR` | 500 | Server error |

---

### 1. Register / Login

**`POST /api/auth/register`** -- Public (no token needed)

Request:
```json
{
  "anonymousId": "550e8400-e29b-41d4-a716-446655440000"
}
```

Response `200`:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "uuid",
    "plan": "free"
  }
}
```

Notes:
- `plan` is a string enum: `"free"` or `"pro"` (not a boolean `isPro`).
- `anonymousId` must be a valid UUID, generated on device once and persisted in Keychain.
- Idempotent: calling again with the same `anonymousId` returns a new token for the existing user.
- Rate limited to 5 requests/min per `anonymousId`.
- Store the returned `token` securely (Keychain). Use it for all subsequent API calls.

---

### 2. Verify Apple Subscription (StoreKit 2 JWS)

**`POST /api/billing/verify`** -- Protected

Request:
```json
{
  "signedTransaction": "eyJhbGciOiJFUzI1NiIs..."
}
```

The `signedTransaction` is a JWS (JSON Web Signature) string obtained from StoreKit 2's `VerificationResult.jwsRepresentation`. It is **not** the legacy Base64 receipt blob from `Bundle.main.appStoreReceiptURL`.

iOS code to obtain the JWS:
```swift
// After purchase:
let result = try await product.purchase()
case .success(let verification):
    let jwsString = verification.jwsRepresentation
    // Send jwsString as signedTransaction

// From current entitlement:
for await result in Transaction.currentEntitlements {
    let jwsString = result.jwsRepresentation
    // Send jwsString as signedTransaction
}
```

Response `200`:
```json
{
  "isPro": true,
  "expiresAt": "2026-03-23T00:00:00.000Z"
}
```

Error `400`:
```json
{
  "error": {
    "code": "INVALID_RECEIPT",
    "message": "Transaction verification failed"
  }
}
```

Notes:
- Rate limited to 10 requests/min per user.
- Server verifies the JWS signature and payload with Apple's App Store Server API.
- On success, user's plan is updated to `pro` server-side.
- The iOS client treats backend verification failures as non-blocking -- the purchase flow still completes locally.

---

### 3. Interviews

**`GET /api/interviews`** -- Protected

Query params: `page` (default 1), `page_size` (default 20, max 100)

> **Breaking change**: Removed `user_id` query param. User is derived from token.

Response `200`:
```json
{
  "interviews": [
    {
      "id": "uuid",
      "title": "string | null",
      "summary": "string | null",
      "created_at": "2026-02-23T..."
    }
  ],
  "pagination": {
    "current_page": 1,
    "page_size": 20,
    "total_pages": 3,
    "total_items": 42
  }
}
```

---

**`GET /api/interviews/:id`** -- Protected

Response `200`:
```json
{
  "id": "uuid",
  "title": "string",
  "summary": "string",
  "strengths": "...",
  "improvement": "...",
  "hiring_signal": "...",
  "key_observations": "..."
}
```

---

**`GET /api/interviews/:id/transcript`** -- Protected

Response `200`:
```json
{
  "id": "uuid",
  "transcript": "string"
}
```

---

**`POST /api/interviews`** -- Protected

Request:
```json
{
  "input": "string",
  "locale": "en",
  "image": {
    "base64": "...",
    "mimeType": "image/png"
  },
  "model": "optional"
}
```

Response `200`:
```json
{
  "provider": "gemini",
  "interview_id": "uuid",
  "reply": { ... }
}
```

---

**`GET /api/interviews/:interviewId/messages`** -- Protected

Response `200`:
```json
{
  "success": true,
  "messages": [ ... ]
}
```

---

### 4. Messages

**`POST /api/messages`** -- Protected

> **Breaking change**: Removed `user_id` from body. User is derived from token.

Request:
```json
{
  "interview_id": "uuid",
  "message": "string",
  "model": "optional"
}
```

Response `200`:
```json
{
  "success": true,
  "reply": "string",
  "messageId": "uuid"
}
```

---

### 5. Transcriptions

**`POST /api/transcriptions`** -- Protected

> **Breaking change**: Removed `x-client-id` header. User derived from token.

Request:
```json
{
  "totalChunks": 3
}
```

Response `200`:
```json
{
  "success": true,
  "jobId": "uuid",
  "status": "pending"
}
```

---

**`POST /api/transcriptions/:jobId/chunks`** -- Protected

Request: `multipart/form-data` with fields `audio` (file) and `chunkIndex` (number)

Response `200`:
```json
{
  "success": true,
  "chunksUploaded": 2,
  "totalChunks": 3
}
```

---

**`GET /api/transcriptions/:jobId`** -- Protected

Response `200`:
```json
{
  "success": true,
  "status": "completed",
  "transcript": "string | null",
  "segments": "object | null",
  "duration": 120.5,
  "completedChunks": 3,
  "totalChunks": 3
}
```

---

### Client Migration Checklist

- [x] Generate and persist a UUID in Keychain as `anonymousId` on first launch
- [x] Call `POST /api/auth/register` and store the returned `token` in Keychain
- [x] Add `Authorization: Bearer <token>` header to all API requests
- [x] Remove all `x-client-id` headers
- [x] Remove `user_id` from `POST /api/messages` body
- [x] Remove `user_id` from `GET /api/interviews` query params
- [x] Handle 401 responses by re-calling `/api/auth/register` to refresh the token
- [x] Update error handling to parse `{ error: { code, message } }` format
- [x] Use `user.plan` (string: `"free"` / `"pro"`) instead of `user.isPro` (boolean)
- [x] StoreKit 2 already in use (`Product.purchase()`, `Transaction.updates`)
- [x] After purchase, send `VerificationResult.jwsRepresentation` to `POST /api/billing/verify` as `signedTransaction`
- [x] Send JWS to backend on restore purchases and transaction listener updates
- [x] Map `INVALID_RECEIPT` error code in `APIError.from(code:message:)`

---

## Testing Guide

### Quick test: Mock subscription (no backend needed)

1. Run the app in the iOS Simulator (DEBUG build).
2. Shake the device (Ctrl+Cmd+Z) to open **Internal Settings**.
3. Toggle **Enable Mock Subscription** on.
4. Switch the **Plan** picker between Free and Pro.
5. Verify that feature gating (session limits, ask message limits) updates correctly.

This tests UI and feature-gating logic but does **not** exercise the `POST /api/billing/verify` network call.

### StoreKit Testing in Xcode (client-side flow)

Uses the StoreKit configuration file (`Resignal: Mock Interviews.storekit`) with sandbox products.

1. In Xcode: Product > Scheme > Edit Scheme > Run > Options > set **StoreKit Configuration** to `Resignal: Mock Interviews.storekit`.
2. Run the app on the Simulator.
3. Open the Paywall and tap Subscribe. Xcode's StoreKit sandbox simulates the purchase dialog (no real charge).
4. Watch the Xcode console for `[SubscriptionService]` logs:
   - `"Purchase successful: com.resignal.pro.monthly"`
   - `"Backend transaction verification: isPro=..."` (success) or `"Backend transaction verification failed: ..."` (expected if backend rejects Xcode sandbox JWS)
5. Test Restore: tap "Restore Purchases" in the paywall footer.
6. Manage subscriptions via Xcode menu: Debug > StoreKit > Manage Transactions (refund, expire, etc.). This triggers `Transaction.updates` and the listener will attempt backend verification.

**Important:** Xcode StoreKit Testing JWS tokens are signed by a local Xcode certificate, **not** by Apple. The backend cannot validate them against Apple's servers. Use this mode to verify the client-side flow (correct request shape, JWS extraction, error handling) but expect `INVALID_RECEIPT` from the backend.

### Backend API testing with Postman/curl

Test the backend endpoint in isolation without the iOS app.

**Test request parsing and error format (dummy JWS):**

```bash
# First, get a JWT token
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"anonymousId": "550e8400-e29b-41d4-a716-446655440000"}'

# Use the returned token to test billing verify
curl -X POST http://localhost:3000/api/billing/verify \
  -H "Authorization: Bearer <token-from-above>" \
  -H "Content-Type: application/json" \
  -d '{"signedTransaction": "fake.jws.string"}'
```

With a dummy JWS, the backend should return:
```json
{
  "error": {
    "code": "INVALID_RECEIPT",
    "message": "Transaction verification failed"
  }
}
```

This validates: routing, auth header parsing, request body shape (`signedTransaction` field), and error response format.

**Test with a real sandbox JWS:**

1. Run the app on a **physical device** (not Simulator) with development signing.
2. Use a [sandbox Apple ID](https://appstoreconnect.apple.com/access/testers) to make a purchase.
3. Capture the JWS string from the Xcode console (printed by `[SubscriptionService]` debug logs, or add a temporary `print(jwsRepresentation)` in `verifyTransactionWithBackend`).
4. Use that JWS in Postman/curl against your dev backend.

A real sandbox JWS is signed by Apple's sandbox infrastructure and the backend can validate it if configured for the sandbox environment.

### End-to-end with local backend

1. Start the local backend: `cd <backend-repo> && npm run dev` (port 3000).
2. In the app, shake to open Internal Settings > switch **API Environment** to **Dev** (the app restarts, base URL becomes `http://localhost:3000`).
3. Make a StoreKit test purchase (Xcode sandbox).
4. Check backend logs for the incoming request: `POST /api/billing/verify` with `Authorization: Bearer <jwt>` and body `{ "signedTransaction": "..." }`.
5. The backend will likely return `INVALID_RECEIPT` for Xcode sandbox JWS -- this is expected. The client-side purchase flow still completes because backend verification is non-blocking.
6. For full Apple validation, use a physical device with a sandbox Apple ID.

### Testing summary

| What to validate | Mock toggle | Xcode StoreKit | Postman/curl | Physical device |
|---|---|---|---|---|
| UI / feature gating | Yes | Yes | -- | Yes |
| `Product.purchase()` flow | -- | Yes | -- | Yes |
| JWS extraction from `VerificationResult` | -- | Yes | -- | Yes |
| Backend request shape and routing | -- | Yes* | Yes | Yes |
| Backend Apple JWS validation | -- | No | With sandbox JWS | Yes |
| Error format (`INVALID_RECEIPT`, etc.) | -- | Yes* | Yes | Yes |
| Restore + listener backend verification | -- | Yes* | -- | Yes |

*Backend call fires but returns `INVALID_RECEIPT` for Xcode sandbox JWS.

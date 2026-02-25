---

## Backend Change Summary

The `x-client-id` header authentication has been replaced with JWT-based auth. The key changes:

- **New auth flow**: iOS generates a UUID (`anonymousId`) on first launch, sends it to `POST /api/auth/register`, and receives a JWT token back. All subsequent requests use `Authorization: Bearer <token>`.
- **No more `x-client-id` header** -- removed from every endpoint.
- **No more `user_id` in request body/query** -- the server derives the user identity from the JWT. The client never sends a userId.
- **Apple receipt verification** added at `POST /api/billing/verify` to validate subscriptions server-side.
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
    "isPro": false
  }
}
```

Notes:
- `anonymousId` must be a valid UUID, generated on device once and persisted in Keychain.
- Idempotent: calling again with the same `anonymousId` returns a new token for the existing user.
- Rate limited to 5 requests/min per `anonymousId`.
- Store the returned `token` securely (Keychain). Use it for all subsequent API calls.

---

### 2. Verify Apple Subscription

**`POST /api/billing/verify`** -- Protected

Request:
```json
{
  "receiptData": "MIIbngYJKoZIhvc..."
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
    "message": "Receipt is invalid or subscription has expired"
  }
}
```

Notes:
- Rate limited to 10 requests/min per user.
- Server verifies receipt with Apple (production first, sandbox fallback).
- On success, user's plan is updated to `pro` server-side.

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

1. On first launch, generate a UUID and persist it in Keychain as `anonymousId`
2. Call `POST /api/auth/register` with that UUID
3. Store the returned `token` in Keychain
4. Add `Authorization: Bearer <token>` header to **all** API requests
5. Remove all `x-client-id` headers
6. Remove `user_id` from `POST /api/messages` body and `GET /api/interviews` query params
7. Handle `401` responses by re-calling `/api/auth/register` to get a fresh token
8. After a successful in-app purchase, call `POST /api/billing/verify` with the receipt data

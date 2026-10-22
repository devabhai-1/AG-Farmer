# AG Farmer Realtime Database

Root: **`ag_farmer/`** — Admin SDK only. App never talks to Firebase RTDB directly.

All chat + course data is dual-written under **uid** and **email**. Each farmer stays isolated.

## Tree

```
ag_farmer/
  meta/
    schemaVersion
    product

  catalog/
    plans
    crops
    meta

  indexes/
    email/{emailKey}          → { uid, email, updatedAt }

  users/{uid}/
    profile
    state
    subscription
    activities/{YYYY-MM-DD}/{id}
    tracks/
    support/
    ai/
      control
      quota/{YYYY-MM-DD}
      sessions/{sessionId}              ← named normal chats + course index
        id, name, threadId, mode, cropId, updatedAt
      threads/
        main/                           ← default normal chat (legacy)
          meta, messages/{id}, window
        chat_{sessionId}/               ← named normal chat session
          meta, messages/{id}, window
        course_{cropId}/                ← one full season chat per crop
          meta
          days/{YYYY-MM-DD}/messages/{id}
          days/{YYYY-MM-DD}/digest
          months/{YYYY-MM}/summary
          window                        ← very large packed context

  email_users/{emailKey}/
    profile
    state
    activities/…
    ai/                                 ← same shape as users/{uid}/ai
      sessions/…
      threads/…
```

`emailKey` = email lowercased, `@` → `_at_`, `.` → `_dot_`

## Chat model

| Type | Thread | History |
|------|--------|---------|
| Normal chat | `chat_{sessionId}` (or `main`) | Separate named sessions under the same email |
| Course (afim) | `course_afim` | All afim course chat old → new, by day |
| Course (lasun) | `course_lasun` | Separate from afim — own context |

## Context window (course)

- Keep ~200 days of messages
- Pack ~160 recent turns + 120 day digests + 12 month summaries into model context (~120k chars)

## Storage

```
ag_farmer/chat_images/{uid}/…
ag_farmer/crop_logs/{uid}/…
ag_farmer/profiles/{uid}/…
```

## Rules

Everything under `ag_farmer/` is **denied** for clients. Backend Admin SDK writes only.

## Enable

`backend/serviceAccountKey.json` required. See `FIREBASE_SETUP.md`.

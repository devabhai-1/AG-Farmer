# AG Farmer Backend — Single API

## One URL only

```
POST http://localhost:5055/api
```

Body always:

```json
{ "action": "...", "...": "..." }
```

Login wali calls pe header: `Authorization: Bearer <firebaseIdToken>`  
Admin: header `x-admin-key` ya body `adminKey`

Firebase Storage / Database / Phone verify — sab backend manage karta hai.

## Examples

```bash
# Health
curl -X POST http://localhost:5055/api -H "Content-Type: application/json" -d "{\"action\":\"health\"}"

# Config
curl -X POST http://localhost:5055/api -H "Content-Type: application/json" -d "{\"action\":\"config\"}"

# Phone lookup
curl -X POST http://localhost:5055/api -H "Content-Type: application/json" -d "{\"action\":\"auth.phone.lookup\",\"phone\":\"9876543210\"}"

# After OTP — verify
curl -X POST http://localhost:5055/api -H "Content-Type: application/json" -d "{\"action\":\"auth.verify\",\"idToken\":\"...\"}"

# Storage upload URL (needs Bearer token)
curl -X POST http://localhost:5055/api -H "Content-Type: application/json" -H "Authorization: Bearer TOKEN" -d "{\"action\":\"storage.upload\",\"kind\":\"chat\",\"filename\":\"leaf.jpg\"}"

# List all actions
curl -X POST http://localhost:5055/api -H "Content-Type: application/json" -d "{\"action\":\"actions\"}"
```

## Flutter

```dart
await ApiClient.instance.call('health');
await ApiClient.instance.call('auth.phone.lookup', data: {'phone': '9876543210'});
await ApiClient.instance.call('storage.upload', auth: true, data: {'kind': 'chat'});
```

`ApiClient.baseUrl` = `http://localhost:5055/api` (ya `--dart-define=AG_API_URL=https://your.domain/api`)

## Setup

1. `backend/.env` — already has ag-farmer1 + `PUBLIC_API_URL`
2. Add `serviceAccountKey.json` from Firebase Console (ag-farmer1)
3. Enable Phone Auth + RTDB + Storage
4. `npm install && npm run seed && npm run dev`

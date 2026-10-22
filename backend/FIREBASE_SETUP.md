# Firebase Realtime Database setup (AG Farmer)

Backend stores users, chats, courses, catalog under RTDB path: `ag_farmer/…`

## Why `ready: false`?

File missing:

`backend/serviceAccountKey.json`

Without this file Admin SDK cannot write to Realtime Database.

## Download key (one time)

1. Open [Firebase Console](https://console.firebase.google.com/) → project **ag-farmer1**
2. Project settings (gear) → **Service accounts**
3. **Generate new private key** → download JSON
4. Rename / move to:

`e:\Devkishan\flutter\AG Farmer\backend\serviceAccountKey.json`

5. Restart backend:

```bash
cd backend
npm start
```

You should see:

`[firebase] ready → project=ag-farmer1 rtdb=/ag_farmer …`

Health will show `"ready": true`.

## Same Wi‑Fi phone ↔ PC

- PC IP: `192.168.1.36`
- App API: `http://192.168.1.36:5055/api`
- Windows Firewall must allow TCP **5055** (Private network)
- Phone and PC on the **same Wi‑Fi** (not mobile data)

Optional USB fallback:

```bash
adb reverse tcp:5055 tcp:5055
```

## After key is placed

```bash
cd backend
npm run seed
npm start
```

This seeds plans/crops into `ag_farmer/catalog` and keeps login/profile/chat data in Firebase.

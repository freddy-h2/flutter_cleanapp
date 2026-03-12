# Firebase Setup

## Prerequisites
1. Create a Firebase project at https://console.firebase.google.com
2. Add an Android app with package name `com.example.flutter_cleanapp`
3. Download `google-services.json`
4. Place it at `android/app/google-services.json`

## Note
`google-services.json` is gitignored for security. Each developer must obtain it from the Firebase console or team lead.

## Service Account Key and Push Notifications

Push notifications are sent server-side via a Firebase service account key (not `google-services.json`).
The service account key is a separate JSON credential used by the Supabase `send-push` Edge Function
to authenticate with the FCM HTTP v1 API.

### How it relates to push notifications

- `google-services.json` — used by the Flutter app at build time to connect to Firebase (client-side).
- Service account JSON — used by the Supabase Edge Function at runtime to send FCM messages (server-side).

### Obtaining the service account key

1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Store the downloaded JSON securely — **never commit it to the repository**
4. Provide it to Supabase as a secret (see `docs/supabase_secrets_setup.md` for full instructions)

For the complete push notification architecture, see `docs/push_notifications_setup.md`.

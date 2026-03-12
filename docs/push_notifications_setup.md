# Push Notifications Architecture

## Overview

Limpy uses FCM (Firebase Cloud Messaging) for real-time push notifications on Android.
This replaces the previous Workmanager-based polling approach which had a minimum 15-minute
delay and was unreliable when the app was killed.

### Why FCM instead of Workmanager?

- **Workmanager** runs periodic tasks at a minimum of 15 minutes, subject to battery
  optimization, Doze mode, and OEM restrictions. When the app is force-stopped or killed,
  many Android OEMs prevent Workmanager from running at all.
- **FCM** uses a persistent system-level connection via Google Play Services that bypasses
  these restrictions, providing near-instant delivery even when the app process is dead.
- **Note**: Workmanager is kept as a fallback for edge cases where FCM might not deliver
  (e.g., no Google Play Services, force-stopped on some OEMs).

## Architecture

1. **Database triggers** fire when events occur (new announcement, extension request, comment)
2. **pg_net** calls the `send-push` Edge Function via HTTP
3. **Edge Function** queries `device_tokens` and sends FCM data messages
4. **FCM** delivers to device even when app is killed
5. **Flutter** `firebaseMessagingBackgroundHandler` shows notification via `flutter_local_notifications`
6. **Deduplication** prevents triple-firing across FCM, Realtime, and Workmanager channels

## Events That Trigger Push Notifications

| Event | Recipients | Notification |
|-------|-----------|-------------|
| New active announcement | All users (broadcast) | "Limpy - {title}" |
| Extension request (pending) | next_user_id | "Limpy - Solicitud de Prórroga" |
| Extension request (accepted) | requester_id | "Limpy - Prórroga Aceptada" |
| Extension request (rejected) | requester_id | "Limpy - Prórroga Rechazada" |
| New comment on schedule | Schedule owner | "Limpy - Nuevo Comentario" |

## Limitations

- **Force-stopped apps**: On some Android OEMs, if the user force-stops the app from
  Settings > Apps, FCM will not deliver until the user opens the app again. This is an
  Android platform limitation, not a bug.
- **No Google Play Services**: FCM requires Google Play Services. Devices without it
  (e.g., Huawei with HMS) will fall back to Workmanager polling.

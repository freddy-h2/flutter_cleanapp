# Push Notifications Testing Checklist

## Prerequisites
- [ ] Firebase project created and configured
- [ ] google-services.json placed at android/app/google-services.json
- [ ] Supabase secrets configured (see docs/supabase_secrets_setup.md)
- [ ] Edge Function deployed: `supabase functions deploy send-push`
- [ ] Database migrations applied (011-014)
- [ ] App built in release mode: `flutter build apk`
- [ ] App installed on a real Android device (emulator may not support FCM)

## Test Scenarios

### 1. Token Registration
- [ ] Login: verify device_tokens row is created with is_active=true
- [ ] Check Supabase Dashboard > Table Editor > device_tokens
- [ ] Logout: verify device_tokens row has is_active=false
- [ ] Re-login: verify token is reactivated (is_active=true, updated_at changes)

### 2. App Foreground
- [ ] Create a new active announcement via admin panel
- [ ] Verify notification appears immediately (via flutter_local_notifications)
- [ ] Create a new extension request targeting the test user
- [ ] Verify "Solicitud de Prórroga" notification appears
- [ ] Accept/reject the extension request
- [ ] Verify accepted/rejected notification appears to requester

### 3. App Background (minimized, not killed)
- [ ] Minimize the app (press Home button)
- [ ] Create a new active announcement
- [ ] Verify notification appears in system tray within seconds
- [ ] Tap notification — verify app opens

### 4. App Killed (swiped away from recents)
- [ ] Open app, verify login, then swipe away from recents
- [ ] Create a new active announcement
- [ ] Verify notification appears in system tray within seconds
- [ ] Tap notification — verify app opens
- [ ] Repeat with extension request event

### 5. App Force-Stopped
- [ ] Go to Settings > Apps > Limpy > Force Stop
- [ ] Create a new active announcement
- [ ] Document behavior: notification likely will NOT arrive until app is reopened
- [ ] This is expected Android behavior, not a bug

### 6. Deduplication
- [ ] With app in foreground, create an announcement
- [ ] Verify only ONE notification appears (not 2 or 3)
- [ ] Check that Realtime, FCM, and Workmanager don't all fire separate notifications

### 7. Comment Notifications (Optional)
- [ ] As a non-responsible user, post a comment on the responsible user's schedule
- [ ] Verify the responsible user receives a push notification
- [ ] Verify the comment sender does NOT receive a notification for their own comment

### 8. Edge Cases
- [ ] No internet: verify app handles gracefully (no crash on token registration failure)
- [ ] Multiple devices: login on two devices, verify both receive notifications
- [ ] Token rotation: verify new token is registered after FCM rotates it

## Debugging

### Check FCM Token
In the app, add a temporary debug button or check logcat:
```bash
adb logcat | grep "FCM"
```

### Check Edge Function Logs
```bash
supabase functions logs send-push --tail
```

### Check Database
```sql
-- Active tokens
SELECT * FROM device_tokens WHERE is_active = true;

-- Recent notification events
SELECT * FROM notification_events ORDER BY created_at DESC LIMIT 10;
```

## Known Limitations
1. Force-stopped apps do not receive FCM until reopened (Android platform limitation)
2. Devices without Google Play Services fall back to Workmanager polling (15-min delay)
3. Battery optimization on some OEMs (Xiaomi, Huawei, Samsung) may delay notifications
   - Recommend users disable battery optimization for Limpy

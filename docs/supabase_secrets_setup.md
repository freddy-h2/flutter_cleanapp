# Supabase Secrets Setup for Push Notifications

## Required Secrets

### 1. FCM Service Account

1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Save the JSON file (DO NOT commit to repo)
4. Set as Supabase secret:
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)"
   ```

### 2. FCM Project ID

```bash
supabase secrets set FCM_PROJECT_ID="your-firebase-project-id"
```

### 3. Push Webhook Secret (for Edge Function auth)

```bash
supabase secrets set PUSH_WEBHOOK_SECRET="$(openssl rand -hex 32)"
```

### 4. Database Configuration (for pg_net triggers)

Set these in the Supabase SQL editor:

```sql
ALTER DATABASE postgres SET app.settings.supabase_url = https://your-project.supabase.co;
ALTER DATABASE postgres SET app.settings.service_role_key = your-service-role-key;
```

## Deploy Edge Function

```bash
supabase functions deploy send-push
```

## Verify Setup

1. Insert a test announcement via Supabase Dashboard
2. Check Edge Function logs: `supabase functions logs send-push`
3. Verify notification arrives on test device

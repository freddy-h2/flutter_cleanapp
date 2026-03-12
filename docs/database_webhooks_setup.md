# Database Webhooks Setup for Push Notifications

This document describes how to configure Supabase to call the `send-push` Edge Function
when database events occur. Two approaches are covered:

- **Option A (preferred)**: `pg_net` HTTP triggers via migration `013_create_push_webhook_triggers.sql`
- **Option B (fallback)**: Manual webhook configuration via the Supabase Dashboard

---

## Option A: pg_net HTTP Triggers (Preferred)

Migration `013_create_push_webhook_triggers.sql` installs the `invoke_send_push` helper
function and updates the three trigger functions to call the Edge Function directly from
the database using the `pg_net` extension.

### Prerequisites

1. The `pg_net` extension must be available in your Supabase project (enabled by default
   on Supabase-hosted projects).
2. Two database-level settings must be configured so the trigger functions can build the
   correct HTTP request without hardcoding secrets.

### Step 1 — Apply the migration

```bash
supabase db push
# or run the SQL file directly in the Supabase SQL editor
```

### Step 2 — Configure database settings

Run the following in the **Supabase SQL Editor** (replace the placeholder values):

```sql
ALTER DATABASE postgres
  SET app.settings.supabase_url = 'https://<your-project-ref>.supabase.co';

ALTER DATABASE postgres
  SET app.settings.service_role_key = '<your-service-role-key>';
```

> **Security note**: The service role key is stored as a database-level setting, not in
> application code or committed files. It is accessible only to `SECURITY DEFINER`
> functions running inside the database. Never commit these values to version control.

### Step 3 — Verify

1. Insert a test announcement with `is_active = true` via the Supabase Dashboard.
2. Check Edge Function logs:
   ```bash
   supabase functions logs send-push
   ```
3. Confirm a push notification arrives on a test device that has a registered token.

### How it works

```
Database event (INSERT/UPDATE)
  └─► Trigger function (trigger_announcement_push / trigger_extension_request_push / trigger_comment_push)
        └─► notify_push_event()   ← dedup check (notification_events table)
              └─► IF FOUND → invoke_send_push()
                    └─► extensions.http_post() via pg_net
                          └─► send-push Edge Function
                                └─► FCM → device
```

The `notify_push_event` helper inserts a row into `notification_events` with a unique
`event_key`. If the key already exists the insert is silently skipped and the Edge
Function is **not** called, preventing duplicate notifications across FCM, Realtime, and
Workmanager channels.

---

## Option B: Manual Webhook via Supabase Dashboard (Fallback)

Use this approach if `pg_net` is unavailable or if you prefer a no-SQL configuration.

### Step 1 — Open Database Webhooks

1. Go to the [Supabase Dashboard](https://app.supabase.com).
2. Select your project.
3. Navigate to **Database → Webhooks**.
4. Click **Create a new hook**.

### Step 2 — Configure the webhook for `notification_events`

| Field | Value |
|-------|-------|
| **Name** | `send_push_on_notification_event` |
| **Table** | `public.notification_events` |
| **Events** | `INSERT` |
| **Type** | Supabase Edge Functions |
| **Edge Function** | `send-push` |
| **HTTP Method** | `POST` |
| **HTTP Headers** | `Content-Type: application/json` |

The webhook will POST the full row payload (including the `payload` JSONB column) to the
`send-push` Edge Function every time a new `notification_events` row is inserted.

> **Note**: Because `notify_push_event` only inserts when the `event_key` is new, the
> deduplication guarantee is preserved even with this approach.

### Step 3 — Secure the webhook (optional but recommended)

1. Generate a random secret:
   ```bash
   openssl rand -hex 32
   ```
2. Add it as a Supabase secret:
   ```bash
   supabase secrets set PUSH_WEBHOOK_SECRET="<generated-secret>"
   ```
3. In the Dashboard webhook configuration, add the header:
   ```
   x-webhook-secret: <generated-secret>
   ```
4. Verify the header in the `send-push` Edge Function before processing the request.

### Step 4 — Verify

1. Insert a test row directly into `notification_events`:
   ```sql
   INSERT INTO public.notification_events (event_key, event_type, payload)
   VALUES (
     'test:manual:' || gen_random_uuid()::text,
     'test',
     '{"type": "test", "broadcast": false}'::jsonb
   );
   ```
2. Check Edge Function logs:
   ```bash
   supabase functions logs send-push
   ```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `invoke_send_push: skipped` warning in Postgres logs | `app.settings.supabase_url` or `app.settings.service_role_key` not set | Run the `ALTER DATABASE` commands in Step 2 |
| Edge Function not called at all | `pg_net` extension not enabled | Enable it in Dashboard → Database → Extensions, or use Option B |
| Duplicate notifications | Dedup table not being consulted | Ensure triggers call `notify_push_event` before `invoke_send_push` |
| Webhook fires but FCM not delivered | FCM service account not configured | See `docs/supabase_secrets_setup.md` |

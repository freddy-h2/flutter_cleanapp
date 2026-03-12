/**
 * Supabase Edge Function: send-push
 *
 * Sends FCM push notifications via the HTTP v1 API using a service account
 * for OAuth2 authentication. Uses data-only messages so the Flutter background
 * handler always fires and has full control over notification display.
 *
 * Environment variables required:
 *   FCM_SERVICE_ACCOUNT_JSON  — full JSON service account key (Supabase secret)
 *   FCM_PROJECT_ID            — Firebase project ID (Supabase secret)
 *   PUSH_WEBHOOK_SECRET       — shared secret for x-push-secret header auth
 *   SUPABASE_URL              — auto-provided by Supabase Edge Functions runtime
 *   SUPABASE_SERVICE_ROLE_KEY — auto-provided by Supabase Edge Functions runtime
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PushRequest {
  type: "announcement" | "extension_request" | "comment";
  /** If true, send to ALL active device tokens (broadcast). */
  broadcast?: boolean;
  /** Specific user IDs to notify (targeted). */
  user_ids?: string[];
  /** Notification title. */
  title: string;
  /** Notification body. */
  body: string;
  /** Additional string key/value data payload. */
  data?: Record<string, string>;
}

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
}

interface TokenRow {
  token: string;
}

interface FcmErrorDetail {
  errorCode?: string;
}

interface FcmErrorResponse {
  error?: {
    status?: string;
    details?: FcmErrorDetail[];
  };
}

// ---------------------------------------------------------------------------
// Helpers: Base64url encoding (Web Crypto / Deno-native)
// ---------------------------------------------------------------------------

function base64urlEncode(data: Uint8Array): string {
  const base64 = btoa(String.fromCharCode(...data));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function encodeUtf8(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

// ---------------------------------------------------------------------------
// OAuth2: Generate access token from service account using Web Crypto RS256
// ---------------------------------------------------------------------------

async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600;

  // Build JWT header and claims
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: expiry,
  };

  const headerB64 = base64urlEncode(encodeUtf8(JSON.stringify(header)));
  const claimsB64 = base64urlEncode(encodeUtf8(JSON.stringify(claims)));
  const signingInput = `${headerB64}.${claimsB64}`;

  // Import the private key (PEM → CryptoKey)
  const pemContents = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\n/g, "")
    .trim();

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  // Sign
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encodeUtf8(signingInput),
  );

  const jwt = `${signingInput}.${base64urlEncode(new Uint8Array(signature))}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const errText = await tokenResponse.text();
    throw new Error(`Failed to get OAuth2 token: ${errText}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token as string;
}

// ---------------------------------------------------------------------------
// Supabase: Query device tokens
// ---------------------------------------------------------------------------

async function getDeviceTokens(
  supabaseUrl: string,
  serviceRoleKey: string,
  broadcast: boolean,
  userIds?: string[],
): Promise<string[]> {
  let url = `${supabaseUrl}/rest/v1/device_tokens?select=token&is_active=eq.true`;

  if (!broadcast && userIds && userIds.length > 0) {
    // Filter by user_ids using PostgREST "in" operator
    const ids = userIds.map((id) => `"${id}"`).join(",");
    url += `&user_id=in.(${ids})`;
  }

  const response = await fetch(url, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Failed to query device_tokens: ${errText}`);
  }

  const rows: TokenRow[] = await response.json();
  return rows.map((r) => r.token);
}

// ---------------------------------------------------------------------------
// Supabase: Mark a token as inactive
// ---------------------------------------------------------------------------

async function markTokenInactive(
  supabaseUrl: string,
  serviceRoleKey: string,
  token: string,
): Promise<void> {
  const encodedToken = encodeURIComponent(token);
  const url =
    `${supabaseUrl}/rest/v1/device_tokens?token=eq.${encodedToken}`;

  await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify({ is_active: false }),
  });
}

// ---------------------------------------------------------------------------
// FCM: Send a single data-only message via HTTP v1 API
// ---------------------------------------------------------------------------

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  deviceToken: string,
  data: Record<string, string>,
): Promise<{ ok: boolean; errorCode?: string }> {
  const url =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const body = {
    message: {
      token: deviceToken,
      // Data-only message — no "notification" key so Flutter background handler
      // always fires and controls notification display.
      data,
      android: {
        priority: "high",
      },
    },
  };

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (response.ok) {
    return { ok: true };
  }

  const errBody: FcmErrorResponse = await response.json().catch(() => ({}));
  const status = errBody?.error?.status ?? "";
  const details = errBody?.error?.details ?? [];
  const errorCode =
    details.find((d) => d.errorCode)?.errorCode ?? status ?? "UNKNOWN";

  return { ok: false, errorCode };
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ---------------------------------------------------------------------------
  // Authentication: verify x-push-secret header OR Authorization Bearer with
  // the service role key (for Database Webhook calls).
  // ---------------------------------------------------------------------------
  const pushSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  const xPushSecret = req.headers.get("x-push-secret");
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearerToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;

  const validPushSecret = pushSecret && xPushSecret === pushSecret;
  const validServiceRole = bearerToken === serviceRoleKey;

  if (!validPushSecret && !validServiceRole) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ---------------------------------------------------------------------------
  // Parse request body
  // ---------------------------------------------------------------------------
  let pushReq: PushRequest;
  try {
    pushReq = await req.json() as PushRequest;
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { type, broadcast, user_ids, title, body, data: extraData } = pushReq;

  if (!type || !title || !body) {
    return new Response(
      JSON.stringify({ error: "Missing required fields: type, title, body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!broadcast && (!user_ids || user_ids.length === 0)) {
    return new Response(
      JSON.stringify({
        error: "Either broadcast:true or user_ids must be provided",
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  // ---------------------------------------------------------------------------
  // Load environment variables
  // ---------------------------------------------------------------------------
  const fcmServiceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  const fcmProjectId = Deno.env.get("FCM_PROJECT_ID");
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";

  if (!fcmServiceAccountJson || !fcmProjectId) {
    return new Response(
      JSON.stringify({
        error: "Missing FCM_SERVICE_ACCOUNT_JSON or FCM_PROJECT_ID secrets",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // ---------------------------------------------------------------------------
  // Parse service account and get OAuth2 access token
  // ---------------------------------------------------------------------------
  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(fcmServiceAccountJson) as ServiceAccount;
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid FCM_SERVICE_ACCOUNT_JSON" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: `Failed to get FCM access token: ${message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // ---------------------------------------------------------------------------
  // Query device tokens
  // ---------------------------------------------------------------------------
  let tokens: string[];
  try {
    tokens = await getDeviceTokens(
      supabaseUrl,
      serviceRoleKey,
      broadcast === true,
      user_ids,
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: `Failed to query device tokens: ${message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  if (tokens.length === 0) {
    return new Response(
      JSON.stringify({ success: true, sent: 0, failed: 0, errors: [] }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }

  // ---------------------------------------------------------------------------
  // Build FCM data payload (data-only, no notification key)
  // ---------------------------------------------------------------------------
  const fcmData: Record<string, string> = {
    type,
    title,
    message: body,
    ...extraData,
  };

  // ---------------------------------------------------------------------------
  // Send FCM messages and collect results
  // ---------------------------------------------------------------------------
  let sent = 0;
  let failed = 0;
  const errors: string[] = [];

  for (const token of tokens) {
    const result = await sendFcmMessage(
      fcmProjectId,
      accessToken,
      token,
      fcmData,
    );

    if (result.ok) {
      sent++;
    } else {
      failed++;
      errors.push(`${token.slice(0, 20)}...: ${result.errorCode}`);

      // Mark token inactive if it is no longer registered or invalid
      if (
        result.errorCode === "UNREGISTERED" ||
        result.errorCode === "INVALID_ARGUMENT"
      ) {
        await markTokenInactive(supabaseUrl, serviceRoleKey, token);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Return summary
  // ---------------------------------------------------------------------------
  return new Response(
    JSON.stringify({ success: true, sent, failed, errors }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});

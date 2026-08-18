// Supabase Edge Function: send_push (version sécurisée)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*", // Tu pourras restreindre plus tard
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type SendPushBody = {
  userId?: string;
  broadcast?: boolean;
  title: string;
  body: string;
  data?: Record<string, string>;
  platform?: "android" | "ios" | "web";
};

function json(data: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(data), {
    headers: { "content-type": "application/json; charset=utf-8", ...CORS_HEADERS, ...(init.headers ?? {}) },
    status: init.status ?? 200,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, { status: 405 });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return json({ error: "Missing Supabase env" }, { status: 500 });
  }
  if (!fcmServerKey) return json({ error: "Missing secret FCM_SERVER_KEY" }, { status: 500 });

  // ========== SÉCURITÉ : Vérifier l'utilisateur qui appelle ==========
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Missing or invalid Authorization header" }, { status: 401 });
  }

  const jwt = authHeader.replace("Bearer ", "");

  // Client avec la clé anon pour vérifier le JWT de l'appelant
  const supabaseUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });

  const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
  if (authError || !user) {
    return json({ error: "Invalid or expired token" }, { status: 401 });
  }

  const callerId = user.id;

  // ========== Lecture du body ==========
  let body: SendPushBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, { status: 400 });
  }

  if (!body?.title || !body?.body) {
    return json({ error: "title and body are required" }, { status: 400 });
  }
  if (!body.userId && !body.broadcast) {
    return json({ error: "Provide userId or broadcast=true" }, { status: 400 });
  }

  // ========== Autorisation ==========
  // - Un utilisateur normal ne peut envoyer qu'à lui-même
  // - Le broadcast est réservé aux admins (à activer plus tard)
  if (body.broadcast) {
    // Pour l'instant on bloque le broadcast (sécurité)
    return json({ error: "Broadcast not allowed" }, { status: 403 });
  }

  if (body.userId && body.userId !== callerId) {
    return json({ error: "You can only send push notifications to yourself" }, { status: 403 });
  }

  // ========== Envoi (avec service_role) ==========
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  let q = supabase.from("thix_push_tokens").select("token, platform").eq("active", true);
  if (body.platform) q = q.eq("platform", body.platform);
  if (body.userId) q = q.eq("user_id", body.userId);

  const { data: rows, error } = await q;
  if (error) return json({ error: `Token query failed: ${error.message}` }, { status: 500 });

  const tokens = (rows ?? []).map((r) => r.token).filter(Boolean);
  if (tokens.length === 0) return json({ ok: true, sent: 0, reason: "No tokens" });

  const batchSize = 900;
  let sent = 0;
  const failures: Array<{ token?: string; error: string }> = [];

  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);

    const payload = {
      registration_ids: batch,
      notification: { title: body.title, body: body.body },
      data: body.data ?? {},
    };

    const res = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `key=${fcmServerKey}`,
      },
      body: JSON.stringify(payload),
    });

    const txt = await res.text();
    if (!res.ok) return json({ error: `FCM error ${res.status}: ${txt}` }, { status: 502 });

    try {
      const parsed = JSON.parse(txt);
      sent += parsed?.success ?? batch.length;
      const results = parsed?.results ?? [];
      for (let j = 0; j < results.length; j++) {
        if (results[j]?.error) {
          failures.push({ token: batch[j], error: results[j].error });
        }
      }
    } catch {
      sent += batch.length;
    }
  }

  // Désactiver les tokens invalides
  const invalid = failures
    .filter((f) => (f.error ?? "").includes("NotRegistered") || (f.error ?? "").includes("InvalidRegistration"))
    .map((f) => f.token)
    .filter(Boolean) as string[];

  if (invalid.length > 0) {
    await supabase
      .from("thix_push_tokens")
      .update({ active: false, updated_at: new Date().toISOString() })
      .in("token", invalid);
  }

  return json({
    ok: true,
    sent,
    tokens: tokens.length,
    failuresCount: failures.length,
    invalidTokensDisabled: invalid.length,
  });
});

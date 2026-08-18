// supabase/functions/sos_alert/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type SosAlertBody = {
  alertId: string;
  userId: string;
  type?: string;
  severity?: string;
  silentMode?: boolean;
  title?: string;
  lat?: number | null;
  lng?: number | null;
  accuracyM?: number | null;
  mapsUrl?: string | null;
  createdAt?: string;
};

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "content-type": "application/json; charset=utf-8",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse(405, { error: "Method not allowed" });

  try {
    const body = (await req.json()) as Partial<SosAlertBody>;
    const alertId = (body.alertId ?? "").toString().trim();
    const userId = (body.userId ?? "").toString().trim();
    if (!alertId || !userId) return jsonResponse(400, { error: "alertId and userId are required" });

    // Service-role is available by default in Edge Functions.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } },
    );

    const createdAt = body.createdAt ?? new Date().toISOString();
    const payload = {
      alert_id: alertId,
      user_id: userId,
      type: body.type ?? null,
      severity: body.severity ?? null,
      silent_mode: body.silentMode ?? null,
      title: body.title ?? null,
      lat: body.lat ?? null,
      lng: body.lng ?? null,
      accuracy_m: body.accuracyM ?? null,
      maps_url: body.mapsUrl ?? null,
      created_at: createdAt,
    };

    // 1) Best-effort persist a notification row for admin dashboards.
    // If table doesn't exist, we just skip.
    try {
      await supabase.from("thix_admin_notifications").insert({
        kind: "sos",
        title: body.title ?? "SOS",
        body: body.mapsUrl ? `Position: ${body.mapsUrl}` : "",
        payload,
        created_at: createdAt,
        updated_at: createdAt,
      });
    } catch (_e) {
      // Ignore missing schema/RLS for now; realtime broadcast still works.
    }

    // 2) Realtime broadcast (admins can subscribe in the app/dashboard).
    try {
      const channel = supabase.channel("admins:sos");
      await channel.subscribe();
      await channel.send({ type: "broadcast", event: "sos_alert", payload });
      await supabase.removeChannel(channel);
    } catch (_e) {
      // Ignore if realtime is not enabled.
    }

    return jsonResponse(200, { ok: true });
  } catch (e) {
    return jsonResponse(500, { error: (e as Error).message ?? "Unknown error" });
  }
});

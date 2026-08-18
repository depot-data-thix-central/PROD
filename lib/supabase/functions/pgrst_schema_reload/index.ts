// Supabase Edge Function: pgrst_schema_reload
// Triggers PostgREST to reload its schema cache.
// Useful when columns were added manually via SQL and the API still returns PGRST204.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import postgres from "https://deno.land/x/postgresjs@v3.4.4/mod.js";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json; charset=utf-8" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  const auth = req.headers.get("authorization") ?? "";
  // Basic guard: require a bearer token so random clients can't spam reload.
  if (!auth.toLowerCase().startsWith("bearer ")) {
    return json({ ok: false, error: "Missing Authorization bearer token" }, 401);
  }

  try {
    // SUPABASE_DB_URL is provided by Supabase for edge functions.
    const dbUrl = Deno.env.get("SUPABASE_DB_URL");
    if (!dbUrl) return json({ ok: false, error: "SUPABASE_DB_URL missing" }, 500);

    const sql = postgres(dbUrl, { max: 1, idle_timeout: 5, connect_timeout: 10 });
    try {
      // PostgREST listens on channel 'pgrst' for: 'reload schema'
      await sql`select pg_notify('pgrst', 'reload schema')`;
      return json({ ok: true });
    } finally {
      await sql.end({ timeout: 2 });
    }
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});

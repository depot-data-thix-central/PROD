import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

type Body = {
  company_slug?: string;
  device_fingerprint?: string;
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(JSON.stringify({ error: "missing_bearer_token" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const body = (await req.json()) as Body;
    const companySlug = (body.company_slug ?? "").trim().toLowerCase();
    const deviceFingerprint = (body.device_fingerprint ?? "").trim();

    if (!companySlug || !deviceFingerprint) {
      return new Response(JSON.stringify({ error: "missing_company_or_device" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Client with service role for DB writes.
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    const { data: userRes, error: userErr } = await admin.auth.getUser();
    if (userErr || !userRes?.user) {
      return new Response(JSON.stringify({ error: "invalid_token" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const userId = userRes.user.id;

    // Resolve company.
    const { data: company, error: cErr } = await admin
      .from("thix_enterprise_companies")
      .select("id, slug")
      .eq("slug", companySlug)
      .maybeSingle();

    if (cErr || !company?.id) {
      return new Response(JSON.stringify({ error: "company_not_found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Verify membership.
    const { data: member, error: mErr } = await admin
      .from("thix_enterprise_memberships")
      .select("id, role")
      .eq("company_id", company.id)
      .eq("user_id", userId)
      .maybeSingle();

    if (mErr || !member?.id) {
      return new Response(JSON.stringify({ error: "not_a_member" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Capture IP & UA.
    const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || req.headers.get("cf-connecting-ip") || null;
    const userAgent = req.headers.get("user-agent") || null;

    // Basic risk heuristics placeholder.
    let riskScore = 0;
    if (!ip) riskScore += 10;
    if (!userAgent) riskScore += 5;

    const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString();

    const { data: inserted, error: iErr } = await admin
      .from("thix_enterprise_sessions")
      .insert({
        company_id: company.id,
        user_id: userId,
        device_fingerprint: deviceFingerprint,
        ip,
        user_agent: userAgent,
        risk_score: riskScore,
        expires_at: expiresAt,
        last_seen_at: new Date().toISOString(),
      })
      .select("id, risk_score")
      .single();

    if (iErr) {
      return new Response(JSON.stringify({ error: "insert_failed", details: iErr.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Emit activity.
    await admin.from("thix_enterprise_activity").insert({
      company_id: company.id,
      type: "session",
      title: "Secure session created",
      subtitle: `Role ${member.role} • Risk ${inserted.risk_score}`,
      severity: inserted.risk_score >= 20 ? "warn" : "info",
      actor_user_id: userId,
    });

    return new Response(JSON.stringify({ session_id: inserted.id, risk_score: inserted.risk_score, ip }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: "unexpected_error", details: String(e) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});

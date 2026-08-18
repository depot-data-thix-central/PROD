import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type ChatAiBody = {
  action: "translateMessage" | "summarizeConversation" | "generateSmartReplies" | "analyzeConversation";
  conversationId?: string;
  message?: string;
  messages?: string[];
  targetLanguage?: string;
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "content-type": "application/json; charset=utf-8",
    },
  });
}

function pickJsonBlock(text: string): any {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```json\s*([\s\S]*?)```/i);
  const candidate = fenced?.[1]?.trim() ?? trimmed;
  try {
    return JSON.parse(candidate);
  } catch {
    return { rawText: text };
  }
}

async function callOpenAI(prompt: string) {
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) throw new Error("OPENAI_API_KEY missing");

  const resp = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${openaiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0.3,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            "You are a chat assistant. Return ONLY valid JSON. Supported keys: translation, summary, smartReplies, sentiment, confidence.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`OpenAI error: ${resp.status} ${errText}`);
  }

  const data = await resp.json();
  const content = data?.choices?.[0]?.message?.content ?? "{}";
  return pickJsonBlock(content);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  try {
    const body = (await req.json()) as ChatAiBody;
    if (!body?.action) return json(400, { error: "action is required" });

    const messages = Array.isArray(body.messages) ? body.messages : [];
    const lastMessage = body.message ?? messages[messages.length - 1] ?? "";
    const targetLanguage = body.targetLanguage ?? "fr";

    let prompt = "";

    switch (body.action) {
      case "translateMessage":
        prompt = `Translate the following message to ${targetLanguage}. Return JSON with key "translation". Message: ${lastMessage}`;
        break;

      case "summarizeConversation":
        prompt = `Summarize this conversation briefly. Return JSON with key "summary". Messages: ${JSON.stringify(messages)}`;
        break;

      case "generateSmartReplies":
        prompt = `Generate 3 concise smart reply suggestions for the last message. Return JSON with key "smartReplies" as an array of strings. Messages: ${JSON.stringify(messages)}`;
        break;

      case "analyzeConversation":
        prompt = `Analyze the sentiment of this conversation. Return JSON with keys "sentiment" (positive, neutral, negative) and "confidence" (0 to 1). Messages: ${JSON.stringify(messages)}`;
        break;

      default:
        return json(400, { error: `Unsupported action: ${body.action}` });
    }

    const ai = await callOpenAI(prompt);

    return json(200, {
      action: body.action,
      conversationId: body.conversationId ?? null,
      translation: ai.translation ?? null,
      summary: ai.summary ?? null,
      smartReplies: Array.isArray(ai.smartReplies) ? ai.smartReplies : [],
      sentiment: ai.sentiment ?? null,
      confidence: typeof ai.confidence === "number" ? ai.confidence : null,
      raw: ai,
    });
  } catch (error) {
    return json(500, {
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
});

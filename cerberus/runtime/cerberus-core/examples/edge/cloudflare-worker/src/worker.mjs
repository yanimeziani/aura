let wasm_instance_promise;

const POLICY_CONCISE = 0;
const POLICY_DETAILED = 1;
const POLICY_URGENT = 2;
const DEFAULT_DEDUP_TTL_SECONDS = 86400;

function ensure_method(req, method) {
  if (req.method !== method) {
    return new Response("method not allowed", { status: 405 });
  }
  return null;
}

function extract_text_features(text) {
  const lower = text.toLowerCase();
  return {
    text_len: text.length,
    has_question: text.includes("?") ? 1 : 0,
    has_urgent_keyword: /\b(urgent|asap|immediately|critical|срочно|немедленно|критично)\b/.test(lower) ? 1 : 0,
    has_code_hint: /```|\b(code|bug|error|stack|trace|zig|compile|build)\b/.test(lower) ? 1 : 0,
  };
}

function policy_system_prompt(policy) {
  if (policy === POLICY_URGENT) {
    return "You are an incident-response assistant. Be concise, prioritize safety and immediate next steps.";
  }
  if (policy === POLICY_DETAILED) {
    return "You are a technical assistant. Give concrete, step-by-step guidance with explicit commands when useful.";
  }
  return "You are a concise assistant. Answer directly and avoid unnecessary detail.";
}

function parse_dedup_ttl_seconds(env) {
  const raw = env.DEDUP_TTL_SECONDS;
  if (typeof raw !== "string" || raw.length === 0) {
    return DEFAULT_DEDUP_TTL_SECONDS;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < 60 || parsed > 7 * 24 * 3600) {
    return DEFAULT_DEDUP_TTL_SECONDS;
  }
  return parsed;
}

function get_dedup_kv(env) {
  const kv = env.TELEGRAM_DEDUP;
  if (!kv || typeof kv.get !== "function" || typeof kv.put !== "function") {
    return null;
  }
  return kv;
}

async function is_duplicate_update(env, update_id) {
  if (!Number.isInteger(update_id)) {
    return false;
  }

  const kv = get_dedup_kv(env);
  if (!kv) {
    return false;
  }

  const dedup_key = `tg:update:${update_id}`;
  try {
    const existing = await kv.get(dedup_key);
    if (existing !== null) {
      return true;
    }

    await kv.put(dedup_key, "1", {
      expirationTtl: parse_dedup_ttl_seconds(env),
    });
    return false;
  } catch {
    // Fail open on KV issues to avoid dropping valid messages.
    return false;
  }
}

async function get_wasm_instance(env) {
  if (!wasm_instance_promise) {
    wasm_instance_promise = WebAssembly.instantiate(env.AGENT_CORE, {});
  }
  return wasm_instance_promise;
}

async function choose_policy_from_wasm(env, text) {
  const inst = await get_wasm_instance(env);
  const features = extract_text_features(text);
  const choose_policy = inst.instance.exports.choose_policy;
  if (typeof choose_policy !== "function") {
    return POLICY_CONCISE;
  }
  return choose_policy(
    features.text_len,
    features.has_question,
    features.has_urgent_keyword,
    features.has_code_hint,
  ) >>> 0;
}

async function call_openai(env, system_prompt, user_text) {
  const model = env.OPENAI_MODEL || "gpt-4o-mini";
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_text },
      ],
    }),
  });

  const payload = await response.json();
  if (!response.ok) {
    const msg = payload?.error?.message || "openai request failed";
    throw new Error(`openai error: ${msg}`);
  }

  const text = payload?.choices?.[0]?.message?.content;
  if (typeof text !== "string" || text.length === 0) {
    throw new Error("openai returned empty content");
  }
  return text;
}

async function send_telegram(env, chat_id, text, reply_to_message_id) {
  const response = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      chat_id,
      text,
      reply_to_message_id,
      allow_sending_without_reply: true,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`telegram sendMessage failed: ${body}`);
  }
}

function verify_telegram_secret(req, env) {
  if (!env.TELEGRAM_WEBHOOK_SECRET) return true;
  const got = req.headers.get("x-telegram-bot-api-secret-token");
  return got === env.TELEGRAM_WEBHOOK_SECRET;
}

async function handle_telegram_webhook(req, env) {
  const invalid_method = ensure_method(req, "POST");
  if (invalid_method) return invalid_method;

  if (!verify_telegram_secret(req, env)) {
    return new Response("forbidden", { status: 403 });
  }

  const update = await req.json();
  const update_id = update?.update_id;

  if (await is_duplicate_update(env, update_id)) {
    return Response.json({ ok: true, dedup: true, update_id });
  }

  const msg = update?.message || update?.edited_message;
  const text = msg?.text;
  const chat_id = msg?.chat?.id;
  const message_id = msg?.message_id;

  if (!chat_id || typeof text !== "string" || text.length === 0) {
    return Response.json({ ok: true, skipped: true });
  }

  const policy = await choose_policy_from_wasm(env, text);
  const system_prompt = policy_system_prompt(policy);
  const llm_reply = await call_openai(env, system_prompt, text);

  await send_telegram(env, chat_id, llm_reply, message_id);
  return Response.json({ ok: true, policy });
}

async function handle_set_webhook(req, env) {
  const invalid_method = ensure_method(req, "POST");
  if (invalid_method) return invalid_method;

  if (!env.PUBLIC_BASE_URL) {
    return new Response("PUBLIC_BASE_URL is required", { status: 400 });
  }

  const url = `${env.PUBLIC_BASE_URL.replace(/\/$/, "")}/telegram/webhook`;
  const response = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/setWebhook`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      url,
      secret_token: env.TELEGRAM_WEBHOOK_SECRET || undefined,
      allowed_updates: ["message", "edited_message"],
    }),
  });
  const payload = await response.text();
  return new Response(payload, {
    status: response.status,
    headers: { "content-type": "application/json" },
  });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);

    if (!env.TELEGRAM_BOT_TOKEN || !env.OPENAI_API_KEY) {
      return new Response("Missing TELEGRAM_BOT_TOKEN or OPENAI_API_KEY", { status: 500 });
    }

    if (url.pathname === "/health") {
      return Response.json({ ok: true });
    }
    if (url.pathname === "/telegram/webhook") {
      try {
        return await handle_telegram_webhook(req, env);
      } catch (err) {
        return new Response(`webhook error: ${err.message}`, { status: 500 });
      }
    }
    if (url.pathname === "/telegram/set-webhook") {
      try {
        return await handle_set_webhook(req, env);
      } catch (err) {
        return new Response(`setWebhook error: ${err.message}`, { status: 500 });
      }
    }

    return new Response("Not found", { status: 404 });
  },
};

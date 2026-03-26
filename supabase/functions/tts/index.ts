import { corsHeaders, errorResponse, handleCors } from "../_shared/cors.ts";

const DEFAULT_VOICE_ID = "pNInz6obpgDQGcFmaJgB";
const DEFAULT_MODEL_ID = "eleven_multilingual_v2";
const MAX_TEXT_LENGTH = 5000;
const UPSTREAM_TIMEOUT_MS = 180_000;

type TtsBody = {
  text: string;
  voice_id?: string;
  model_id?: string;
};

Deno.serve(async (req: Request) => {
  const preflight = handleCors(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse("Метод не поддерживается", 405);
  }

  const apiKey = Deno.env.get("ELEVENLABS_API_KEY");
  if (!apiKey?.trim()) {
    return errorResponse("Сервер не настроен: отсутствует ELEVENLABS_API_KEY", 500);
  }

  let body: TtsBody;
  try {
    const raw = await req.text();
    if (!raw) throw new Error("Пустое тело запроса.");
    const data = JSON.parse(raw) as Partial<TtsBody>;
    if (typeof data.text !== "string" || !data.text.trim()) {
      throw new Error("Поле text обязательно.");
    }
    if (data.voice_id !== undefined && typeof data.voice_id !== "string") {
      throw new Error("voice_id должно быть строкой.");
    }
    if (data.model_id !== undefined && typeof data.model_id !== "string") {
      throw new Error("model_id должно быть строкой.");
    }
    body = {
      text: data.text.trim(),
      voice_id: data.voice_id?.trim(),
      model_id: data.model_id?.trim(),
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Некорректный JSON.";
    return errorResponse(msg, 400);
  }

  if (body.text.length > MAX_TEXT_LENGTH) {
    return errorResponse(`text не длиннее ${MAX_TEXT_LENGTH} символов`, 400);
  }

  const voiceId = body.voice_id || DEFAULT_VOICE_ID;
  const modelId = body.model_id || DEFAULT_MODEL_ID;

  const url = `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}`;

  const ac = new AbortController();
  const timeoutId = setTimeout(() => ac.abort(), UPSTREAM_TIMEOUT_MS);

  let elevenRes: Response;
  try {
    elevenRes = await fetch(url, {
      method: "POST",
      signal: ac.signal,
      headers: {
        "xi-api-key": apiKey.trim(),
        Accept: "audio/mpeg",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        text: body.text,
        model_id: modelId,
      }),
    });
  } catch (e) {
    console.error("ElevenLabs fetch error:", e);
    const aborted = e instanceof Error && e.name === "AbortError";
    return errorResponse(
      aborted ? "Превышено время ожидания ответа ElevenLabs" : "Не удалось связаться с ElevenLabs",
      502,
    );
  } finally {
    clearTimeout(timeoutId);
  }

  if (!elevenRes.ok) {
    let detail: string | undefined;
    try {
      const errJson = await elevenRes.json() as { detail?: { message?: string } | string };
      detail = typeof errJson.detail === "object" && errJson.detail?.message
        ? errJson.detail.message
        : typeof errJson.detail === "string"
        ? errJson.detail
        : JSON.stringify(errJson);
    } catch {
      detail = await elevenRes.text().catch(() => elevenRes.statusText);
    }
    console.error("ElevenLabs API error:", elevenRes.status, detail);
    const headers = new Headers(corsHeaders);
    headers.set("Content-Type", "application/json; charset=utf-8");
    return new Response(
      JSON.stringify({ error: "Ошибка ElevenLabs API", details: detail }),
      {
        status: elevenRes.status >= 500 ? 502 : 400,
        headers,
      },
    );
  }

  const audioBuffer = await elevenRes.arrayBuffer();
  const headers = new Headers(corsHeaders);
  const contentType = elevenRes.headers.get("Content-Type") || "audio/mpeg";
  headers.set("Content-Type", contentType);
  const contentLength = elevenRes.headers.get("Content-Length");
  if (contentLength) headers.set("Content-Length", contentLength);

  return new Response(audioBuffer, { status: 200, headers });
});

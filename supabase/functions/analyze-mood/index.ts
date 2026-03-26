import {
  errorResponse,
  handleCors,
  jsonResponse,
} from "../_shared/cors.ts";

type MoodEntryInput = {
  emotion: string;
  intensity: number;
  note?: string;
  created_at: string;
};

type AnalyzeBody = {
  entries: MoodEntryInput[];
  user_goals: string[];
};

type OpenAIChatResponse = {
  choices?: Array<{
    message?: { content?: string };
  }>;
  error?: { message?: string };
};

const MAX_ENTRIES = 200;
const MAX_NOTE_PER_ENTRY = 2000;
const MAX_GOALS = 20;
const MAX_GOAL_LEN = 200;
const UPSTREAM_TIMEOUT_MS = 120_000;

function parseBody(raw: string): AnalyzeBody {
  const data = JSON.parse(raw) as Partial<AnalyzeBody>;
  if (!Array.isArray(data.entries)) {
    throw new Error("Поле entries должно быть массивом.");
  }
  if (data.entries.length === 0) {
    throw new Error("Нужна хотя бы одна запись в entries.");
  }
  if (data.entries.length > MAX_ENTRIES) {
    throw new Error(`Не более ${MAX_ENTRIES} записей за запрос.`);
  }
  if (!Array.isArray(data.user_goals)) {
    throw new Error("Поле user_goals должно быть массивом строк.");
  }
  if (data.user_goals.length > MAX_GOALS) {
    throw new Error(`Не более ${MAX_GOALS} целей.`);
  }

  const entries: MoodEntryInput[] = data.entries.map((e, i) => {
    if (!e || typeof e !== "object") {
      throw new Error(`entries[${i}]: ожидается объект.`);
    }
    if (typeof e.emotion !== "string" || !e.emotion.trim()) {
      throw new Error(`entries[${i}].emotion обязательно.`);
    }
    if (typeof e.intensity !== "number" || !Number.isFinite(e.intensity)) {
      throw new Error(`entries[${i}].intensity должно быть числом.`);
    }
    if (e.intensity < 1 || e.intensity > 5 || !Number.isInteger(e.intensity)) {
      throw new Error(`entries[${i}].intensity: целое от 1 до 5.`);
    }
    if (e.note !== undefined && typeof e.note !== "string") {
      throw new Error(`entries[${i}].note должно быть строкой.`);
    }
    if (e.note && e.note.length > MAX_NOTE_PER_ENTRY) {
      throw new Error(`entries[${i}].note слишком длинное.`);
    }
    if (typeof e.created_at !== "string" || !e.created_at.trim()) {
      throw new Error(`entries[${i}].created_at обязательно (ISO-строка).`);
    }
    const t = Date.parse(e.created_at);
    if (Number.isNaN(t)) {
      throw new Error(`entries[${i}].created_at: невалидная дата.`);
    }
    return {
      emotion: e.emotion.trim(),
      intensity: e.intensity,
      note: e.note?.trim(),
      created_at: e.created_at.trim(),
    };
  });

  const user_goals: string[] = [];
  for (let i = 0; i < data.user_goals.length; i++) {
    const g = data.user_goals[i];
    if (typeof g !== "string" || !g.trim()) {
      throw new Error(`user_goals[${i}]: непустая строка.`);
    }
    if (g.length > MAX_GOAL_LEN) {
      throw new Error(`user_goals[${i}]: не длиннее ${MAX_GOAL_LEN} символов.`);
    }
    user_goals.push(g.trim());
  }

  return { entries, user_goals };
}

Deno.serve(async (req: Request) => {
  const preflight = handleCors(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse("Метод не поддерживается", 405);
  }

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey?.trim()) {
    return errorResponse("Сервер не настроен: отсутствует OPENAI_API_KEY", 500);
  }

  let body: AnalyzeBody;
  try {
    const text = await req.text();
    if (!text) throw new Error("Пустое тело запроса.");
    body = parseBody(text);
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Некорректный JSON.";
    return errorResponse(msg, 400);
  }

  const entriesSummary = body.entries
    .map((e) =>
      `- ${e.created_at} | эмоция: ${e.emotion} | интенсивность: ${e.intensity}/5` +
      (e.note ? ` | заметка: ${e.note}` : "")
    )
    .join("\n");

  const goalsLine = body.user_goals.length
    ? body.user_goals.join("; ")
    : "(цели не указаны)";

  const systemPrompt =
    `Ты психологический аналитик данных самонаблюдения (не клинический диагноз). ` +
    `Проанализируй дневник настроения на русском языке. ` +
    `Ищи закономерности: время суток, дни недели, повторяющиеся эмоции, связь с заметками, возможные триггеры. ` +
    `Учитывай цели пользователя при рекомендациях. ` +
    `Не ставь диагнозы и не заменяй терапию. Тон — поддерживающий и конкретный. ` +
    `Верни ТОЛЬКО валидный JSON без markdown: ` +
    `{"patterns": string[] (3–8 коротких пунктов), ` +
    `"recommendations": string[] (4–8 практичных шагов), ` +
    `"summary": string (2–4 предложения обзора)}. ` +
    `Все строки на русском.`;

  const userContent =
    `Цели пользователя: ${goalsLine}\n\nЗаписи:\n${entriesSummary}`;

  const ac = new AbortController();
  const timeoutId = setTimeout(() => ac.abort(), UPSTREAM_TIMEOUT_MS);

  let openaiRes: Response;
  try {
    openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      signal: ac.signal,
      headers: {
        Authorization: `Bearer ${apiKey.trim()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",
        temperature: 0.5,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
      }),
    });
  } catch (e) {
    console.error("OpenAI fetch error:", e);
    const aborted = e instanceof Error && e.name === "AbortError";
    return errorResponse(
      aborted ? "Превышено время ожидания ответа OpenAI" : "Не удалось связаться с OpenAI",
      502,
    );
  } finally {
    clearTimeout(timeoutId);
  }

  let openaiJson: OpenAIChatResponse;
  try {
    openaiJson = await openaiRes.json() as OpenAIChatResponse;
  } catch {
    return errorResponse("Некорректный ответ OpenAI", 502);
  }

  if (!openaiRes.ok) {
    const errMsg = openaiJson.error?.message ?? openaiRes.statusText;
    console.error("OpenAI API error:", openaiRes.status, errMsg);
    return errorResponse("Ошибка OpenAI API", openaiRes.status >= 500 ? 502 : 400, {
      openai: errMsg,
    });
  }

  const content = openaiJson.choices?.[0]?.message?.content;
  if (!content) {
    return errorResponse("Пустой ответ модели", 502);
  }

  let parsed: {
    patterns?: unknown;
    recommendations?: unknown;
    summary?: unknown;
  };
  try {
    parsed = JSON.parse(content) as typeof parsed;
  } catch {
    return errorResponse("Модель вернула невалидный JSON", 502);
  }

  const patterns = Array.isArray(parsed.patterns)
    ? parsed.patterns.filter((p): p is string => typeof p === "string").map((s) => s.trim()).filter(Boolean)
    : [];
  const recommendations = Array.isArray(parsed.recommendations)
    ? parsed.recommendations
      .filter((p): p is string => typeof p === "string")
      .map((s) => s.trim())
      .filter(Boolean)
    : [];
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";

  if (!patterns.length || !recommendations.length || !summary) {
    return errorResponse(
      "В ответе модели отсутствуют корректные patterns, recommendations или summary",
      502,
    );
  }

  return jsonResponse({ patterns, recommendations, summary });
});

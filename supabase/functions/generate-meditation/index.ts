import {
  errorResponse,
  handleCors,
  jsonResponse,
} from "../_shared/cors.ts";

type GenerateBody = {
  mood: string;
  goal: string;
  duration_minutes: number;
  language: string;
  user_context?: string;
};

type OpenAIChatResponse = {
  choices?: Array<{
    message?: { content?: string };
  }>;
  error?: { message?: string; type?: string };
};

const MAX_CONTEXT_LEN = 4000;
const MIN_DURATION = 3;
const MAX_DURATION = 60;
const UPSTREAM_TIMEOUT_MS = 120_000;

function parseBody(raw: string): GenerateBody {
  const data = JSON.parse(raw) as Partial<GenerateBody>;
  if (typeof data.mood !== "string" || !data.mood.trim()) {
    throw new Error("Поле mood обязательно и должно быть непустой строкой.");
  }
  if (typeof data.goal !== "string" || !data.goal.trim()) {
    throw new Error("Поле goal обязательно и должно быть непустой строкой.");
  }
  if (typeof data.duration_minutes !== "number" || !Number.isFinite(data.duration_minutes)) {
    throw new Error("Поле duration_minutes должно быть числом.");
  }
  if (data.duration_minutes < MIN_DURATION || data.duration_minutes > MAX_DURATION) {
    throw new Error(
      `duration_minutes должно быть от ${MIN_DURATION} до ${MAX_DURATION}.`,
    );
  }
  if (data.language !== "ru") {
    throw new Error('Поддерживается только language: "ru".');
  }
  if (data.user_context !== undefined && typeof data.user_context !== "string") {
    throw new Error("user_context должно быть строкой.");
  }
  if (
    data.user_context &&
    data.user_context.length > MAX_CONTEXT_LEN
  ) {
    throw new Error(`user_context не длиннее ${MAX_CONTEXT_LEN} символов.`);
  }
  return {
    mood: data.mood.trim(),
    goal: data.goal.trim(),
    duration_minutes: Math.round(data.duration_minutes),
    language: "ru",
    user_context: data.user_context?.trim(),
  };
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

  let body: GenerateBody;
  try {
    const text = await req.text();
    if (!text) throw new Error("Пустое тело запроса.");
    body = parseBody(text);
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Некорректный JSON.";
    return errorResponse(msg, 400);
  }

  const systemPrompt =
    `Ты профессиональный ведущий медитаций и терапевт по релаксации. ` +
    `Создай полный текст медитации на русском языке: спокойный, уважительный, без панибратства, ` +
    `без медицинских обещаний и диагнозов. Структура: короткое приветствие, настройка осанки и дыхания, ` +
    `основная часть под настроение и цель пользователя, мягкое завершение. ` +
    `Длительность чтения должна соответствовать примерно ${body.duration_minutes} минутам спокойной речи ` +
    `(не слишком кратко). Верни ТОЛЬКО валидный JSON-объект без markdown и пояснений, со строковыми полями: ` +
    `"title" — короткое название медитации, "description" — 1–2 предложения для карточки в приложении, ` +
    `"script" — полный текст для озвучки с абзацами через \\n.`;

  const userParts = [
    `Настроение: ${body.mood}`,
    `Цель/фокус: ${body.goal}`,
    `Длительность (мин): ${body.duration_minutes}`,
  ];
  if (body.user_context) {
    userParts.push(`Доп. контекст пользователя: ${body.user_context}`);
  }

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
        temperature: 0.7,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userParts.join("\n") },
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

  let parsed: { title?: string; description?: string; script?: string };
  try {
    parsed = JSON.parse(content) as typeof parsed;
  } catch {
    return errorResponse("Модель вернула невалидный JSON", 502);
  }

  const title = typeof parsed.title === "string" ? parsed.title.trim() : "";
  const description =
    typeof parsed.description === "string" ? parsed.description.trim() : "";
  const script = typeof parsed.script === "string" ? parsed.script.trim() : "";

  if (!title || !description || !script) {
    return errorResponse(
      "В ответе модели отсутствуют обязательные поля title, description или script",
      502,
    );
  }

  return jsonResponse({ script, title, description });
});

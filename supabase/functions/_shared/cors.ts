/**
 * Shared CORS for Supabase Edge Functions (browser / Flutter web clients).
 */
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-requested-with",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

/**
 * Respond to CORS preflight. Returns a Response for OPTIONS, otherwise null.
 */
export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  return null;
}

export function jsonResponse(
  body: unknown,
  init: ResponseInit & { status?: number } = {},
): Response {
  const headers = new Headers(init.headers);
  for (const [k, v] of Object.entries(corsHeaders)) {
    if (!headers.has(k)) headers.set(k, v);
  }
  headers.set("Content-Type", "application/json; charset=utf-8");
  return new Response(JSON.stringify(body), {
    ...init,
    status: init.status ?? 200,
    headers,
  });
}

export function errorResponse(
  message: string,
  status: number,
  details?: unknown,
): Response {
  const payload: Record<string, unknown> = { error: message };
  if (details !== undefined) payload.details = details;
  return jsonResponse(payload, { status });
}

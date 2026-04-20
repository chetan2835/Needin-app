type Level = 'info' | 'warn' | 'error';

export function log(level: Level, event: string, data?: Record<string, unknown>) {
  // Structured JSON log — never log raw tokens, Aadhaar, or PII
  console[level === 'error' ? 'error' : 'log'](JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    event,
    ...sanitize(data ?? {}),
  }));
}

function sanitize(obj: Record<string, unknown>): Record<string, unknown> {
  const BLOCKED = ['access_token', 'refresh_token', 'code_verifier',
                   'client_secret', 'aadhaar', 'dob', 'gender'];
  return Object.fromEntries(
    Object.entries(obj).map(([k, v]) =>
      BLOCKED.some(b => k.toLowerCase().includes(b))
        ? [k, '[REDACTED]']
        : [k, v]
    )
  );
}

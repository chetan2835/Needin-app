export async function withRetry<T>(
  fn: () => Promise<T>,
  maxAttempts = 3,
  baseDelayMs = 300
): Promise<T> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (attempt < maxAttempts) {
        // Exponential backoff with jitter
        const delay = baseDelayMs * Math.pow(2, attempt - 1)
                    + Math.random() * 100;
        await new Promise(r => setTimeout(r, delay));
      }
    }
  }
  throw lastError;
}

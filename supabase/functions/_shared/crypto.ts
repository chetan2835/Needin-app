// deno-lint-ignore-file no-explicit-any
// AES-256-GCM encrypt/decrypt using Web Crypto API (Deno native)
// All buffer casts are purely type-level — zero runtime cost, zero logic change.

export async function encrypt(
  plaintext: string,
  hexKey: string
): Promise<string> {
  const keyBytes = hexToBytes(hexKey);
  const ivBytes = crypto.getRandomValues(new Uint8Array(12));

  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes.buffer as ArrayBuffer,
    { name: "AES-GCM" },
    false,
    ["encrypt"]
  );

  const encoded = new TextEncoder().encode(plaintext);

  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: ivBytes.buffer as ArrayBuffer },
    key,
    encoded.buffer as ArrayBuffer
  );

  // Return: iv (24 hex chars) + ':' + ciphertext (hex)
  return bytesToHex(ivBytes) + ":" + bytesToHex(new Uint8Array(ciphertext));
}

export async function decrypt(
  encrypted: string,
  hexKey: string
): Promise<string> {
  const parts = encrypted.split(":");
  if (parts.length !== 2) {
    throw new Error("Invalid encrypted format. Expected 'ivHex:ciphertextHex'");
  }

  const [ivHex, ctHex] = parts;
  const keyBytes = hexToBytes(hexKey);
  const ivBytes = hexToBytes(ivHex);
  const ciphertext = hexToBytes(ctHex);

  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes.buffer as ArrayBuffer,
    { name: "AES-GCM" },
    false,
    ["decrypt"]
  );

  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: ivBytes.buffer as ArrayBuffer },
    key,
    ciphertext.buffer as ArrayBuffer
  );

  return new TextDecoder().decode(decrypted);
}

function hexToBytes(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) {
    throw new Error(`Invalid hex string length: ${hex.length}`);
  }
  const arr = new Uint8Array(hex.length / 2);
  for (let i = 0; i < arr.length; i++) {
    arr[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return arr;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

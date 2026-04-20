// deno-lint-ignore-file no-explicit-any

export function getConfig() {
  const env = Deno.env.get("DIGILOCKER_ENV") ?? "sandbox";
  const isProd = env === "production";

  const clientId = Deno.env.get("DIGILOCKER_CLIENT_ID") ?? "";
  const clientSecret = Deno.env.get("DIGILOCKER_CLIENT_SECRET") ?? "";
  const redirectUri = Deno.env.get("DIGILOCKER_REDIRECT_URI") ?? "";
  const encryptionKey = Deno.env.get("TOKEN_ENCRYPTION_KEY") ?? "";
  const deepLink = Deno.env.get("APP_DEEP_LINK_SCHEME") ?? "";

  if (!clientId) throw new Error("Missing env: DIGILOCKER_CLIENT_ID");
  if (!clientSecret) throw new Error("Missing env: DIGILOCKER_CLIENT_SECRET");
  if (!redirectUri) throw new Error("Missing env: DIGILOCKER_REDIRECT_URI");
  if (!encryptionKey) throw new Error("Missing env: TOKEN_ENCRYPTION_KEY");
  if (!deepLink) throw new Error("Missing env: APP_DEEP_LINK_SCHEME");

  const authUrl = isProd
    ? (Deno.env.get("DIGILOCKER_PROD_AUTH_URL") ?? "")
    : (Deno.env.get("DIGILOCKER_AUTH_URL") ?? "");
  const tokenUrl = isProd
    ? (Deno.env.get("DIGILOCKER_PROD_TOKEN_URL") ?? "")
    : (Deno.env.get("DIGILOCKER_TOKEN_URL") ?? "");
  const profileUrl = isProd
    ? (Deno.env.get("DIGILOCKER_PROD_PROFILE_URL") ?? "")
    : (Deno.env.get("DIGILOCKER_PROFILE_URL") ?? "");
  const filesUrl = isProd
    ? (Deno.env.get("DIGILOCKER_PROD_FILES_URL") ?? "")
    : (Deno.env.get("DIGILOCKER_FILES_URL") ?? "");
  const aadhaarUrl = isProd
    ? (Deno.env.get("DIGILOCKER_PROD_AADHAAR_URL") ?? "")
    : (Deno.env.get("DIGILOCKER_AADHAAR_URL") ?? "");

  return {
    clientId,
    clientSecret,
    redirectUri,
    authUrl,
    tokenUrl,
    profileUrl,
    filesUrl,
    aadhaarUrl,
    deepLink,
    encryptionKey,
    isProd,
  };
}

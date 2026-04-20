// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getConfig } from '../_shared/digilocker_config.ts'
import { encrypt } from '../_shared/crypto.ts'
import { log } from '../_shared/logger.ts'
import { withRetry } from '../_shared/retry.ts'

serve(async (req: Request) => {
  const config = getConfig();
  const serviceClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const url = new URL(req.url);
  const code    = url.searchParams.get('code');
  const state   = url.searchParams.get('state');
  const error   = url.searchParams.get('error');
  const deepLink = config.deepLink;

  // Helper: redirect to app deep link
  const redirect = (status: string, extra?: Record<string, string>) => {
    const params = new URLSearchParams({ status, ...extra });
    return Response.redirect(`${deepLink}?${params.toString()}`, 302);
  };

  // 1. User denied consent
  if (error === 'access_denied') {
    log('info', 'callback.consent_denied');
    return redirect('failed', { reason: 'consent_denied' });
  }

  // 2. Missing required params
  if (!code || !state) {
    log('warn', 'callback.missing_params', { hasCode: !!code, hasState: !!state });
    return redirect('failed', { reason: 'invalid_request' });
  }

  // 3. Validate state + load session
  const { data: session, error: sessionError } = await serviceClient
    .from('digilocker_sessions')
    .select('user_id, code_verifier, expires_at')
    .eq('state', state)
    .single();

  if (sessionError || !session) {
    log('warn', 'callback.invalid_state', { state: state.slice(0,8) + '...' });
    return redirect('failed', { reason: 'invalid_state' });
  }

  // 4. Check expiry
  if (new Date(session.expires_at) < new Date()) {
    log('warn', 'callback.session_expired', { userId: session.user_id });
    await serviceClient.from('digilocker_sessions').delete().eq('state', state);
    return redirect('failed', { reason: 'session_expired' });
  }

  const userId      = session.user_id;
  const codeVerifier = session.code_verifier;

  // 5. Immediately delete the session (prevents replay)
  await serviceClient.from('digilocker_sessions').delete().eq('state', state);

  // 6. Exchange code for token — with retry + exponential backoff
  let tokenData: Record<string, unknown>;
  try {
    tokenData = await withRetry(async () => {
      const resp = await fetch(config.tokenUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type:    'authorization_code',
          code,
          redirect_uri:  config.redirectUri,
          client_id:     config.clientId,
          client_secret: config.clientSecret,
          code_verifier: codeVerifier,
        }),
      });
      if (!resp.ok) {
        const body = await resp.text();
        throw new Error(`Token exchange failed: ${resp.status} ${body}`);
      }
      return resp.json();
    }, 3, 500);
  } catch (err) {
    log('error', 'callback.token_exchange_failed', { 
      userId, error: String(err) 
    });
    return redirect('failed', { reason: 'token_exchange_failed' });
  }

  const accessToken  = tokenData.access_token as string;
  const refreshToken = tokenData.refresh_token as string | undefined;
  const expiresIn    = tokenData.expires_in as number ?? 3600;
  const tokenExpiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

  // 7. Encrypt tokens before storing
  const encryptedAccess  = await encrypt(accessToken,  config.encryptionKey);
  const encryptedRefresh = refreshToken
    ? await encrypt(refreshToken, config.encryptionKey)
    : null;

  // 8. Fetch user profile — with retry
  let userProfile: Record<string, unknown> = {};
  try {
    userProfile = await withRetry(async () => {
      const resp = await fetch(config.profileUrl, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!resp.ok) throw new Error(`Profile fetch failed: ${resp.status}`);
      return resp.json();
    });
  } catch (err) {
    log('warn', 'callback.profile_fetch_failed', { userId, error: String(err) });
  }

  // 9. Fetch issued files — with retry (non-fatal)
  let issuedFiles: unknown = null;
  try {
    issuedFiles = await withRetry(async () => {
      const resp = await fetch(config.filesUrl, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!resp.ok) throw new Error(`Files fetch failed: ${resp.status}`);
      return resp.json();
    });
  } catch (err) {
    log('warn', 'callback.files_fetch_failed', { userId, error: String(err) });
  }

  // 10. Upsert verification record — IDEMPOTENT (safe if called twice)
  const { error: upsertError } = await serviceClient
    .from('digilocker_verifications')
    .upsert({
      user_id:                  userId,
      digilocker_id:            (userProfile.digilockerid as string) ?? null,
      name:                     (userProfile.name as string) ?? null,
      date_of_birth:            (userProfile.dob as string) ?? null,
      gender:                   (userProfile.gender as string) ?? null,
      reference_key:            (userProfile.reference_key as string) ?? null,
      raw_userprofile:          userProfile,
      raw_issued_files:         issuedFiles,
      access_token_encrypted:   encryptedAccess,
      refresh_token_encrypted:  encryptedRefresh,
      token_expires_at:         tokenExpiresAt,
      verification_status:      'verified',
      verified_at:              new Date().toISOString(),
      failure_reason:           null,
      attempt_count:            1,
    }, {
      onConflict: 'user_id',
      ignoreDuplicates: false,
    });

  if (upsertError) {
    log('error', 'callback.upsert_failed', { userId, error: upsertError.message });
    return redirect('failed', { reason: 'database_error' });
  }

  // 11. Update users table
  const { error: userUpdateError } = await serviceClient
    .from('users')
    .update({
      is_identity_verified:  true,
      identity_verified_at:  new Date().toISOString(),
      identity_provider:     'digilocker',
    })
    .eq('id', userId);

  if (userUpdateError) {
    log('error', 'callback.user_update_failed', { 
      userId, error: userUpdateError.message 
    });
  }

  const userName = encodeURIComponent((userProfile.name as string) ?? '');

  log('info', 'callback.verification_complete', { 
    userId,
    hasName: !!userProfile.name,
    hasFiles: !!issuedFiles,
  });

  // 12. Redirect to app — success!
  return redirect('success', { name: userName });
});

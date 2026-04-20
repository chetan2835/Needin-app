// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getConfig } from '../_shared/digilocker_config.ts'
import { log } from '../_shared/logger.ts'

serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, content-type',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // 1. Authenticate caller — must have valid Supabase JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: corsHeaders }
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      log('warn', 'initiate.auth_failed', { error: authError?.message });
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: corsHeaders }
      );
    }

    // 2. Check if already verified — no need to re-initiate
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: existing } = await serviceClient
      .from('digilocker_verifications')
      .select('verification_status')
      .eq('user_id', user.id)
      .single();

    if (existing?.verification_status === 'verified') {
      return new Response(
        JSON.stringify({ error: 'already_verified' }),
        { status: 409, headers: corsHeaders }
      );
    }

    const config = getConfig();

    // 3. Generate PKCE — S256 method
    const codeVerifier = generateCodeVerifier();
    const codeChallenge = await generateCodeChallenge(codeVerifier);
    const state = generateState();

    // 4. Store session with 10-minute expiry
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    const { error: insertError } = await serviceClient
      .from('digilocker_sessions')
      .insert({
        user_id: user.id,
        state,
        code_verifier: codeVerifier,
        expires_at: expiresAt,
      });

    if (insertError) {
      log('error', 'initiate.session_insert_failed', { 
        userId: user.id, 
        error: insertError.message 
      });
      return new Response(
        JSON.stringify({ error: 'Failed to initiate. Please try again.' }),
        { status: 500, headers: corsHeaders }
      );
    }

    // 5. Build DigiLocker authorization URL
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: config.clientId,
      redirect_uri: config.redirectUri,
      state,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
      scope: 'openid',
    });

    const authorizationUrl = `${config.authUrl}?${params.toString()}`;

    log('info', 'initiate.success', { userId: user.id });

    return new Response(
      JSON.stringify({ url: authorizationUrl }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    log('error', 'initiate.unhandled_error', { error: String(err) });
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: corsHeaders }
    );
  }
});

// ── PKCE Helpers ──────────────────────────────────────────────
function generateCodeVerifier(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return base64UrlEncode(array);
}

async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoded = new TextEncoder().encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', encoded);
  return base64UrlEncode(new Uint8Array(hash));
}

function generateState(): string {
  const array = new Uint8Array(16);
  crypto.getRandomValues(array);
  return Array.from(array).map(b => b.toString(16).padStart(2,'0')).join('');
}

function base64UrlEncode(input: Uint8Array): string {
  return btoa(String.fromCharCode(...input))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

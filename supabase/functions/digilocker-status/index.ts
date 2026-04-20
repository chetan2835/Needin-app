// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req: Request) => {
  const corsHeaders = { 'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'authorization, content-type' };
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return new Response(JSON.stringify({ error: 'Unauthorized' }), 
    { status: 401, headers: corsHeaders });

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), 
    { status: 401, headers: corsHeaders });

  const serviceClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { data } = await serviceClient
    .from('digilocker_verifications')
    .select('verification_status, verified_at, name, digilocker_id, failure_reason')
    .eq('user_id', user.id)
    .single();

  // Also fetch from users table
  const { data: userData } = await serviceClient
    .from('users')
    .select('is_identity_verified, identity_verified_at')
    .eq('id', user.id)
    .single();

  return new Response(JSON.stringify({
    is_verified:     userData?.is_identity_verified ?? false,
    verified_at:     data?.verified_at ?? null,
    name:            data?.name ?? null,
    digilocker_id:   data?.digilocker_id ?? null,
    status:          data?.verification_status ?? 'not_started',
    failure_reason:  data?.failure_reason ?? null,
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});

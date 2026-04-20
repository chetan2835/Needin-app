// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as bcrypt from "https://deno.land/x/bcrypt@v0.4.1/mod.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { user_id, mpin } = body as { user_id: string; mpin: string };

    if (!user_id || !mpin) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing user_id or mpin' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ success: false, error: 'Server configuration error' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: user, error } = await supabase
      .from('profiles')
      .select(
        'id, full_name, phone, city, photo_url, role, ' +
          'mpin_hash, mpin_attempts, mpin_locked_at, is_active'
      )
      .eq('id', user_id)
      .single();

    if (error || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'User not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const profile = user as any;

    if (!profile.is_active) {
      return new Response(
        JSON.stringify({ success: false, error: 'Account is disabled' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Check lockout — 5 wrong attempts = 30 second lockout
    if (profile.mpin_locked_at) {
      const lockedAt = new Date(profile.mpin_locked_at as string).getTime();
      const now = Date.now();
      const elapsed = (now - lockedAt) / 1000;

      if (elapsed < 30) {
        const waitSeconds = Math.ceil(30 - elapsed);
        return new Response(
          JSON.stringify({
            success: false,
            locked: true,
            wait_seconds: waitSeconds,
            error: `Too many attempts. Wait ${waitSeconds} seconds.`,
          }),
          {
            status: 429,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // Lockout expired — reset counter
      await supabase
        .from('profiles')
        .update({ mpin_attempts: 0, mpin_locked_at: null })
        .eq('id', user_id);
      profile.mpin_attempts = 0;
    }

    // Verify MPIN against stored bcrypt hash
    const isValid = await bcrypt.compare(
      mpin,
      profile.mpin_hash as string
    );

    if (!isValid) {
      const newAttempts = ((profile.mpin_attempts as number) || 0) + 1;
      const updateData: Record<string, unknown> = {
        mpin_attempts: newAttempts,
      };
      if (newAttempts >= 5) {
        updateData.mpin_locked_at = new Date().toISOString();
      }

      await supabase
        .from('profiles')
        .update(updateData)
        .eq('id', user_id);

      return new Response(
        JSON.stringify({
          success: false,
          locked: newAttempts >= 5,
          attempts_remaining: Math.max(0, 5 - newAttempts),
          error:
            newAttempts >= 5
              ? 'Account locked for 30 seconds'
              : `Wrong MPIN. ${5 - newAttempts} attempts remaining.`,
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // MPIN correct — reset all attempt tracking
    await supabase
      .from('profiles')
      .update({ mpin_attempts: 0, mpin_locked_at: null })
      .eq('id', user_id);

    return new Response(
      JSON.stringify({
        success: true,
        user: {
          id: profile.id,
          full_name: profile.full_name,
          phone: profile.phone,
          city: profile.city,
          photo_url: profile.photo_url,
          role: profile.role,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Internal server error: ' + errorMsg,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

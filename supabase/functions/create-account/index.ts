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
    const {
      user_id,
      full_name,
      phone,
      email,
      city,
      mpin,
      photo_url,
    } = body as {
      user_id: string;
      full_name: string;
      phone: string;
      email?: string;
      city: string;
      mpin: string;
      photo_url?: string;
    };

    if (!user_id || !full_name || !phone || !city || !mpin) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing required fields' }),
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

    // Hash MPIN before storing — NEVER store raw PIN
    const salt = await bcrypt.genSalt(10);
    const mpinHash = await bcrypt.hash(mpin, salt);

    // Fetch existing profile to preserve any existing data
    const { data: existingProfile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user_id)
      .single();

    // Upsert profile row
    const { data, error } = await supabase
      .from('profiles')
      .upsert(
        {
          id: user_id,
          full_name: full_name || (existingProfile as any)?.full_name,
          phone: phone || (existingProfile as any)?.phone,
          email: email || (existingProfile as any)?.email || null,
          city: city || (existingProfile as any)?.city,
          photo_url: photo_url || (existingProfile as any)?.photo_url || null,
          mpin_hash: mpinHash,
          role: (existingProfile as any)?.role ?? 'user',
          is_active: true,
          mpin_attempts: 0,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'id' }
      )
      .select('id, full_name, phone, email, city, photo_url, role')
      .single();

    if (error) {
      throw new Error(error.message);
    }

    return new Response(JSON.stringify({ success: true, user: data }), {
      status: 201,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
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

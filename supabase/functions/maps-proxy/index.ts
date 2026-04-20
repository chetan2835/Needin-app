// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, query, placeId, origin, destination, sessionToken, waypoints } = body;
    const apiKey = Deno.env.get('GOOGLE_MAPS_API_KEY');

    if (!apiKey) {
      throw new Error('API key not configured in Edge Function environment');
    }

    let url = '';

    if (action === 'autocomplete') {
      url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(query)}&components=country:in&key=${apiKey}&sessiontoken=${sessionToken || ''}`;
    } else if (action === 'details') {
      url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=geometry,formatted_address,name&key=${apiKey}`;
    } else if (action === 'directions') {
      url = `https://maps.googleapis.com/maps/api/directions/json?origin=${origin}&destination=${destination}&mode=driving&alternatives=false&key=${apiKey}`;
      if (waypoints) {
        url += `&waypoints=${waypoints}`;
      }
    } else if (action === 'geocode') {
      url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${origin}&key=${apiKey}`;
    } else {
      throw new Error('Invalid action or unsupported maps function');
    }

    const res = await fetch(url);
    const data = await res.json();

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

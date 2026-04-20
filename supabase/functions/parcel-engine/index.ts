// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { classifyParcel } from "./classification.ts";
import { calculatePrice } from "./pricing.ts";
import { searchTravelers } from "./matching.ts";
import {
  validateDimensionsAndWeight,
  validatePricingPayload,
  sanitizeInput,
  ValidationError,
} from "./validation.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-idempotency-key",
};

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Timeout Protection (returns 504 if processing takes > 5s)
  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error("Timeout: Operation took too long")), 5000)
  );

  const requestHandler = async () => {
    // SECURITY: Validate API origin
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      throw new ValidationError("Unauthorized: Missing Auth Header");
    }

    // Engine is cleared for calculation. The API gateway handles JWT parsing.
    // Safety 1: Parse payload
    const rawBody = await req.json();
    const body = sanitizeInput(rawBody);

    // Idempotency check (Require Header)
    const idempotencyKey = req.headers.get("x-idempotency-key");
    if (!idempotencyKey || idempotencyKey.length < 10) {
      throw new ValidationError("Missing or invalid 'x-idempotency-key' header. Required for safe identical retries.");
    }

    // Action-based Routing
    const action = body.action;

    // Endpoint 1: /classify-parcel
    if (action === "classify") {
      const { length, width, height, weight } = body;
      validateDimensionsAndWeight(length, width, height, weight);
      
      const payload = classifyParcel(length, width, height, weight);

      return new Response(
        JSON.stringify({
          success: true,
          data: payload,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // Endpoint 2: /calculate-price
    if (action === "calculatePrice") {
      const { fromCity, toCity, distanceKM, parcelCategory, routeType } = body;
      validatePricingPayload(fromCity, toCity, distanceKM, parcelCategory, routeType);

      const pricePayload = calculatePrice(distanceKM, parcelCategory as any, routeType as any);

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            ...pricePayload,
            price: pricePayload.roundedPrice, // Ensure final output is mapped correctly
            valid: true
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // Endpoint 3: /search-travelers
    if (action === "searchTravelers") {
      const { parcelCategory, parcelWeight, senderRoute, travelerList } = body;
      if (!parcelCategory || typeof parcelWeight !== "number" || !senderRoute || !Array.isArray(travelerList)) {
        throw new ValidationError("Missing or invalid matching payload.");
      }

      const travelers = searchTravelers(parcelCategory, parcelWeight, senderRoute, travelerList);

      return new Response(
        JSON.stringify({
          success: true,
          data: { travelers },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // Invalid endpoint
    return new Response(
      JSON.stringify({ success: false, error: "Action not found in body" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    );
  };

  try {
    return await Promise.race([requestHandler(), timeoutPromise]) as Response;
  } catch (error: any) {
    if (error instanceof ValidationError || error.message.includes("exceeds allowed limits") || error.message.includes("key")) {
      // 400 Bad Request
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }
    if (error.message.includes("Timeout")) {
      return new Response(
        JSON.stringify({ success: false, error: "Gateway Timeout" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 504 }
      );
    }
    if (error instanceof SyntaxError) {
      return new Response(
        JSON.stringify({ success: false, error: "Malformed JSON payload" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // 500 Internal Error - graceful 
    console.error("Internal Error: ", error); // Log out safely without exposing PII client side
    return new Response(
      JSON.stringify({ success: false, error: "Internal Server Error" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface TokenWebhookPayload {
  webhook_url: string;
  tab_id: string;
  tab_name: string;
  domain: string;
  token_name: string;
  token_value: string;
  captured_at: string;
  user_email?: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const payload: TokenWebhookPayload = await req.json();
    
    console.log('[forward-token-webhook] Received request:', {
      tab_id: payload.tab_id,
      tab_name: payload.tab_name,
      domain: payload.domain,
      token_name: payload.token_name,
      webhook_url: payload.webhook_url,
    });

    if (!payload.webhook_url) {
      console.log('[forward-token-webhook] No webhook URL provided, skipping');
      return new Response(
        JSON.stringify({ success: false, error: 'No webhook URL provided' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Prepare webhook payload
    const webhookPayload = {
      event: 'token_captured',
      tab_id: payload.tab_id,
      tab_name: payload.tab_name,
      domain: payload.domain,
      token_name: payload.token_name,
      token_value: payload.token_value,
      captured_at: payload.captured_at,
      user_email: payload.user_email,
    };

    console.log('[forward-token-webhook] Sending to webhook:', payload.webhook_url);

    // Forward to the webhook URL
    const webhookResponse = await fetch(payload.webhook_url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(webhookPayload),
    });

    const responseStatus = webhookResponse.status;
    let responseBody = '';
    try {
      responseBody = await webhookResponse.text();
    } catch {
      responseBody = 'Unable to read response body';
    }

    console.log('[forward-token-webhook] Webhook response:', {
      status: responseStatus,
      body: responseBody.substring(0, 200),
    });

    if (!webhookResponse.ok) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: `Webhook returned ${responseStatus}`,
          response: responseBody.substring(0, 500),
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, status: responseStatus }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error('[forward-token-webhook] Error:', errorMessage);
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

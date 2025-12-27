import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    console.log("update-release-url: Starting update process");

    // Verificar autorização usando o secret personalizado
    const authHeader = req.headers.get('Authorization');
    const expectedSecret = Deno.env.get('UPLOAD_RELEASE_SECRET');
    
    if (!authHeader) {
      console.error("update-release-url: Missing authorization header");
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const token = authHeader.replace('Bearer ', '');
    
    if (token !== expectedSecret) {
      console.error("update-release-url: Invalid authorization token");
      return new Response(
        JSON.stringify({ error: 'Invalid authorization token' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Parse JSON body
    const { version, platform, url } = await req.json();
    console.log(`update-release-url: Received - version: ${version}, platform: ${platform}, url: ${url}`);

    if (!version || !platform || !url) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: version, platform, url' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validar plataforma
    const validPlatforms = ['windows', 'macos', 'apk'];
    if (!validPlatforms.includes(platform)) {
      return new Response(
        JSON.stringify({ error: `Invalid platform. Must be one of: ${validPlatforms.join(', ')}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Criar cliente Supabase admin
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Mapear plataforma para coluna do banco
    const platformColumns: Record<string, string> = {
      windows: 'windows_url',
      macos: 'macos_url',
      apk: 'apk_url',
    };

    const columnName = platformColumns[platform];
    
    // Atualizar a URL no banco
    const { error: updateError } = await supabaseAdmin
      .from('app_versions')
      .update({ 
        [columnName]: url,
        status: 'completed',
        deploy_completed_at: new Date().toISOString()
      })
      .eq('version', version);

    if (updateError) {
      console.error("update-release-url: Database update error:", updateError);
      return new Response(
        JSON.stringify({ error: 'Failed to update database', details: updateError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`update-release-url: Successfully updated ${columnName} for version ${version}`);

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Updated ${platform} URL for version ${version}`,
        url 
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error("update-release-url: Unexpected error:", error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

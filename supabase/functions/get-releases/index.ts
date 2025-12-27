import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    console.log("get-releases: Fetching public releases");

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Buscar versões com status 'completed' que tenham pelo menos uma URL de download
    const { data: releases, error } = await supabaseAdmin
      .from('app_versions')
      .select('id, version, description, changes, status, windows_url, macos_url, apk_url, deploy_completed_at, created_at')
      .eq('status', 'completed')
      .or('windows_url.neq.null,macos_url.neq.null,apk_url.neq.null')
      .order('created_at', { ascending: false });

    if (error) {
      console.error("get-releases: Database error:", error);
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`get-releases: Found ${releases?.length || 0} releases`);

    // Retornar a versão mais recente como destaque e as outras como histórico
    const latestRelease = releases?.[0] || null;
    const previousReleases = releases?.slice(1) || [];

    return new Response(
      JSON.stringify({
        latest: latestRelease,
        previous: previousReleases,
        total: releases?.length || 0,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: unknown) {
    console.error("get-releases: Unexpected error:", error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

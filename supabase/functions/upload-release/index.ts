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
    console.log("upload-release: Starting upload process");

    // Verificar autorização (service role key)
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      console.error("upload-release: Missing authorization header");
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Criar cliente admin para bypass de RLS
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Parse multipart form data
    const formData = await req.formData();
    const version = formData.get('version') as string;
    const platform = formData.get('platform') as string;
    const file = formData.get('file') as File;

    console.log(`upload-release: Received - version: ${version}, platform: ${platform}, file: ${file?.name}`);

    if (!version || !platform || !file) {
      console.error("upload-release: Missing required fields");
      return new Response(
        JSON.stringify({ error: 'Missing required fields: version, platform, file' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validar platform
    const validPlatforms = ['windows', 'macos', 'apk'];
    if (!validPlatforms.includes(platform)) {
      console.error(`upload-release: Invalid platform: ${platform}`);
      return new Response(
        JSON.stringify({ error: `Invalid platform. Must be one of: ${validPlatforms.join(', ')}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Determinar extensão e nome do arquivo
    const extensions: Record<string, string> = {
      windows: '.exe',
      macos: '.dmg',
      apk: '.apk',
    };

    const fileName = `GerenciaZap-${version}-${platform}${extensions[platform]}`;
    const storagePath = `${version}/${fileName}`;

    console.log(`upload-release: Uploading to storage path: ${storagePath}`);

    // Converter File para ArrayBuffer
    const fileBuffer = await file.arrayBuffer();

    // Upload para o Storage
    const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
      .from('releases')
      .upload(storagePath, fileBuffer, {
        contentType: file.type || 'application/octet-stream',
        upsert: true,
      });

    if (uploadError) {
      console.error("upload-release: Storage upload error:", uploadError);
      return new Response(
        JSON.stringify({ error: `Storage upload failed: ${uploadError.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log("upload-release: File uploaded successfully:", uploadData);

    // Obter URL pública
    const { data: urlData } = supabaseAdmin.storage
      .from('releases')
      .getPublicUrl(storagePath);

    const publicUrl = urlData.publicUrl;
    console.log(`upload-release: Public URL: ${publicUrl}`);

    // Atualizar a tabela app_versions com a URL
    const urlColumn = `${platform}_url`;
    const { error: updateError } = await supabaseAdmin
      .from('app_versions')
      .update({ [urlColumn]: publicUrl })
      .eq('version', version);

    if (updateError) {
      console.error("upload-release: Database update error:", updateError);
      // Não retornar erro, o arquivo já foi uploaded com sucesso
      console.log("upload-release: File uploaded but database update failed");
    } else {
      console.log(`upload-release: Database updated - ${urlColumn} set for version ${version}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        publicUrl,
        storagePath,
        platform,
        version,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: unknown) {
    console.error("upload-release: Unexpected error:", error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

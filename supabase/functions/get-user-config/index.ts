import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    // Get the authorization header
    const authHeader = req.headers.get('Authorization');
    console.log('[get-user-config] Auth header present:', !!authHeader);
    
    if (!authHeader) {
      console.error('[get-user-config] Missing authorization header');
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Extract the token from Bearer header
    const token = authHeader.replace('Bearer ', '');
    console.log('[get-user-config] Token length:', token.length);
    console.log('[get-user-config] Token prefix:', token.substring(0, 20));

    // Create admin Supabase client to verify user token
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });

    // Get user from token using the admin client
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    
    if (userError || !user) {
      console.error('[get-user-config] Auth error:', userError?.message);
      console.error('[get-user-config] Auth error code:', userError?.code);
      const errorMsg = userError?.message || 'Invalid JWT';
      return new Response(
        JSON.stringify({ error: errorMsg }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    console.log('[get-user-config] User authenticated:', user.id);

    console.log(`[get-user-config] Fetching config for user: ${user.id}`);

    // Create client with user's RLS context
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    // Fetch all data in parallel
    const [tabGroupsRes, tabsRes, shortcutsRes, layoutsRes] = await Promise.all([
      supabase.from('tab_groups').select('*').eq('user_id', user.id).order('position'),
      supabase.from('tabs').select('*').eq('user_id', user.id).order('position'),
      supabase.from('text_shortcuts').select('*').eq('user_id', user.id).order('command'),
      supabase.from('split_layouts').select('*').eq('user_id', user.id).order('name'),
    ]);

    // Check for errors
    if (tabGroupsRes.error) console.error('[get-user-config] Tab groups error:', tabGroupsRes.error);
    if (tabsRes.error) console.error('[get-user-config] Tabs error:', tabsRes.error);
    if (shortcutsRes.error) console.error('[get-user-config] Shortcuts error:', shortcutsRes.error);
    if (layoutsRes.error) console.error('[get-user-config] Layouts error:', layoutsRes.error);

    // Organize tabs by group
    const tabGroups = (tabGroupsRes.data || []).map(group => ({
      ...group,
      tabs: (tabsRes.data || []).filter(tab => tab.group_id === group.id)
    }));

    const response = {
      user_id: user.id,
      email: user.email,
      fetched_at: new Date().toISOString(),
      tab_groups: tabGroups,
      text_shortcuts: shortcutsRes.data || [],
      split_layouts: layoutsRes.data || [],
      stats: {
        total_groups: tabGroupsRes.data?.length || 0,
        total_tabs: tabsRes.data?.length || 0,
        total_shortcuts: shortcutsRes.data?.length || 0,
        total_layouts: layoutsRes.data?.length || 0,
      }
    };

    console.log(`[get-user-config] Config fetched: ${response.stats.total_groups} groups, ${response.stats.total_tabs} tabs`);

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: unknown) {
    console.error('Error in get-user-config:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

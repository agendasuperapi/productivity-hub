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
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!;
    
    // Get the authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create Supabase client with user's token
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    // Get user from token
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      console.error('Auth error:', userError);
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Fetching config for user: ${user.id}`);

    // Fetch all data in parallel
    const [tabGroupsRes, tabsRes, shortcutsRes, layoutsRes] = await Promise.all([
      supabase.from('tab_groups').select('*').order('position'),
      supabase.from('tabs').select('*').order('position'),
      supabase.from('text_shortcuts').select('*').order('command'),
      supabase.from('split_layouts').select('*').order('name'),
    ]);

    // Check for errors
    if (tabGroupsRes.error) console.error('Tab groups error:', tabGroupsRes.error);
    if (tabsRes.error) console.error('Tabs error:', tabsRes.error);
    if (shortcutsRes.error) console.error('Shortcuts error:', shortcutsRes.error);
    if (layoutsRes.error) console.error('Layouts error:', layoutsRes.error);

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

    console.log(`Config fetched: ${response.stats.total_groups} groups, ${response.stats.total_tabs} tabs`);

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

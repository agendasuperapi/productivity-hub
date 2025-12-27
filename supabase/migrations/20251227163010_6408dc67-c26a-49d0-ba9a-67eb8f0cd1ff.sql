-- Habilitar realtime para tab_groups e tabs
ALTER PUBLICATION supabase_realtime ADD TABLE public.tab_groups;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tabs;
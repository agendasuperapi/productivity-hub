-- Habilitar realtime para text_shortcuts e keywords
ALTER PUBLICATION supabase_realtime ADD TABLE public.text_shortcuts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.keywords;
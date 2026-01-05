-- Criar função para incrementar o contador de uso do atalho
CREATE OR REPLACE FUNCTION public.increment_shortcut_use_count(shortcut_id uuid, increment_by integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.text_shortcuts 
  SET use_count = use_count + increment_by,
      updated_at = now()
  WHERE id = shortcut_id 
    AND user_id = auth.uid();
END;
$$;
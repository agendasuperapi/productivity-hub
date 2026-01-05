-- Adicionar coluna de contagem de uso na tabela text_shortcuts
ALTER TABLE public.text_shortcuts 
ADD COLUMN use_count integer NOT NULL DEFAULT 0;
-- Adicionar coluna para domínios alternativos na tabela tabs
ALTER TABLE public.tabs 
ADD COLUMN alternative_domains jsonb DEFAULT '[]'::jsonb;
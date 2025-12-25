-- Adicionar colunas para preferências de cores na tabela profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS primary_color jsonb DEFAULT NULL,
ADD COLUMN IF NOT EXISTS background_color jsonb DEFAULT NULL;
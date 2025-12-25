-- Adicionar coluna de preferência de tema na tabela profiles
ALTER TABLE public.profiles 
ADD COLUMN theme_preference text DEFAULT 'dark';

-- Adicionar comentário para documentação
COMMENT ON COLUMN public.profiles.theme_preference IS 'Preferência de tema do usuário: dark ou light';
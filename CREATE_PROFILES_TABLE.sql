-- Tabela para perfis de usuário
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para busca rápida
CREATE INDEX IF NOT EXISTS idx_profiles_id ON profiles(id);

-- RLS (Row Level Security)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Política: usuários só podem ver seus próprios perfis
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Política: usuários só podem inserir seus próprios perfis
CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Política: usuários só podem atualizar seus próprios perfis
CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Política: usuários só podem deletar seus próprios perfis
CREATE POLICY "Users can delete their own profile"
  ON profiles FOR DELETE
  USING (auth.uid() = id);

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Criar bucket de storage para avatares (execute no SQL Editor do Supabase)
-- NOTA: Você precisa criar o bucket manualmente no Supabase Dashboard:
-- 1. Vá para Storage no dashboard do Supabase
-- 2. Clique em "New bucket"
-- 3. Nome: "avatars"
-- 4. Marque "Public bucket" para tornar as imagens públicas
-- 5. Crie o bucket

-- Políticas de storage para o bucket avatars
-- NOTA: As políticas de storage devem ser criadas através do Dashboard do Supabase:
-- 1. Vá para Storage > Policies no dashboard do Supabase
-- 2. Selecione o bucket "avatars"
-- 3. Clique em "New Policy"
-- 
-- Para Upload (INSERT):
--   Policy name: "Users can upload their own avatar"
--   Allowed operation: INSERT
--   Policy definition: (bucket_id = 'avatars')
--   Policy check: (bucket_id = 'avatars') AND (auth.uid()::text = (storage.foldername(name))[1])
--
-- Para Read (SELECT):
--   Policy name: "Public avatars are readable"
--   Allowed operation: SELECT
--   Policy definition: (bucket_id = 'avatars')
--   Policy check: (bucket_id = 'avatars')
--
-- OU use o SQL abaixo (método alternativo):
-- CREATE POLICY "Users can upload their own avatar"
-- ON storage.objects FOR INSERT
-- TO authenticated
-- WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
--
-- CREATE POLICY "Public avatars are readable"
-- ON storage.objects FOR SELECT
-- TO public
-- USING (bucket_id = 'avatars');


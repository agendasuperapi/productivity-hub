-- Script SQL para configurar o banco de dados no Supabase

-- 1. Criar tabela de perfis de usuário
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Criar tabela de abas salvas
-- NOTA: Permite múltiplas abas com a mesma URL para o mesmo usuário
-- Não há constraint UNIQUE, permitindo URLs duplicadas
CREATE TABLE IF NOT EXISTS saved_tabs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  icon_url TEXT,
  tab_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Remover qualquer constraint UNIQUE que possa existir na URL (se houver)
-- Isso garante que múltiplas abas com a mesma URL sejam permitidas
DO $$ 
BEGIN
  -- Remove constraint UNIQUE em (user_id, url) se existir
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname LIKE '%saved_tabs%url%' 
    AND contype = 'u'
  ) THEN
    ALTER TABLE saved_tabs DROP CONSTRAINT IF EXISTS saved_tabs_user_id_url_key;
  END IF;
END $$;

-- 3. Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_saved_tabs_user_id ON saved_tabs(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_tabs_order ON saved_tabs(user_id, tab_order);

-- 4. Habilitar Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_tabs ENABLE ROW LEVEL SECURITY;

-- 5. Criar políticas RLS para profiles
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- 6. Criar políticas RLS para saved_tabs
-- NOTA: As políticas permitem múltiplas abas com a mesma URL
-- Não há restrição que impeça URLs duplicadas para o mesmo usuário
CREATE POLICY "Users can view their own saved tabs"
  ON saved_tabs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own saved tabs"
  ON saved_tabs FOR INSERT
  WITH CHECK (auth.uid() = user_id);
  -- Permite inserir múltiplas abas com a mesma URL

CREATE POLICY "Users can update their own saved tabs"
  ON saved_tabs FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
  -- Permite atualizar abas mesmo que outras tenham a mesma URL

CREATE POLICY "Users can delete their own saved tabs"
  ON saved_tabs FOR DELETE
  USING (auth.uid() = user_id);

-- 7. Criar função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Criar triggers para atualizar updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_saved_tabs_updated_at
  BEFORE UPDATE ON saved_tabs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 9. Criar bucket de storage para ícones (execute no Supabase Dashboard > Storage)
-- Nome do bucket: tab-icons
-- Público: Não (privado)
-- Política de acesso: Usuários autenticados podem fazer upload/download de seus próprios arquivos


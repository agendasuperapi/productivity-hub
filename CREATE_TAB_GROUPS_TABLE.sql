-- Script SQL para criar a tabela de grupos de abas no Supabase

-- 1. Criar tabela de grupos de abas
CREATE TABLE IF NOT EXISTS tab_groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  group_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Adicionar coluna group_id na tabela saved_tabs (se não existir)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'saved_tabs' AND column_name = 'group_id'
  ) THEN
    ALTER TABLE saved_tabs ADD COLUMN group_id UUID REFERENCES tab_groups(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 3. Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_tab_groups_user_id ON tab_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_tab_groups_order ON tab_groups(user_id, group_order);
CREATE INDEX IF NOT EXISTS idx_saved_tabs_group_id ON saved_tabs(group_id);

-- 4. Habilitar Row Level Security (RLS)
ALTER TABLE tab_groups ENABLE ROW LEVEL SECURITY;

-- 5. Criar políticas RLS para tab_groups
CREATE POLICY "Users can view their own tab groups"
  ON tab_groups FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tab groups"
  ON tab_groups FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tab groups"
  ON tab_groups FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tab groups"
  ON tab_groups FOR DELETE
  USING (auth.uid() = user_id);

-- 6. Função para criar grupo padrão automaticamente para novos usuários
CREATE OR REPLACE FUNCTION create_default_tab_group()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO tab_groups (user_id, name, group_order, created_at, updated_at)
  VALUES (NEW.id, 'Geral', 0, NOW(), NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Trigger para criar grupo padrão quando um novo usuário é criado
DROP TRIGGER IF EXISTS on_auth_user_created_create_default_group ON auth.users;
CREATE TRIGGER on_auth_user_created_create_default_group
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_default_tab_group();

-- 8. Criar grupos padrão para usuários existentes que não têm grupos
INSERT INTO tab_groups (user_id, name, group_order, created_at, updated_at)
SELECT 
  id as user_id,
  'Geral' as name,
  0 as group_order,
  NOW() as created_at,
  NOW() as updated_at
FROM auth.users
WHERE id NOT IN (SELECT DISTINCT user_id FROM tab_groups)
ON CONFLICT DO NOTHING;


-- Tabela para palavras-chave customizáveis
CREATE TABLE IF NOT EXISTS keywords (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(user_id, key)
);

-- Índice para busca rápida por usuário
CREATE INDEX IF NOT EXISTS idx_keywords_user_id ON keywords(user_id);

-- Índice para busca rápida por chave
CREATE INDEX IF NOT EXISTS idx_keywords_key ON keywords(key);

-- RLS (Row Level Security)
ALTER TABLE keywords ENABLE ROW LEVEL SECURITY;

-- Política: usuários só podem ver suas próprias palavras-chave
CREATE POLICY "Users can view their own keywords"
  ON keywords FOR SELECT
  USING (auth.uid() = user_id);

-- Política: usuários só podem inserir suas próprias palavras-chave
CREATE POLICY "Users can insert their own keywords"
  ON keywords FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Política: usuários só podem atualizar suas próprias palavras-chave
CREATE POLICY "Users can update their own keywords"
  ON keywords FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Política: usuários só podem deletar suas próprias palavras-chave
CREATE POLICY "Users can delete their own keywords"
  ON keywords FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_keywords_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_keywords_updated_at_trigger
  BEFORE UPDATE ON keywords
  FOR EACH ROW
  EXECUTE FUNCTION update_keywords_updated_at();


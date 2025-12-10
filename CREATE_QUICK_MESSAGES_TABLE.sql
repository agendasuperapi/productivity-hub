-- Tabela para mensagens rápidas
CREATE TABLE IF NOT EXISTS quick_messages (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  shortcut TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE,
  CONSTRAINT unique_user_shortcut UNIQUE (user_id, shortcut)
);

-- Índice para busca rápida por atalho
CREATE INDEX IF NOT EXISTS idx_quick_messages_user_shortcut 
ON quick_messages(user_id, shortcut);

-- Índice para ordenação por data de criação
CREATE INDEX IF NOT EXISTS idx_quick_messages_user_created 
ON quick_messages(user_id, created_at DESC);

-- RLS (Row Level Security)
ALTER TABLE quick_messages ENABLE ROW LEVEL SECURITY;

-- Política: usuários só podem ver suas próprias mensagens
CREATE POLICY "Users can view their own quick messages"
  ON quick_messages FOR SELECT
  USING (auth.uid() = user_id);

-- Política: usuários só podem inserir suas próprias mensagens
CREATE POLICY "Users can insert their own quick messages"
  ON quick_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Política: usuários só podem atualizar suas próprias mensagens
CREATE POLICY "Users can update their own quick messages"
  ON quick_messages FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Política: usuários só podem deletar suas próprias mensagens
CREATE POLICY "Users can delete their own quick messages"
  ON quick_messages FOR DELETE
  USING (auth.uid() = user_id);




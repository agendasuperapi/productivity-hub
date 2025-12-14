-- Adiciona coluna usage_count na tabela quick_messages
-- Execute este script no Supabase SQL Editor

ALTER TABLE quick_messages 
ADD COLUMN IF NOT EXISTS usage_count INTEGER DEFAULT 0 NOT NULL;

-- Cria índice para ordenação por uso
CREATE INDEX IF NOT EXISTS idx_quick_messages_usage_count 
ON quick_messages(user_id, usage_count DESC);

-- Comentário na coluna
COMMENT ON COLUMN quick_messages.usage_count IS 'Contador de quantas vezes a mensagem foi usada';



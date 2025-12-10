-- Adiciona campo enable_quick_messages na tabela saved_tabs
-- Este campo controla se a aba deve usar atalhos rápidos ou não

-- Adiciona a coluna se não existir
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'saved_tabs' 
    AND column_name = 'enable_quick_messages'
  ) THEN
    ALTER TABLE saved_tabs 
    ADD COLUMN enable_quick_messages BOOLEAN DEFAULT true NOT NULL;
    
    -- Cria índice para busca rápida
    CREATE INDEX IF NOT EXISTS idx_saved_tabs_enable_quick_messages 
    ON saved_tabs(user_id, enable_quick_messages);
    
    RAISE NOTICE 'Coluna enable_quick_messages adicionada com sucesso';
  ELSE
    RAISE NOTICE 'Coluna enable_quick_messages já existe';
  END IF;
END $$;


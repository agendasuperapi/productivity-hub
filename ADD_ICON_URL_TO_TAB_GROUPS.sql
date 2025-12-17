-- Script SQL para adicionar coluna icon_url na tabela tab_groups

-- Adicionar coluna icon_url (se não existir)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tab_groups' AND column_name = 'icon_url'
  ) THEN
    ALTER TABLE tab_groups ADD COLUMN icon_url TEXT;
  END IF;
END $$;


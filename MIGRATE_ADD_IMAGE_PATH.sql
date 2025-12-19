-- Script de migração para adicionar campo image_path à tabela quick_messages
-- Execute este script se a tabela já existe e você quer adicionar o campo image_path

-- Adiciona a coluna image_path se ela não existir
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'quick_messages' 
        AND column_name = 'image_path'
    ) THEN
        ALTER TABLE quick_messages ADD COLUMN image_path TEXT;
        RAISE NOTICE 'Coluna image_path adicionada com sucesso';
    ELSE
        RAISE NOTICE 'Coluna image_path já existe';
    END IF;
END $$;


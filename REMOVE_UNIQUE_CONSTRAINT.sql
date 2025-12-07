-- Script para remover constraints UNIQUE que possam impedir múltiplas URLs iguais
-- Execute este script no SQL Editor do Supabase se você encontrar erros de URL duplicada

-- Remove qualquer constraint UNIQUE relacionada à URL na tabela saved_tabs
DO $$ 
DECLARE
  constraint_name text;
BEGIN
  -- Procura e remove constraints UNIQUE que envolvem user_id e url
  FOR constraint_name IN 
    SELECT conname 
    FROM pg_constraint 
    WHERE conrelid = 'saved_tabs'::regclass 
    AND contype = 'u'
    AND (conname LIKE '%url%' OR conname LIKE '%user_id%')
  LOOP
    EXECUTE 'ALTER TABLE saved_tabs DROP CONSTRAINT IF EXISTS ' || constraint_name;
    RAISE NOTICE 'Removida constraint: %', constraint_name;
  END LOOP;
END $$;

-- Verifica se ainda existem constraints UNIQUE
SELECT 
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'saved_tabs'::regclass
AND contype = 'u';

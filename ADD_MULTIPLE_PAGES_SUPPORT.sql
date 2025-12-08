-- Script para adicionar suporte a múltiplas páginas nas abas salvas
-- Execute este script no Supabase SQL Editor

-- Adiciona coluna para armazenar múltiplas URLs (JSON array)
ALTER TABLE saved_tabs 
ADD COLUMN IF NOT EXISTS urls JSONB;

-- Adiciona coluna para número de colunas no layout
ALTER TABLE saved_tabs 
ADD COLUMN IF NOT EXISTS columns INTEGER;

-- Adiciona coluna para número de linhas no layout
ALTER TABLE saved_tabs 
ADD COLUMN IF NOT EXISTS rows INTEGER;

-- Adiciona coluna para indicar se deve abrir como janela
ALTER TABLE saved_tabs 
ADD COLUMN IF NOT EXISTS open_as_window BOOLEAN DEFAULT FALSE;

-- Comentários para documentação
COMMENT ON COLUMN saved_tabs.urls IS 'Array de URLs para múltiplas páginas (formato JSON)';
COMMENT ON COLUMN saved_tabs.columns IS 'Número de colunas no layout de exibição';
COMMENT ON COLUMN saved_tabs.rows IS 'Número de linhas no layout de exibição';
COMMENT ON COLUMN saved_tabs.open_as_window IS 'Se true, abre a aba em uma nova janela do navegador ao invés de carregar nas abas';

-- Índice para melhorar performance em consultas que filtram por múltiplas URLs
CREATE INDEX IF NOT EXISTS idx_saved_tabs_urls ON saved_tabs USING GIN (urls);


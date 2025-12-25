-- Adicionar colunas para salvar posição e tamanho da janela
ALTER TABLE public.tabs 
ADD COLUMN IF NOT EXISTS window_x integer DEFAULT NULL,
ADD COLUMN IF NOT EXISTS window_y integer DEFAULT NULL,
ADD COLUMN IF NOT EXISTS window_width integer DEFAULT 1200,
ADD COLUMN IF NOT EXISTS window_height integer DEFAULT 800;
-- Adicionar coluna para armazenar múltiplas URLs como JSONB
-- Formato: [{ "url": "https://...", "shortcut_enabled": true }]
ALTER TABLE public.tabs ADD COLUMN IF NOT EXISTS urls jsonb DEFAULT '[]'::jsonb;

-- Adicionar coluna para o tipo de layout (quando há múltiplas URLs)
-- Valores: 'single', '2x1', '1x2', '2x2', '3x1', etc
ALTER TABLE public.tabs ADD COLUMN IF NOT EXISTS layout_type text DEFAULT 'single';

-- Migrar dados existentes: copiar a URL atual para o array de URLs
UPDATE public.tabs 
SET urls = jsonb_build_array(
  jsonb_build_object(
    'url', url,
    'shortcut_enabled', true
  )
)
WHERE urls = '[]'::jsonb AND url IS NOT NULL AND url != '';

-- Adicionar comentários para documentação
COMMENT ON COLUMN public.tabs.urls IS 'Array de URLs para abrir em layout split. Formato: [{url: string, shortcut_enabled: boolean}]';
COMMENT ON COLUMN public.tabs.layout_type IS 'Tipo de layout: single, 2x1, 1x2, 2x2, 3x1, 1x3';
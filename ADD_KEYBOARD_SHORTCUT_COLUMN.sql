-- Adiciona coluna keyboard_shortcut na tabela saved_tabs
-- Permite cadastrar atalhos de teclado para abrir abas/janelas rapidamente

ALTER TABLE saved_tabs
ADD COLUMN IF NOT EXISTS keyboard_shortcut TEXT;

-- Comentário na coluna
COMMENT ON COLUMN saved_tabs.keyboard_shortcut IS 'Atalho de teclado para abrir a aba (ex: Ctrl+M, F3, Ctrl+H). Não pode ser um atalho padrão do sistema.';


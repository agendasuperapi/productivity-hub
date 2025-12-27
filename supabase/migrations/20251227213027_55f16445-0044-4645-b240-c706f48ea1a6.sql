-- Criar bucket público para releases
INSERT INTO storage.buckets (id, name, public)
VALUES ('releases', 'releases', true)
ON CONFLICT (id) DO NOTHING;

-- Policy: Qualquer um pode ler (público)
CREATE POLICY "Releases são públicas para leitura" ON storage.objects
FOR SELECT USING (bucket_id = 'releases');

-- Policy: Service role pode inserir releases (via edge function)
CREATE POLICY "Service role pode inserir releases" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'releases');

-- Policy: Service role pode deletar releases antigas
CREATE POLICY "Service role pode deletar releases" ON storage.objects
FOR DELETE USING (bucket_id = 'releases');

-- Adicionar colunas de URL na tabela app_versions
ALTER TABLE public.app_versions
ADD COLUMN IF NOT EXISTS windows_url text,
ADD COLUMN IF NOT EXISTS macos_url text,
ADD COLUMN IF NOT EXISTS apk_url text;
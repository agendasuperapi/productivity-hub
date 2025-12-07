-- Políticas de Storage para o bucket tab-icons (CORRIGIDAS)
-- Execute este script no SQL Editor do Supabase após criar o bucket

-- IMPORTANTE: Certifique-se de que o bucket 'tab-icons' foi criado como PRIVADO
-- No Supabase Dashboard: Storage > New bucket > Nome: tab-icons > Público: NÃO

-- Remove políticas antigas se existirem (opcional, pode dar erro se não existirem)
DROP POLICY IF EXISTS "Users can upload their own icons" ON storage.objects;
DROP POLICY IF EXISTS "Users can download their own icons" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own icons" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own icons" ON storage.objects;

-- 1. Política de Upload (INSERT) - Permite upload apenas na pasta do próprio usuário
CREATE POLICY "Users can upload their own icons"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'tab-icons' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 2. Política de Download (SELECT) - Permite visualizar apenas seus próprios ícones
CREATE POLICY "Users can download their own icons"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'tab-icons' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. Política de Delete - Permite deletar apenas seus próprios ícones
CREATE POLICY "Users can delete their own icons"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'tab-icons' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 4. Política de Update - Permite atualizar apenas seus próprios ícones
CREATE POLICY "Users can update their own icons"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'tab-icons' AND
  (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'tab-icons' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Verifica se as políticas foram criadas corretamente
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'objects' AND schemaname = 'storage'
AND policyname LIKE '%icons%';


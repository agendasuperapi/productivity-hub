-- Políticas de Storage para o bucket tab-icons
-- Execute este script no SQL Editor do Supabase após criar o bucket

-- 1. Política de Upload (INSERT)
CREATE POLICY "Users can upload their own icons"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'tab-icons' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 2. Política de Download (SELECT)
CREATE POLICY "Users can download their own icons"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'tab-icons' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 3. Política de Delete
CREATE POLICY "Users can delete their own icons"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'tab-icons' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 4. Política de Update (opcional)
CREATE POLICY "Users can update their own icons"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'tab-icons' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'tab-icons' AND
  auth.uid()::text = (storage.foldername(name))[1]
);


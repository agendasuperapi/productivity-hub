-- Políticas de Storage para o bucket "avatars"
-- IMPORTANTE: Execute este script APÓS criar o bucket "avatars" no Supabase Dashboard
-- O bucket deve ser criado como "Public bucket" para permitir leitura pública

-- Remove políticas existentes antes de criar novas (evita erros se já existirem)
DROP POLICY IF EXISTS "Users can upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatars" ON storage.objects;
DROP POLICY IF EXISTS "Public avatars are readable" ON storage.objects;

-- 1. Política para permitir que usuários autenticados façam upload de avatares
-- Esta política permite que qualquer usuário autenticado faça upload de arquivos no bucket avatars
-- O nome do arquivo deve começar com o user_id do usuário (ex: user_id_timestamp.jpg)
CREATE POLICY "Users can upload avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' 
  AND split_part(name, '_', 1) = auth.uid()::text
);

-- 2. Política para permitir que usuários autenticados atualizem seus próprios avatares
-- Permite atualizar apenas arquivos que começam com o próprio user_id
CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars' 
  AND split_part(name, '_', 1) = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars' 
  AND split_part(name, '_', 1) = auth.uid()::text
);

-- 3. Política para permitir que usuários autenticados deletem seus próprios avatares
CREATE POLICY "Users can delete their own avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars' 
  AND split_part(name, '_', 1) = auth.uid()::text
);

-- 4. Política para permitir leitura pública dos avatares
-- Esta política permite que qualquer pessoa (autenticada ou não) leia os arquivos do bucket avatars
CREATE POLICY "Public avatars are readable"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');


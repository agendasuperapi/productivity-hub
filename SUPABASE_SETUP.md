# Configuração do Supabase

## Passos para configurar o Supabase

### 1. Criar projeto no Supabase

1. Acesse [https://supabase.com](https://supabase.com)
2. Crie uma conta ou faça login
3. Crie um novo projeto
4. Anote a URL do projeto e a chave anônima (anon key)

### 2. Configurar o banco de dados

1. No Supabase Dashboard, vá em **SQL Editor**
2. Execute o script `supabase_setup.sql` que está na raiz do projeto
3. Isso criará as tabelas necessárias e as políticas de segurança

### 3. Configurar Storage para ícones

1. No Supabase Dashboard, vá em **Storage**
2. Clique em **New bucket**
3. Nome: `tab-icons`
4. Público: **Não** (privado)
5. Clique em **Create bucket**

#### Configurar políticas de Storage:

No **Storage** > **Policies** do bucket `tab-icons`, adicione as seguintes políticas:

**1. Habilitar RLS no bucket:**
```sql
-- Certifique-se de que o bucket existe e tem RLS habilitado
-- Isso é feito automaticamente ao criar o bucket como privado
```

**2. Política de Upload (INSERT):**
```sql
CREATE POLICY "Users can upload their own icons"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'tab-icons' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

**3. Política de Download (SELECT):**
```sql
CREATE POLICY "Users can download their own icons"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'tab-icons' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

**4. Política de Delete:**
```sql
CREATE POLICY "Users can delete their own icons"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'tab-icons' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

**5. Política de Update (caso necessário):**
```sql
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
```

**IMPORTANTE:** 
- O bucket `tab-icons` deve ser criado como **PRIVADO** (não público)
- As políticas devem ser criadas no SQL Editor do Supabase
- O caminho dos arquivos deve seguir o padrão: `tab-icons/{user_id}/{filename}`

### 4. Configurar credenciais no aplicativo

1. Abra `lib/main.dart`
2. Substitua `YOUR_SUPABASE_URL` pela URL do seu projeto
3. Substitua `YOUR_SUPABASE_ANON_KEY` pela chave anônima do seu projeto

```dart
await Supabase.initialize(
  url: 'https://seu-projeto.supabase.co',
  anonKey: 'sua-chave-anon-aqui',
);
```

### 5. Estrutura das tabelas

#### Tabela `profiles`
- `id` (UUID, PK): ID do usuário (referência a auth.users)
- `name` (TEXT): Nome do usuário
- `created_at` (TIMESTAMP): Data de criação
- `updated_at` (TIMESTAMP): Data de atualização

#### Tabela `saved_tabs`
- `id` (UUID, PK): ID da aba salva
- `user_id` (UUID, FK): ID do usuário
- `name` (TEXT): Nome da aba
- `url` (TEXT): URL da aba
- `icon_url` (TEXT, nullable): URL do ícone no storage
- `order` (INTEGER): Ordem da aba
- `created_at` (TIMESTAMP): Data de criação
- `updated_at` (TIMESTAMP): Data de atualização

### 6. Testar

1. Execute o aplicativo
2. Crie uma conta
3. Faça login
4. Tente salvar uma aba como favorito
5. Verifique no Supabase Dashboard se os dados foram salvos


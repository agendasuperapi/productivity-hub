-- Enum para roles
CREATE TYPE public.app_role AS ENUM ('super_admin', 'admin', 'user');

-- Tabela de roles
CREATE TABLE public.user_roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role app_role NOT NULL DEFAULT 'user',
    created_at timestamp with time zone DEFAULT now(),
    UNIQUE (user_id, role)
);

-- Enable RLS
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Função segura para verificar role (evita recursão)
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  )
$$;

-- Políticas RLS para user_roles
CREATE POLICY "Users can view their own role"
ON public.user_roles
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all roles"
ON public.user_roles
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Super admins can manage roles"
ON public.user_roles
FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'))
WITH CHECK (public.has_role(auth.uid(), 'super_admin'));

-- Inserir super admin inicial
INSERT INTO public.user_roles (user_id, role) 
VALUES ('8c82c892-3265-4fc2-a6f4-304c857f96ab', 'super_admin');

-- Tabela de versões do app
CREATE TABLE public.app_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version text NOT NULL UNIQUE,
    description text NOT NULL,
    changes jsonb NOT NULL DEFAULT '[]',
    status text NOT NULL DEFAULT 'pending',
    created_by uuid REFERENCES auth.users(id) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    deploy_started_at timestamp with time zone,
    deploy_completed_at timestamp with time zone,
    workflow_run_id text
);

-- Enable RLS
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Políticas para app_versions (apenas admins podem gerenciar)
CREATE POLICY "Admins can view all versions"
ON public.app_versions
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can insert versions"
ON public.app_versions
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update versions"
ON public.app_versions
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Super admins can delete versions"
ON public.app_versions
FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'));

-- Enable realtime para app_versions
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_versions;
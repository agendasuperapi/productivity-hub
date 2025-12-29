-- Create table for blocked credential domains
CREATE TABLE public.blocked_credential_domains (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  domain TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, domain)
);

-- Enable Row Level Security
ALTER TABLE public.blocked_credential_domains ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own blocked domains"
ON public.blocked_credential_domains
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own blocked domains"
ON public.blocked_credential_domains
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own blocked domains"
ON public.blocked_credential_domains
FOR DELETE
USING (auth.uid() = user_id);
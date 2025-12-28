-- Create table for storing encrypted credentials
CREATE TABLE public.saved_credentials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  domain TEXT NOT NULL,
  site_name TEXT,
  username TEXT NOT NULL,
  encrypted_password TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, domain, username)
);

-- Enable RLS
ALTER TABLE public.saved_credentials ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own credentials"
ON public.saved_credentials
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own credentials"
ON public.saved_credentials
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own credentials"
ON public.saved_credentials
FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own credentials"
ON public.saved_credentials
FOR DELETE
USING (auth.uid() = user_id);

-- Trigger for updated_at
CREATE TRIGGER update_saved_credentials_updated_at
BEFORE UPDATE ON public.saved_credentials
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();
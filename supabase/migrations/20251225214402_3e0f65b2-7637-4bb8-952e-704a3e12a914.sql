-- Create clipboard_domains table
CREATE TABLE public.clipboard_domains (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  domain TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.clipboard_domains ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own clipboard domains" 
ON public.clipboard_domains 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own clipboard domains" 
ON public.clipboard_domains 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own clipboard domains" 
ON public.clipboard_domains 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create unique constraint to prevent duplicates
CREATE UNIQUE INDEX clipboard_domains_user_domain_unique 
ON public.clipboard_domains (user_id, domain);
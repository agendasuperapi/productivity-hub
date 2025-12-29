-- Create captured_tokens table
CREATE TABLE public.captured_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  tab_id UUID NOT NULL REFERENCES public.tabs(id) ON DELETE CASCADE,
  domain TEXT NOT NULL,
  token_name TEXT NOT NULL DEFAULT 'X-Access-Token',
  token_value TEXT NOT NULL,
  captured_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.captured_tokens ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view own tokens" ON public.captured_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tokens" ON public.captured_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tokens" ON public.captured_tokens
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own tokens" ON public.captured_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX idx_captured_tokens_user_tab ON public.captured_tokens(user_id, tab_id);
CREATE UNIQUE INDEX idx_captured_tokens_unique ON public.captured_tokens(user_id, tab_id, domain);

-- Add capture_token columns to tabs table
ALTER TABLE public.tabs ADD COLUMN capture_token BOOLEAN DEFAULT false;
ALTER TABLE public.tabs ADD COLUMN capture_token_header TEXT DEFAULT 'X-Access-Token';

-- Trigger for updated_at
CREATE TRIGGER update_captured_tokens_updated_at
  BEFORE UPDATE ON public.captured_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
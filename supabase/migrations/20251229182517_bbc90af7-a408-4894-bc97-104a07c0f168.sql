-- Add webhook_url column to tabs table for automatic token forwarding
ALTER TABLE public.tabs 
ADD COLUMN webhook_url TEXT DEFAULT NULL;

-- Add comment explaining the column
COMMENT ON COLUMN public.tabs.webhook_url IS 'URL to send captured tokens via POST webhook';
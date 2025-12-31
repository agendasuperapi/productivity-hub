-- Add session_group column to tabs table for shared session/cookies
ALTER TABLE public.tabs ADD COLUMN session_group TEXT DEFAULT NULL;

-- Add comment explaining the column
COMMENT ON COLUMN public.tabs.session_group IS 'Tabs with the same session_group share cookies and login sessions';
-- Add column to store panel sizes
ALTER TABLE public.tabs 
ADD COLUMN panel_sizes jsonb DEFAULT NULL;

-- Comment for documentation
COMMENT ON COLUMN public.tabs.panel_sizes IS 'Stores the sizes of resizable panels as an array of percentages';
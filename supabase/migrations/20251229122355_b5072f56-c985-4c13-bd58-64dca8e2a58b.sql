-- Add column to store if link transform panel should be shown
ALTER TABLE public.tabs 
ADD COLUMN show_link_transform_panel boolean DEFAULT true;
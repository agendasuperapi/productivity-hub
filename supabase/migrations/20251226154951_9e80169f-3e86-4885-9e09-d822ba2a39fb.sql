-- Add auto_send column to text_shortcuts table
ALTER TABLE public.text_shortcuts 
ADD COLUMN auto_send BOOLEAN DEFAULT false;
-- Create table for storing form field values per domain
CREATE TABLE public.form_field_values (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  domain TEXT NOT NULL,
  field_identifier TEXT NOT NULL,
  field_label TEXT,
  field_value TEXT NOT NULL,
  use_count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, domain, field_identifier, field_value)
);

-- Enable Row Level Security
ALTER TABLE public.form_field_values ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own form field values" 
ON public.form_field_values 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own form field values" 
ON public.form_field_values 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own form field values" 
ON public.form_field_values 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own form field values" 
ON public.form_field_values 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create trigger for automatic timestamp updates
CREATE TRIGGER update_form_field_values_updated_at
BEFORE UPDATE ON public.form_field_values
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();
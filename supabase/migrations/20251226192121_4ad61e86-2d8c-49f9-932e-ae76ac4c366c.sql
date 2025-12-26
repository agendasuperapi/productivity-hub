-- Add messages column to store array of messages with individual auto_send
ALTER TABLE text_shortcuts 
ADD COLUMN IF NOT EXISTS messages JSONB DEFAULT '[]'::jsonb;

-- Migrate existing data to the new format
UPDATE text_shortcuts 
SET messages = jsonb_build_array(
  jsonb_build_object(
    'text', expanded_text, 
    'auto_send', COALESCE(auto_send, false)
  )
)
WHERE (messages = '[]'::jsonb OR messages IS NULL) AND expanded_text IS NOT NULL AND expanded_text != '';
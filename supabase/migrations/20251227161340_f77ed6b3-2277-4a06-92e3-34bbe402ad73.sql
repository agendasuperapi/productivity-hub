-- Add settings JSONB column to profiles table for user preferences
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS settings JSONB DEFAULT '{
  "browser": {
    "auto_restore_session": true,
    "save_window_positions": true,
    "confirm_on_close": true
  },
  "shortcuts": {
    "prefix": "/"
  },
  "notifications": {
    "sound_enabled": false,
    "toast_position": "bottom-right"
  },
  "interface": {
    "density": "normal",
    "animations_enabled": true,
    "sidebar_collapsed": false
  }
}'::jsonb;
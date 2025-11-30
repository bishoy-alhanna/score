-- Add global filter settings to organizations table
ALTER TABLE organizations 
ADD COLUMN IF NOT EXISTS filter_start_date DATE,
ADD COLUMN IF NOT EXISTS filter_end_date DATE,
ADD COLUMN IF NOT EXISTS filter_enabled BOOLEAN DEFAULT FALSE;

-- Update existing organizations to have filter_enabled = FALSE
UPDATE organizations SET filter_enabled = FALSE WHERE filter_enabled IS NULL;

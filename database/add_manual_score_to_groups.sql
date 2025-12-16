-- Migration: Add manual_score field to groups table
-- This allows admins to manually set a score for a group
-- The total group score will be: manual_score + sum of all member scores

-- Add manual_score column to groups table
ALTER TABLE groups ADD COLUMN IF NOT EXISTS manual_score INTEGER DEFAULT 0;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_groups_manual_score ON groups(manual_score);

-- Add comment to document the field
COMMENT ON COLUMN groups.manual_score IS 'Manually assigned score for the group by admins. Total group score = manual_score + sum of member scores';

-- Verify the change
\echo 'Manual score field added to groups table'
\echo 'Verifying groups table structure:'
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'groups' 
AND column_name = 'manual_score';

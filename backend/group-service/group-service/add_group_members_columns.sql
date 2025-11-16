-- Add missing columns to group_members table
-- This ensures each organization has its own groups and members have roles

-- Add organization_id column
ALTER TABLE group_members 
ADD COLUMN IF NOT EXISTS organization_id UUID;

-- Add role column (MEMBER, ADMIN, MODERATOR)
ALTER TABLE group_members 
ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'MEMBER';

-- Add foreign key constraint for organization_id
ALTER TABLE group_members 
ADD CONSTRAINT group_members_organization_id_fkey 
FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_group_members_organization ON group_members(organization_id);
CREATE INDEX IF NOT EXISTS idx_group_members_role ON group_members(role);

-- Update existing records to have organization_id from their group
UPDATE group_members gm
SET organization_id = g.organization_id
FROM groups g
WHERE gm.group_id = g.id
AND gm.organization_id IS NULL;

-- Make organization_id NOT NULL after populating existing data
ALTER TABLE group_members 
ALTER COLUMN organization_id SET NOT NULL;

-- Add comment to document the schema
COMMENT ON COLUMN group_members.organization_id IS 'Organization that this group membership belongs to (for multi-tenancy)';
COMMENT ON COLUMN group_members.role IS 'Member role in the group: MEMBER, ADMIN, or MODERATOR';

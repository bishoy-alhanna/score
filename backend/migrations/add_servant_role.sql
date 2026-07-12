-- Migration: Add SERVANT role and servant-group assignment
-- Description: This migration adds the SERVANT role functionality
-- allowing servants to be assigned to groups and manage scores

-- Create servant_group_assignments table
CREATE TABLE IF NOT EXISTS servant_group_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    servant_user_id UUID NOT NULL,
    group_id UUID NOT NULL,
    organization_id UUID NOT NULL,
    assigned_by_user_id UUID,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys
    CONSTRAINT fk_servant_user FOREIGN KEY (servant_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_group FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    CONSTRAINT fk_organization FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    CONSTRAINT fk_assigned_by FOREIGN KEY (assigned_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    
    -- Unique constraint: one assignment per servant-group pair
    CONSTRAINT unique_servant_per_group UNIQUE (servant_user_id, group_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_servant_user ON servant_group_assignments(servant_user_id);
CREATE INDEX IF NOT EXISTS idx_group ON servant_group_assignments(group_id);
CREATE INDEX IF NOT EXISTS idx_organization ON servant_group_assignments(organization_id);
CREATE INDEX IF NOT EXISTS idx_is_active ON servant_group_assignments(is_active);

-- Add SERVANT role to existing role checks (if they exist in constraints)
-- Note: The role column is VARCHAR, so no constraint changes needed

-- Optional: Add a view for easy servant group lookups
CREATE OR REPLACE VIEW servant_groups_view AS
SELECT 
    sga.id as assignment_id,
    sga.servant_user_id,
    u.username as servant_username,
    u.email as servant_email,
    sga.group_id,
    g.name as group_name,
    g.description as group_description,
    sga.organization_id,
    o.name as organization_name,
    sga.assigned_by_user_id,
    admin_u.username as assigned_by_username,
    sga.is_active,
    sga.created_at,
    sga.updated_at,
    (SELECT COUNT(*) FROM group_members WHERE group_id = sga.group_id AND is_active = TRUE) as member_count
FROM 
    servant_group_assignments sga
    JOIN users u ON sga.servant_user_id = u.id
    JOIN groups g ON sga.group_id = g.id
    JOIN organizations o ON sga.organization_id = o.id
    LEFT JOIN users admin_u ON sga.assigned_by_user_id = admin_u.id
WHERE 
    sga.is_active = TRUE;

-- Insert some comments for documentation
COMMENT ON TABLE servant_group_assignments IS 'Assigns servant users to groups they are responsible for managing';
COMMENT ON COLUMN servant_group_assignments.servant_user_id IS 'User with SERVANT role assigned to manage this group';
COMMENT ON COLUMN servant_group_assignments.group_id IS 'Group that this servant is responsible for';
COMMENT ON COLUMN servant_group_assignments.assigned_by_user_id IS 'ORG_ADMIN who assigned this servant to the group';

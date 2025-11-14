-- Migration: Fix Schema to Match Multi-Org Architecture
-- This migration updates the existing database to support multi-organization structure

BEGIN;

-- Step 1: Create organizations table if it doesn't exist
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Step 2: Insert default organization if it doesn't exist
INSERT INTO organizations (id, name, description)
VALUES ('11111111-1111-1111-1111-111111111111', 'Default Organization', 'Default organization for existing users')
ON CONFLICT (id) DO NOTHING;

-- Step 3: Add organization_id to users table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'organization_id'
    ) THEN
        ALTER TABLE users ADD COLUMN organization_id UUID;
    END IF;
END $$;

-- Step 4: Update existing users to belong to default organization
UPDATE users 
SET organization_id = '11111111-1111-1111-1111-111111111111'
WHERE organization_id IS NULL;

-- Step 5: Make organization_id NOT NULL and add foreign key
ALTER TABLE users 
    ALTER COLUMN organization_id SET NOT NULL,
    DROP CONSTRAINT IF EXISTS users_organization_id_fkey,
    ADD CONSTRAINT users_organization_id_fkey 
        FOREIGN KEY (organization_id) 
        REFERENCES organizations(id) 
        ON DELETE CASCADE;

-- Step 6: Add role column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'role'
    ) THEN
        ALTER TABLE users ADD COLUMN role VARCHAR(50) DEFAULT 'user';
    END IF;
END $$;

-- Step 7: Create user_organizations junction table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_organizations (
    user_id UUID NOT NULL,
    organization_id UUID NOT NULL,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, organization_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
);

-- Step 8: Populate user_organizations from existing users
INSERT INTO user_organizations (user_id, organization_id, role)
SELECT id, organization_id, role
FROM users
ON CONFLICT (user_id, organization_id) DO NOTHING;

-- Step 9: Create groups table if it doesn't exist
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by UUID,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE (organization_id, name)
);

-- Step 10: Create group_members table if it doesn't exist
CREATE TABLE IF NOT EXISTS group_members (
    group_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Step 11: Create score_categories table if it doesn't exist
CREATE TABLE IF NOT EXISTS score_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    max_value INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    UNIQUE (organization_id, name)
);

-- Step 12: Insert default score categories if they don't exist
INSERT INTO score_categories (organization_id, name, description, max_value)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Attendance', 'Points for attendance', 100),
    ('11111111-1111-1111-1111-111111111111', 'Participation', 'Points for class participation', 100),
    ('11111111-1111-1111-1111-111111111111', 'Leadership', 'Points for leadership activities', 100),
    ('11111111-1111-1111-1111-111111111111', 'Academic', 'Points for academic achievements', 100),
    ('11111111-1111-1111-1111-111111111111', 'Community Service', 'Points for community service', 100)
ON CONFLICT (organization_id, name) DO NOTHING;

-- Step 13: Create scores table if it doesn't exist
CREATE TABLE IF NOT EXISTS scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    category_id UUID NOT NULL,
    value INTEGER NOT NULL DEFAULT 0,
    awarded_by UUID,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES score_categories(id) ON DELETE CASCADE,
    FOREIGN KEY (awarded_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Step 14: Create score_history table if it doesn't exist
CREATE TABLE IF NOT EXISTS score_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    category_id UUID NOT NULL,
    old_value INTEGER NOT NULL,
    new_value INTEGER NOT NULL,
    change_value INTEGER NOT NULL,
    changed_by UUID,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES score_categories(id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Step 15: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_organization_id ON users(organization_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_user_organizations_user_id ON user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_organization_id ON user_organizations(organization_id);
CREATE INDEX IF NOT EXISTS idx_groups_organization_id ON groups(organization_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_user_id ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_category_id ON scores(category_id);
CREATE INDEX IF NOT EXISTS idx_score_categories_organization_id ON score_categories(organization_id);

-- Step 16: Create or replace trigger function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Step 17: Create triggers for updated_at on all tables
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_organizations_updated_at ON organizations;
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_groups_updated_at ON groups;
CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_score_categories_updated_at ON score_categories;
CREATE TRIGGER update_score_categories_updated_at BEFORE UPDATE ON score_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_scores_updated_at ON scores;
CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON scores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 18: Create views for common queries
CREATE OR REPLACE VIEW user_total_scores AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    u.organization_id,
    COALESCE(SUM(s.value), 0) as total_score,
    COUNT(DISTINCT s.category_id) as categories_count
FROM users u
LEFT JOIN scores s ON u.id = s.user_id
GROUP BY u.id, u.username, u.email, u.organization_id;

CREATE OR REPLACE VIEW organization_leaderboard AS
SELECT 
    u.organization_id,
    o.name as organization_name,
    u.id as user_id,
    u.username,
    u.first_name,
    u.last_name,
    COALESCE(SUM(s.value), 0) as total_score,
    RANK() OVER (PARTITION BY u.organization_id ORDER BY COALESCE(SUM(s.value), 0) DESC) as rank
FROM users u
JOIN organizations o ON u.organization_id = o.id
LEFT JOIN scores s ON u.id = s.user_id
GROUP BY u.organization_id, o.name, u.id, u.username, u.first_name, u.last_name
ORDER BY u.organization_id, total_score DESC;

CREATE OR REPLACE VIEW category_scores AS
SELECT 
    u.id as user_id,
    u.username,
    u.organization_id,
    sc.id as category_id,
    sc.name as category_name,
    COALESCE(SUM(s.value), 0) as score
FROM users u
CROSS JOIN score_categories sc
LEFT JOIN scores s ON u.id = s.user_id AND sc.id = s.category_id
WHERE sc.organization_id = u.organization_id
GROUP BY u.id, u.username, u.organization_id, sc.id, sc.name
ORDER BY u.username, sc.name;

-- Step 19: Update admin user if exists
UPDATE users 
SET role = 'admin' 
WHERE username = 'admin' OR email = 'admin@score.com';

COMMIT;

-- Display summary
SELECT 
    'Migration completed successfully!' as status,
    COUNT(*) as total_users,
    COUNT(DISTINCT organization_id) as total_organizations
FROM users;

SELECT 
    o.name as organization,
    COUNT(u.id) as user_count
FROM organizations o
LEFT JOIN users u ON o.id = u.organization_id
GROUP BY o.id, o.name
ORDER BY user_count DESC;

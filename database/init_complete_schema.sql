-- Complete Database Schema for Score Platform
-- Multi-Organization Scoring System
-- PostgreSQL 15+

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- DROP EXISTING TABLES (for clean reinstall)
-- ============================================
-- Uncomment the following block if you want to drop and recreate all tables

-- DROP TABLE IF EXISTS score_history CASCADE;
-- DROP TABLE IF EXISTS scores CASCADE;
-- DROP TABLE IF EXISTS group_members CASCADE;
-- DROP TABLE IF EXISTS groups CASCADE;
-- DROP TABLE IF EXISTS organization_invitations CASCADE;
-- DROP TABLE IF EXISTS organization_join_requests CASCADE;
-- DROP TABLE IF EXISTS user_organizations CASCADE;
-- DROP TABLE IF EXISTS score_categories CASCADE;
-- DROP TABLE IF EXISTS users CASCADE;
-- DROP TABLE IF EXISTS organizations CASCADE;

-- ============================================
-- ORGANIZATIONS
-- ============================================

CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- USERS
-- ============================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    profile_picture_url VARCHAR(500),
    phone_number VARCHAR(50),
    date_of_birth DATE,
    gender VARCHAR(20),
    university VARCHAR(255),
    major VARCHAR(255),
    year_of_study INTEGER,
    student_id VARCHAR(100),
    bio TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================
-- USER ORGANIZATIONS (Many-to-Many)
-- ============================================

CREATE TABLE IF NOT EXISTS user_organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'USER', -- USER, ORG_ADMIN, SUPER_ADMIN
    department VARCHAR(255),
    title VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_user_organization UNIQUE (user_id, organization_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_orgs_user ON user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_orgs_org ON user_organizations(organization_id);

-- ============================================
-- ORGANIZATION JOIN REQUESTS
-- ============================================

CREATE TABLE IF NOT EXISTS organization_join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    requested_role VARCHAR(50) DEFAULT 'USER',
    message TEXT,
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_join_requests_user ON organization_join_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_org ON organization_join_requests(organization_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_status ON organization_join_requests(status);

-- ============================================
-- ORGANIZATION INVITATIONS
-- ============================================

CREATE TABLE IF NOT EXISTS organization_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    invited_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'USER',
    message TEXT,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, ACCEPTED, EXPIRED
    accepted_by UUID REFERENCES users(id),
    accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_invitations_token ON organization_invitations(token);
CREATE INDEX IF NOT EXISTS idx_invitations_email ON organization_invitations(email);

-- ============================================
-- SCORE CATEGORIES
-- ============================================

CREATE TABLE IF NOT EXISTS score_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    max_score INTEGER NOT NULL DEFAULT 100,
    icon VARCHAR(100),
    color VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_category_per_org UNIQUE (organization_id, name)
);

CREATE INDEX IF NOT EXISTS idx_categories_org ON score_categories(organization_id);

-- ============================================
-- GROUPS
-- ============================================

CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_group_name_per_org UNIQUE (name, organization_id)
);

CREATE INDEX IF NOT EXISTS idx_groups_org ON groups(organization_id);

-- ============================================
-- GROUP MEMBERS
-- ============================================

CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'MEMBER', -- ADMIN, MEMBER
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_user_per_group UNIQUE (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);

-- ============================================
-- SCORES
-- ============================================

CREATE TABLE IF NOT EXISTS scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES score_categories(id) ON DELETE CASCADE,
    score INTEGER NOT NULL DEFAULT 0,
    reason TEXT,
    awarded_by UUID REFERENCES users(id),
    group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scores_user ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_org ON scores(organization_id);
CREATE INDEX IF NOT EXISTS idx_scores_category ON scores(category_id);
CREATE INDEX IF NOT EXISTS idx_scores_created ON scores(created_at);

-- ============================================
-- SCORE HISTORY (for tracking changes)
-- ============================================

CREATE TABLE IF NOT EXISTS score_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    score_id UUID NOT NULL REFERENCES scores(id) ON DELETE CASCADE,
    old_score INTEGER,
    new_score INTEGER,
    changed_by UUID REFERENCES users(id),
    change_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_score_history_score ON score_history(score_id);

-- ============================================
-- TRIGGERS FOR UPDATED_AT
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to all tables with updated_at
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_organizations_updated_at BEFORE UPDATE ON user_organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_score_categories_updated_at BEFORE UPDATE ON score_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON scores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- INITIAL SEED DATA
-- ============================================

-- Insert default organization
INSERT INTO organizations (id, name, description, is_active)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Default Organization', 'Default organization for the platform', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Insert default admin user (password: admin123)
-- Note: This is a bcrypt hash of "admin123"
INSERT INTO users (id, username, email, password_hash, first_name, last_name, is_active)
VALUES 
    ('22222222-2222-2222-2222-222222222222', 
     'admin', 
     'admin@score.com', 
     '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5NU7FqNr0mVEu', 
     'System', 
     'Administrator', 
     TRUE)
ON CONFLICT (username) DO NOTHING;

-- Make admin a SUPER_ADMIN of default organization
INSERT INTO user_organizations (user_id, organization_id, role)
VALUES 
    ('22222222-2222-2222-2222-222222222222', 
     '11111111-1111-1111-1111-111111111111', 
     'SUPER_ADMIN')
ON CONFLICT (user_id, organization_id) DO NOTHING;

-- Insert default score categories
INSERT INTO score_categories (organization_id, name, description, max_score, icon, color)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Attendance', 'Points for attending events', 100, 'calendar', 'blue'),
    ('11111111-1111-1111-1111-111111111111', 'Participation', 'Points for active participation', 100, 'users', 'green'),
    ('11111111-1111-1111-1111-111111111111', 'Leadership', 'Points for leadership activities', 100, 'star', 'yellow'),
    ('11111111-1111-1111-1111-111111111111', 'Academic', 'Points for academic achievements', 100, 'book', 'purple'),
    ('11111111-1111-1111-1111-111111111111', 'Community Service', 'Points for community service', 100, 'heart', 'red')
ON CONFLICT (organization_id, name) DO NOTHING;

-- ============================================
-- VIEWS FOR COMMON QUERIES
-- ============================================

-- View for user total scores by organization
CREATE OR REPLACE VIEW user_total_scores AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    uo.organization_id,
    o.name as organization_name,
    COALESCE(SUM(s.score), 0) as total_score,
    COUNT(s.id) as score_count
FROM users u
JOIN user_organizations uo ON u.id = uo.user_id
JOIN organizations o ON uo.organization_id = o.id
LEFT JOIN scores s ON u.id = s.user_id AND s.organization_id = o.id
WHERE u.is_active = TRUE AND uo.is_active = TRUE
GROUP BY u.id, u.username, u.email, u.first_name, u.last_name, uo.organization_id, o.name;

-- View for leaderboard by organization
CREATE OR REPLACE VIEW organization_leaderboard AS
SELECT 
    organization_id,
    organization_name,
    user_id,
    username,
    first_name,
    last_name,
    total_score,
    score_count,
    RANK() OVER (PARTITION BY organization_id ORDER BY total_score DESC) as rank
FROM user_total_scores
ORDER BY organization_id, total_score DESC;

-- View for category-wise scores
CREATE OR REPLACE VIEW category_scores AS
SELECT 
    u.id as user_id,
    u.username,
    uo.organization_id,
    o.name as organization_name,
    sc.id as category_id,
    sc.name as category_name,
    COALESCE(SUM(s.score), 0) as category_total,
    sc.max_score,
    ROUND((COALESCE(SUM(s.score), 0)::NUMERIC / sc.max_score) * 100, 2) as percentage
FROM users u
JOIN user_organizations uo ON u.id = uo.user_id
JOIN organizations o ON uo.organization_id = o.id
CROSS JOIN score_categories sc
LEFT JOIN scores s ON u.id = s.user_id 
    AND s.organization_id = o.id 
    AND s.category_id = sc.id
WHERE sc.organization_id = o.id 
    AND u.is_active = TRUE 
    AND uo.is_active = TRUE
GROUP BY u.id, u.username, uo.organization_id, o.name, sc.id, sc.name, sc.max_score;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant permissions to postgres user (adjust as needed for your setup)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- ============================================
-- COMPLETION MESSAGE
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Database schema initialized successfully!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Default Admin Credentials:';
    RAISE NOTICE '  Username: admin';
    RAISE NOTICE '  Email: admin@score.com';
    RAISE NOTICE '  Password: admin123';
    RAISE NOTICE '';
    RAISE NOTICE 'Default Organization: Default Organization';
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: Change the admin password immediately!';
    RAISE NOTICE '================================================';
END $$;

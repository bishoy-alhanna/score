-- Multi-Tenant SaaS Platform Database Schema
-- PostgreSQL Database Schema for Scoring and Leaderboard Platform

-- Create database (run this separately)
-- CREATE DATABASE saas_platform;

-- Organizations table (tenant isolation)
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Users table (belongs to organization)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'USER', -- USER, ORG_ADMIN
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    department VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraints for multi-tenancy
    CONSTRAINT unique_username_per_org UNIQUE (username, organization_id),
    CONSTRAINT unique_email_per_org UNIQUE (email, organization_id)
);

-- Groups table (belongs to organization)
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint for group name within organization
    CONSTRAINT unique_group_name_per_org UNIQUE (name, organization_id)
);

-- Group members table (many-to-many relationship)
CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'MEMBER', -- MEMBER, ADMIN
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint for user in group
    CONSTRAINT unique_user_per_group UNIQUE (group_id, user_id)
);

-- Scores table (individual score entries)
CREATE TABLE IF NOT EXISTS scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    score_value INTEGER NOT NULL,
    category VARCHAR(255) DEFAULT 'general',
    description TEXT,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Ensure either user_id or group_id is set, but not both
    CONSTRAINT check_user_or_group CHECK (
        (user_id IS NOT NULL AND group_id IS NULL) OR 
        (user_id IS NULL AND group_id IS NOT NULL)
    )
);

-- Score aggregates table (for performance optimization)
CREATE TABLE IF NOT EXISTS score_aggregates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    category VARCHAR(255) DEFAULT 'general',
    total_score INTEGER DEFAULT 0,
    score_count INTEGER DEFAULT 0,
    average_score DECIMAL(10,2) DEFAULT 0.0,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraints for aggregates
    CONSTRAINT unique_user_category_org UNIQUE (user_id, category, organization_id),
    CONSTRAINT unique_group_category_org UNIQUE (group_id, category, organization_id),
    
    -- Ensure either user_id or group_id is set, but not both
    CONSTRAINT check_aggregate_user_or_group CHECK (
        (user_id IS NOT NULL AND group_id IS NULL) OR 
        (user_id IS NULL AND group_id IS NOT NULL)
    )
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_users_organization_id ON users(organization_id);
CREATE INDEX IF NOT EXISTS idx_users_username_org ON users(username, organization_id);
CREATE INDEX IF NOT EXISTS idx_users_email_org ON users(email, organization_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE INDEX IF NOT EXISTS idx_groups_organization_id ON groups(organization_id);
CREATE INDEX IF NOT EXISTS idx_groups_name_org ON groups(name, organization_id);
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups(created_by);

CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_org_id ON group_members(organization_id);

CREATE INDEX IF NOT EXISTS idx_scores_user_id ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_group_id ON scores(group_id);
CREATE INDEX IF NOT EXISTS idx_scores_organization_id ON scores(organization_id);
CREATE INDEX IF NOT EXISTS idx_scores_category ON scores(category);
CREATE INDEX IF NOT EXISTS idx_scores_created_at ON scores(created_at);

CREATE INDEX IF NOT EXISTS idx_score_aggregates_user_id ON score_aggregates(user_id);
CREATE INDEX IF NOT EXISTS idx_score_aggregates_group_id ON score_aggregates(group_id);
CREATE INDEX IF NOT EXISTS idx_score_aggregates_org_id ON score_aggregates(organization_id);
CREATE INDEX IF NOT EXISTS idx_score_aggregates_category ON score_aggregates(category);
CREATE INDEX IF NOT EXISTS idx_score_aggregates_total_score ON score_aggregates(total_score DESC);

-- Triggers for updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON scores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update score aggregates
CREATE OR REPLACE FUNCTION update_score_aggregate()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle user score aggregates
    IF NEW.user_id IS NOT NULL THEN
        INSERT INTO score_aggregates (user_id, category, organization_id, total_score, score_count, average_score)
        SELECT 
            NEW.user_id,
            NEW.category,
            NEW.organization_id,
            COALESCE(SUM(score_value), 0),
            COUNT(*),
            COALESCE(AVG(score_value), 0)
        FROM scores 
        WHERE user_id = NEW.user_id 
          AND category = NEW.category 
          AND organization_id = NEW.organization_id
        ON CONFLICT (user_id, category, organization_id) 
        DO UPDATE SET
            total_score = EXCLUDED.total_score,
            score_count = EXCLUDED.score_count,
            average_score = EXCLUDED.average_score,
            last_updated = CURRENT_TIMESTAMP;
    END IF;
    
    -- Handle group score aggregates
    IF NEW.group_id IS NOT NULL THEN
        INSERT INTO score_aggregates (group_id, category, organization_id, total_score, score_count, average_score)
        SELECT 
            NEW.group_id,
            NEW.category,
            NEW.organization_id,
            COALESCE(SUM(score_value), 0),
            COUNT(*),
            COALESCE(AVG(score_value), 0)
        FROM scores 
        WHERE group_id = NEW.group_id 
          AND category = NEW.category 
          AND organization_id = NEW.organization_id
        ON CONFLICT (group_id, category, organization_id) 
        DO UPDATE SET
            total_score = EXCLUDED.total_score,
            score_count = EXCLUDED.score_count,
            average_score = EXCLUDED.average_score,
            last_updated = CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update aggregates when scores change
CREATE TRIGGER trigger_update_score_aggregate
    AFTER INSERT OR UPDATE ON scores
    FOR EACH ROW
    EXECUTE FUNCTION update_score_aggregate();

-- Sample data for testing (optional)
-- INSERT INTO organizations (name) VALUES ('Demo Organization');

-- Get the organization ID for sample data
-- WITH demo_org AS (SELECT id FROM organizations WHERE name = 'Demo Organization')
-- INSERT INTO users (username, email, password_hash, role, organization_id)
-- SELECT 'admin', 'admin@demo.com', '$2b$12$hash', 'ORG_ADMIN', demo_org.id FROM demo_org;

-- Views for common queries
CREATE OR REPLACE VIEW user_leaderboard AS
SELECT 
    u.id as user_id,
    u.username,
    u.organization_id,
    sa.category,
    sa.total_score,
    sa.score_count,
    sa.average_score,
    RANK() OVER (PARTITION BY u.organization_id, sa.category ORDER BY sa.total_score DESC) as rank
FROM users u
JOIN score_aggregates sa ON u.id = sa.user_id
WHERE u.is_active = true
ORDER BY u.organization_id, sa.category, sa.total_score DESC;

CREATE OR REPLACE VIEW group_leaderboard AS
SELECT 
    g.id as group_id,
    g.name as group_name,
    g.organization_id,
    sa.category,
    sa.total_score,
    sa.score_count,
    sa.average_score,
    RANK() OVER (PARTITION BY g.organization_id, sa.category ORDER BY sa.total_score DESC) as rank
FROM groups g
JOIN score_aggregates sa ON g.id = sa.group_id
WHERE g.is_active = true
ORDER BY g.organization_id, sa.category, sa.total_score DESC;


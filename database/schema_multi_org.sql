-- Enhanced Multi-Organization Database Schema
-- PostgreSQL Database Schema for Multi-Organization Scoring Platform

-- Organizations table (unchanged)
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Global users table (no longer tied to a specific organization)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    profile_picture_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User organization memberships table (many-to-many with roles)
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
    
    -- Unique constraint: user can only have one role per organization
    CONSTRAINT unique_user_organization UNIQUE (user_id, organization_id)
);

-- Organization join requests table
CREATE TABLE IF NOT EXISTS organization_join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    requested_role VARCHAR(50) DEFAULT 'USER', -- Role user is requesting
    message TEXT, -- Optional message from user
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    reviewed_by UUID REFERENCES users(id), -- Admin who reviewed the request
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_message TEXT, -- Optional message from reviewer
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint: user can only have one pending request per organization
    CONSTRAINT unique_pending_request UNIQUE (user_id, organization_id, status)
    DEFERRABLE INITIALLY DEFERRED
);

-- Organization invitations table (admin invites users)
CREATE TABLE IF NOT EXISTS organization_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    invited_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'USER',
    message TEXT,
    token VARCHAR(255) UNIQUE NOT NULL, -- Invitation token
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, ACCEPTED, EXPIRED
    accepted_by UUID REFERENCES users(id),
    accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Groups table (updated to reference organization)
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

-- Group members table (updated)
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

-- Scores table (updated)
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

-- Score aggregates table (updated)
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

-- QR scan logs table for analytics and security
CREATE TABLE IF NOT EXISTS qr_scan_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scanned_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scanner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    qr_token VARCHAR(255) NOT NULL,
    scan_result VARCHAR(50) NOT NULL, -- success, expired, invalid, unauthorized
    score_assigned DECIMAL(10,2),
    score_type VARCHAR(50), -- user, group
    scan_ip INET,
    user_agent TEXT,
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Super admin configuration table
CREATE TABLE IF NOT EXISTS super_admin_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);

CREATE INDEX IF NOT EXISTS idx_user_organizations_user_id ON user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_org_id ON user_organizations(organization_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_role ON user_organizations(role);
CREATE INDEX IF NOT EXISTS idx_user_organizations_active ON user_organizations(is_active);

CREATE INDEX IF NOT EXISTS idx_join_requests_user_id ON organization_join_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_org_id ON organization_join_requests(organization_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_status ON organization_join_requests(status);
CREATE INDEX IF NOT EXISTS idx_join_requests_created_at ON organization_join_requests(created_at);

CREATE INDEX IF NOT EXISTS idx_invitations_org_id ON organization_invitations(organization_id);
CREATE INDEX IF NOT EXISTS idx_invitations_email ON organization_invitations(email);
CREATE INDEX IF NOT EXISTS idx_invitations_token ON organization_invitations(token);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON organization_invitations(status);
CREATE INDEX IF NOT EXISTS idx_invitations_expires_at ON organization_invitations(expires_at);

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

CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_scanned_user ON qr_scan_logs(scanned_user_id);
CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_scanner_user ON qr_scan_logs(scanner_user_id);
CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_org_id ON qr_scan_logs(organization_id);
CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_scan_result ON qr_scan_logs(scan_result);
CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_scanned_at ON qr_scan_logs(scanned_at);

CREATE INDEX IF NOT EXISTS idx_super_admin_username ON super_admin_config(username);
CREATE INDEX IF NOT EXISTS idx_super_admin_active ON super_admin_config(is_active);

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

CREATE TRIGGER update_user_organizations_updated_at BEFORE UPDATE ON user_organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_join_requests_updated_at BEFORE UPDATE ON organization_join_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invitations_updated_at BEFORE UPDATE ON organization_invitations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON scores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically remove duplicate pending requests
CREATE OR REPLACE FUNCTION cleanup_duplicate_pending_requests()
RETURNS TRIGGER AS $$
BEGIN
    -- Remove any existing pending requests for the same user-organization pair
    DELETE FROM organization_join_requests 
    WHERE user_id = NEW.user_id 
      AND organization_id = NEW.organization_id 
      AND status = 'PENDING'
      AND id != NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cleanup_duplicate_pending_requests
    AFTER INSERT ON organization_join_requests
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_duplicate_pending_requests();

-- Function to update score aggregates (updated for new schema)
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

-- Updated views for multi-organization support
CREATE OR REPLACE VIEW user_organization_details AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    uo.organization_id,
    o.name as organization_name,
    uo.role,
    uo.department,
    uo.title,
    uo.is_active as membership_active,
    uo.joined_at
FROM users u
JOIN user_organizations uo ON u.id = uo.user_id
JOIN organizations o ON uo.organization_id = o.id
WHERE u.is_active = true AND uo.is_active = true;

CREATE OR REPLACE VIEW user_leaderboard AS
SELECT 
    uod.user_id,
    uod.username,
    uod.first_name,
    uod.last_name,
    uod.organization_id,
    uod.organization_name,
    sa.category,
    sa.total_score,
    sa.score_count,
    sa.average_score,
    RANK() OVER (PARTITION BY uod.organization_id, sa.category ORDER BY sa.total_score DESC) as rank
FROM user_organization_details uod
JOIN score_aggregates sa ON uod.user_id = sa.user_id AND uod.organization_id = sa.organization_id
ORDER BY uod.organization_id, sa.category, sa.total_score DESC;

CREATE OR REPLACE VIEW group_leaderboard AS
SELECT 
    g.id as group_id,
    g.name as group_name,
    g.organization_id,
    o.name as organization_name,
    sa.category,
    sa.total_score,
    sa.score_count,
    sa.average_score,
    RANK() OVER (PARTITION BY g.organization_id, sa.category ORDER BY sa.total_score DESC) as rank
FROM groups g
JOIN organizations o ON g.organization_id = o.id
JOIN score_aggregates sa ON g.id = sa.group_id
WHERE g.is_active = true
ORDER BY g.organization_id, sa.category, sa.total_score DESC;

-- View for pending organization requests
CREATE OR REPLACE VIEW pending_organization_requests AS
SELECT 
    ojr.id as request_id,
    ojr.user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    ojr.organization_id,
    o.name as organization_name,
    ojr.requested_role,
    ojr.message,
    ojr.created_at as requested_at
FROM organization_join_requests ojr
JOIN users u ON ojr.user_id = u.id
JOIN organizations o ON ojr.organization_id = o.id
WHERE ojr.status = 'PENDING'
ORDER BY ojr.created_at ASC;
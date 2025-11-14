-- ================================================================
-- SaaS Platform - Database Initialization Script
-- Run this script for first-time setup
-- ================================================================

-- Drop existing database if needed (BE CAREFUL - THIS DELETES ALL DATA)
-- DROP DATABASE IF EXISTS saas_platform;
-- CREATE DATABASE saas_platform;

-- Connect to the database
\c saas_platform;

-- ================================================================
-- EXTENSIONS
-- ================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ================================================================
-- ORGANIZATIONS TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_org_name ON organizations(name);
CREATE INDEX IF NOT EXISTS idx_org_active ON organizations(is_active);

-- ================================================================
-- USERS TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    profile_picture_url VARCHAR(500),
    
    -- Personal Information
    birthdate DATE,
    phone_number VARCHAR(20),
    bio TEXT,
    gender VARCHAR(20),
    
    -- Academic Information
    school_year VARCHAR(50),
    student_id VARCHAR(50),
    major VARCHAR(100),
    gpa FLOAT,
    graduation_year INTEGER,
    university_name VARCHAR(255),
    faculty_name VARCHAR(255),
    
    -- Contact Information
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    
    -- Emergency Contact
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(20),
    emergency_contact_relationship VARCHAR(50),
    
    -- Social Media & Links
    linkedin_url VARCHAR(500),
    github_url VARCHAR(500),
    personal_website VARCHAR(500),
    
    -- Preferences
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(10) DEFAULT 'en',
    notification_preferences JSON,
    
    -- System fields
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- QR Code fields
    qr_code_token VARCHAR(255) UNIQUE,
    qr_code_generated_at TIMESTAMP WITH TIME ZONE,
    qr_code_expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_user_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_user_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_qr_token ON users(qr_code_token);
CREATE INDEX IF NOT EXISTS idx_user_student_id ON users(student_id);
CREATE INDEX IF NOT EXISTS idx_user_school_year ON users(school_year);
CREATE INDEX IF NOT EXISTS idx_user_graduation_year ON users(graduation_year);
CREATE INDEX IF NOT EXISTS idx_user_active ON users(is_active);

-- ================================================================
-- USER-ORGANIZATION RELATIONSHIP TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS user_organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'USER',
    department VARCHAR(100),
    title VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, organization_id)
);

CREATE INDEX IF NOT EXISTS idx_user_org_user ON user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_org_org ON user_organizations(organization_id);
CREATE INDEX IF NOT EXISTS idx_user_org_role ON user_organizations(role);
CREATE INDEX IF NOT EXISTS idx_user_org_active ON user_organizations(is_active);

-- ================================================================
-- ORGANIZATION JOIN REQUESTS TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS organization_join_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    requested_role VARCHAR(50) NOT NULL DEFAULT 'USER',
    message TEXT,
    status VARCHAR(20) DEFAULT 'PENDING',
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, organization_id, status)
);

CREATE INDEX IF NOT EXISTS idx_join_req_user ON organization_join_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_join_req_org ON organization_join_requests(organization_id);
CREATE INDEX IF NOT EXISTS idx_join_req_status ON organization_join_requests(status);

-- ================================================================
-- ORGANIZATION INVITATIONS TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS organization_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'USER',
    token VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    accepted_by UUID REFERENCES users(id),
    accepted_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_invitation_org ON organization_invitations(organization_id);
CREATE INDEX IF NOT EXISTS idx_invitation_email ON organization_invitations(email);
CREATE INDEX IF NOT EXISTS idx_invitation_token ON organization_invitations(token);
CREATE INDEX IF NOT EXISTS idx_invitation_status ON organization_invitations(status);

-- ================================================================
-- GROUPS TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, organization_id)
);

CREATE INDEX IF NOT EXISTS idx_group_org ON groups(organization_id);
CREATE INDEX IF NOT EXISTS idx_group_name ON groups(name);
CREATE INDEX IF NOT EXISTS idx_group_active ON groups(is_active);

-- ================================================================
-- GROUP MEMBERS TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_member_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_member_user ON group_members(user_id);

-- ================================================================
-- SCORE CATEGORIES TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS score_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    max_score INTEGER DEFAULT 100,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    is_predefined BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, organization_id)
);

CREATE INDEX IF NOT EXISTS idx_category_org ON score_categories(organization_id);
CREATE INDEX IF NOT EXISTS idx_category_name ON score_categories(name);

-- ================================================================
-- SCORES TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category_id UUID REFERENCES score_categories(id) ON DELETE SET NULL,
    category VARCHAR(255) DEFAULT 'general',  -- Backward compatibility
    score_value INTEGER NOT NULL DEFAULT 0,
    description TEXT,
    assigned_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CHECK ((user_id IS NOT NULL AND group_id IS NULL) OR (user_id IS NULL AND group_id IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_score_user ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_score_group ON scores(group_id);
CREATE INDEX IF NOT EXISTS idx_score_org ON scores(organization_id);
CREATE INDEX IF NOT EXISTS idx_score_category ON scores(category_id);
CREATE INDEX IF NOT EXISTS idx_score_date ON scores(created_at);

-- ================================================================
-- SCORE AGGREGATES TABLE (for performance)
-- ================================================================
CREATE TABLE IF NOT EXISTS score_aggregates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category VARCHAR(255) DEFAULT 'general',
    total_score INTEGER DEFAULT 0,
    score_count INTEGER DEFAULT 0,
    average_score NUMERIC(10, 2) DEFAULT 0.0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, organization_id, category),
    UNIQUE(group_id, organization_id, category),
    CHECK ((user_id IS NOT NULL AND group_id IS NULL) OR (user_id IS NULL AND group_id IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_aggregate_user ON score_aggregates(user_id);
CREATE INDEX IF NOT EXISTS idx_aggregate_group ON score_aggregates(group_id);
CREATE INDEX IF NOT EXISTS idx_aggregate_org ON score_aggregates(organization_id);
CREATE INDEX IF NOT EXISTS idx_aggregate_category ON score_aggregates(category);
CREATE INDEX IF NOT EXISTS idx_aggregate_points ON score_aggregates(total_score DESC);

-- ================================================================
-- QR SCAN LOGS TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS qr_scan_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    scanned_by UUID REFERENCES users(id),
    scan_type VARCHAR(50),
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scan_user ON qr_scan_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_scan_org ON qr_scan_logs(organization_id);
CREATE INDEX IF NOT EXISTS idx_scan_date ON qr_scan_logs(scanned_at);

-- ================================================================
-- SUPER ADMIN CONFIG TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS super_admin_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_super_admin BOOLEAN DEFAULT TRUE,
    granted_by UUID REFERENCES users(id),
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_super_admin_user ON super_admin_config(user_id);

-- ================================================================
-- DEMO DATA SECTION
-- ================================================================

-- Insert Demo Organizations
INSERT INTO organizations (id, name, description, is_active) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Tech University', 'Technology and Engineering University', TRUE),
    ('22222222-2222-2222-2222-222222222222', 'Business School', 'School of Business and Management', TRUE),
    ('33333333-3333-3333-3333-333333333333', 'Arts Academy', 'Academy of Arts and Design', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Insert Demo Users
-- Password for all users: 'password123' (hashed with bcrypt)
-- Note: organization membership is set via user_organizations table
INSERT INTO users (id, username, email, password_hash, first_name, last_name, is_active) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin', 'admin@score.com', crypt('password123', gen_salt('bf')), 'Admin', 'User', TRUE),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'john.admin', 'john.admin@tech.edu', crypt('password123', gen_salt('bf')), 'John', 'Admin', TRUE),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'sarah.admin', 'sarah.admin@business.edu', crypt('password123', gen_salt('bf')), 'Sarah', 'Admin', TRUE),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'john.doe', 'john.doe@tech.edu', crypt('password123', gen_salt('bf')), 'John', 'Doe', TRUE),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'jane.smith', 'jane.smith@tech.edu', crypt('password123', gen_salt('bf')), 'Jane', 'Smith', TRUE),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'bob.wilson', 'bob.wilson@business.edu', crypt('password123', gen_salt('bf')), 'Bob', 'Wilson', TRUE),
    ('12121212-1212-1212-1212-121212121212', 'alice.brown', 'alice.brown@business.edu', crypt('password123', gen_salt('bf')), 'Alice', 'Brown', TRUE),
    ('13131313-1313-1313-1313-131313131313', 'charlie.davis', 'charlie.davis@arts.edu', crypt('password123', gen_salt('bf')), 'Charlie', 'Davis', TRUE),
    ('14141414-1414-1414-1414-141414141414', 'emma.taylor', 'emma.taylor@arts.edu', crypt('password123', gen_salt('bf')), 'Emma', 'Taylor', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Insert User-Organization relationships with roles
INSERT INTO user_organizations (user_id, organization_id, role, is_active) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'ORG_ADMIN', TRUE),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'ORG_ADMIN', TRUE),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', 'ORG_ADMIN', TRUE),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'USER', TRUE),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', 'USER', TRUE),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', 'USER', TRUE),
    ('12121212-1212-1212-1212-121212121212', '22222222-2222-2222-2222-222222222222', 'USER', TRUE),
    ('13131313-1313-1313-1313-131313131313', '33333333-3333-3333-3333-333333333333', 'USER', TRUE),
    ('14141414-1414-1414-1414-141414141414', '33333333-3333-3333-3333-333333333333', 'USER', TRUE)
ON CONFLICT (user_id, organization_id) DO NOTHING;

-- Insert Score Categories for each organization
INSERT INTO score_categories (id, name, description, max_score, organization_id, created_by, is_predefined, is_active) VALUES
    -- Tech University categories
    ('c1111111-1111-1111-1111-111111111111', 'Attendance', 'Attendance points', 100, '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', TRUE, TRUE),
    ('c1111111-1111-1111-1111-111111111112', 'Participation', 'Class participation points', 100, '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', TRUE, TRUE),
    ('c1111111-1111-1111-1111-111111111113', 'Leadership', 'Leadership activities points', 100, '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', TRUE, TRUE),
    ('c1111111-1111-1111-1111-111111111114', 'Academic Excellence', 'Academic achievement points', 100, '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', TRUE, TRUE),
    ('c1111111-1111-1111-1111-111111111115', 'Community Service', 'Community service points', 100, '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', TRUE, TRUE),
    -- Business School categories
    ('c2222222-2222-2222-2222-222222222221', 'Attendance', 'Attendance points', 100, '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', TRUE, TRUE),
    ('c2222222-2222-2222-2222-222222222222', 'Participation', 'Class participation points', 100, '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', TRUE, TRUE),
    ('c2222222-2222-2222-2222-222222222223', 'Leadership', 'Leadership activities points', 100, '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', TRUE, TRUE),
    -- Arts Academy categories
    ('c3333333-3333-3333-3333-333333333331', 'Attendance', 'Attendance points', 100, '33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', TRUE, TRUE),
    ('c3333333-3333-3333-3333-333333333332', 'Creative Works', 'Points for creative projects', 100, '33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', TRUE, TRUE)
ON CONFLICT (name, organization_id) DO NOTHING;

-- Insert Sample Scores for demo users
INSERT INTO scores (user_id, organization_id, category_id, category, score_value, description, assigned_by) VALUES
    -- Tech University scores
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 'Attendance', 85, 'Great attendance record', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111112', 'Participation', 90, 'Excellent class participation', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 'Attendance', 95, 'Perfect attendance', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111114', 'Academic Excellence', 88, 'Outstanding academic performance', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    -- Business School scores
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222221', 'Attendance', 80, 'Good attendance', 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
    ('12121212-1212-1212-1212-121212121212', '22222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222223', 'Leadership', 92, 'Great leadership in team projects', 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
    -- Arts Academy scores
    ('13131313-1313-1313-1313-131313131313', '33333333-3333-3333-3333-333333333333', 'c3333333-3333-3333-3333-333333333332', 'Creative Works', 96, 'Exceptional creative project', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('14141414-1414-1414-1414-141414141414', '33333333-3333-3333-3333-333333333333', 'c3333333-3333-3333-3333-333333333331', 'Attendance', 87, 'Consistent attendance', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
ON CONFLICT DO NOTHING;

-- ================================================================
-- CREATE DEFAULT SUPER ADMIN USER
-- Password: password123 (CHANGE THIS IN PRODUCTION!)
-- ================================================================
-- Make admin user a super admin
INSERT INTO super_admin_config (user_id, is_super_admin, granted_by)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', TRUE, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
ON CONFLICT (user_id) DO NOTHING;

-- ================================================================
-- TRIGGERS FOR UPDATED_AT TIMESTAMPS
-- ================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to all tables with updated_at
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_organizations_updated_at BEFORE UPDATE ON user_organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_score_categories_updated_at BEFORE UPDATE ON score_categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON scores FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- GRANT PERMISSIONS (Adjust as needed for your setup)
-- ================================================================
-- Grant all privileges to postgres user (default)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- ================================================================
-- SUMMARY
-- ================================================================
-- Database initialization complete!
-- 
-- Next steps:
-- 1. Review and customize default values
-- 2. Update default admin credentials if uncommented
-- 3. Add your initial organizations and users
-- 4. Configure backup and monitoring
-- 
-- Tables created:
-- - organizations
-- - users (with academic fields)
-- - user_organizations
-- - organization_join_requests
-- - organization_invitations
-- - groups
-- - group_members
-- - score_categories
-- - scores
-- - score_aggregates
-- - qr_scan_logs
-- - super_admin_config
-- ================================================================

-- ================================================================
-- LOAD DEMO DATA (Optional - can be deleted by super admin)
-- ================================================================
\echo 'Loading demo data...'
\i /database/seed_demo_data.sql
\echo 'Demo data loaded successfully!'

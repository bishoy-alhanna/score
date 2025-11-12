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
    name VARCHAR(100) NOT NULL,
    description TEXT,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
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
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category_id UUID REFERENCES score_categories(id) ON DELETE SET NULL,
    points INTEGER NOT NULL DEFAULT 0,
    reason TEXT,
    awarded_by UUID REFERENCES users(id),
    scored_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_score_user ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_score_org ON scores(organization_id);
CREATE INDEX IF NOT EXISTS idx_score_category ON scores(category_id);
CREATE INDEX IF NOT EXISTS idx_score_date ON scores(scored_at);

-- ================================================================
-- SCORE AGGREGATES TABLE (for performance)
-- ================================================================
CREATE TABLE IF NOT EXISTS score_aggregates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category_id UUID REFERENCES score_categories(id) ON DELETE CASCADE,
    total_points INTEGER DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, organization_id, category_id)
);

CREATE INDEX IF NOT EXISTS idx_aggregate_user ON score_aggregates(user_id);
CREATE INDEX IF NOT EXISTS idx_aggregate_org ON score_aggregates(organization_id);
CREATE INDEX IF NOT EXISTS idx_aggregate_category ON score_aggregates(category_id);
CREATE INDEX IF NOT EXISTS idx_aggregate_points ON score_aggregates(total_points DESC);

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
-- INSERT DEFAULT CATEGORIES (Optional - customize as needed)
-- ================================================================
-- You can add default categories here or let organizations create their own

-- ================================================================
-- CREATE DEFAULT SUPER ADMIN USER (Optional)
-- Password: admin123 (CHANGE THIS IN PRODUCTION!)
-- ================================================================
-- Uncomment and customize if you want a default admin user
/*
INSERT INTO users (username, email, password_hash, first_name, last_name, is_active)
VALUES (
    'superadmin',
    'admin@example.com',
    crypt('admin123', gen_salt('bf')),
    'Super',
    'Admin',
    TRUE
) ON CONFLICT (username) DO NOTHING;

-- Make the user a super admin
INSERT INTO super_admin_config (user_id, is_super_admin)
SELECT id, TRUE FROM users WHERE username = 'superadmin'
ON CONFLICT (user_id) DO NOTHING;
*/

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

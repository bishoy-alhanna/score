-- ==========================================
-- COMPREHENSIVE DATABASE MIGRATION SCRIPT
-- Generated for SCORE Platform
-- Date: 2025-11-16
-- ==========================================

-- This script adds all missing columns and tables based on
-- the comparison between API models and current production schema

BEGIN;

-- ==========================================
-- 1. USERS TABLE - Add Missing Columns
-- ==========================================

-- Check and add columns that might be missing
DO $$ 
BEGIN
    -- Personal Information
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='profile_picture_url') THEN
        ALTER TABLE users ADD COLUMN profile_picture_url VARCHAR(500);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='birthdate') THEN
        ALTER TABLE users ADD COLUMN birthdate DATE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='phone_number') THEN
        ALTER TABLE users ADD COLUMN phone_number VARCHAR(20);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='bio') THEN
        ALTER TABLE users ADD COLUMN bio TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='gender') THEN
        ALTER TABLE users ADD COLUMN gender VARCHAR(20);
    END IF;
    
    -- Academic Information
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='school_year') THEN
        ALTER TABLE users ADD COLUMN school_year VARCHAR(50);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='student_id') THEN
        ALTER TABLE users ADD COLUMN student_id VARCHAR(50);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='major') THEN
        ALTER TABLE users ADD COLUMN major VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='gpa') THEN
        ALTER TABLE users ADD COLUMN gpa FLOAT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='graduation_year') THEN
        ALTER TABLE users ADD COLUMN graduation_year INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='university_name') THEN
        ALTER TABLE users ADD COLUMN university_name VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='faculty_name') THEN
        ALTER TABLE users ADD COLUMN faculty_name VARCHAR(255);
    END IF;
    
    -- Contact Information
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='address_line1') THEN
        ALTER TABLE users ADD COLUMN address_line1 VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='address_line2') THEN
        ALTER TABLE users ADD COLUMN address_line2 VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='city') THEN
        ALTER TABLE users ADD COLUMN city VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='state') THEN
        ALTER TABLE users ADD COLUMN state VARCHAR(50);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='postal_code') THEN
        ALTER TABLE users ADD COLUMN postal_code VARCHAR(20);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='country') THEN
        ALTER TABLE users ADD COLUMN country VARCHAR(100);
    END IF;
    
    -- Emergency Contact
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='emergency_contact_name') THEN
        ALTER TABLE users ADD COLUMN emergency_contact_name VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='emergency_contact_phone') THEN
        ALTER TABLE users ADD COLUMN emergency_contact_phone VARCHAR(20);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='emergency_contact_relationship') THEN
        ALTER TABLE users ADD COLUMN emergency_contact_relationship VARCHAR(50);
    END IF;
    
    -- Social Media & Links
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='linkedin_url') THEN
        ALTER TABLE users ADD COLUMN linkedin_url VARCHAR(500);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='github_url') THEN
        ALTER TABLE users ADD COLUMN github_url VARCHAR(500);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='personal_website') THEN
        ALTER TABLE users ADD COLUMN personal_website VARCHAR(500);
    END IF;
    
    -- Preferences
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='timezone') THEN
        ALTER TABLE users ADD COLUMN timezone VARCHAR(50) DEFAULT 'UTC';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='language') THEN
        ALTER TABLE users ADD COLUMN language VARCHAR(10) DEFAULT 'en';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='notification_preferences') THEN
        ALTER TABLE users ADD COLUMN notification_preferences JSONB;
    END IF;
    
    -- System fields
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='is_verified') THEN
        ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='email_verified_at') THEN
        ALTER TABLE users ADD COLUMN email_verified_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='last_login_at') THEN
        ALTER TABLE users ADD COLUMN last_login_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- QR Code fields
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='qr_code_token') THEN
        ALTER TABLE users ADD COLUMN qr_code_token VARCHAR(255) UNIQUE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='qr_code_generated_at') THEN
        ALTER TABLE users ADD COLUMN qr_code_generated_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='qr_code_expires_at') THEN
        ALTER TABLE users ADD COLUMN qr_code_expires_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    RAISE NOTICE 'Users table migration completed';
END $$;

-- ==========================================
-- 2. ORGANIZATIONS TABLE - Add Missing Columns
-- ==========================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organizations' AND column_name='updated_at') THEN
        ALTER TABLE organizations ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    END IF;
    
    RAISE NOTICE 'Organizations table migration completed';
END $$;

-- ==========================================
-- 3. USER_ORGANIZATIONS TABLE - Add Missing Columns
-- ==========================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_organizations' AND column_name='department') THEN
        ALTER TABLE user_organizations ADD COLUMN department VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_organizations' AND column_name='title') THEN
        ALTER TABLE user_organizations ADD COLUMN title VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_organizations' AND column_name='left_at') THEN
        ALTER TABLE user_organizations ADD COLUMN left_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_organizations' AND column_name='updated_at') THEN
        ALTER TABLE user_organizations ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    END IF;
    
    RAISE NOTICE 'User_organizations table migration completed';
END $$;

-- ==========================================
-- 4. ORGANIZATION_JOIN_REQUESTS TABLE - Add Missing Columns  
-- ==========================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organization_join_requests' AND column_name='reviewed_at') THEN
        ALTER TABLE organization_join_requests ADD COLUMN reviewed_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organization_join_requests' AND column_name='reviewed_by') THEN
        ALTER TABLE organization_join_requests ADD COLUMN reviewed_by UUID REFERENCES users(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organization_join_requests' AND column_name='review_message') THEN
        ALTER TABLE organization_join_requests ADD COLUMN review_message TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organization_join_requests' AND column_name='updated_at') THEN
        ALTER TABLE organization_join_requests ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    END IF;
    
    RAISE NOTICE 'Organization_join_requests table migration completed';
END $$;

-- ==========================================
-- 5. SCORE_CATEGORIES TABLE - Verify Structure
-- ==========================================

DO $$ 
BEGIN
    -- Already created in previous migration, verify it has all fields
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='score_categories' AND column_name='is_predefined') THEN
        ALTER TABLE score_categories ADD COLUMN is_predefined BOOLEAN DEFAULT FALSE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='score_categories' AND column_name='created_by') THEN
        ALTER TABLE score_categories ADD COLUMN created_by UUID REFERENCES users(id);
    END IF;
    
    RAISE NOTICE 'Score_categories table migration completed';
END $$;

-- ==========================================
-- 6. SCORES TABLE - Add Missing Columns
-- ==========================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='scores' AND column_name='category_id') THEN
        ALTER TABLE scores ADD COLUMN category_id UUID REFERENCES score_categories(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_score_category_id ON scores(category_id);
    END IF;
    
    RAISE NOTICE 'Scores table migration completed';
END $$;

-- ==========================================
-- 7. GROUPS TABLE - Add Missing Columns
-- ==========================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='groups' AND column_name='description') THEN
        ALTER TABLE groups ADD COLUMN description TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='groups' AND column_name='updated_at') THEN
        ALTER TABLE groups ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    END IF;
    
    RAISE NOTICE 'Groups table migration completed';
END $$;

-- ==========================================
-- 8. CREATE MISSING INDEXES
-- ==========================================

DO $$ 
BEGIN
    -- Users table indexes
    CREATE INDEX IF NOT EXISTS idx_user_student_id ON users(student_id);
    CREATE INDEX IF NOT EXISTS idx_user_school_year ON users(school_year);
    CREATE INDEX IF NOT EXISTS idx_user_graduation_year ON users(graduation_year);
    CREATE INDEX IF NOT EXISTS idx_qr_token ON users(qr_code_token);
    
    -- Organizations indexes
    CREATE INDEX IF NOT EXISTS idx_org_name ON organizations(name);
    CREATE INDEX IF NOT EXISTS idx_org_active ON organizations(is_active);
    
    -- User_organizations indexes
    CREATE INDEX IF NOT EXISTS idx_user_org_user ON user_organizations(user_id);
    CREATE INDEX IF NOT EXISTS idx_user_org_org ON user_organizations(organization_id);
    CREATE INDEX IF NOT EXISTS idx_user_org_role ON user_organizations(role);
    CREATE INDEX IF NOT EXISTS idx_user_org_active ON user_organizations(is_active);
    
    -- Score_categories indexes
    CREATE INDEX IF NOT EXISTS idx_score_cat_org ON score_categories(organization_id);
    CREATE INDEX IF NOT EXISTS idx_score_cat_predefined ON score_categories(is_predefined);
    
    -- Scores indexes  
    CREATE INDEX IF NOT EXISTS idx_score_user ON scores(user_id);
    CREATE INDEX IF NOT EXISTS idx_score_group ON scores(group_id);
    CREATE INDEX IF NOT EXISTS idx_score_org ON scores(organization_id);
    CREATE INDEX IF NOT EXISTS idx_score_cat ON scores(category_id);
    
    RAISE NOTICE 'Indexes created successfully';
END $$;

-- ==========================================
-- 9. CREATE UPDATE TRIGGERS
-- ==========================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DO $$ 
BEGIN
    -- Add updated_at triggers
    DROP TRIGGER IF EXISTS update_users_updated_at ON users;
    CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    
    DROP TRIGGER IF EXISTS update_organizations_updated_at ON organizations;
    CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    
    DROP TRIGGER IF EXISTS update_user_organizations_updated_at ON user_organizations;
    CREATE TRIGGER update_user_organizations_updated_at BEFORE UPDATE ON user_organizations 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    
    DROP TRIGGER IF EXISTS update_score_categories_updated_at ON score_categories;
    CREATE TRIGGER update_score_categories_updated_at BEFORE UPDATE ON score_categories 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    
    DROP TRIGGER IF EXISTS update_scores_updated_at ON scores;
    CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON scores 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    
    DROP TRIGGER IF EXISTS update_groups_updated_at ON groups;
    CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    
    RAISE NOTICE 'Triggers created successfully';
END $$;

-- ==========================================
-- 10. VERIFICATION QUERIES
-- ==========================================

\echo ''
\echo '=========================================='
\echo 'MIGRATION VERIFICATION'
\echo '=========================================='
\echo ''

\echo 'Users table column count:'
SELECT COUNT(*) as column_count FROM information_schema.columns WHERE table_name = 'users';

\echo ''
\echo 'Score_categories table exists and has columns:'
SELECT COUNT(*) as column_count FROM information_schema.columns WHERE table_name = 'score_categories';

\echo ''
\echo 'All indexes on users table:'
SELECT indexname FROM pg_indexes WHERE tablename = 'users' ORDER BY indexname;

\echo ''
\echo 'All foreign keys:'
SELECT 
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;

COMMIT;

\echo ''
\echo '=========================================='
\echo 'MIGRATION COMPLETED SUCCESSFULLY!'
\echo '=========================================='

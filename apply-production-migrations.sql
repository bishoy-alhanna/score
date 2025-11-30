-- Production Database Migrations
-- Apply these migrations before deploying code changes
-- These are IDEMPOTENT - safe to run multiple times

-- ============================================
-- Migration 1: Organization Filter Settings
-- ============================================
-- Adds global date filter settings for organizations

DO $$
BEGIN
    -- Add filter_enabled column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' 
        AND column_name = 'filter_enabled'
    ) THEN
        ALTER TABLE organizations 
        ADD COLUMN filter_enabled BOOLEAN DEFAULT FALSE;
        
        RAISE NOTICE '✓ Added filter_enabled column to organizations table';
    ELSE
        RAISE NOTICE '  filter_enabled column already exists';
    END IF;

    -- Add filter_start_date column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' 
        AND column_name = 'filter_start_date'
    ) THEN
        ALTER TABLE organizations 
        ADD COLUMN filter_start_date TIMESTAMP;
        
        RAISE NOTICE '✓ Added filter_start_date column to organizations table';
    ELSE
        RAISE NOTICE '  filter_start_date column already exists';
    END IF;

    -- Add filter_end_date column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' 
        AND column_name = 'filter_end_date'
    ) THEN
        ALTER TABLE organizations 
        ADD COLUMN filter_end_date TIMESTAMP;
        
        RAISE NOTICE '✓ Added filter_end_date column to organizations table';
    ELSE
        RAISE NOTICE '  filter_end_date column already exists';
    END IF;
END $$;

-- ============================================
-- Migration 2: User Organizations Membership
-- ============================================
-- Adds is_active flag and role for membership tracking

DO $$
BEGIN
    -- Add is_active column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_organizations' 
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE user_organizations 
        ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
        
        -- Set all existing memberships to active
        UPDATE user_organizations 
        SET is_active = TRUE 
        WHERE is_active IS NULL;
        
        RAISE NOTICE '✓ Added is_active column to user_organizations table';
        RAISE NOTICE '✓ Set all existing memberships to active';
    ELSE
        RAISE NOTICE '  is_active column already exists';
    END IF;

    -- Add role column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_organizations' 
        AND column_name = 'role'
    ) THEN
        ALTER TABLE user_organizations 
        ADD COLUMN role VARCHAR(50) DEFAULT 'member';
        
        -- Set default role for existing memberships
        UPDATE user_organizations 
        SET role = 'member' 
        WHERE role IS NULL;
        
        RAISE NOTICE '✓ Added role column to user_organizations table';
        RAISE NOTICE '✓ Set default role for existing memberships';
    ELSE
        RAISE NOTICE '  role column already exists';
    END IF;
END $$;

-- ============================================
-- Migration 3: Performance Indexes
-- ============================================
-- Creates indexes to improve query performance

-- Index for scores by organization_id (leaderboard queries)
CREATE INDEX IF NOT EXISTS idx_scores_organization_id 
    ON scores(organization_id);

-- Index for scores by created_at (date range filtering)
CREATE INDEX IF NOT EXISTS idx_scores_created_at 
    ON scores(created_at);

-- Composite index for active organization members (leaderboard filtering)
CREATE INDEX IF NOT EXISTS idx_user_organizations_active 
    ON user_organizations(organization_id, is_active)
    WHERE is_active = TRUE;

-- Index for user_organizations by user_id (user lookups)
CREATE INDEX IF NOT EXISTS idx_user_organizations_user_id 
    ON user_organizations(user_id);

-- ============================================
-- Verification
-- ============================================
-- Verify all migrations were applied successfully

DO $$
DECLARE
    v_filter_enabled BOOLEAN;
    v_is_active BOOLEAN;
    v_idx_count INTEGER;
BEGIN
    -- Check organizations columns
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' 
        AND column_name = 'filter_enabled'
    ) INTO v_filter_enabled;

    -- Check user_organizations columns
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_organizations' 
        AND column_name = 'is_active'
    ) INTO v_is_active;

    -- Check indexes
    SELECT COUNT(*) INTO v_idx_count
    FROM pg_indexes 
    WHERE tablename IN ('scores', 'user_organizations')
    AND indexname LIKE 'idx_%';

    -- Report results
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration Verification';
    RAISE NOTICE '========================================';
    
    IF v_filter_enabled THEN
        RAISE NOTICE '✓ Organizations filter columns: OK';
    ELSE
        RAISE WARNING '✗ Organizations filter columns: MISSING';
    END IF;

    IF v_is_active THEN
        RAISE NOTICE '✓ User organizations membership columns: OK';
    ELSE
        RAISE WARNING '✗ User organizations membership columns: MISSING';
    END IF;

    RAISE NOTICE '✓ Performance indexes created: % indexes', v_idx_count;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Migration Status: %', 
        CASE WHEN v_filter_enabled AND v_is_active 
        THEN 'SUCCESS ✓' 
        ELSE 'INCOMPLETE ✗' 
        END;
    RAISE NOTICE '========================================';
END $$;

-- Show table structures for verification
\d organizations
\d user_organizations

-- Show indexes
SELECT tablename, indexname, indexdef 
FROM pg_indexes 
WHERE tablename IN ('scores', 'user_organizations', 'organizations')
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

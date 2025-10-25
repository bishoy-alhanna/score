-- Migration to add predefined categories functionality
-- This adds the is_predefined column to score_categories table and creates predefined categories

-- Step 1: Add is_predefined column to score_categories table
ALTER TABLE score_categories ADD COLUMN IF NOT EXISTS is_predefined BOOLEAN DEFAULT FALSE;

-- Step 2: Get a sample organization and admin user for testing
-- We'll use the first organization and its first admin
DO $$
DECLARE
    org_record RECORD;
    admin_user_id VARCHAR(36);
BEGIN
    -- Loop through organizations and create predefined categories
    FOR org_record IN SELECT id::varchar AS organization_id FROM organizations LOOP
        -- Find an admin user for this organization
        SELECT u.id::varchar INTO admin_user_id 
        FROM users u 
        WHERE u.organization_id = org_record.organization_id 
        AND u.role IN ('ADMIN', 'ORG_ADMIN') 
        LIMIT 1;
        
        -- If no admin found, use any user from that org
        IF admin_user_id IS NULL THEN
            SELECT u.id::varchar INTO admin_user_id 
            FROM users u 
            WHERE u.organization_id = org_record.organization_id 
            LIMIT 1;
        END IF;
        
        -- If still no user, skip this organization
        IF admin_user_id IS NOT NULL THEN
            -- Insert القداس (Mass)
            INSERT INTO score_categories (id, name, description, max_score, organization_id, created_by, is_active, is_predefined, created_at, updated_at)
            SELECT 
                replace(gen_random_uuid()::varchar, '-', ''),
                'القداس',
                'حضور القداس',
                100,
                org_record.organization_id,
                admin_user_id,
                true,
                true,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            WHERE NOT EXISTS (
                SELECT 1 FROM score_categories sc 
                WHERE sc.organization_id = org_record.organization_id AND sc.name = 'القداس'
            );

            -- Insert التناول (Communion)
            INSERT INTO score_categories (id, name, description, max_score, organization_id, created_by, is_active, is_predefined, created_at, updated_at)
            SELECT 
                replace(gen_random_uuid()::varchar, '-', ''),
                'التناول',
                'تناول القربان المقدس',
                100,
                org_record.organization_id,
                admin_user_id,
                true,
                true,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            WHERE NOT EXISTS (
                SELECT 1 FROM score_categories sc 
                WHERE sc.organization_id = org_record.organization_id AND sc.name = 'التناول'
            );

            -- Insert الاعتراف (Confession)
            INSERT INTO score_categories (id, name, description, max_score, organization_id, created_by, is_active, is_predefined, created_at, updated_at)
            SELECT 
                replace(gen_random_uuid()::varchar, '-', ''),
                'الاعتراف',
                'سر الاعتراف',
                100,
                org_record.organization_id,
                admin_user_id,
                true,
                true,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            WHERE NOT EXISTS (
                SELECT 1 FROM score_categories sc 
                WHERE sc.organization_id = org_record.organization_id AND sc.name = 'الاعتراف'
            );
        END IF;
    END LOOP;
END $$;

-- Step 3: Update any existing categories with these names to be predefined
UPDATE score_categories 
SET is_predefined = true 
WHERE name IN ('القداس', 'التناول', 'الاعتراف');

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_score_categories_predefined ON score_categories(is_predefined);
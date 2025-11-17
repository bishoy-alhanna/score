#!/bin/bash

# Create Missing Score Categories Table

echo "=========================================="
echo "Creating Score Categories Table"
echo "=========================================="
echo ""

ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker exec -i score_postgres_prod psql -U postgres -d saas_platform' << 'EOSQL'

-- Create score_categories table
CREATE TABLE IF NOT EXISTS score_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_category_org ON score_categories(organization_id);
CREATE INDEX IF NOT EXISTS idx_category_name ON score_categories(name);
CREATE INDEX IF NOT EXISTS idx_score_categories_predefined ON score_categories(is_predefined);

-- Add category_id column to scores table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'scores' AND column_name = 'category_id'
    ) THEN
        ALTER TABLE scores ADD COLUMN category_id UUID REFERENCES score_categories(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_score_category_id ON scores(category_id);
    END IF;
END $$;

\echo '✅ Score categories table created successfully'

-- Show table structure
\d score_categories

EOSQL

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database schema updated successfully"
else
    echo ""
    echo "❌ Failed to update database schema"
    exit 1
fi

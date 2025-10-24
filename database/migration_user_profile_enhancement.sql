-- Migration script for enhanced user profile fields
-- Run this on your database to add the new profile fields

BEGIN;

-- Add personal information fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS birthdate DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(20);

-- Add academic information fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS school_year VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS student_id VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS major VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS gpa FLOAT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS graduation_year INTEGER;

-- Add contact information fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS address_line1 VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS address_line2 VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS state VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS country VARCHAR(100);

-- Add emergency contact fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS emergency_contact_name VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS emergency_contact_phone VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS emergency_contact_relationship VARCHAR(50);

-- Add social media and links fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS linkedin_url VARCHAR(500);
ALTER TABLE users ADD COLUMN IF NOT EXISTS github_url VARCHAR(500);
ALTER TABLE users ADD COLUMN IF NOT EXISTS personal_website VARCHAR(500);

-- Add preferences fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'UTC';
ALTER TABLE users ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en';
ALTER TABLE users ADD COLUMN IF NOT EXISTS notification_preferences JSONB;

-- Add system fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP;

-- Create indexes for commonly searched fields
CREATE INDEX IF NOT EXISTS idx_user_student_id ON users(student_id);
CREATE INDEX IF NOT EXISTS idx_user_school_year ON users(school_year);
CREATE INDEX IF NOT EXISTS idx_user_graduation_year ON users(graduation_year);
CREATE INDEX IF NOT EXISTS idx_user_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_user_verified ON users(is_verified);
CREATE INDEX IF NOT EXISTS idx_user_phone ON users(phone_number);

-- Update existing users to have default values for new fields
UPDATE users SET 
    timezone = 'UTC',
    language = 'en',
    is_verified = FALSE
WHERE 
    timezone IS NULL 
    OR language IS NULL 
    OR is_verified IS NULL;

COMMIT;

-- Verification queries to check the migration
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
    AND table_schema = 'public'
ORDER BY ordinal_position;
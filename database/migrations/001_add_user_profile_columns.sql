-- Migration: Add missing user profile columns
-- This adds all the columns that the user-service expects

-- Add missing user profile columns
ALTER TABLE users ADD COLUMN IF NOT EXISTS birthdate DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(50);

-- Academic information
ALTER TABLE users ADD COLUMN IF NOT EXISTS school_year VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS student_id VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS major VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS gpa DECIMAL(3,2);
ALTER TABLE users ADD COLUMN IF NOT EXISTS graduation_year INTEGER;
ALTER TABLE users ADD COLUMN IF NOT EXISTS university_name VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS faculty_name VARCHAR(255);

-- Address information
ALTER TABLE users ADD COLUMN IF NOT EXISTS address_line1 VARCHAR(500);
ALTER TABLE users ADD COLUMN IF NOT EXISTS address_line2 VARCHAR(500);
ALTER TABLE users ADD COLUMN IF NOT EXISTS city VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS state VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS postal_code VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS country VARCHAR(100);

-- Emergency contact
ALTER TABLE users ADD COLUMN IF NOT EXISTS emergency_contact_name VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS emergency_contact_phone VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS emergency_contact_relationship VARCHAR(100);

-- Social links
ALTER TABLE users ADD COLUMN IF NOT EXISTS linkedin_url VARCHAR(500);
ALTER TABLE users ADD COLUMN IF NOT EXISTS github_url VARCHAR(500);
ALTER TABLE users ADD COLUMN IF NOT EXISTS personal_website VARCHAR(500);

-- Preferences
ALTER TABLE users ADD COLUMN IF NOT EXISTS timezone VARCHAR(100) DEFAULT 'UTC';
ALTER TABLE users ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en';
ALTER TABLE users ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT '{"email": true, "push": false}';

-- Status and verification
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE;

-- QR Code for attendance
ALTER TABLE users ADD COLUMN IF NOT EXISTS qr_code_token VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS qr_code_generated_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS qr_code_expires_at TIMESTAMP WITH TIME ZONE;

-- Super admin flag
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_super_admin BOOLEAN DEFAULT FALSE;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_is_super_admin ON users(is_super_admin);
CREATE INDEX IF NOT EXISTS idx_users_qr_code_token ON users(qr_code_token);

-- Display success message
DO $$
BEGIN
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'All missing user columns have been added.';
END $$;

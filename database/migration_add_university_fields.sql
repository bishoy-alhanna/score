-- Migration script to add university and faculty fields to users table
-- Run after migration_user_profile_enhancement.sql

BEGIN;

ALTER TABLE users ADD COLUMN IF NOT EXISTS university_name VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS faculty_name VARCHAR(255);

COMMIT;

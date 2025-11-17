# Database Schema Migration - Complete

## Overview
Comprehensive database migration applied to align production schema with all API service models.

## Migration Date
November 16, 2025

## Migration Analysis

### Tables Analyzed
1. ✅ `users` - 43 columns after migration
2. ✅ `organizations` - Updated
3. ✅ `user_organizations` - Enhanced with department, title fields
4. ✅ `organization_join_requests` - Added review tracking
5. ✅ `organization_invitations` - Verified
6. ✅ `groups` - Added description, updated_at
7. ✅ `group_members` - Verified
8. ✅ `score_categories` - Created and enhanced (10 columns)
9. ✅ `scores` - Added category_id foreign key
10. ✅ `score_aggregates` - Verified
11. ✅ `super_admin_config` - Verified
12. ✅ `qr_scan_logs` - Verified

## Changes Applied

### 1. USERS Table - 30+ New Columns Added ✅

**Personal Information:**
- `profile_picture_url` VARCHAR(500)
- `birthdate` DATE
- `phone_number` VARCHAR(20)
- `bio` TEXT
- `gender` VARCHAR(20)

**Academic Information:**
- `school_year` VARCHAR(50)
- `student_id` VARCHAR(50)
- `major` VARCHAR(100)
- `gpa` FLOAT
- `graduation_year` INTEGER
- `university_name` VARCHAR(255)
- `faculty_name` VARCHAR(255)

**Contact Information:**
- `address_line1` VARCHAR(255)
- `address_line2` VARCHAR(255)
- `city` VARCHAR(100)
- `state` VARCHAR(50)
- `postal_code` VARCHAR(20)
- `country` VARCHAR(100)

**Emergency Contact:**
- `emergency_contact_name` VARCHAR(255)
- `emergency_contact_phone` VARCHAR(20)
- `emergency_contact_relationship` VARCHAR(50)

**Social Media & Links:**
- `linkedin_url` VARCHAR(500)
- `github_url` VARCHAR(500)
- `personal_website` VARCHAR(500)

**Preferences:**
- `timezone` VARCHAR(50) DEFAULT 'UTC'
- `language` VARCHAR(10) DEFAULT 'en'
- `notification_preferences` JSONB

**System Fields:**
- `is_verified` BOOLEAN DEFAULT FALSE
- `email_verified_at` TIMESTAMP WITH TIME ZONE
- `last_login_at` TIMESTAMP WITH TIME ZONE

**QR Code Fields:**
- `qr_code_token` VARCHAR(255) UNIQUE
- `qr_code_generated_at` TIMESTAMP WITH TIME ZONE
- `qr_code_expires_at` TIMESTAMP WITH TIME ZONE

### 2. ORGANIZATIONS Table ✅
- `updated_at` TIMESTAMP WITH TIME ZONE

### 3. USER_ORGANIZATIONS Table ✅
- `department` VARCHAR(255)
- `title` VARCHAR(255)
- `left_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### 4. ORGANIZATION_JOIN_REQUESTS Table ✅
- `reviewed_at` TIMESTAMP WITH TIME ZONE
- `reviewed_by` UUID REFERENCES users(id)
- `review_message` TEXT
- `updated_at` TIMESTAMP WITH TIME ZONE

### 5. SCORE_CATEGORIES Table ✅
- Already created with all required fields
- `is_predefined` BOOLEAN
- `created_by` UUID

### 6. SCORES Table ✅
- `category_id` UUID REFERENCES score_categories(id)

### 7. GROUPS Table ✅
- `description` TEXT
- `updated_at` TIMESTAMP WITH TIME ZONE

### 8. Indexes Created ✅

**Users Table:**
- `idx_user_student_id` ON users(student_id)
- `idx_user_school_year` ON users(school_year)
- `idx_user_graduation_year` ON users(graduation_year)
- `idx_qr_token` ON users(qr_code_token)

**Organizations Table:**
- `idx_org_name` ON organizations(name)
- `idx_org_active` ON organizations(is_active)

**User_Organizations Table:**
- `idx_user_org_user` ON user_organizations(user_id)
- `idx_user_org_org` ON user_organizations(organization_id)
- `idx_user_org_role` ON user_organizations(role)
- `idx_user_org_active` ON user_organizations(is_active)

**Score_Categories Table:**
- `idx_score_cat_org` ON score_categories(organization_id)
- `idx_score_cat_predefined` ON score_categories(is_predefined)

**Scores Table:**
- `idx_score_user` ON scores(user_id)
- `idx_score_group` ON scores(group_id)
- `idx_score_org` ON scores(organization_id)
- `idx_score_cat` ON scores(category_id)

### 9. Triggers Created ✅

Auto-update `updated_at` timestamp on:
- users
- organizations
- user_organizations
- score_categories
- scores
- groups

## Verification Results

### Final Column Counts:
- **users**: 43 columns ✅
- **score_categories**: 10 columns ✅

### Indexes Created:
- **users table**: 14 indexes ✅

### Foreign Keys:
- **Total**: 26 foreign key relationships ✅
- All properly referencing parent tables

## Impact on Services

### Auth Service ✅
- Full user profile support
- QR code authentication
- Multi-organization membership
- Join request workflow

### User Service ✅
- Complete user profile management
- Academic information tracking
- Contact and emergency information
- Social media links

### Group Service ✅
- Group descriptions
- Updated timestamps

### Scoring Service ✅
- Category-based scoring
- Predefined categories support
- Score history tracking

### Leaderboard Service ✅
- Category-based leaderboards
- Organization-wide rankings

## Migration Safety

All migrations used:
```sql
DO $$ 
BEGIN
    IF NOT EXISTS (...) THEN
        ALTER TABLE ... ADD COLUMN ...
    END IF;
END $$;
```

This ensures:
- ✅ Idempotent (can be run multiple times)
- ✅ No data loss
- ✅ No downtime required
- ✅ Backwards compatible

## Post-Migration Verification

Run on production:
```bash
ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform -c "
SELECT table_name, COUNT(*) as column_count 
FROM information_schema.columns 
WHERE table_schema = '\''public'\'' 
GROUP BY table_name 
ORDER BY table_name;
"'
```

## Files Created
1. `/database/comprehensive-migration.sql` - Main migration script
2. `DATABASE_MIGRATION_COMPLETE.md` - This document

## Next Steps

### Immediate
- ✅ Migration applied successfully
- ✅ All services can now use full schema

### Optional Enhancements
- [ ] Add database backups automation
- [ ] Set up migration versioning system
- [ ] Create data validation scripts
- [ ] Add database monitoring

## Status
🎉 **MIGRATION COMPLETED SUCCESSFULLY**

All API services now have full database schema support. The system can handle:
- Complete user profiles with academic information
- Multi-organization workflows
- QR code authentication
- Score categories and predefined activities
- Comprehensive join request management
- User preferences and notifications

## Rollback (if needed)

The migration is non-destructive (only adds columns/indexes). To rollback:
1. Columns added are nullable
2. Can be dropped individually if needed
3. No existing data modified

```sql
-- Example rollback (if needed)
ALTER TABLE users DROP COLUMN IF EXISTS birthdate;
ALTER TABLE users DROP COLUMN IF EXISTS phone_number;
-- etc...
```

However, **rollback is not recommended** as the new schema is required by the API services.

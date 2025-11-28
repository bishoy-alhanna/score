# Post-Deployment Database Setup

This guide explains how to restore database backups and apply schema updates after deployment.

## Quick Start

After running `deploy-ubuntu.sh` or deploying the application:

```bash
bash post-deployment-setup.sh
```

This script will:
1. ✅ Restore database from backup (optional)
2. ✅ Apply all schema migrations
3. ✅ Create performance indexes
4. ✅ Restart services

---

## What the Script Does

### Step 1: Database Restore

Restores the database from `backups/backup_20251123_214617.sql`:

- Stops backend services safely
- Drops existing database connections
- Recreates database from backup
- Preserves all user data, scores, and organizations

**You will be prompted** before restore happens.

### Step 2: Schema Updates

Applies the following schema migrations:

#### Organizations Table
```sql
- filter_enabled (BOOLEAN) - Enable/disable organization-wide date filtering
- filter_start_date (DATE) - Start date for score filtering
- filter_end_date (DATE) - End date for score filtering
```

#### User Organizations Table
```sql
- is_active (BOOLEAN) - Track active/inactive memberships
- role (VARCHAR) - User role within organization (USER, ORG_ADMIN, SUPER_ADMIN)
```

#### Performance Indexes
```sql
- idx_scores_organization_id
- idx_scores_user_id
- idx_scores_created_at
- idx_scores_org_user (composite)
- idx_user_organizations_active (composite)
```

### Step 3: Service Restart

- Starts all backend services
- Waits for services to initialize
- Displays service status

---

## Manual Execution

### Restore Database Only

```bash
bash restore-database.sh backups/backup_20251123_214617.sql
```

### Apply Schema Updates Only

```bash
# Using docker-compose (macOS)
docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres -d saas_platform < schema-updates.sql

# Using docker compose (Ubuntu)
docker compose -f docker-compose.prod.yml exec postgres psql -U postgres -d saas_platform < schema-updates.sql
```

### Manual Schema Updates

Connect to database:
```bash
docker compose -f docker-compose.prod.yml exec -it postgres psql -U postgres -d saas_platform
```

Run migrations:
```sql
-- Add organization filter columns
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS filter_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS filter_start_date DATE;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS filter_end_date DATE;

-- Add user_organizations columns
ALTER TABLE user_organizations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE user_organizations ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'USER';

-- Update existing records
UPDATE user_organizations SET is_active = TRUE WHERE is_active IS NULL;
UPDATE user_organizations SET role = 'USER' WHERE role IS NULL;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_scores_organization_id ON scores(organization_id);
CREATE INDEX IF NOT EXISTS idx_scores_user_id ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_org_user ON scores(organization_id, user_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_active ON user_organizations(organization_id, is_active);
```

---

## Deployment Workflow

### For Ubuntu Server

```bash
# 1. Install prerequisites
sudo bash setup-prerequisites-ubuntu.sh

# 2. Log out and back in
exit
# SSH back in

# 3. Deploy application
sudo bash deploy-ubuntu.sh
# Script will prompt to run post-deployment setup

# 4. If skipped, run manually
bash post-deployment-setup.sh

# 5. Create admin user
bash create-super-admin.sh
```

### For macOS Development

```bash
# 1. Install prerequisites
bash setup-prerequisites.sh

# 2. Initialize project
bash init-project.sh

# 3. Run post-deployment setup
bash post-deployment-setup.sh

# 4. Create admin user
bash create-super-admin.sh
```

---

## Backup Files

Current backups in repository:

| File | Date | Size | Description |
|------|------|------|-------------|
| `backup_20251123_214617.sql` | Nov 23, 2025 | 35KB | Base database backup |
| `saas_platform_20251128_141410.sql.gz` | Nov 28, 2025 | 4.3KB | With membership filter |

**Default backup used:** `backups/backup_20251123_214617.sql`

To use a different backup, edit `post-deployment-setup.sh`:

```bash
# Line 29
BACKUP_FILE="backups/YOUR_BACKUP_FILE.sql"
```

---

## Verification Steps

After running post-deployment setup:

### 1. Check Services
```bash
docker compose -f docker-compose.prod.yml ps
```

All services should show "Up" status.

### 2. Verify Schema
```bash
docker compose -f docker-compose.prod.yml exec postgres psql -U postgres -d saas_platform -c "\d organizations"
```

Should show: `filter_enabled`, `filter_start_date`, `filter_end_date`

### 3. Test Application

**Admin Dashboard:** http://YOUR_SERVER:3001
- Login with super admin credentials
- Check Organizations → Settings
- Verify filter date options appear

**User Dashboard:** http://YOUR_SERVER:3000
- Login as regular user
- Check leaderboard
- Verify only active members appear

### 4. Verify Data Integrity

```bash
docker compose -f docker-compose.prod.yml exec postgres psql -U postgres -d saas_platform
```

```sql
-- Check organization filters
SELECT id, name, filter_enabled, filter_start_date, filter_end_date FROM organizations;

-- Check active memberships
SELECT COUNT(*) FROM user_organizations WHERE is_active = true;

-- Check inactive memberships
SELECT COUNT(*) FROM user_organizations WHERE is_active = false;

-- Verify scores
SELECT COUNT(*) FROM scores;
```

---

## Troubleshooting

### Database restore fails

**Error:** "database is being accessed by other users"

**Solution:**
```bash
# Stop all services
docker compose -f docker-compose.prod.yml stop

# Restart only postgres
docker compose -f docker-compose.prod.yml up -d postgres

# Wait for postgres
sleep 10

# Run restore again
bash post-deployment-setup.sh
```

### Schema update fails

**Error:** "column already exists"

**Solution:** This is normal! The script uses `IF NOT EXISTS` checks. The migration will skip existing columns and continue.

### Services won't start

**Solution:**
```bash
# Check logs
docker compose -f docker-compose.prod.yml logs

# Restart services
docker compose -f docker-compose.prod.yml restart

# Or rebuild
docker compose -f docker-compose.prod.yml up -d --build
```

### Leaderboard still shows inactive users

**Solution:**
```bash
# Rebuild leaderboard service
docker compose -f docker-compose.prod.yml up -d --build leaderboard-service

# Check logs
docker compose -f docker-compose.prod.yml logs leaderboard-service

# Verify filter in code
docker compose -f docker-compose.prod.yml exec leaderboard-service cat /app/src/routes/leaderboards.py | grep -A5 "is_active"
```

---

## Rollback Procedure

If something goes wrong:

### 1. Restore Previous Backup

```bash
# Find older backup
ls -lh backups/

# Restore it
bash restore-database.sh backups/OLD_BACKUP.sql
```

### 2. Revert Code Changes

```bash
git log --oneline
git checkout PREVIOUS_COMMIT
docker compose -f docker-compose.prod.yml up -d --build
```

### 3. Emergency Database Backup

```bash
# Before any changes
docker compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres saas_platform > emergency_backup_$(date +%Y%m%d_%H%M%S).sql
```

---

## Best Practices

### Before Running

- ✅ Backup current database
- ✅ Note current git commit
- ✅ Test in development first
- ✅ Schedule during low-traffic period
- ✅ Notify users of maintenance

### During Execution

- ✅ Monitor service logs
- ✅ Watch for errors
- ✅ Keep terminal session active
- ✅ Don't interrupt the process

### After Completion

- ✅ Verify all services running
- ✅ Test key functionality
- ✅ Check for errors in logs
- ✅ Monitor performance
- ✅ Create post-deployment backup

---

## Related Scripts

- `deploy-ubuntu.sh` - Full Ubuntu deployment
- `restore-database.sh` - Database restore only
- `create-super-admin.sh` - Create admin user
- `check-services.sh` - Service health check

---

## Support

For issues:
1. Check logs: `docker compose -f docker-compose.prod.yml logs`
2. Review this guide
3. Check UBUNTU_SETUP_GUIDE.md
4. Contact support team

---

**Last Updated:** November 28, 2025

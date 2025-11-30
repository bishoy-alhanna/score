# Quick Production Deployment Reference

## 📋 Deployment Summary

**Tested Features:**
- ✅ Organization membership filter (is_active check)
- ✅ Organization-wide date filter settings  
- ✅ Leaderboard display names
- ✅ User scores management
- ✅ All services working correctly

**Database Changes:**
- Organizations: `filter_enabled`, `filter_start_date`, `filter_end_date`
- User Organizations: `is_active`, `role`
- Performance indexes on scores and user_organizations

---

## 🚀 Option 1: Automated Deployment (Recommended)

### On Your Local Machine:

```bash
cd /Users/bhanna/Projects/Score/score

# This script will:
# - Merge pre-prod-dev → prod
# - Push to remote
# - Generate deployment commands
./deploy-to-production.sh
```

### On Production Server:

```bash
# SSH to server
ssh root@escore.al-hanna.com

# Navigate to project
cd /root/score

# Run the automated deployment script
./production-deploy-server.sh
```

That's it! The script handles everything automatically.

---

## 🔧 Option 2: Manual Deployment (Step-by-Step)

### Part A: Merge Code (Local Machine)

```bash
cd /Users/bhanna/Projects/Score/score

# Switch to prod branch
git checkout prod

# Merge tested changes
git merge pre-prod-dev

# Push to remote
git push origin prod

# Switch back to pre-prod-dev
git checkout pre-prod-dev
```

### Part B: Deploy to Server (Production Server)

```bash
# 1. SSH to production
ssh root@escore.al-hanna.com

# 2. Navigate to project
cd /root/score

# 3. Backup database (CRITICAL!)
./backup-database.sh

# 4. Pull latest code
git pull origin prod

# 5. Apply database migrations
docker-compose -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d saas_platform < apply-production-migrations.sql

# 6. Rebuild services
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml build --no-cache

# 7. Start services
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d

# 8. Wait for services to start
sleep 30

# 9. Check status
docker-compose -f docker-compose.prod.yml ps
```

---

## ✅ Post-Deployment Verification

### 1. Check All Services Running

```bash
docker-compose -f docker-compose.prod.yml ps
```

Expected: All services show "Up" status

### 2. Monitor Logs

```bash
# All services
docker-compose -f docker-compose.prod.yml logs -f

# Just leaderboard (most important for this deployment)
docker-compose -f docker-compose.prod.yml logs -f leaderboard-service
```

### 3. Test Leaderboard API

```bash
# Get auth token first (replace with your credentials)
TOKEN=$(curl -X POST https://escore.al-hanna.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"yourpassword"}' \
  | jq -r '.access_token')

# Test leaderboard (replace with your org ID)
curl -H "Authorization: Bearer $TOKEN" \
  "https://escore.al-hanna.com/api/leaderboards/user?organization_id=YOUR_ORG_ID"
```

### 4. Manual UI Testing

1. **User Dashboard** - https://escore.al-hanna.com
   - ✅ Login successfully
   - ✅ Leaderboard shows only active members
   - ✅ Verify Test3 and Bfawzy don't appear
   - ✅ Date filter works

2. **Admin Dashboard** - https://admin.escore.al-hanna.com
   - ✅ Login successfully
   - ✅ Organization filter settings save/load
   - ✅ User scores management works
   - ✅ Can manage user memberships

### 5. Database Verification

```bash
# Connect to database
docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres -d saas_platform

# Check migrations applied
\d organizations
\d user_organizations

# Should show new columns:
# organizations: filter_enabled, filter_start_date, filter_end_date
# user_organizations: is_active, role

# Check indexes
SELECT indexname FROM pg_indexes WHERE tablename IN ('scores', 'user_organizations');

# Exit
\q
```

---

## 🔄 Rollback Procedure (If Needed)

### Quick Rollback (Code Only)

```bash
# On production server
cd /root/score

# Find previous commit
git log --oneline | head -10

# Rollback to previous commit
git checkout <previous-commit-hash>

# Rebuild and restart
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
```

### Full Rollback (Database + Code)

```bash
# 1. Find backup
ls -lh backups/

# 2. Restore database
./restore-database.sh backups/saas_platform_YYYYMMDD_HHMMSS.sql.gz

# 3. Rollback code
git checkout <previous-commit-hash>
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
```

---

## 📊 Expected Results

### Before Deployment:
- Leaderboard shows inactive users (Test3, Bfawzy)
- No organization filter settings
- No date range filtering

### After Deployment:
- ✅ Leaderboard shows only 6 active members
- ✅ Test3 (no membership) filtered out
- ✅ Bfawzy (is_active=false) filtered out
- ✅ Organization filter settings available
- ✅ Date range filtering works
- ✅ Admin can manage memberships

---

## 🆘 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs

# Rebuild specific service
docker-compose -f docker-compose.prod.yml up -d --build leaderboard-service
```

### Migration Errors

```bash
# Re-run migrations (they're idempotent)
docker-compose -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d saas_platform < apply-production-migrations.sql
```

### Leaderboard Shows Wrong Users

```bash
# Restart leaderboard service
docker-compose -f docker-compose.prod.yml restart leaderboard-service

# Check logs for errors
docker-compose -f docker-compose.prod.yml logs leaderboard-service
```

### Database Connection Errors

```bash
# Check postgres is running
docker-compose -f docker-compose.prod.yml ps postgres

# Restart if needed
docker-compose -f docker-compose.prod.yml restart postgres
```

---

## 📝 Files Created for This Deployment

1. **apply-production-migrations.sql** - Database schema updates
2. **deploy-to-production.sh** - Local deployment prep script
3. **production-deploy-server.sh** - Server-side deployment script
4. **DEPLOYMENT_QUICK_REFERENCE.md** - This guide

---

## ⏱️ Estimated Timeline

- **Merge & Push**: 2 minutes
- **Database Backup**: 1-2 minutes  
- **Apply Migrations**: 30 seconds
- **Rebuild Services**: 5-10 minutes
- **Startup & Testing**: 5 minutes

**Total**: ~15-20 minutes

---

## 📞 Support Checklist

Before asking for help, verify:
- [ ] All services show "Up" in `docker-compose ps`
- [ ] No errors in `docker-compose logs`
- [ ] Migrations completed successfully
- [ ] Database backup created
- [ ] .env.production file exists and has correct values

---

## 🎯 Success Criteria

✅ All 8 services running  
✅ User dashboard accessible  
✅ Admin dashboard accessible  
✅ Leaderboard shows 6 active members only  
✅ Organization filter settings work  
✅ No errors in logs for 10+ minutes  

Once all verified, deployment is successful! 🎉

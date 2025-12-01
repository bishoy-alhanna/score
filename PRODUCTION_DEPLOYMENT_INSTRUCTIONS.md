# 🚀 PRODUCTION DEPLOYMENT READY

## ✅ Local Machine - COMPLETED

1. ✅ **Code Merged**: pre-prod-dev → prod branch  
2. ✅ **Pushed to GitHub**: `prod` branch updated with all changes  
3. ✅ **Migration Script**: `apply-production-migrations.sql` created  
4. ✅ **Deployment Script**: `production-deploy-server.sh` created  

---

## 📦 What's Being Deployed

**Features:**
- ✅ Organization membership filter (shows only active members)
- ✅ Organization-wide date filter settings
- ✅ Leaderboard improvements
- ✅ User scores management
- ✅ All tested and working on pre-prod

**Database Changes:**
- Organizations: `filter_enabled`, `filter_start_date`, `filter_end_date`
- User Organizations: `is_active`, `role`
- Performance indexes

**Expected Results:**
- Leaderboard shows 6 active members (not 8)
- Test3 filtered out (no membership)
- Bfawzy filtered out (is_active=false)

---

## 🎯 DEPLOY NOW - 3 Simple Steps

### Step 1: Copy Files to Server (from your Mac)

```bash
scp apply-production-migrations.sql production-deploy-server.sh \
  root@escore.al-hanna.com:/root/score/
```

### Step 2: SSH to Production

```bash
ssh root@escore.al-hanna.com
cd /root/score
```

### Step 3: Run Deployment Script

```bash
./production-deploy-server.sh
```

**That's it!** The script will automatically:
1. Backup database
2. Pull latest code
3. Apply migrations
4. Rebuild services
5. Restart everything
6. Show status

**Time:** ~15-20 minutes

---

## 🔧 OR: Manual Deployment

```bash
ssh root@escore.al-hanna.com
cd /root/score

# 1. Backup
./backup-database.sh

# 2. Pull code
git pull origin prod

# 3. Migrate database
docker-compose -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d saas_platform < apply-production-migrations.sql

# 4. Rebuild
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d

# 5. Check
sleep 30
docker-compose -f docker-compose.prod.yml ps
```

---

## ✅ Verification

**Check Services:**
```bash
docker-compose -f docker-compose.prod.yml ps
# All should show "Up"
```

**Test:**
1. https://escore.al-hanna.com (user dashboard)
2. https://admin.escore.al-hanna.com (admin dashboard)
3. Verify leaderboard shows 6 active members
4. Check organization filter settings work

**Monitor:**
```bash
docker-compose -f docker-compose.prod.yml logs -f leaderboard-service
```

---

## 🎉 Success Criteria

- [ ] All 8 services running
- [ ] User dashboard accessible
- [ ] Admin dashboard accessible  
- [ ] Leaderboard shows 6 members (Test3 & Bfawzy filtered)
- [ ] Organization filters work
- [ ] No errors in logs

**Once verified: DEPLOYMENT SUCCESSFUL!**

---

## 📞 Need Help?

**Service won't start:**
```bash
docker-compose -f docker-compose.prod.yml logs <service-name>
docker-compose -f docker-compose.prod.yml restart <service-name>
```

**Rollback:**
```bash
ls -lh backups/
./restore-database.sh backups/<latest-backup>.sql.gz
git checkout <previous-commit>
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
```

---

**Ready to deploy! 🚀**

See `DEPLOYMENT_QUICK_REFERENCE.md` for detailed guide.

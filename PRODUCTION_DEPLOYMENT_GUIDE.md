# 🚀 Production Deployment Guide - escore.al-hanna.com

## Complete Production Setup Steps

### Prerequisites ✅

Before deploying, ensure you have:
- [x] Server with Ubuntu/Debian Linux
- [x] Docker and Docker Compose installed
- [x] Domain `escore.al-hanna.com` pointing to server IP
- [x] Ports 80, 443, 5432 open in firewall
- [x] SSH access as root

---

## 1️⃣ First-Time Production Setup

### Step 1: Clone Repository
```bash
ssh root@escore.al-hanna.com

cd /root
git clone https://github.com/bishoy-alhanna/score.git
cd score
```

### Step 2: Update Configuration
```bash
# Update email in SSL setup script
nano scripts/setup-ssl.sh
# Change: EMAIL="your-email@example.com" to your actual email
```

### Step 3: Setup SSL Certificate (One-Time)
```bash
chmod +x scripts/setup-ssl.sh
sudo ./scripts/setup-ssl.sh
```

This will:
- Install certbot
- Obtain Let's Encrypt SSL certificate for `escore.al-hanna.com`
- Configure auto-renewal (90 days)
- Set up cron job for automatic renewal

### Step 4: Setup Database (One-Time)
```bash
chmod +x scripts/reset-database.sh

# Start PostgreSQL first
docker-compose up -d postgres
sleep 10

# Initialize database with demo data
./scripts/reset-database.sh
# Type: DELETE ALL DATA when prompted
```

### Step 5: Build and Start All Services
```bash
# Build all containers
docker-compose build

# Start all services
docker-compose up -d

# Check status
docker-compose ps
```

### Step 6: Verify Deployment
```bash
# Check nginx logs
docker-compose logs nginx | tail -50

# Check API Gateway
curl https://escore.al-hanna.com/api/health

# Visit in browser:
# - https://escore.al-hanna.com/ (User Dashboard)
# - https://escore.al-hanna.com/admin/ (Admin Dashboard)
# - https://escore.al-hanna.com/clear-cache.html (Cache Clearer)
```

---

## 2️⃣ Regular Updates/Deployments

### Quick Update Script
Use this for deploying code changes:

```bash
ssh root@escore.al-hanna.com
cd /root/score
git pull
docker-compose build admin-dashboard user-dashboard nginx
docker-compose up -d
```

Or use the automated script:
```bash
# From your local machine
./scripts/deploy-production.sh
```

### What Gets Updated:
- ✅ Frontend (Admin & User Dashboards) - 5-second loading timeout
- ✅ Nginx config - SSL, reverse proxy, cache clearing page
- ✅ Backend services (if code changed)

### Services NOT Rebuilt (for speed):
- PostgreSQL (data persists)
- Redis (cache)

---

## 3️⃣ Troubleshooting

### Issue: Loading Screen Won't Go Away

**Solution 1: Clear Browser Cache**
```
Visit: https://escore.al-hanna.com/clear-cache.html
```

**Solution 2: Hard Refresh**
```
Chrome/Firefox: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
```

**Solution 3: Manual Cache Clear**
```javascript
// In browser console (F12)
localStorage.clear();
sessionStorage.clear();
location.reload();
```

### Issue: Nginx Won't Start

**Check SSL Certificates**
```bash
sudo certbot certificates
ls -la /etc/letsencrypt/live/escore.al-hanna.com/
```

**If certificates missing, re-run SSL setup:**
```bash
./scripts/setup-ssl.sh
```

**Check nginx logs:**
```bash
docker-compose logs nginx
```

### Issue: Database Connection Failed

**Check if PostgreSQL is running:**
```bash
docker-compose ps postgres
docker-compose logs postgres | tail -50
```

**Restart PostgreSQL:**
```bash
docker-compose restart postgres
```

**Reset database (WARNING: deletes all data):**
```bash
./scripts/reset-database.sh
```

### Issue: Frontend Not Updating After Deployment

**Rebuild without cache:**
```bash
docker-compose build --no-cache admin-dashboard user-dashboard
docker-compose up -d
```

**Check container creation time:**
```bash
docker-compose ps
# Look at "Created" column - should be recent
```

**View frontend logs:**
```bash
docker-compose logs admin-dashboard | tail -50
docker-compose logs user-dashboard | tail -50
```

---

## 4️⃣ SSL Certificate Management

### Check Certificate Status
```bash
sudo certbot certificates
```

### Manual Renewal (if needed)
```bash
sudo certbot renew
docker-compose restart nginx
```

### Auto-Renewal Setup
Certificate auto-renews via cron job (set up by setup-ssl.sh):
- Runs twice daily: 00:00 and 12:00
- Nginx auto-restarts after renewal
- Certificate valid for 90 days

### Test Renewal (Dry Run)
```bash
sudo certbot renew --dry-run
```

---

## 5️⃣ Monitoring

### Check All Services Status
```bash
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f nginx
docker-compose logs -f api-gateway
docker-compose logs -f admin-dashboard
docker-compose logs -f user-dashboard

# Last 100 lines
docker-compose logs --tail=100 api-gateway
```

### Check Health Endpoints
```bash
# Nginx health
curl https://escore.al-hanna.com/health

# API Gateway health
curl https://escore.al-hanna.com/api/health

# Database connection
docker exec saas_postgres psql -U postgres -d saas_platform -c "SELECT COUNT(*) FROM users;"
```

### Disk Space
```bash
df -h
docker system df
```

### Clean Up Old Images
```bash
docker system prune -a
# WARNING: This removes unused images and containers
```

---

## 6️⃣ Backup & Recovery

### Backup Database
```bash
docker exec saas_postgres pg_dump -U postgres saas_platform > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore Database
```bash
# Stop services
docker-compose stop api-gateway auth-service user-service group-service scoring-service leaderboard-service

# Restore
cat backup_20241115_120000.sql | docker exec -i saas_postgres psql -U postgres -d saas_platform

# Restart services
docker-compose up -d
```

### Backup Uploaded Files
```bash
docker run --rm -v score_profile_pictures:/data -v $(pwd):/backup alpine tar czf /backup/profile_pictures_backup_$(date +%Y%m%d).tar.gz /data
```

---

## 7️⃣ Performance Tuning

### Check Resource Usage
```bash
docker stats
```

### Restart All Services
```bash
docker-compose restart
```

### Restart Specific Service
```bash
docker-compose restart admin-dashboard
docker-compose restart api-gateway
```

### Scale Services (if needed)
```bash
# Not configured yet - requires load balancer setup
```

---

## 8️⃣ Security

### Firewall Configuration
```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP (redirects to HTTPS)
sudo ufw allow 80/tcp

# Allow HTTPS
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable
sudo ufw status
```

### Update System
```bash
sudo apt update
sudo apt upgrade -y
```

### Docker Security
```bash
# Run containers as non-root user (TODO: configure in docker-compose.yml)
# Use secrets for sensitive data (TODO: implement Docker secrets)
```

---

## 9️⃣ Quick Reference

### Important URLs
- **User Dashboard**: https://escore.al-hanna.com/
- **Admin Dashboard**: https://escore.al-hanna.com/admin/
- **API Gateway**: https://escore.al-hanna.com/api/
- **Health Check**: https://escore.al-hanna.com/health
- **Clear Cache**: https://escore.al-hanna.com/clear-cache.html

### Important Paths
- **Project**: `/root/score`
- **SSL Certs**: `/etc/letsencrypt/live/escore.al-hanna.com/`
- **Database Data**: Docker volume `score_postgres_data`
- **Uploads**: Docker volume `score_profile_pictures`

### Default Credentials (Demo Data)
- **Super Admin**: `admin` / `password123`
- **Org Admin**: `john.admin` / `password123`
- **Regular User**: `john.doe` / `password123`

⚠️ **Change these passwords immediately after first login!**

---

## 🔟 Deployment Checklist

Before deploying to production:

- [ ] SSL certificate is valid and not expired
- [ ] Database backup created
- [ ] Git changes committed and pushed
- [ ] Local testing completed
- [ ] All containers building successfully
- [ ] Environment variables configured
- [ ] Firewall rules configured
- [ ] Health endpoints responding
- [ ] Admin can login
- [ ] User can login
- [ ] File upload works
- [ ] API endpoints functional

---

## 📞 Emergency Contacts

If deployment fails:
1. Check logs: `docker-compose logs -f`
2. Check status: `docker-compose ps`
3. Review this guide
4. Contact system administrator

---

## 📝 Change Log

### 2024-11-15
- Added 5-second loading timeout to prevent infinite loading
- Added cache clearing page at `/clear-cache.html`
- Updated nginx configuration
- Added production deployment script

### Previous
- Initial production setup
- SSL configuration
- Multi-organization support
- Database schema updates

---

**Last Updated**: November 15, 2024  
**Deployment Target**: https://escore.al-hanna.com  
**Production Server**: root@escore.al-hanna.com

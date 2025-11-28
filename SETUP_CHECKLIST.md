# Score Platform - Quick Setup Checklist

Use this checklist to ensure all prerequisites and setup steps are completed.

## ✅ Prerequisites Checklist

- [ ] **macOS Big Sur 11.0 or later**
- [ ] **At least 8GB RAM** (16GB recommended)
- [ ] **At least 10GB free disk space**
- [ ] **Internet connection** for downloading packages

## ✅ Installation Checklist

### Step 1: Prerequisites Installation

Run: `bash setup-prerequisites.sh`

- [ ] Homebrew installed
- [ ] Docker Desktop installed
- [ ] Docker Desktop is running (whale icon in menu bar)
- [ ] Python 3.11+ installed
- [ ] pip3 available
- [ ] Node.js 18+ installed
- [ ] npm available
- [ ] Git installed

**Verify:**
```bash
brew --version
docker --version
docker ps  # Should not error
python3 --version
pip3 --version
node --version
npm --version
git --version
```

### Step 2: Project Initialization

Run: `bash init-project.sh`

- [ ] .env.production file created
- [ ] .env.production file edited with secure passwords
- [ ] Frontend dependencies installed (optional)
- [ ] Docker containers built
- [ ] All services started
- [ ] Database initialized

**Verify:**
```bash
docker-compose -f docker-compose.prod.yml ps
# All services should show "Up" status
```

### Step 3: Post-Installation

- [ ] Admin dashboard accessible at http://localhost:3001
- [ ] User dashboard accessible at http://localhost:3000
- [ ] API gateway responding at http://localhost:5000
- [ ] Super admin user created (`bash create-super-admin.sh`)
- [ ] Can login to admin dashboard
- [ ] Can create an organization

## ✅ Service Health Check

Run: `bash check-services.sh` or check manually:

- [ ] postgres (Port 5432) - Database
- [ ] redis (Port 6379) - Cache
- [ ] auth-service (Port 5001) - Authentication
- [ ] user-service (Port 5002) - User management
- [ ] group-service (Port 5003) - Group management
- [ ] scoring-service (Port 5004) - Score management
- [ ] leaderboard-service (Port 5005) - Leaderboards
- [ ] api-gateway (Port 5000) - API Gateway
- [ ] admin-dashboard (Port 3001) - Admin UI
- [ ] user-dashboard (Port 3000) - User UI

**Quick test:**
```bash
curl http://localhost:5000/health
# Should return health status
```

## ✅ Environment Configuration

Edit `.env.production` and verify:

- [ ] POSTGRES_PASSWORD is set (not default)
- [ ] JWT_SECRET_KEY is set (not default)
- [ ] SECRET_KEY is set (not default)
- [ ] All service URLs are correct
- [ ] Database credentials are correct

**Security Note:** Never use default passwords in production!

## ✅ Database Verification

- [ ] Database is running
- [ ] Tables are created
- [ ] Can connect to database

**Test:**
```bash
docker exec score_postgres_prod psql -U postgres -d saas_platform -c "\dt"
# Should list all tables
```

## ✅ Troubleshooting Quick Fixes

### If Docker is not running:
```bash
# Open Docker Desktop from Applications
open -a Docker
# Wait for whale icon in menu bar
```

### If containers won't start:
```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs

# Restart services
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d
```

### If frontend won't load:
```bash
# Check container status
docker-compose -f docker-compose.prod.yml ps

# Rebuild frontend containers
docker-compose -f docker-compose.prod.yml up -d --build admin-dashboard user-dashboard
```

### If database connection fails:
```bash
# Wait for database (takes ~10 seconds)
sleep 15

# Check if database is ready
docker-compose -f docker-compose.prod.yml logs postgres | grep "ready to accept connections"
```

## ✅ First Use Setup

After installation is complete:

1. **Create Super Admin** (if not done)
   ```bash
   bash create-super-admin.sh
   ```

2. **Login to Admin Dashboard**
   - URL: http://localhost:3001
   - Use credentials from create-super-admin.sh

3. **Create First Organization**
   - Dashboard → Organizations → Add Organization
   - Fill in organization details
   - Save

4. **Add Users**
   - Dashboard → Users → Add User
   - Assign to organization
   - Set role (Admin/User)

5. **Configure Categories**
   - Dashboard → Settings → Categories
   - Add scoring categories
   - Set point values

6. **Test User Dashboard**
   - URL: http://localhost:3000
   - Login as regular user
   - View leaderboard

## ✅ Production Deployment Checklist

Before deploying to production:

- [ ] Change all default passwords in .env.production
- [ ] Generate strong JWT_SECRET_KEY
- [ ] Generate strong SECRET_KEY
- [ ] Configure proper database backups
- [ ] Set up SSL/TLS certificates
- [ ] Configure firewall rules
- [ ] Set up monitoring and logging
- [ ] Test all features thoroughly
- [ ] Document admin credentials securely
- [ ] Set up domain names
- [ ] Configure email notifications (if applicable)

## 📝 Important Notes

- **Security**: Always change default passwords before production use
- **Backups**: Set up regular database backups
- **Updates**: Keep Docker images and dependencies updated
- **Logs**: Monitor service logs for errors
- **Performance**: Monitor resource usage (CPU, RAM, Disk)

## 🆘 Need Help?

1. Check SETUP_GUIDE.md for detailed instructions
2. Review service logs: `docker-compose -f docker-compose.prod.yml logs -f`
3. Check GitHub issues
4. Contact development team

---

**Installation Date**: _________________

**Installed By**: _________________

**Notes**: 
_____________________________________________
_____________________________________________
_____________________________________________

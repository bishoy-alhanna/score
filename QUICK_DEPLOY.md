# Production Deployment - Quick Start Guide

## 🚀 Ready to Deploy

The `prod` branch is now configured and ready for deployment to production.

## Production URLs
- **User Dashboard**: https://escore.al-hanna.com
- **Admin Dashboard**: https://admin.escore.al-hanna.com

## Prerequisites Checklist

Before deploying, ensure:
- [ ] DNS records configured:
  - `escore.al-hanna.com` → Your server IP
  - `admin.escore.al-hanna.com` → Your server IP
- [ ] Server has Docker & Docker Compose installed
- [ ] Ports 80 and 443 are open
- [ ] You have SSH access to the production server

## Deployment Commands

### On Production Server:

```bash
# 1. Clone the repository
git clone https://github.com/bishoy-alhanna/score.git
cd score
git checkout prod

# 2. Configure environment
cp .env.production.example .env.production
nano .env.production  # Update passwords and secrets!

# 3. Set up SSL certificates (Let's Encrypt)
sudo apt update && sudo apt install certbot
sudo certbot certonly --standalone -d escore.al-hanna.com -d admin.escore.al-hanna.com
sudo mkdir -p nginx/ssl
sudo cp /etc/letsencrypt/live/escore.al-hanna.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/escore.al-hanna.com/privkey.pem nginx/ssl/key.pem
sudo chown -R $USER:$USER nginx/ssl

# 4. Deploy!
chmod +x deploy-production.sh
./deploy-production.sh
```

## What Gets Deployed

### Backend Services:
- ✅ PostgreSQL Database (port 5432)
- ✅ Redis Cache (port 6379)
- ✅ Auth Service (JWT authentication)
- ✅ User Service (user management)
- ✅ Group Service (group management with member details)
- ✅ Scoring Service (scoring system)
- ✅ Leaderboard Service (rankings)
- ✅ API Gateway (unified API endpoint)

### Frontend Applications:
- ✅ Admin Dashboard (React 18 + Vite)
- ✅ User Dashboard (React 18 + Vite)

### Infrastructure:
- ✅ Nginx Reverse Proxy (ports 80 & 443)
- ✅ SSL/TLS Certificates (HTTPS)
- ✅ Health checks for all services
- ✅ Auto-restart on failure

## Environment Variables to Update

**CRITICAL** - Update these in `.env.production`:

```bash
# Database
POSTGRES_PASSWORD=<CHANGE_THIS_STRONG_PASSWORD>

# Redis
REDIS_PASSWORD=<CHANGE_THIS_STRONG_PASSWORD>

# Security (Generate with: openssl rand -hex 32)
JWT_SECRET_KEY=<GENERATE_NEW_32_CHAR_SECRET>
SECRET_KEY=<GENERATE_NEW_32_CHAR_SECRET>

# Super Admin
SUPER_ADMIN_USERNAME=<YOUR_ADMIN_USERNAME>
SUPER_ADMIN_PASSWORD=<YOUR_STRONG_PASSWORD>

# SMTP (Email notifications)
SMTP_USER=Noreply@al-hanna.com
SMTP_PASSWORD=<YOUR_SMTP_PASSWORD>
```

## Post-Deployment Verification

```bash
# Check all services are running
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Test URLs
curl https://escore.al-hanna.com
curl https://admin.escore.al-hanna.com

# Test API
curl https://escore.al-hanna.com/api/health
```

## Monitoring

```bash
# View real-time logs
docker-compose -f docker-compose.prod.yml logs -f

# Check specific service
docker-compose -f docker-compose.prod.yml logs -f group-service
docker-compose -f docker-compose.prod.yml logs -f api-gateway

# Check resource usage
docker stats
```

## Common Commands

```bash
# Restart all services
docker-compose -f docker-compose.prod.yml restart

# Restart specific service
docker-compose -f docker-compose.prod.yml restart nginx

# Pull latest updates
git pull origin prod
./deploy-production.sh

# Stop everything
docker-compose -f docker-compose.prod.yml down

# Backup database
docker exec score_postgres_prod pg_dump -U postgres saas_platform > backup_$(date +%Y%m%d).sql
```

## Rollback

If something goes wrong:

```bash
# Stop current deployment
docker-compose -f docker-compose.prod.yml down

# Go back to previous version
git log  # Find previous commit
git checkout <previous-commit-hash>

# Redeploy
./deploy-production.sh
```

## Support

For detailed deployment instructions, see:
- **PRODUCTION_DEPLOYMENT.md** - Complete deployment guide
- **docker-compose.prod.yml** - Production configuration
- **deploy-production.sh** - Automated deployment script

## Security Reminders

- ✅ Change all default passwords
- ✅ Use strong JWT secrets (32+ characters)
- ✅ Keep SSL certificates up to date
- ✅ Set up firewall rules (UFW)
- ✅ Regular backups (automated daily)
- ✅ Monitor logs for suspicious activity

## Database Schema

The database is automatically initialized with:
- Users table
- Organizations table (multi-tenancy)
- Groups table
- Group members table (with user details)
- Scoring tables
- Leaderboard tables

## Features Ready for Production

✅ **Authentication & Authorization**
- JWT-based authentication
- Multi-organization support
- Role-based access control (ADMIN, MEMBER)

✅ **Group Management** (Just Fixed!)
- Create/edit/delete groups
- Add/remove members with user details display
- Member roles (ADMIN, MEMBER)
- Member information properly displayed in UI

✅ **User Management**
- User profiles
- Organization membership
- Profile pictures

✅ **Scoring System**
- Score tracking
- Leaderboards
- Rankings

✅ **Dashboards**
- Admin dashboard (admin.escore.al-hanna.com)
- User dashboard (escore.al-hanna.com)
- Responsive design
- Multi-language support (i18n)

---

**Ready to deploy?** Follow the deployment commands above! 🚀

**Questions?** Check PRODUCTION_DEPLOYMENT.md for detailed information.

**Last Updated**: November 16, 2025  
**Branch**: prod  
**Domains**: escore.al-hanna.com, admin.escore.al-hanna.com

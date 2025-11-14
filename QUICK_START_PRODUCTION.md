# Quick Start Guide - Production Deployment

This guide helps you get the Score platform running on your production server at **escore.al-hanna.com**.

## 🚀 Initial Server Setup (Ubuntu)

If you're setting up a fresh Ubuntu server, run these commands:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Node.js 20.x LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install pnpm
npm install -g pnpm

# Install Python 3 and pip
sudo apt install -y python3 python3-pip python3-venv

# Install PostgreSQL client (for database management)
sudo apt install -y postgresql-client

# Install Redis client
sudo apt install -y redis-tools

# Install certbot for SSL
sudo apt install -y certbot

# Verify installations
docker --version
docker compose version
node --version
npm --version
pnpm --version
python3 --version
certbot --version
```

## 📦 Deploy Application

```bash
# Clone/upload your code to the server
cd /root/score  # or wherever your code is

# Build and start services
docker-compose up -d

# Check all services are running
docker-compose ps
```

## 🔒 Setup SSL Certificate

Run the automated SSL setup script:

```bash
cd /root/score
./scripts/setup-ssl.sh
```

This will:
- Stop Docker containers temporarily
- Obtain SSL certificate from Let's Encrypt
- Configure auto-renewal
- Restart containers with HTTPS enabled

**Note:** Make sure DNS is pointing to your server before running this!

## 💾 Initialize Database

**First Time Setup:**

```bash
cd /root/score
./scripts/init-database.sh
# Select option 1 (Initialize database)
```

This creates all tables and sets up the default admin user:
- **Username:** `admin`
- **Email:** `admin@score.com`
- **Password:** `admin123`

⚠️ **IMPORTANT:** Change the admin password immediately after first login!

## 🔧 Troubleshooting

### Issue: Infinite Loading Screen

**Cause:** Browser has old authentication token that's failing verification.

**Solution:**
1. Open browser console (F12)
2. Run: `localStorage.clear(); location.reload()`
3. You should now see the login page

### Issue: Port 80 Already in Use

**Cause:** System nginx is running on port 80.

**Solution:**
```bash
sudo systemctl stop nginx
sudo systemctl disable nginx
docker-compose restart nginx
```

### Issue: SSL Certificate Errors

**Cause:** Certificates expired or not properly configured.

**Solution:**
```bash
# Test renewal
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# Restart nginx
docker-compose restart nginx
```

### Issue: Database Connection Errors

**Cause:** PostgreSQL container not running or database not initialized.

**Solution:**
```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Start if stopped
docker-compose up -d postgres

# Initialize database if needed
./scripts/init-database.sh
```

### Issue: Can't Login with Admin Credentials

**Cause:** Database not properly initialized or user doesn't exist.

**Solution:**
```bash
# Reset database (WARNING: Deletes all data!)
./scripts/init-database.sh
# Select option 2 (Reset database)
# Type RESET to confirm
```

## 📍 Access Points

After successful deployment:

- **User Dashboard:** https://escore.al-hanna.com/
- **Admin Dashboard:** https://escore.al-hanna.com/admin/
- **API Health Check:** https://escore.al-hanna.com/api/health
- **API Base:** https://escore.al-hanna.com/api/

## 🔑 Default Credentials

**Admin User:**
- Username: `admin`
- Email: `admin@score.com`
- Password: `admin123`

**Default Organization:**
- Name: `Default Organization`
- UUID: `11111111-1111-1111-1111-111111111111`

## 🛡️ Security Checklist

After deployment, make sure to:

- [ ] Change admin password
- [ ] Update environment variables in docker-compose.yml
- [ ] Set strong JWT_SECRET
- [ ] Set strong database password
- [ ] Configure firewall (ufw)
- [ ] Enable fail2ban for SSH protection
- [ ] Set up regular database backups
- [ ] Review nginx security headers
- [ ] Configure rate limiting

## 📊 Monitoring

### Check Service Health

```bash
# All containers
docker-compose ps

# View logs
docker-compose logs -f

# Check specific service
docker-compose logs -f api-gateway
docker-compose logs -f postgres

# Check API health
curl https://escore.al-hanna.com/api/health
```

### Database Backup

```bash
# Manual backup
./scripts/init-database.sh
# Select option 3 (Backup database)

# Backups are saved to: database/backups/
```

## 🆘 Emergency Commands

### Restart Everything

```bash
docker-compose down
docker-compose up -d
```

### View All Logs

```bash
docker-compose logs -f --tail=100
```

### Connect to Database

```bash
docker exec -it saas_postgres psql -U postgres -d saas_platform
```

### Clear All Data and Start Fresh

```bash
# WARNING: This deletes EVERYTHING!
docker-compose down -v  # -v removes volumes
./scripts/init-database.sh  # Select option 1
```

## 📝 Additional Resources

- **SSL Setup Guide:** See `SSL_SETUP_GUIDE.md`
- **API Documentation:** See `API_DOCUMENTATION.md`
- **Database Schema:** See `database/init_complete_schema.sql`
- **Deployment Details:** See `DEPLOYMENT.md`

## 🎯 Quick Test After Deployment

1. **Test HTTPS:** `curl -I https://escore.al-hanna.com`
   - Should return 200 OK
   - Should show SSL certificate info

2. **Test API:** `curl https://escore.al-hanna.com/api/health`
   - Should return: `{"service":"api-gateway","status":"healthy"}`

3. **Test Admin Dashboard:** Open https://escore.al-hanna.com/admin/
   - Should show login page (not infinite loading)
   - Login with admin/admin123
   - Should access admin dashboard

4. **Test User Dashboard:** Open https://escore.al-hanna.com/
   - Should show login page
   - Can create new user or login

## 🔄 Updates and Maintenance

### Pull Latest Code

```bash
cd /root/score
git pull
docker-compose down
docker-compose build
docker-compose up -d
```

### Update SSL Certificate

Certificates auto-renew via cron job. To manually renew:

```bash
sudo certbot renew
docker-compose restart nginx
```

### Database Migration

If schema changes are needed:

```bash
# Backup first!
./scripts/init-database.sh  # Option 3

# Apply migration
docker exec -i saas_postgres psql -U postgres -d saas_platform < database/migration_file.sql
```

---

**Need Help?** Check the logs: `docker-compose logs -f`

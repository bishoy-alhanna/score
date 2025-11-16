# Production Deployment Guide

## 📋 Pre-Deployment Checklist

### 1. Server Requirements
- **OS**: Ubuntu 20.04 LTS or later (recommended)
- **CPU**: Minimum 4 cores (8+ recommended)
- **RAM**: Minimum 8GB (16GB+ recommended)
- **Storage**: Minimum 50GB SSD
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+

### 2. Domain Configuration
Ensure you have configured DNS records for:
- `escore.al-hanna.com` → Your server IP
- `admin.escore.al-hanna.com` → Your server IP

## 🚀 Deployment Steps

### Step 1: Clone the Repository

```bash
# SSH into your production server
ssh user@your-server-ip

# Clone the repository
git clone https://github.com/bishoy-alhanna/score.git
cd score

# Checkout the production branch
git checkout prod
```

### Step 2: Configure Environment Variables

```bash
# Copy the production environment template
cp .env.production.example .env.production

# Edit the production environment file
nano .env.production
```

**Required Changes in `.env.production`:**

```bash
# Database Configuration
POSTGRES_PASSWORD=YOUR_STRONG_DATABASE_PASSWORD_HERE

# Redis Configuration  
REDIS_PASSWORD=YOUR_STRONG_REDIS_PASSWORD_HERE

# Security Keys (CRITICAL - Generate unique values)
JWT_SECRET_KEY=$(openssl rand -hex 32)
SECRET_KEY=$(openssl rand -hex 32)

# Super Admin (Change these!)
SUPER_ADMIN_USERNAME=your_admin_username
SUPER_ADMIN_PASSWORD=your_strong_password

# SMTP Configuration (for email notifications)
SMTP_HOST=smtp.office365.com
SMTP_PORT=587
SMTP_USER=Noreply@al-hanna.com
SMTP_PASSWORD=YOUR_SMTP_PASSWORD
SMTP_FROM_EMAIL=noreply@al-hanna.com

# Domain Configuration
DOMAIN_NAME=escore.al-hanna.com
ADMIN_SUBDOMAIN=admin.escore.al-hanna.com
USER_SUBDOMAIN=escore.al-hanna.com
```

### Step 3: Set Up SSL Certificates

#### Option A: Using Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt update
sudo apt install certbot

# Generate SSL certificates
sudo certbot certonly --standalone -d escore.al-hanna.com -d admin.escore.al-hanna.com

# Copy certificates to project
sudo mkdir -p nginx/ssl
sudo cp /etc/letsencrypt/live/escore.al-hanna.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/escore.al-hanna.com/privkey.pem nginx/ssl/key.pem
sudo chown -R $USER:$USER nginx/ssl
```

#### Option B: Using Existing Certificates

```bash
# Create SSL directory
mkdir -p nginx/ssl

# Copy your certificates
cp /path/to/your/cert.pem nginx/ssl/cert.pem
cp /path/to/your/key.pem nginx/ssl/key.pem
```

### Step 4: Configure Nginx

The nginx configuration is already set up in `nginx/nginx.conf`. Verify it matches your domain:

```bash
# Check nginx configuration
cat nginx/nginx.conf | grep server_name

# Should show:
# server_name escore.al-hanna.com;
# server_name admin.escore.al-hanna.com;
```

### Step 5: Deploy the Application

```bash
# Make deployment script executable
chmod +x deploy-production.sh

# Run the deployment script
./deploy-production.sh
```

The script will:
1. Pull latest code from prod branch
2. Stop existing containers
3. Build Docker images
4. Start all services
5. Perform health checks
6. Show logs

### Step 6: Verify Deployment

```bash
# Check running containers
docker-compose -f docker-compose.prod.yml ps

# All services should be "healthy"

# Check logs
docker-compose -f docker-compose.prod.yml logs -f

# Test endpoints
curl https://escore.al-hanna.com
curl https://admin.escore.al-hanna.com
```

### Step 7: Initialize Database (First Time Only)

The database schema is automatically initialized on first run. To verify:

```bash
# Connect to database
docker exec -it score_postgres_prod psql -U postgres -d saas_platform

# List tables
\dt

# You should see: users, organizations, groups, group_members, etc.

# Exit
\q
```

### Step 8: Create First Organization (Optional)

```bash
# Access the API gateway container
docker exec -it score_api_gateway_prod bash

# Run Python script to create organization
python -c "
from src.utils.db import create_organization
org = create_organization(
    name='Tech University',
    domain='tech.edu',
    admin_email='admin@tech.edu'
)
print(f'Organization created: {org}')
"
```

## 🔧 Post-Deployment Configuration

### Set Up Automated Backups

```bash
# Create backup script
cat > backup-database.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/score"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

docker exec score_postgres_prod pg_dump -U postgres saas_platform | gzip > $BACKUP_DIR/score_backup_$DATE.sql.gz

# Keep only last 7 days of backups
find $BACKUP_DIR -name "score_backup_*.sql.gz" -mtime +7 -delete
EOF

chmod +x backup-database.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /path/to/backup-database.sh") | crontab -
```

### Configure SSL Auto-Renewal

```bash
# Add Let's Encrypt renewal to crontab
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && docker-compose -f /path/to/score/docker-compose.prod.yml restart nginx") | crontab -
```

### Set Up Monitoring (Optional)

```bash
# Install monitoring tools
docker run -d \
  --name=prometheus \
  -p 9090:9090 \
  -v /path/to/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

docker run -d \
  --name=grafana \
  -p 3000:3000 \
  grafana/grafana
```

## 📊 Maintenance Commands

### Update Application

```bash
# Pull latest changes
git pull origin prod

# Rebuild and restart
./deploy-production.sh
```

### View Logs

```bash
# All services
docker-compose -f docker-compose.prod.yml logs -f

# Specific service
docker-compose -f docker-compose.prod.yml logs -f auth-service
docker-compose -f docker-compose.prod.yml logs -f api-gateway
docker-compose -f docker-compose.prod.yml logs -f group-service
```

### Restart Services

```bash
# Restart all services
docker-compose -f docker-compose.prod.yml restart

# Restart specific service
docker-compose -f docker-compose.prod.yml restart nginx
docker-compose -f docker-compose.prod.yml restart api-gateway
```

### Stop Services

```bash
# Stop all services
docker-compose -f docker-compose.prod.yml down

# Stop and remove volumes (DANGER: This deletes data!)
docker-compose -f docker-compose.prod.yml down -v
```

### Database Management

```bash
# Backup database
docker exec score_postgres_prod pg_dump -U postgres saas_platform > backup.sql

# Restore database
docker exec -i score_postgres_prod psql -U postgres saas_platform < backup.sql

# Access database shell
docker exec -it score_postgres_prod psql -U postgres -d saas_platform
```

## 🔒 Security Best Practices

1. **Change Default Passwords**: Update all passwords in `.env.production`
2. **Firewall Configuration**: 
   ```bash
   # Allow only necessary ports
   sudo ufw allow 22/tcp   # SSH
   sudo ufw allow 80/tcp   # HTTP
   sudo ufw allow 443/tcp  # HTTPS
   sudo ufw enable
   ```
3. **Regular Updates**: Keep Docker images and system packages updated
4. **SSL/TLS**: Always use HTTPS in production
5. **Backup Strategy**: Regular automated backups
6. **Monitoring**: Set up alerts for service failures
7. **Access Control**: Limit SSH access, use key-based authentication

## 🚨 Troubleshooting

### Services Not Starting

```bash
# Check Docker daemon
sudo systemctl status docker

# Check container logs
docker-compose -f docker-compose.prod.yml logs

# Rebuild specific service
docker-compose -f docker-compose.prod.yml build --no-cache service-name
docker-compose -f docker-compose.prod.yml up -d service-name
```

### SSL Certificate Issues

```bash
# Verify certificate files exist
ls -la nginx/ssl/

# Test SSL configuration
openssl s_client -connect escore.al-hanna.com:443
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker-compose -f docker-compose.prod.yml ps postgres

# Test database connection
docker exec score_postgres_prod pg_isready -U postgres

# Check database logs
docker-compose -f docker-compose.prod.yml logs postgres
```

### High Memory Usage

```bash
# Check resource usage
docker stats

# Restart services
docker-compose -f docker-compose.prod.yml restart
```

## 📞 Support

For issues or questions:
- Check logs: `docker-compose -f docker-compose.prod.yml logs -f`
- Review this guide
- Contact system administrator

## 🔄 Rollback Procedure

If deployment fails:

```bash
# Stop current deployment
docker-compose -f docker-compose.prod.yml down

# Checkout previous working version
git log  # Find previous commit hash
git checkout <previous-commit-hash>

# Redeploy
./deploy-production.sh
```

---

**Last Updated**: November 16, 2025
**Version**: 1.0.0

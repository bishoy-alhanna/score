# Score Platform - Ubuntu Server Setup Guide

Complete guide for deploying Score Platform on Ubuntu Server (20.04, 22.04, or 24.04).

---

## Quick Start (Fresh Ubuntu Server)

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Clone repository
git clone https://github.com/bishoy-alhanna/score.git
cd score

# 3. Install prerequisites
sudo bash setup-prerequisites-ubuntu.sh

# 4. Log out and back in (for docker group changes)
exit
# SSH back in

# 5. Deploy the platform
sudo bash deploy-ubuntu.sh

# 6. Create super admin
bash create-super-admin.sh
```

**Done!** Access at `http://YOUR_SERVER_IP:3001`

---

## Detailed Setup Instructions

### Prerequisites

**Minimum Requirements:**
- Ubuntu Server 20.04 LTS or newer
- 2 CPU cores (4 recommended)
- 4GB RAM (8GB recommended)
- 20GB disk space (50GB recommended)
- Root or sudo access
- Internet connection

### Step 1: Install Prerequisites

The `setup-prerequisites-ubuntu.sh` script installs:

- ✅ Docker Engine (latest)
- ✅ Docker Compose V2
- ✅ Python 3.11
- ✅ Node.js 18.x
- ✅ PostgreSQL client
- ✅ Essential build tools
- ✅ System utilities (htop, git, curl, etc.)

**Run:**
```bash
sudo bash setup-prerequisites-ubuntu.sh
```

**After installation:**
- Log out and log back in (for docker group membership)
- Verify: `docker ps` (should work without sudo)

### Step 2: Deploy Application

The `deploy-ubuntu.sh` script:

- ✅ Creates `.env.production` with secure passwords
- ✅ Builds Docker containers
- ✅ Starts all services
- ✅ Sets up auto-start (systemd)
- ✅ Configures log rotation

**Run:**
```bash
sudo bash deploy-ubuntu.sh
```

**What it does:**
1. Checks prerequisites
2. Generates secure passwords automatically
3. Builds all Docker images
4. Starts PostgreSQL, Redis, and all services
5. Optionally sets up systemd for auto-start
6. Displays access URLs

---

## Docker Compose Commands

Ubuntu uses Docker Compose V2 (`docker compose` instead of `docker-compose`).

### Basic Commands

```bash
# Start all services
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# Stop all services
docker compose -f docker-compose.prod.yml down

# View logs
docker compose -f docker-compose.prod.yml logs -f

# View specific service logs
docker compose -f docker-compose.prod.yml logs -f auth-service

# Restart a service
docker compose -f docker-compose.prod.yml restart leaderboard-service

# Rebuild and restart a service
docker compose -f docker-compose.prod.yml up -d --build leaderboard-service

# Check service status
docker compose -f docker-compose.prod.yml ps

# Execute command in container
docker compose -f docker-compose.prod.yml exec postgres psql -U postgres
```

### Alias (Optional)

The setup script creates an alias for backwards compatibility:

```bash
# After setup, you can use either:
docker compose ...
# or
docker-compose ...  # (alias to docker compose)
```

---

## System Management

### Systemd Service

If you enabled auto-start during deployment:

```bash
# Check status
sudo systemctl status score-platform

# Start services
sudo systemctl start score-platform

# Stop services
sudo systemctl stop score-platform

# Restart services
sudo systemctl restart score-platform

# Disable auto-start
sudo systemctl disable score-platform

# Enable auto-start
sudo systemctl enable score-platform

# View service logs
sudo journalctl -u score-platform -f
```

### Resource Monitoring

```bash
# Monitor Docker containers
docker stats

# System resource usage
htop

# Disk usage
df -h
ncdu /var/lib/docker

# Check Docker disk usage
docker system df

# Clean up unused Docker resources
docker system prune -a
```

---

## Firewall Configuration

### Using UFW (Uncomplicated Firewall)

```bash
# Enable firewall
sudo ufw enable

# Allow SSH (IMPORTANT - do this first!)
sudo ufw allow 22/tcp

# Allow application ports
sudo ufw allow 3000/tcp  # User Dashboard
sudo ufw allow 3001/tcp  # Admin Dashboard
sudo ufw allow 5000/tcp  # API Gateway

# Allow HTTP/HTTPS (if using reverse proxy)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check status
sudo ufw status

# Deny a port
sudo ufw deny 5432/tcp  # PostgreSQL (if exposed)
```

### Production Firewall Rules

For production, only expose necessary ports:

```bash
# Allow only SSH and HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 443/tcp

# Use nginx reverse proxy for internal services
# This way, only port 443 is exposed to internet
```

---

## Database Management

### Backup Database

```bash
# Manual backup
docker exec score_postgres_prod pg_dump -U postgres saas_platform > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup with gzip compression
docker exec score_postgres_prod pg_dump -U postgres saas_platform | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Automated Backups

Create a cron job for automatic backups:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/score && docker exec score_postgres_prod pg_dump -U postgres saas_platform | gzip > backups/saas_platform_$(date +\%Y\%m\%d_\%H\%M\%S).sql.gz

# Keep only last 7 days of backups
0 3 * * * find /path/to/score/backups -name "*.sql.gz" -mtime +7 -delete
```

### Restore Database

```bash
# Using the restore script
bash restore-database.sh backups/backup_file.sql.gz

# Manual restore (compressed)
gunzip -c backup.sql.gz | docker exec -i score_postgres_prod psql -U postgres saas_platform

# Manual restore (uncompressed)
docker exec -i score_postgres_prod psql -U postgres saas_platform < backup.sql
```

---

## SSL/TLS Setup (Production)

### Using Nginx Reverse Proxy

**1. Install Nginx:**
```bash
sudo apt install nginx certbot python3-certbot-nginx -y
```

**2. Create Nginx config:**
```bash
sudo nano /etc/nginx/sites-available/score-platform
```

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**3. Enable site:**
```bash
sudo ln -s /etc/nginx/sites-available/score-platform /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

**4. Get SSL certificate:**
```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

---

## Troubleshooting

### Docker daemon not running

```bash
sudo systemctl status docker
sudo systemctl start docker
sudo systemctl enable docker
```

### Permission denied (docker socket)

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then verify
docker ps
```

### Port already in use

```bash
# Find process using port
sudo lsof -i :5432

# Kill process
sudo kill -9 PID

# Or change port in docker-compose.prod.yml
```

### Out of disk space

```bash
# Check disk usage
df -h

# Clean Docker resources
docker system prune -a --volumes

# Remove old images
docker image prune -a
```

### Container fails to start

```bash
# Check logs
docker compose -f docker-compose.prod.yml logs SERVICE_NAME

# Common issues:
# - Missing environment variables
# - Database not ready
# - Port conflicts
# - Insufficient memory
```

### Database connection refused

```bash
# Wait for database to initialize
docker compose -f docker-compose.prod.yml logs postgres | grep "ready"

# Usually takes 10-30 seconds on first start
```

---

## Maintenance Tasks

### Daily Tasks
- Monitor service status
- Check disk space
- Review error logs

### Weekly Tasks
- Review application logs
- Check database size
- Monitor resource usage

### Monthly Tasks
- Update system packages: `sudo apt update && sudo apt upgrade`
- Rotate logs manually if needed
- Review and optimize database
- Check backup integrity

### Security Updates

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Rebuild containers with latest base images
docker compose -f docker-compose.prod.yml build --pull
docker compose -f docker-compose.prod.yml up -d
```

---

## Performance Optimization

### Increase Docker Resources

Edit `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    {
      "base": "172.80.0.0/16",
      "size": 24
    }
  ]
}
```

Restart Docker:
```bash
sudo systemctl restart docker
```

### Database Tuning

Increase PostgreSQL memory:

```yaml
# In docker-compose.prod.yml
postgres:
  command: >
    postgres
    -c shared_buffers=256MB
    -c max_connections=200
    -c work_mem=16MB
```

---

## Useful Commands Reference

```bash
# System
sudo systemctl status score-platform
sudo journalctl -u score-platform -f
htop

# Docker
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f
docker stats
docker system df

# Database
docker exec -it score_postgres_prod psql -U postgres -d saas_platform
docker exec score_postgres_prod pg_dump -U postgres saas_platform > backup.sql

# Cleanup
docker compose -f docker-compose.prod.yml down
docker system prune -a
docker volume prune

# Updates
git pull origin main
docker compose -f docker-compose.prod.yml up -d --build
```

---

## Support

For issues:
1. Check logs: `docker compose -f docker-compose.prod.yml logs`
2. Review this guide
3. Check GitHub issues
4. Contact support team

---

## Additional Resources

- Docker Documentation: https://docs.docker.com
- Docker Compose: https://docs.docker.com/compose
- Ubuntu Server Guide: https://ubuntu.com/server/docs
- PostgreSQL Docs: https://www.postgresql.org/docs
- Nginx Documentation: https://nginx.org/en/docs

---

**Last Updated:** November 28, 2025

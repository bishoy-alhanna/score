# Score Platform - Setup Scripts Reference

Quick reference for all installation and deployment scripts across different platforms.

---

## 📋 Available Scripts

### macOS Setup
| Script | Purpose | Usage |
|--------|---------|-------|
| `setup-prerequisites.sh` | Install Docker, Python, Node.js on macOS | `bash setup-prerequisites.sh` |
| `init-project.sh` | Initialize project on macOS | `bash init-project.sh` |

### Ubuntu/Linux Setup
| Script | Purpose | Usage |
|--------|---------|-------|
| `setup-prerequisites-ubuntu.sh` | Install Docker, Python, Node.js on Ubuntu | `sudo bash setup-prerequisites-ubuntu.sh` |
| `deploy-ubuntu.sh` | Deploy on Ubuntu server | `sudo bash deploy-ubuntu.sh` |

### Database Management
| Script | Purpose | Usage |
|--------|---------|-------|
| `restore-database.sh` | Restore database from backup | `bash restore-database.sh backup_file.sql.gz` |
| `create-super-admin.sh` | Create super admin user | `bash create-super-admin.sh` |

### Utility Scripts
| Script | Purpose | Usage |
|--------|---------|-------|
| `docker-compose-detect.sh` | Detect Docker Compose version | `source docker-compose-detect.sh` |
| `check-services.sh` | Check service health | `bash check-services.sh` |

---

## 🚀 Quick Start Guide

### For macOS Development

```bash
# 1. Install prerequisites
bash setup-prerequisites.sh

# 2. Initialize project
bash init-project.sh

# 3. Create admin user
bash create-super-admin.sh

# 4. Access
open http://localhost:3001  # Admin
open http://localhost:3000  # User
```

### For Ubuntu Production Server

```bash
# 1. Install prerequisites
sudo bash setup-prerequisites-ubuntu.sh

# 2. Log out and back in
exit
# SSH back in

# 3. Deploy application
sudo bash deploy-ubuntu.sh

# 4. Create admin user
bash create-super-admin.sh

# 5. Access
# http://YOUR_SERVER_IP:3001  (Admin)
# http://YOUR_SERVER_IP:3000  (User)
```

---

## 🔄 Docker Compose Command Differences

### macOS (Docker Desktop)
```bash
docker-compose -f docker-compose.prod.yml up -d
```

### Ubuntu (Docker Engine with Compose V2)
```bash
docker compose -f docker-compose.prod.yml up -d
```

**Note:** Our scripts automatically detect and use the correct command!

---

## 📚 Documentation Files

| Document | Description | Platform |
|----------|-------------|----------|
| `README.md` | Main project documentation | All |
| `SETUP_GUIDE.md` | Detailed macOS setup guide | macOS |
| `SETUP_CHECKLIST.md` | Installation checklist | All |
| `UBUNTU_SETUP_GUIDE.md` | Ubuntu deployment guide | Ubuntu/Linux |
| `API_DOCUMENTATION.md` | API reference | All |

---

## 🛠️ Common Tasks

### Start Services

**macOS:**
```bash
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d
```

**Ubuntu:**
```bash
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# Or if systemd is enabled:
sudo systemctl start score-platform
```

### View Logs

**Both platforms:**
```bash
# Using detected command
source docker-compose-detect.sh
dc logs -f

# Or directly (adjust for your platform)
docker compose -f docker-compose.prod.yml logs -f
```

### Restart a Service

**macOS:**
```bash
docker-compose -f docker-compose.prod.yml restart leaderboard-service
```

**Ubuntu:**
```bash
docker compose -f docker-compose.prod.yml restart leaderboard-service
```

### Backup Database

**Both platforms:**
```bash
docker exec score_postgres_prod pg_dump -U postgres saas_platform | gzip > backup_$(date +%Y%m%d).sql.gz
```

### Restore Database

**Both platforms:**
```bash
bash restore-database.sh backup_20251128.sql.gz
```

---

## 🔧 Script Features Comparison

### Prerequisites Installation

| Feature | macOS Script | Ubuntu Script |
|---------|--------------|---------------|
| Homebrew/APT | ✅ | ✅ |
| Docker Desktop/Engine | ✅ | ✅ |
| Python 3.11 | ✅ | ✅ |
| Node.js 18 | ✅ | ✅ |
| PostgreSQL Client | ✅ | ✅ |
| Auto sudo check | ❌ | ✅ |
| Firewall setup | ❌ | ✅ |
| Systemd service | ❌ | ✅ |

### Deployment Scripts

| Feature | macOS (init-project.sh) | Ubuntu (deploy-ubuntu.sh) |
|---------|------------------------|---------------------------|
| Environment setup | ✅ | ✅ |
| Auto password gen | ❌ | ✅ |
| Build containers | ✅ | ✅ |
| Start services | ✅ | ✅ |
| Auto-start on boot | ❌ | ✅ |
| Log rotation | ❌ | ✅ |
| Security hardening | ❌ | ✅ |

---

## 📋 Environment Variables

Both platforms use `.env.production`:

```bash
# Required variables
POSTGRES_PASSWORD=<secure_password>
JWT_SECRET_KEY=<secure_key>
SECRET_KEY=<secure_key>

# Service URLs (same for both)
AUTH_SERVICE_URL=http://auth-service:5001
USER_SERVICE_URL=http://user-service:5002
# ... etc
```

**macOS:** Manually set in `.env.production`  
**Ubuntu:** Auto-generated during deployment

---

## 🔐 Security Considerations

### macOS (Development)
- Use strong passwords
- Don't expose ports to internet
- Keep Docker Desktop updated

### Ubuntu (Production)
- ✅ Auto-generated secure passwords
- ✅ Firewall configuration (UFW)
- ✅ File permission hardening (600 for .env)
- ✅ Log rotation
- ✅ Systemd service isolation
- 🔧 **TODO:** Set up SSL/TLS with nginx
- 🔧 **TODO:** Configure automated backups

---

## 🆘 Troubleshooting

### Docker Compose Not Found (Ubuntu)

**Error:** `docker-compose: command not found`

**Solution:**
```bash
# Use V2 syntax
docker compose ...

# Or create alias
echo "alias docker-compose='docker compose'" >> ~/.bashrc
source ~/.bashrc
```

### Permission Denied (Ubuntu)

**Error:** `permission denied while trying to connect to Docker daemon`

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in
exit
# SSH back in

# Verify
docker ps
```

### Port Already in Use

**Both platforms:**
```bash
# Find what's using the port
lsof -i :5432

# macOS - kill process
kill -9 <PID>

# Ubuntu - kill process
sudo kill -9 <PID>
```

---

## 📞 Support Resources

| Platform | Guide | Troubleshooting |
|----------|-------|-----------------|
| macOS | SETUP_GUIDE.md | SETUP_CHECKLIST.md |
| Ubuntu | UBUNTU_SETUP_GUIDE.md | UBUNTU_SETUP_GUIDE.md |
| Both | README.md | Service logs |

---

## 🔄 Update Procedure

### macOS
```bash
git pull origin pre-prod-dev
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
```

### Ubuntu
```bash
git pull origin pre-prod-dev
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d --build

# Or with systemd
sudo systemctl restart score-platform
```

---

## 📊 Resource Requirements

### Development (macOS)
- **RAM:** 8GB minimum
- **Disk:** 10GB
- **CPU:** Any modern Mac

### Production (Ubuntu)
- **RAM:** 4GB minimum (8GB recommended)
- **Disk:** 20GB minimum (50GB recommended)
- **CPU:** 2 cores minimum (4 recommended)
- **Network:** Static IP recommended

---

**Last Updated:** November 28, 2025  
**Maintained by:** Score Platform Team

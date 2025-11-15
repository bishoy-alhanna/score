# 🛠️ Local Development Guide

This guide explains how to run the Score platform locally for development and testing.

## 📋 Prerequisites

- Docker Desktop installed and running
- Git
- At least 4GB RAM available for Docker
- Ports available: 80, 5432, 6379, 5000

## 🚀 Quick Start

### 1. Clone and Switch to Development Branch

```bash
git clone https://github.com/bishoy-alhanna/score.git
cd score
git checkout development
```

### 2. Start Local Development Environment

```bash
chmod +x scripts/start-local-dev.sh
./scripts/start-local-dev.sh
```

This will:
- Create `.env.local` from template
- Build all Docker containers
- Start all services
- Initialize database
- Show access URLs

### 3. Access the Application

- **Admin Dashboard**: http://localhost/admin/
- **User Dashboard**: http://localhost/
- **API Gateway**: http://localhost/api/health
- **Debug Tools**: http://localhost/debug.html

### 4. Login with Demo Credentials

```
Username: admin
Password: password123
```

## 🔧 Development Workflow

### Starting the Environment

```bash
# Start all services
./scripts/start-local-dev.sh

# Or manually:
docker-compose -f docker-compose.dev.yml up -d
```

### Stopping the Environment

```bash
# Stop all services
docker-compose -f docker-compose.dev.yml down

# Stop and remove volumes (clean slate)
docker-compose -f docker-compose.dev.yml down -v
```

### Viewing Logs

```bash
# All services
docker-compose -f docker-compose.dev.yml logs -f

# Specific service
docker-compose -f docker-compose.dev.yml logs -f nginx
docker-compose -f docker-compose.dev.yml logs -f api-gateway
docker-compose -f docker-compose.dev.yml logs -f postgres
```

### Rebuilding Services

```bash
# Rebuild specific service
docker-compose -f docker-compose.dev.yml build admin-dashboard
docker-compose -f docker-compose.dev.yml up -d admin-dashboard

# Rebuild all
docker-compose -f docker-compose.dev.yml build
docker-compose -f docker-compose.dev.yml up -d
```

### Restarting Services

```bash
# Restart specific service
docker-compose -f docker-compose.dev.yml restart api-gateway

# Restart all
docker-compose -f docker-compose.dev.yml restart
```

## 🗄️ Database Management

### Reset Database with Demo Data

```bash
./scripts/reset-database.sh
# Type: DELETE ALL DATA when prompted
```

This creates:
- 3 organizations
- 9 users (3 admins, 6 regular users)
- 10 score categories
- 8 sample scores

### Connect to Database

```bash
# Using Docker exec
docker exec -it score_postgres_dev psql -U postgres -d saas_platform

# Or from host (if psql installed)
psql -h localhost -U postgres -d saas_platform
# Password: password
```

### Common SQL Queries

```sql
-- View all users
SELECT username, email, is_super_admin FROM users;

-- View all organizations
SELECT name, created_at FROM organizations;

-- View all score categories
SELECT name, max_score FROM score_categories;

-- View scores with user info
SELECT u.username, sc.name as category, s.score_value 
FROM scores s
JOIN users u ON s.user_id = u.id
JOIN score_categories sc ON s.category_id = sc.id;
```

## 🧪 Testing

### Run Platform Tests

```bash
./scripts/test-local-platform.sh
```

This tests:
- All containers running
- Database connectivity
- Redis connectivity
- Nginx configuration
- API Gateway health
- Frontend accessibility
- Debug tools

### Test Specific API Endpoints

```bash
# Health check
curl http://localhost/api/health

# Login (get token)
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "password123",
    "organization_name": "Tech Corp"
  }'

# Verify token
curl -X POST http://localhost/api/auth/verify \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## 🐛 Debugging

### Use the Debug Page

Visit http://localhost/debug.html and use the interactive tools:
- Test API Connection
- Test Auth Verify
- Test Auth with Timeout
- Clear Storage

### Check Container Status

```bash
docker-compose -f docker-compose.dev.yml ps
```

### View Container Logs

```bash
# See last 50 lines
docker-compose -f docker-compose.dev.yml logs --tail=50 api-gateway

# Follow logs in real-time
docker-compose -f docker-compose.dev.yml logs -f api-gateway
```

### Exec into Container

```bash
# Nginx
docker exec -it score_nginx_dev sh

# Postgres
docker exec -it score_postgres_dev sh

# API Gateway
docker exec -it score_api_gateway_dev sh
```

### Check Nginx Configuration

```bash
docker exec score_nginx_dev nginx -t
```

## 📁 Project Structure

```
score/
├── backend/                    # Backend microservices
│   ├── api-gateway/           # Main API gateway
│   ├── auth-service/          # Authentication
│   ├── user-service/          # User management
│   ├── group-service/         # Group management
│   ├── scoring-service/       # Score management
│   └── leaderboard-service/   # Leaderboards
├── frontend/                   # Frontend applications
│   ├── admin-dashboard/       # Admin UI
│   └── user-dashboard/        # User UI
├── nginx/                      # Nginx configuration
│   ├── nginx.local.conf       # Local (no SSL)
│   ├── nginx.conf             # Production (with SSL)
│   ├── Dockerfile.dev         # Local Dockerfile
│   └── Dockerfile             # Production Dockerfile
├── database/                   # Database scripts
│   └── init_database.sql      # Schema + demo data
├── scripts/                    # Utility scripts
│   ├── start-local-dev.sh     # Start local env
│   ├── test-local-platform.sh # Test local env
│   └── reset-database.sh      # Reset DB
├── docker-compose.dev.yml      # Local development
└── docker-compose.yml          # Production
```

## 🔄 Development vs Production

### Key Differences

| Feature | Development | Production |
|---------|------------|-----------|
| **Docker Compose** | `docker-compose.dev.yml` | `docker-compose.yml` |
| **Nginx** | HTTP only (port 80) | HTTPS (ports 80, 443) |
| **SSL** | Not required | Let's Encrypt |
| **Secrets** | Hardcoded (dev-*) | Environment variables |
| **Flask** | Debug mode ON | Debug mode OFF |
| **WSGI Server** | Gunicorn (2 workers) | Gunicorn (4 workers) |
| **Database** | postgres:password | Strong password |
| **Volumes** | `_dev` suffix | No suffix |
| **Container Names** | `score_*_dev` | `saas_*` |

### Environment Variables

Development (`.env.development`):
- `FLASK_ENV=development`
- `FLASK_DEBUG=1`
- Weak passwords (dev only!)

Production (`.env.production`):
- `FLASK_ENV=production`
- Strong passwords
- Real SSL certificates

## 🚨 Common Issues

### Issue: Port 80 already in use

**Solution:**
```bash
# Find process using port 80
sudo lsof -i :80

# Stop the process or change port in docker-compose.dev.yml
ports:
  - "8080:80"  # Use 8080 instead
```

### Issue: Nginx won't start (SSL cert error)

**Solution:**
Make sure you're using the development config:
```bash
docker-compose -f docker-compose.dev.yml up
# NOT docker-compose up (that uses production config)
```

### Issue: Database empty

**Solution:**
```bash
./scripts/reset-database.sh
```

### Issue: Frontend shows loading forever

**Solution:**
1. Check if API Gateway is running
2. Check browser console for errors
3. Visit http://localhost/debug.html
4. Click "Test Auth Verify"
5. Check the error message

### Issue: Permission denied on scripts

**Solution:**
```bash
chmod +x scripts/*.sh
```

## 📝 Making Changes

### Frontend Changes

1. Edit files in `frontend/admin-dashboard/` or `frontend/user-dashboard/`
2. Rebuild container:
   ```bash
   docker-compose -f docker-compose.dev.yml build admin-dashboard
   docker-compose -f docker-compose.dev.yml up -d admin-dashboard
   ```
3. Hard refresh browser (Ctrl+Shift+R)

### Backend Changes

1. Edit files in `backend/<service-name>/`
2. Rebuild container:
   ```bash
   docker-compose -f docker-compose.dev.yml build api-gateway
   docker-compose -f docker-compose.dev.yml up -d api-gateway
   ```
3. Test API endpoint

### Nginx Changes

1. Edit `nginx/nginx.local.conf`
2. Rebuild and restart:
   ```bash
   docker-compose -f docker-compose.dev.yml build nginx
   docker-compose -f docker-compose.dev.yml up -d nginx
   ```
3. Verify: `docker exec score_nginx_dev nginx -t`

### Database Changes

1. Edit `database/init_database.sql`
2. Reset database:
   ```bash
   docker-compose -f docker-compose.dev.yml down -v
   ./scripts/start-local-dev.sh
   ```

## 🎯 Development Tips

1. **Use Debug Tools**: http://localhost/debug.html is your friend
2. **Watch Logs**: Keep logs open while developing
3. **Test Often**: Run `./scripts/test-local-platform.sh` frequently
4. **Clear Cache**: Browser cache can cause issues - clear it often
5. **Docker Prune**: Clean up old images/containers regularly
   ```bash
   docker system prune -a
   ```

## 🔐 Security Notes

**⚠️ NEVER use development secrets in production!**

Development uses weak passwords and keys for convenience:
- Database: `postgres:password`
- JWT Secret: `dev-jwt-secret-key-DO-NOT-USE-IN-PRODUCTION`

These are **ONLY** for local development.

## 📖 Next Steps

- Review [PRODUCTION_DEPLOYMENT_GUIDE.md](PRODUCTION_DEPLOYMENT_GUIDE.md)
- Read [LOADING_SCREEN_TROUBLESHOOTING.md](LOADING_SCREEN_TROUBLESHOOTING.md)
- Check [API_DOCUMENTATION.md](API_DOCUMENTATION.md)

---

**Questions?** Check the troubleshooting guide or open an issue on GitHub.

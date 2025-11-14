# 🔧 Fix: Python Command Not Found on Production

## Problem
The old `test-platform.sh` script tries to run `python` directly on the host, but:
- Python might not be installed on the host
- The application runs inside Docker containers, not on the host

## Solution
Use the new Docker-based test script instead.

## Quick Fix

On your production server, run:

```bash
cd /root/score

# Pull latest changes (includes new test script)
git pull

# Make script executable
chmod +x scripts/test-platform-docker.sh

# Run the new Docker-based test
./scripts/test-platform-docker.sh
```

## What's Different?

### ❌ Old Script (test-platform.sh)
- Tries to run `python` on host
- Requires Python virtualenv on host
- Requires manual service startup
- **Don't use this in production**

### ✅ New Script (scripts/test-platform-docker.sh)
- Tests Docker containers directly
- No Python installation needed on host
- Tests all services through Docker
- **Use this for production testing**

## What the New Script Tests

1. ✅ Docker containers running
2. ✅ PostgreSQL connection
3. ✅ Database schema exists
4. ✅ Redis connection
5. ✅ Demo data loaded
6. ✅ Nginx configuration
7. ✅ API Gateway health
8. ✅ HTTPS endpoints
9. ✅ SSL certificates
10. ✅ Authentication (login test)
11. ✅ Frontend containers

## Expected Output

```bash
==========================================
🧪 Score Platform Production Test
==========================================

1. Checking Docker containers...
✓ saas_postgres is running
✓ saas_redis is running
✓ saas_nginx is running
✓ api-gateway is running

2. Testing database connection...
✓ PostgreSQL connection successful
✓ Database 'saas_platform' exists

3. Checking database schema...
✓ Table 'users' exists
✓ Table 'organizations' exists
✓ Table 'user_organizations' exists
✓ Table 'score_categories' exists
✓ Table 'scores' exists
✓ Table 'score_aggregates' exists

... (more tests)

==========================================
📊 Test Summary
==========================================

Core Services:
✓ PostgreSQL: Running
✓ Redis: Running
✓ Nginx: Running
✓ API Gateway: Running

Access URLs:
  🌐 Admin Dashboard: https://escore.al-hanna.com/admin/
  🌐 User Dashboard:  https://escore.al-hanna.com/
  🔧 API Gateway:     https://escore.al-hanna.com/api/
  🧹 Clear Cache:     https://escore.al-hanna.com/clear-cache.html

Demo Credentials:
  👤 Super Admin: admin / password123
  👤 Org Admin:   john.admin / password123
  👤 User:        john.doe / password123

==========================================
✓ Platform test completed!
==========================================
```

## Troubleshooting

### If database tests fail:
```bash
./scripts/reset-database.sh
```

### If containers are not running:
```bash
docker-compose up -d
```

### If frontend containers need rebuilding:
```bash
docker-compose build admin-dashboard user-dashboard
docker-compose up -d
```

### View container logs:
```bash
docker-compose logs -f api-gateway
docker-compose logs -f nginx
```

## Summary

**DO THIS on production:**
```bash
cd /root/score
git pull
./scripts/test-platform-docker.sh
```

**NOT THIS:**
```bash
./test-platform.sh  # ❌ Don't use - requires Python on host
```

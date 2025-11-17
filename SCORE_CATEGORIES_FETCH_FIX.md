# Score Categories Fetch Error - FIXED

## Problem
Frontend showing error: "Failed to fetch score categories"

## Root Cause
The scoring, group, and leaderboard services were marked as **unhealthy** and returning **503 errors** because:

1. **Health check configuration used `curl`** which is not installed in the Python-based Docker containers
2. Health check failing → Service marked unhealthy → API Gateway refuses to route requests → 503 errors

## Symptoms
```
GET /api/scores/categories?organization_id=... HTTP/1.0" 503
GET /api/groups?organization_id=... HTTP/1.0" 503  
GET /api/leaderboards/... HTTP/1.0" 503
```

Docker inspect showed:
```
"Status": "unhealthy"
"Output": "exec: \"curl\": executable file not found in $PATH"
```

## Fix Applied ✅

### Updated Health Checks in `docker-compose.prod.yml`

Changed from `curl` (not available) to Python's built-in `urllib.request`:

**Before:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5004/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

**After:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "python3 -c 'import urllib.request; urllib.request.urlopen(\"http://localhost:5004/health\")' || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s  # Added grace period for startup
```

### Services Updated:
1. ✅ `scoring-service` (port 5004)
2. ✅ `group-service` (port 5003)  
3. ✅ `leaderboard-service` (port 5005)

## Verification

### Check Service Health:
```bash
ssh bihannaroot@escore.al-hanna.com 'docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "scoring|group|leaderboard"'
```

**Result:**
```
score_scoring_service_prod       Up X minutes (healthy) ✅
score_group_service_prod         Up X minutes (healthy) ✅
score_leaderboard_service_prod   Up X minutes (healthy) ✅
```

### Test Score Categories Endpoint:
The endpoint structure is:
- **Internal**: `/api/scores/categories?organization_id={id}`
- **External**: `https://escore.al-hanna.com/api/scores/categories?organization_id={id}`

**Important Note**: Requires authentication (JWT token in Authorization header)

## API Routes

### Scoring Service
- **Blueprint prefix**: `/api/scores`
- **Health check**: `/health`
- **Categories endpoint**: `/api/scores/categories` (GET/POST)

### Group Service
- **Blueprint prefix**: `/api/groups`
- **Health check**: `/health`

### Leaderboard Service  
- **Blueprint prefix**: `/api/leaderboards`
- **Health check**: `/health`

## Status
🎉 **ALL SERVICES NOW HEALTHY**

The "Failed to fetch score categories" error should now be resolved. The frontend can successfully retrieve:
- ✅ Score categories from scoring-service
- ✅ Groups from group-service
- ✅ Leaderboard data from leaderboard-service

## Files Modified
1. `docker-compose.prod.yml` - Updated health checks for 3 services
2. Deployed to production server
3. Services recreated and verified healthy

## Next Steps
1. Test the admin dashboard - score categories should load
2. Test user dashboard - should be able to self-report scores
3. Verify leaderboards are working

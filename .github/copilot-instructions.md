# AI Agent Instructions - Multi-Tenant SaaS Scoring Platform

## Architecture Overview

This is a **microservices-based multi-tenant SaaS platform** for scoring, leaderboards, and group management. Eight backend services communicate through an API Gateway, with React frontends and shared PostgreSQL database.

### Core Services (Flask + SQLAlchemy)
- **auth-service** (5001): JWT authentication, user registration, organization management
- **user-service** (5002): User CRUD, profiles, role management
- **group-service** (5003): Group management, memberships, hierarchies
- **scoring-service** (5004): Score assignment, category management, aggregation
- **leaderboard-service** (5005): Real-time leaderboards with Redis caching
- **organization-service** (5006): Organization settings and management
- **api-gateway** (5000): Request routing, CORS, service orchestration
- **config-server** (5007): Centralized configuration

### Frontend Applications
- **admin-dashboard** (3000): React + Vite, shadcn/ui components, organization admin interface
- **user-dashboard** (3001): React + Vite, end-user interface for scores and leaderboards

### Infrastructure
- **PostgreSQL**: Shared database with organization_id tenant isolation
- **Redis**: Leaderboard caching (5-minute TTL)
- **Nginx**: Reverse proxy, SSL termination, static file serving

## Multi-Tenancy Model - CRITICAL

**Every database query MUST filter by `organization_id`** - this is the tenant isolation mechanism:

```python
# ✅ CORRECT - Tenant-scoped query
users = User.query.filter_by(organization_id=org_id).all()

# ❌ WRONG - Cross-tenant data leak
users = User.query.all()
```

JWT tokens contain `organization_id` - extract it in route handlers:
```python
def verify_token_and_get_user():
    token = request.headers.get('Authorization').split(' ')[1]
    payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=['HS256'])
    return payload  # Contains: user_id, organization_id, role, username, email
```

**Roles**: `ORG_ADMIN` (full org access), `USER` (limited access), `SUPER_ADMIN` (platform-wide)

## Service Communication Pattern

Services call each other via **direct HTTP requests with JWT forwarding**:

```python
# Example: leaderboard-service fetching user details from user-service
headers = {'Authorization': f'Bearer {auth_token}'}
user_service_url = os.environ.get('USER_SERVICE_URL', 'http://user-service:5000')
response = requests.get(f'{user_service_url}/api/users/{user_id}', headers=headers, timeout=5)
```

**Always include fallback data** if service calls fail - services should degrade gracefully, not crash.

## Database Models - Shared Schema Pattern

Each service has its own `src/models/database.py` but all models reference the **same PostgreSQL database**. Key relationships:

```python
# Organizations (root tenant entity)
Organization: id (UUID), name (unique), is_active, created_at

# Users (belongs to one organization)
User: id (UUID), username, email, organization_id (FK), role, password_hash

# UserOrganization (many-to-many for multi-org users)
UserOrganization: user_id, organization_id, role, is_active

# Groups (org-scoped)
Group: id, name, organization_id, created_by, is_active
GroupMember: group_id, user_id (composite PK)

# Scores (can belong to user OR group)
Score: id, user_id (nullable), group_id (nullable), score_value, category, organization_id

# ScoreAggregate (pre-computed leaderboard data)
ScoreAggregate: organization_id, category, user_id/group_id, total_score, score_count, average_score
```

**Unique constraints**: `(organization_id, username)`, `(organization_id, email)`, `(organization_id, group_name)` - usernames/emails can repeat across orgs.

## Development Workflow

### Local Development Setup
```bash
# Start all services (first time setup)
docker-compose up -d postgres redis  # Start dependencies first
docker-compose up                     # Start all services

# Access points
# Admin Dashboard: http://localhost:3000
# User Dashboard:  http://localhost:3001
# API Gateway:     http://localhost:5000/api
# Database:        postgres://postgres:password@localhost:5432/saas_platform
```

### Database Management
```bash
# Initialize database with schema
docker exec -it saas_postgres psql -U postgres -d saas_platform -f /docker-entrypoint-initdb.d/init_database.sql

# Reset database (destructive)
./scripts/reset-database.sh

# Run migrations
./scripts/apply-migration.sh
```

### Service-Specific Development
Each backend service follows this structure:
```
backend/{service-name}/{service-name}/
├── src/
│   ├── main.py              # Flask app entry point
│   ├── models/
│   │   └── database.py      # SQLAlchemy models
│   └── routes/
│       └── {resource}.py    # Blueprint-based routes
├── requirements.txt
├── Dockerfile
└── venv/                    # Local virtual environment
```

To run a service standalone:
```bash
cd backend/{service-name}/{service-name}
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export DATABASE_URL="postgresql://postgres:password@localhost:5432/saas_platform"
export JWT_SECRET_KEY="jwt-secret-key-change-in-production"
python src/main.py
```

## Frontend Patterns

### API Communication
```javascript
// API base URL from environment
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

// Axios instance with auth interceptor
const api = axios.create({ baseURL: API_BASE_URL })
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('authToken')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})
```

### Component Structure
- **shadcn/ui components** in `src/components/ui/` (button, card, dialog, etc.)
- Main components in `src/components/` (SuperAdminDashboard, AdminLogin, etc.)
- Routing in `App.jsx` with protected routes checking `authToken`

## Production Deployment

### Docker Compose Production
```bash
# Build and deploy production stack
docker-compose -f docker-compose.prod.yml up -d --build

# Production uses:
# - Gunicorn for Python services (4 workers)
# - Production React builds (Vite)
# - Nginx SSL termination
# - Volume mounts for persistence
```

### Environment Variables
Set these in `.env.production`:
```env
DATABASE_URL=postgresql://postgres:password@postgres:5432/saas_platform
JWT_SECRET_KEY=<strong-random-key>
SECRET_KEY=<strong-random-key>
AUTH_SERVICE_URL=http://auth-service:5001
USER_SERVICE_URL=http://user-service:5002
GROUP_SERVICE_URL=http://group-service:5003
SCORING_SERVICE_URL=http://scoring-service:5004
LEADERBOARD_SERVICE_URL=http://leaderboard-service:5005
```

## Common Patterns & Conventions

### Error Handling
```python
# Always return consistent error format
try:
    # ... operation
    return jsonify({'data': result}), 200
except Exception as e:
    return jsonify({'error': str(e)}), 500
```

### Leaderboard Caching Strategy
```python
# Cache key format: "leaderboard:{org_id}:{type}:{category}"
cache_key = f"leaderboard:{organization_id}:users:general"
redis_client.setex(cache_key, 300, json.dumps(data))  # 5-minute TTL
```

### Blueprint Registration Pattern
```python
# In src/main.py
from src.routes.auth import auth_bp
app.register_blueprint(auth_bp, url_prefix='/api/auth')
```

### Service-to-Service Calls
Always use environment variables for service URLs, never hardcode:
```python
service_url = os.environ.get('USER_SERVICE_URL', 'http://user-service:5000')
```

## Critical Files Reference

- **Database schema**: `database/init_database.sql`
- **Docker orchestration**: `docker-compose.yml`, `docker-compose.prod.yml`
- **API Gateway routing**: `backend/api-gateway/api-gateway/src/routes/gateway.py`
- **Nginx config**: `nginx/nginx.conf`
- **Frontend env**: `frontend/*/vite.config.js`

## Testing & Debugging

### Debug Shell Scripts Available
- `test-platform.sh` - End-to-end API tests
- `check-services.sh` - Health check all services
- `debug-auth-service.sh` - Auth service troubleshooting

### Common Issues
1. **"Cannot fetch" errors**: Check service URLs in API gateway config
2. **Multi-org data leak**: Verify all queries include `organization_id` filter
3. **Token expiry**: JWT tokens expire after 24 hours (set in `generate_jwt_token()`)
4. **Redis connection fails**: Leaderboard service degrades gracefully, uses DB queries
5. **CORS errors**: API gateway enables CORS for all origins (`CORS(app, origins="*")`)

## Code Style Notes

- Python: PEP 8 compliant, snake_case for variables/functions
- JavaScript/React: camelCase, functional components with hooks
- Database: UUID primary keys, timestamps on all tables (`created_at`, `updated_at`)
- Routes: RESTful conventions (`GET /api/users`, `POST /api/scores`)

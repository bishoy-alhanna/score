# Multi-Tenant SaaS Platform - Development Setup

## Quick Start

1. **Clone and navigate to the project:**
   ```bash
   cd saas-platform
   ```

2. **Start all services with Docker Compose:**
   ```bash
   docker-compose up --build
   ```

3. **Access the applications:**
   - API Gateway: http://localhost:5000
   - Admin Dashboard: http://localhost:3000
   - User Dashboard: http://localhost:3001

## Services Overview

### Backend Services
- **API Gateway** (Port 5000): Central entry point for all API requests
- **Auth Service** (Port 5001): Authentication and organization management
- **User Service** (Port 5002): User management and profiles
- **Group Service** (Port 5003): Group creation and membership
- **Scoring Service** (Port 5004): Score assignment and tracking
- **Leaderboard Service** (Port 5005): Real-time leaderboards and rankings

### Frontend Applications
- **Admin Dashboard** (Port 3000): Organization admin interface
- **User Dashboard** (Port 3001): End-user interface

### Infrastructure
- **PostgreSQL** (Port 5432): Primary database
- **Redis** (Port 6379): Caching and session storage

## Development Workflow

### Running Individual Services

Each service can be run independently for development:

```bash
# Backend services (example for auth service)
cd backend/auth-service/auth-service
source venv/bin/activate
pip install -r requirements.txt
python src/main.py

# Frontend applications (example for admin dashboard)
cd frontend/admin-dashboard/admin-dashboard
pnpm install
pnpm run dev
```

### Database Setup

The database schema is automatically applied when PostgreSQL starts. For manual setup:

```bash
# Connect to PostgreSQL
psql -h localhost -U postgres -d saas_platform

# Run schema manually if needed
\i database/schema.sql
```

### Environment Variables

Key environment variables for production:

```bash
# Security
JWT_SECRET_KEY=your-secure-jwt-secret
SECRET_KEY=your-secure-app-secret

# Database
DATABASE_URL=postgresql://user:password@host:port/database

# Redis
REDIS_URL=redis://host:port/db

# Service URLs (for API Gateway)
AUTH_SERVICE_URL=http://auth-service:5001
USER_SERVICE_URL=http://user-service:5002
# ... etc
```

## Testing the Platform

### 1. Register a New Organization

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "email": "admin@example.com",
    "password": "password123",
    "organization_name": "Test Organization"
  }'
```

### 2. Login to Admin Dashboard

1. Go to http://localhost:3000
2. Use the credentials from registration
3. Organization name: "Test Organization"

### 3. Login to User Dashboard

1. Go to http://localhost:3001
2. Use the same credentials
3. View your personal dashboard

## API Documentation

### Authentication Endpoints

- `POST /api/auth/register` - Register new organization
- `POST /api/auth/login` - User login
- `POST /api/auth/verify` - Verify JWT token
- `POST /api/auth/invite-user` - Invite new user (Admin only)

### User Management

- `GET /api/users` - List organization users
- `GET /api/users/{id}` - Get user details
- `PUT /api/users/{id}` - Update user
- `DELETE /api/users/{id}` - Deactivate user

### Group Management

- `GET /api/groups` - List organization groups
- `POST /api/groups` - Create new group
- `GET /api/groups/{id}` - Get group details
- `PUT /api/groups/{id}` - Update group
- `DELETE /api/groups/{id}` - Delete group
- `POST /api/groups/{id}/members` - Add member to group

### Scoring System

- `POST /api/scores` - Assign score (Admin only)
- `GET /api/scores` - List scores with filters
- `PUT /api/scores/{id}` - Update score
- `DELETE /api/scores/{id}` - Delete score
- `GET /api/scores/aggregates` - Get score aggregates

### Leaderboards

- `GET /api/leaderboards/users` - User leaderboard
- `GET /api/leaderboards/groups` - Group leaderboard
- `GET /api/leaderboards/user/{id}/rank` - Get user rank
- `GET /api/leaderboards/group/{id}/rank` - Get group rank

## Architecture Features

### Multi-Tenancy
- Complete data isolation between organizations
- Shared infrastructure with tenant-scoped queries
- Organization-specific user management and scoring

### Security
- JWT-based authentication with organization context
- Role-based access control (ORG_ADMIN, USER)
- Rate limiting and request validation
- Secure password hashing with bcrypt

### Scalability
- Microservices architecture for independent scaling
- Redis caching for high-performance leaderboards
- Database indexing for optimized queries
- Event-driven score aggregation

### Performance
- Materialized score aggregates for fast leaderboard queries
- Redis caching with intelligent invalidation
- Optimized database schema with proper indexing
- Efficient API design with pagination

## Monitoring and Health Checks

All services include health check endpoints:

```bash
# Check individual service health
curl http://localhost:5001/health  # Auth service
curl http://localhost:5002/health  # User service
# ... etc

# Check all services via API Gateway
curl http://localhost:5000/api/health/services
```

## Production Deployment

### Security Considerations

1. **Change default secrets:**
   - Update JWT_SECRET_KEY
   - Update SECRET_KEY
   - Use strong database passwords

2. **Enable HTTPS:**
   - Use reverse proxy (nginx/traefik)
   - SSL/TLS certificates

3. **Database security:**
   - Use connection pooling
   - Enable SSL connections
   - Regular backups

4. **Rate limiting:**
   - Configure appropriate limits
   - Use Redis for distributed rate limiting

### Scaling Recommendations

1. **Horizontal scaling:**
   - Run multiple instances of each service
   - Use load balancer for distribution

2. **Database optimization:**
   - Read replicas for read-heavy workloads
   - Connection pooling
   - Query optimization

3. **Caching strategy:**
   - Redis cluster for high availability
   - CDN for static assets
   - Application-level caching

## Troubleshooting

### Common Issues

1. **Services not starting:**
   - Check Docker logs: `docker-compose logs [service-name]`
   - Verify environment variables
   - Ensure ports are not in use

2. **Database connection errors:**
   - Wait for PostgreSQL to be ready
   - Check connection string format
   - Verify network connectivity

3. **Authentication issues:**
   - Verify JWT secret consistency across services
   - Check token expiration
   - Validate organization context

### Logs and Debugging

```bash
# View logs for all services
docker-compose logs -f

# View logs for specific service
docker-compose logs -f auth-service

# Access service containers
docker-compose exec auth-service bash
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

## License

This project is licensed under the MIT License.


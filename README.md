# Multi-Tenant SaaS Scoring & Leaderboard Platform

A secure, scalable multi-tenant SaaS platform for organizations to manage users, groups, scoring systems, and leaderboards.

## 🚀 Quick Start

For a **brand new system** (fresh macOS installation):

```bash
# 1. Install prerequisites (Docker, Python, Node.js, npm)
bash setup-prerequisites.sh

# 2. Initialize and start the project
bash init-project.sh

# 3. Create your first admin user
bash create-super-admin.sh

# 4. Access the application
open http://localhost:3001  # Admin Dashboard
open http://localhost:3000  # User Dashboard
```

**See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed installation instructions.**

**Use [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md) to track your installation progress.**

---

## Architecture Overview

- **Backend**: Microservices architecture with Flask
- **Frontend**: React applications (Admin & User dashboards)
- **Database**: PostgreSQL with Redis caching
- **Deployment**: Docker containers with Docker Compose

## Services

### Backend Services
- **auth-service** (Port 5001): Authentication, JWT tokens, password management
- **user-service** (Port 5002): User CRUD, role management, org-scoped operations
- **group-service** (Port 5003): Group management, membership, hierarchies
- **scoring-service** (Port 5004): Score assignment, updates, aggregation
- **leaderboard-service** (Port 5005): Real-time leaderboards, caching
- **api-gateway** (Port 5000): Request routing, authentication, rate limiting

### Frontend Applications
- **admin-dashboard** (Port 3001): Organization admin interface
- **user-dashboard** (Port 3000): End-user interface

### Infrastructure
- **PostgreSQL** (Port 5432): Primary database
- **Redis** (Port 6379): Caching and session storage

## Multi-Tenancy

- Shared schema with tenant column (organization_id)
- Complete data isolation between organizations
- JWT-based authentication with org context
- Role-based access control (ORG_ADMIN, SUPER_ADMIN, USER)
- Organization-specific settings and configurations

## Features

✅ **Multi-Organization Support**
- Isolated data per organization
- Organization-specific settings
- Cross-organization user management

✅ **User & Group Management**
- User CRUD operations
- Group hierarchies
- Role-based access control
- Active/inactive user status

✅ **Scoring System**
- Customizable score categories
- User and group scoring
- Historical score tracking
- Score aggregation

✅ **Leaderboards**
- Real-time user leaderboards
- Group leaderboards
- Date range filtering
- Organization-wide filter settings
- Redis caching for performance

✅ **Security**
- JWT-based authentication
- Password hashing (bcrypt)
- Organization-scoped data access
- Role-based permissions

---

## Installation Options

### Option 1: Automated Setup (Recommended)

Use the provided setup scripts for a hassle-free installation:

```bash
bash setup-prerequisites.sh  # Install Docker, Python, Node.js, etc.
bash init-project.sh         # Initialize and start the project
```

### Option 2: Manual Setup

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed manual installation steps.

### Option 3: Existing Environment

If you already have Docker installed:

```bash
# Configure environment
cp .env.example .env.production
# Edit .env.production with your settings

# Build and start services
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d --build

# Create admin user
bash create-super-admin.sh
```

---

## Development

### Project Structure

```
score/
├── backend/
│   ├── auth-service/
│   ├── user-service/
│   ├── group-service/
│   ├── scoring-service/
│   ├── leaderboard-service/
│   └── api-gateway/
├── frontend/
│   ├── admin-dashboard/
│   └── user-dashboard/
├── docker-compose.prod.yml
├── setup-prerequisites.sh
├── init-project.sh
└── README.md
```

### Running in Development Mode

Each service can be developed independently:

```bash
# Start infrastructure only
docker-compose -f docker-compose.prod.yml up -d postgres redis

# Run a service locally (example: auth-service)
cd backend/auth-service/auth-service
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python src/app.py

# Run frontend with hot reload
cd frontend/admin-dashboard/admin-dashboard
npm install
npm start
```

### Useful Commands

```bash
# View all logs
docker-compose -f docker-compose.prod.yml logs -f

# View specific service logs
docker-compose -f docker-compose.prod.yml logs -f leaderboard-service

# Restart a service
docker-compose -f docker-compose.prod.yml restart auth-service

# Rebuild and restart a service
docker-compose -f docker-compose.prod.yml up -d --build auth-service

# Stop all services
docker-compose -f docker-compose.prod.yml down

# Access database
docker exec -it score_postgres_prod psql -U postgres -d saas_platform
```

---

## API Documentation

API Gateway runs on port 5000 and routes requests to microservices.

### Authentication

```bash
# Login
POST /api/auth/login
{
  "username": "user@example.com",
  "password": "password"
}

# Returns JWT token
{
  "token": "eyJ...",
  "user": {...}
}
```

### Example API Calls

```bash
# Get leaderboard (requires authentication)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/leaderboards/users?category=general&limit=10

# Get user scores
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/scores?user_id=USER_ID

# Create organization (admin only)
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "My Organization"}' \
  http://localhost:5000/api/organizations
```

See [API_DOCUMENTATION.md](API_DOCUMENTATION.md) for full API reference.

---

## Troubleshooting

### Common Issues

**Docker not running:**
```bash
open -a Docker  # Start Docker Desktop
```

**Port conflicts:**
```bash
# Check what's using a port
lsof -ti:5432

# Stop the process
lsof -ti:5432 | xargs kill -9
```

**Database connection issues:**
```bash
# Wait for database to initialize (~10 seconds)
docker-compose -f docker-compose.prod.yml logs postgres | grep "ready to accept connections"
```

**Service fails to start:**
```bash
# Check service logs
docker-compose -f docker-compose.prod.yml logs SERVICE_NAME

# Common issues:
# - Missing environment variables
# - Database not ready
# - Port already in use
```

See [SETUP_GUIDE.md](SETUP_GUIDE.md) troubleshooting section for more solutions.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

[Your License Here]

## Support

For issues or questions:
- Check [SETUP_GUIDE.md](SETUP_GUIDE.md)
- Review [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md)
- Check service logs
- Open a GitHub issue

---

## Changelog

See individual service README files and commit history for detailed changes.

**Latest Updates:**
- ✅ Organization membership filtering with `is_active` status
- ✅ Organization-wide date filter settings
- ✅ Improved leaderboard caching
- ✅ Admin user scores management page
- ✅ Enhanced security and data isolation


# Score Platform - Setup Guide

This guide will help you set up the Score Platform on a fresh macOS system.

## Quick Start

For a brand new system, run these two scripts in order:

```bash
# 1. Install prerequisites (Docker, Python, Node.js, etc.)
bash setup-prerequisites.sh

# 2. Initialize the project
bash init-project.sh
```

---

## Detailed Setup Instructions

### Step 1: Install Prerequisites

The `setup-prerequisites.sh` script will check for and install:

- **Homebrew** - macOS package manager
- **Docker Desktop** - Container runtime
- **Python 3.11+** - Backend services runtime
- **Node.js 18+** - Frontend applications runtime
- **npm** - Node package manager
- **Git** - Version control
- **PostgreSQL Client** (optional) - Database access tool

**Run the script:**

```bash
bash setup-prerequisites.sh
```

**What it does:**
- Checks if each tool is already installed
- Installs missing tools via Homebrew
- Updates existing installations
- Verifies versions meet requirements
- Provides a summary of installed versions

**After installation:**
- Start Docker Desktop from your Applications folder
- Wait for Docker to fully start (you'll see the whale icon in your menu bar)

---

### Step 2: Initialize the Project

The `init-project.sh` script will:

- Verify prerequisites are installed
- Create environment configuration files
- Install frontend dependencies (npm packages)
- Build Docker containers for all services
- Start the application stack
- Run database migrations

**Run the script:**

```bash
bash init-project.sh
```

**The script will prompt you for:**
- Whether to install frontend dependencies
- Whether to build and start Docker containers

**What it creates:**
- `.env.production` file with default configuration
- Node modules for admin and user dashboards
- Docker containers for all backend services
- PostgreSQL database with schema
- Redis cache instance

---

## Manual Setup (Alternative)

If you prefer to set up components manually:

### 1. Install Prerequisites Manually

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker Desktop
brew install --cask docker

# Install Python 3.11
brew install python@3.11

# Install Node.js
brew install node

# Install PostgreSQL client (optional)
brew install postgresql@15
```

### 2. Configure Environment

```bash
# Copy and edit environment file
cp .env.example .env.production
nano .env.production  # Edit with your values
```

**Required environment variables:**
```bash
POSTGRES_PASSWORD=your_secure_password
JWT_SECRET_KEY=your_jwt_secret_key
SECRET_KEY=your_secret_key
```

### 3. Install Frontend Dependencies

```bash
# Admin Dashboard
cd frontend/admin-dashboard/admin-dashboard
npm install
cd ../../..

# User Dashboard
cd frontend/user-dashboard/user-dashboard
npm install
cd ../../..
```

### 4. Build and Start Services

```bash
# Build all containers
docker-compose -f docker-compose.prod.yml --env-file .env.production build

# Start all services
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d
```

### 5. Create Super Admin

```bash
bash create-super-admin.sh
```

---

## Access the Application

After setup is complete, access the application at:

- **Admin Dashboard**: http://localhost:3001
- **User Dashboard**: http://localhost:3000
- **API Gateway**: http://localhost:5000

---

## Useful Commands

### Docker Management

```bash
# View all container logs
docker-compose -f docker-compose.prod.yml logs -f

# View specific service logs
docker-compose -f docker-compose.prod.yml logs -f auth-service

# Check service status
docker-compose -f docker-compose.prod.yml ps

# Stop all services
docker-compose -f docker-compose.prod.yml down

# Restart all services
docker-compose -f docker-compose.prod.yml restart

# Restart specific service
docker-compose -f docker-compose.prod.yml restart auth-service

# Rebuild and restart a service
docker-compose -f docker-compose.prod.yml up -d --build auth-service
```

### Database Management

```bash
# Access PostgreSQL directly
docker exec -it score_postgres_prod psql -U postgres -d saas_platform

# Run SQL from command line
docker exec score_postgres_prod psql -U postgres -d saas_platform -c "SELECT * FROM organizations;"

# Backup database
docker exec score_postgres_prod pg_dump -U postgres saas_platform > backup.sql

# Restore database
cat backup.sql | docker exec -i score_postgres_prod psql -U postgres -d saas_platform
```

### Application Management

```bash
# Create super admin user
bash create-super-admin.sh

# Check all services health
bash check-services.sh

# Create demo data
bash create-demo-groups-complete.sh
```

---

## Troubleshooting

### Docker not running

**Error**: `Cannot connect to the Docker daemon`

**Solution**: 
1. Open Docker Desktop from Applications
2. Wait for it to fully start (whale icon in menu bar)
3. Try your command again

### Port already in use

**Error**: `Port 5432 is already allocated`

**Solution**:
```bash
# Stop the service using the port
lsof -ti:5432 | xargs kill -9

# Or change the port in docker-compose.prod.yml
```

### Container fails to start

**Error**: Service exits immediately

**Solution**:
```bash
# Check logs for the specific service
docker-compose -f docker-compose.prod.yml logs service-name

# Common issues:
# 1. Missing environment variables in .env.production
# 2. Database connection issues
# 3. Port conflicts
```

### Frontend build errors

**Error**: npm install fails

**Solution**:
```bash
# Clear npm cache
npm cache clean --force

# Delete node_modules and package-lock.json
rm -rf node_modules package-lock.json

# Reinstall
npm install
```

### Database connection issues

**Error**: `could not connect to server`

**Solution**:
```bash
# Wait for database to be ready
docker-compose -f docker-compose.prod.yml logs postgres

# Database takes ~10 seconds to initialize on first run
# Look for "database system is ready to accept connections"
```

---

## System Requirements

- **OS**: macOS (Big Sur 11.0 or later)
- **RAM**: Minimum 8GB (16GB recommended)
- **Disk Space**: At least 10GB free
- **Processor**: Intel or Apple Silicon (M1/M2)

---

## Development vs Production

### Development Mode

```bash
# Use development compose file (if available)
docker-compose up -d

# Frontend development servers with hot reload
cd frontend/admin-dashboard/admin-dashboard
npm start
```

### Production Mode

```bash
# Use production compose file
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d

# Frontend is built and served via containers
# No need to run npm start
```

---

## Next Steps

After successful setup:

1. **Create your first organization**
   - Login to admin dashboard
   - Navigate to Organizations
   - Create a new organization

2. **Add users**
   - Go to Users section
   - Invite users to your organization
   - Assign roles (Admin, User)

3. **Configure scoring categories**
   - Set up score categories
   - Define point values
   - Configure leaderboard settings

4. **Create groups** (optional)
   - Organize users into groups
   - Track group scores
   - View group leaderboards

---

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review service logs: `docker-compose -f docker-compose.prod.yml logs`
3. Check GitHub issues
4. Contact the development team

---

## License

[Your License Here]

## Contributors

[Your Team Here]

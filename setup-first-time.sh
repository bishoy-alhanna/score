#!/bin/bash

# ================================================================
# SaaS Platform - First-Time Setup Script
# ================================================================
# This script initializes the database and sets up the environment
# for first-time deployment.
# ================================================================

set -e  # Exit on error

echo "================================================"
echo "SaaS Platform - First-Time Setup"
echo "================================================"
echo ""

# Configuration
DB_CONTAINER="saas_postgres"
DB_NAME="saas_platform"
DB_USER="postgres"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$SCRIPT_DIR/database"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

echo "Step 1: Starting Docker containers..."
docker-compose up -d

echo ""
echo "Step 2: Waiting for PostgreSQL to be ready..."
sleep 10

# Wait for PostgreSQL to be healthy
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker exec $DB_CONTAINER pg_isready -U $DB_USER > /dev/null 2>&1; then
        echo -e "${GREEN}PostgreSQL is ready!${NC}"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "Waiting for PostgreSQL... (Attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "${RED}Error: PostgreSQL failed to start within the expected time.${NC}"
    exit 1
fi

echo ""
echo "Step 3: Initializing database..."

# Run the initialization script
if [ -f "$DATABASE_DIR/init_database.sql" ]; then
    echo "Running init_database.sql..."
    docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < "$DATABASE_DIR/init_database.sql"
    echo -e "${GREEN}Database initialized successfully!${NC}"
else
    echo -e "${YELLOW}Warning: init_database.sql not found. Skipping database initialization.${NC}"
fi

echo ""
echo "Step 4: Applying migrations..."

# Apply any additional migrations if they exist
if [ -f "$DATABASE_DIR/migration_add_university_fields.sql" ]; then
    echo "Running migration_add_university_fields.sql..."
    docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < "$DATABASE_DIR/migration_add_university_fields.sql" || true
fi

echo ""
echo "Step 5: Creating uploads directory structure..."
docker exec $DB_CONTAINER mkdir -p /app/uploads/profile_pictures || true

echo ""
echo "================================================"
echo -e "${GREEN}Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Your SaaS platform is now ready to use!"
echo ""
echo "Access points:"
echo "  - Main site: http://localhost or http://score.al-hanna.com"
echo "  - Admin dashboard: http://admin.localhost or http://admin.score.al-hanna.com"
echo ""
echo "Database details:"
echo "  - Host: localhost:5432"
echo "  - Database: $DB_NAME"
echo "  - User: $DB_USER"
echo ""
echo "Next steps:"
echo "  1. Create your first organization"
echo "  2. Register admin users"
echo "  3. Configure score categories"
echo "  4. Invite users to join"
echo ""
echo "For more information, see the documentation in the docs/ directory."
echo "================================================"

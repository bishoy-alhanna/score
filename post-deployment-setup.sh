#!/bin/bash

# Post-Deployment Database Setup Script
# This script restores a database backup and applies schema updates
# Usage: bash post-deployment-setup.sh

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓ ${NC}$1"; }
print_warning() { echo -e "${YELLOW}⚠ ${NC}$1"; }
print_error() { echo -e "${RED}✗ ${NC}$1"; }
print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Detect Docker Compose command
detect_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    else
        print_error "Docker Compose not found!"
        exit 1
    fi
    export DOCKER_COMPOSE
}

# Configuration
DB_NAME="saas_platform"
DB_USER="postgres"
BACKUP_FILE="backups/backup_20251123_214617.sql"
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env.production"

print_header "Post-Deployment Database Setup"

# Change to script directory
cd "$(dirname "$0")"

# Detect docker-compose command
detect_docker_compose
print_info "Using Docker Compose: $DOCKER_COMPOSE"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Backup file not found: $BACKUP_FILE"
    print_info "Available backups:"
    ls -lh backups/*.sql* 2>/dev/null || echo "No backups found"
    exit 1
fi

print_success "Backup file found: $BACKUP_FILE"

# Check if services are running
print_header "Checking Services"

if ! $DOCKER_COMPOSE -f "$COMPOSE_FILE" ps | grep -q "Up"; then
    print_warning "Services are not running. Starting services..."
    if [ -f "$ENV_FILE" ]; then
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    else
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
    fi
    
    print_info "Waiting for database to be ready (30 seconds)..."
    sleep 30
fi

# Check if PostgreSQL is ready
print_info "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres pg_isready -U "$DB_USER" &>/dev/null; then
        print_success "PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "PostgreSQL is not responding after 30 seconds"
        exit 1
    fi
    sleep 1
done

# Step 1: Restore database backup
print_header "Step 1: Restoring Database Backup"

print_warning "This will REPLACE the current database with the backup!"
read -p "Continue with database restore? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Database restore skipped."
    SKIP_RESTORE=true
else
    SKIP_RESTORE=false
    
    print_info "Stopping backend services..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" stop auth-service user-service group-service scoring-service leaderboard-service api-gateway
    
    print_info "Dropping existing connections..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" || true
    
    print_info "Dropping and recreating database..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;"
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"
    
    print_info "Restoring from backup: $BACKUP_FILE"
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        gunzip -c "$BACKUP_FILE" | $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" "$DB_NAME"
    else
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" "$DB_NAME" < "$BACKUP_FILE"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Database backup restored successfully"
    else
        print_error "Database restore failed!"
        exit 1
    fi
fi

# Step 2: Apply schema updates
print_header "Step 2: Applying Schema Updates"

print_info "Applying schema migrations..."

# Add organization filter columns if they don't exist
print_info "Checking organization filter settings columns..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" << 'EOF'
-- Add filter columns to organizations table if they don't exist
DO $$ 
BEGIN
    -- Check and add filter_enabled
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'filter_enabled'
    ) THEN
        ALTER TABLE organizations ADD COLUMN filter_enabled BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added filter_enabled column';
    ELSE
        RAISE NOTICE 'filter_enabled column already exists';
    END IF;

    -- Check and add filter_start_date
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'filter_start_date'
    ) THEN
        ALTER TABLE organizations ADD COLUMN filter_start_date DATE;
        RAISE NOTICE 'Added filter_start_date column';
    ELSE
        RAISE NOTICE 'filter_start_date column already exists';
    END IF;

    -- Check and add filter_end_date
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'filter_end_date'
    ) THEN
        ALTER TABLE organizations ADD COLUMN filter_end_date DATE;
        RAISE NOTICE 'Added filter_end_date column';
    ELSE
        RAISE NOTICE 'filter_end_date column already exists';
    END IF;
END $$;
EOF

print_success "Organization filter columns checked/added"

# Verify user_organizations table has is_active column
print_info "Checking user_organizations is_active column..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" << 'EOF'
-- Add is_active column to user_organizations if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_organizations' AND column_name = 'is_active'
    ) THEN
        ALTER TABLE user_organizations ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
        -- Set existing records to active
        UPDATE user_organizations SET is_active = TRUE WHERE is_active IS NULL;
        RAISE NOTICE 'Added is_active column and set existing records to active';
    ELSE
        RAISE NOTICE 'is_active column already exists';
    END IF;
END $$;
EOF

print_success "User organizations is_active column checked/added"

# Add role column to user_organizations if it doesn't exist
print_info "Checking user_organizations role column..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" << 'EOF'
-- Add role column to user_organizations if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_organizations' AND column_name = 'role'
    ) THEN
        ALTER TABLE user_organizations ADD COLUMN role VARCHAR(50) DEFAULT 'USER';
        -- Set existing records to USER role
        UPDATE user_organizations SET role = 'USER' WHERE role IS NULL;
        RAISE NOTICE 'Added role column and set existing records to USER';
    ELSE
        RAISE NOTICE 'role column already exists';
    END IF;
END $$;
EOF

print_success "User organizations role column checked/added"

# Create indexes for better performance
print_info "Creating/verifying performance indexes..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" << 'EOF'
-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_scores_organization_id ON scores(organization_id);
CREATE INDEX IF NOT EXISTS idx_scores_user_id ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_group_id ON scores(group_id);
CREATE INDEX IF NOT EXISTS idx_scores_created_at ON scores(created_at);
CREATE INDEX IF NOT EXISTS idx_scores_org_user ON scores(organization_id, user_id);
CREATE INDEX IF NOT EXISTS idx_scores_org_created ON scores(organization_id, created_at);

CREATE INDEX IF NOT EXISTS idx_user_organizations_user_id ON user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_org_id ON user_organizations(organization_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_active ON user_organizations(organization_id, is_active);

-- Show created indexes
SELECT 'Created/verified indexes' as status;
EOF

print_success "Performance indexes created/verified"

# Display schema update summary
print_header "Schema Update Summary"

$DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" << 'EOF'
-- Display table summaries
SELECT 'ORGANIZATIONS TABLE' as info;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'organizations' 
AND column_name IN ('filter_enabled', 'filter_start_date', 'filter_end_date')
ORDER BY column_name;

SELECT 'USER_ORGANIZATIONS TABLE' as info;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'user_organizations' 
AND column_name IN ('is_active', 'role')
ORDER BY column_name;

SELECT 'DATA SUMMARY' as info;
SELECT 
    (SELECT COUNT(*) FROM organizations) as total_organizations,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM user_organizations WHERE is_active = true) as active_memberships,
    (SELECT COUNT(*) FROM user_organizations WHERE is_active = false) as inactive_memberships,
    (SELECT COUNT(*) FROM scores) as total_scores;
EOF

# Step 3: Restart services
print_header "Step 3: Restarting Services"

print_info "Restarting all backend services..."
if [ -f "$ENV_FILE" ]; then
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
else
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
fi

print_info "Waiting for services to start (15 seconds)..."
sleep 15

# Check service status
print_info "Service status:"
$DOCKER_COMPOSE -f "$COMPOSE_FILE" ps

# Final summary
print_header "Post-Deployment Setup Complete!"

echo ""
echo "Summary:"
if [ "$SKIP_RESTORE" = false ]; then
    echo "  ✅ Database restored from: $BACKUP_FILE"
else
    echo "  ⏭️  Database restore skipped"
fi
echo "  ✅ Schema migrations applied"
echo "  ✅ Performance indexes created"
echo "  ✅ All services restarted"
echo ""
echo "Next Steps:"
echo "  1. Verify services are running: $DOCKER_COMPOSE -f $COMPOSE_FILE ps"
echo "  2. Check logs: $DOCKER_COMPOSE -f $COMPOSE_FILE logs -f"
echo "  3. Test admin dashboard: http://YOUR_SERVER:3001"
echo "  4. Test user dashboard: http://YOUR_SERVER:3000"
echo "  5. Verify leaderboard shows only active members"
echo ""
print_success "Setup completed successfully!"

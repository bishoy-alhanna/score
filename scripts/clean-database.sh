#!/bin/bash

# ================================================================
# SaaS Platform - Database Cleanup Script
# ================================================================
# This script cleans all data from the database while preserving
# the schema structure.
# ================================================================

set -e  # Exit on error

echo "================================================"
echo "SaaS Platform - Database Cleanup"
echo "================================================"
echo ""

# Configuration
DB_CONTAINER="saas_postgres"
DB_NAME="saas_platform"
DB_USER="postgres"

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

# Check if database container is running
if ! docker ps | grep -q $DB_CONTAINER; then
    echo -e "${RED}Error: PostgreSQL container is not running.${NC}"
    echo "Please start your Docker containers with: docker-compose up -d"
    exit 1
fi

echo -e "${YELLOW}WARNING: This will delete ALL data from the database!${NC}"
echo "This includes:"
echo "  - All users"
echo "  - All organizations"
echo "  - All groups"
echo "  - All scores"
echo "  - All user-organization relationships"
echo "  - All uploaded files (profile pictures)"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Step 1: Displaying current data counts..."
echo "--------------------------------------------"

docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -c "
SELECT 
    'Users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'Organizations', COUNT(*) FROM organizations
UNION ALL
SELECT 'Groups', COUNT(*) FROM groups
UNION ALL
SELECT 'Scores', COUNT(*) FROM scores
UNION ALL
SELECT 'User Organizations', COUNT(*) FROM user_organizations
UNION ALL
SELECT 'Organization Join Requests', COUNT(*) FROM organization_join_requests
UNION ALL
SELECT 'Score Categories', COUNT(*) FROM score_categories
UNION ALL
SELECT 'QR Scan Logs', COUNT(*) FROM qr_scan_logs;
"

echo ""
echo "Step 2: Cleaning database tables..."
echo "--------------------------------------------"

# Clean data in correct order (respecting foreign key constraints)
docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -c "
BEGIN;

-- Delete in order to respect foreign key constraints
DELETE FROM qr_scan_logs;
DELETE FROM score_aggregates;
DELETE FROM scores;
DELETE FROM group_members;
DELETE FROM groups;
DELETE FROM organization_invitations;
DELETE FROM organization_join_requests;
DELETE FROM user_organizations;
DELETE FROM users;
DELETE FROM score_categories;
DELETE FROM organizations;
DELETE FROM super_admin_config;

COMMIT;
"

echo -e "${GREEN}Database tables cleaned successfully!${NC}"

echo ""
echo "Step 3: Cleaning uploaded files..."
echo "--------------------------------------------"

# Clean profile pictures from auth-service container
docker exec saas_auth_service sh -c "rm -rf /app/uploads/profile_pictures/* 2>/dev/null || true" || true
echo "Profile pictures directory cleaned."

echo ""
echo "Step 4: Verifying cleanup..."
echo "--------------------------------------------"

docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -c "
SELECT 
    'Users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'Organizations', COUNT(*) FROM organizations
UNION ALL
SELECT 'Groups', COUNT(*) FROM groups
UNION ALL
SELECT 'Scores', COUNT(*) FROM scores
UNION ALL
SELECT 'User Organizations', COUNT(*) FROM user_organizations
UNION ALL
SELECT 'Organization Join Requests', COUNT(*) FROM organization_join_requests
UNION ALL
SELECT 'Score Categories', COUNT(*) FROM score_categories
UNION ALL
SELECT 'QR Scan Logs', COUNT(*) FROM qr_scan_logs;
"

echo ""
echo "================================================"
echo -e "${GREEN}Database Cleanup Complete!${NC}"
echo "================================================"
echo ""
echo "The database is now empty and ready for fresh data."
echo ""
echo "Next steps:"
echo "  1. Create your first organization"
echo "  2. Register admin users"
echo "  3. Configure score categories"
echo "  4. Invite users to join"
echo ""
echo "================================================"

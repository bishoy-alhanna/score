#!/bin/bash

# Backup from Production Server and Restore to Local
# Usage: ./backup-from-prod.sh [production-server-ssh]

set -e

echo "========================================="
echo "Production to Local Database Migration"
echo "========================================="
echo ""

# Configuration
PROD_SERVER="${1:-root@your-production-server.com}"
PROD_DB_CONTAINER="score_postgres_prod"
PROD_DB_NAME="saas_platform"
PROD_DB_USER="postgres"
LOCAL_DB_CONTAINER="saas_postgres"
LOCAL_DB_NAME="saas_platform"
LOCAL_DB_USER="postgres"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/prod_backup_$TIMESTAMP.sql.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Step 1: Backing up production database from $PROD_SERVER..."
echo "This will:"
echo "  • Connect to production server via SSH"
echo "  • Create a compressed backup of the database"
echo "  • Download it to your local machine"
echo ""

# Check if SSH key is set up
read -p "Do you have SSH access to the production server? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo ""
    echo "Please set up SSH access first:"
    echo "  ssh-copy-id $PROD_SERVER"
    echo ""
    echo "Or provide the backup file manually and use restore-database.sh"
    exit 1
fi

# Backup from production server
echo ""
echo "Creating backup on production server..."
ssh "$PROD_SERVER" "docker exec $PROD_DB_CONTAINER pg_dump -U $PROD_DB_USER $PROD_DB_NAME | gzip" > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✅ Production backup created: $BACKUP_FILE ($BACKUP_SIZE)"
else
    echo "❌ Failed to create production backup"
    exit 1
fi

echo ""
echo "Step 2: Restoring to local development environment..."
echo "⚠️  WARNING: This will REPLACE your local database!"
echo ""
read -p "Continue with restore? (yes/no): " -r

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled. Backup saved at: $BACKUP_FILE"
    exit 0
fi

# Stop local services
echo ""
echo "Stopping local services..."
docker-compose stop auth-service user-service group-service scoring-service leaderboard-service api-gateway

# Drop and recreate local database
echo "Recreating local database..."
docker-compose exec -T postgres psql -U "$LOCAL_DB_USER" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$LOCAL_DB_NAME' AND pid <> pg_backend_pid();" 2>/dev/null || true
docker-compose exec -T postgres psql -U "$LOCAL_DB_USER" -c "DROP DATABASE IF EXISTS $LOCAL_DB_NAME;"
docker-compose exec -T postgres psql -U "$LOCAL_DB_USER" -c "CREATE DATABASE $LOCAL_DB_NAME;"

# Restore the backup
echo "Restoring production backup to local database..."
gunzip -c "$BACKUP_FILE" | docker-compose exec -T postgres psql -U "$LOCAL_DB_USER" "$LOCAL_DB_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Production database restored to local successfully!"
else
    echo "❌ Failed to restore database"
    exit 1
fi

# Restart services
echo ""
echo "Restarting local services..."
docker-compose start auth-service user-service group-service scoring-service leaderboard-service api-gateway

# Verify restoration
echo ""
echo "Verifying restoration..."
USER_COUNT=$(docker-compose exec -T postgres psql -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -t -c "SELECT COUNT(*) FROM users;")
ORG_COUNT=$(docker-compose exec -T postgres psql -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -t -c "SELECT COUNT(*) FROM organizations;")
SCORE_COUNT=$(docker-compose exec -T postgres psql -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -t -c "SELECT COUNT(*) FROM scores;")

echo "Database Contents:"
echo "  • Users: $USER_COUNT"
echo "  • Organizations: $ORG_COUNT"
echo "  • Scores: $SCORE_COUNT"

echo ""
echo "========================================="
echo "Migration Complete!"
echo "========================================="
echo "Production backup saved at: $BACKUP_FILE"
echo "Local database now contains production data"
echo ""
echo "You can now test the leaderboard with real production data!"

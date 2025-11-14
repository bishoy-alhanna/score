#!/bin/bash

# Database Initialization Script
# Initializes or resets the Score platform database

set -e  # Exit on error

echo "========================================="
echo "Score Platform - Database Initialization"
echo "========================================="
echo ""

# Configuration
DB_CONTAINER="saas_postgres"
DB_NAME="saas_platform"
DB_USER="postgres"
SCHEMA_FILE="database/init_complete_schema.sql"

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo "❌ Error: Docker is not running"
    exit 1
fi

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "❌ Error: PostgreSQL container '${DB_CONTAINER}' not found"
    echo "Please start your Docker containers first: docker-compose up -d"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "⚠️  PostgreSQL container is not running. Starting it..."
    docker-compose up -d postgres
    echo "Waiting for PostgreSQL to be ready..."
    sleep 5
fi

# Menu
echo "Select an option:"
echo "1) Initialize database (first time setup)"
echo "2) Reset database (WARNING: This will delete all data!)"
echo "3) Backup current database"
echo "4) Exit"
echo ""
read -p "Enter option (1-4): " option

case $option in
    1)
        echo ""
        echo "Initializing database..."
        echo "This will create all tables and insert default data."
        read -p "Continue? (y/n): " confirm
        
        if [ "$confirm" = "y" ]; then
            docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < $SCHEMA_FILE
            
            if [ $? -eq 0 ]; then
                echo ""
                echo "✅ Database initialized successfully!"
                echo ""
                echo "Default Admin Credentials:"
                echo "  Username: admin"
                echo "  Email: admin@score.com"
                echo "  Password: admin123"
                echo ""
                echo "⚠️  IMPORTANT: Change the admin password immediately!"
            else
                echo "❌ Error initializing database"
                exit 1
            fi
        else
            echo "Cancelled"
        fi
        ;;
        
    2)
        echo ""
        echo "⚠️  WARNING: This will delete ALL data in the database!"
        echo "This action cannot be undone."
        echo ""
        read -p "Are you absolutely sure? Type 'RESET' to confirm: " confirm
        
        if [ "$confirm" = "RESET" ]; then
            echo ""
            echo "Creating backup before reset..."
            BACKUP_FILE="database/backups/backup_$(date +%Y%m%d_%H%M%S).sql"
            mkdir -p database/backups
            docker exec $DB_CONTAINER pg_dump -U $DB_USER $DB_NAME > $BACKUP_FILE
            echo "✅ Backup saved to: $BACKUP_FILE"
            
            echo ""
            echo "Resetting database..."
            
            # Drop and recreate database
            docker exec $DB_CONTAINER psql -U $DB_USER -c "DROP DATABASE IF EXISTS ${DB_NAME};"
            docker exec $DB_CONTAINER psql -U $DB_USER -c "CREATE DATABASE ${DB_NAME};"
            
            # Initialize schema
            docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < $SCHEMA_FILE
            
            if [ $? -eq 0 ]; then
                echo ""
                echo "✅ Database reset successfully!"
                echo ""
                echo "Default Admin Credentials:"
                echo "  Username: admin"
                echo "  Email: admin@score.com"
                echo "  Password: admin123"
            else
                echo "❌ Error resetting database"
                echo "You can restore from backup: $BACKUP_FILE"
                exit 1
            fi
        else
            echo "Cancelled"
        fi
        ;;
        
    3)
        echo ""
        echo "Creating database backup..."
        BACKUP_FILE="database/backups/backup_$(date +%Y%m%d_%H%M%S).sql"
        mkdir -p database/backups
        
        docker exec $DB_CONTAINER pg_dump -U $DB_USER $DB_NAME > $BACKUP_FILE
        
        if [ $? -eq 0 ]; then
            echo "✅ Backup created successfully!"
            echo "Location: $BACKUP_FILE"
            
            # Show backup size
            SIZE=$(du -h $BACKUP_FILE | cut -f1)
            echo "Size: $SIZE"
        else
            echo "❌ Error creating backup"
            exit 1
        fi
        ;;
        
    4)
        echo "Exiting..."
        exit 0
        ;;
        
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "Database operation completed!"
echo "========================================="

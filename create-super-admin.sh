#!/bin/bash

# Create Super Admin User Script
# This script creates the super admin user in the database

set -e

echo "=========================================="
echo "Creating Super Admin User"
echo "=========================================="
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
elif [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
else
    echo "ERROR: No .env file found!"
    exit 1
fi

# Default values if not set in .env
SUPER_ADMIN_USERNAME=${SUPER_ADMIN_USERNAME:-admin}
SUPER_ADMIN_PASSWORD=${SUPER_ADMIN_PASSWORD:-SuperBishoy@2024!}
SUPER_ADMIN_EMAIL=${SUPER_ADMIN_EMAIL:-admin@escore.al-hanna.com}
SUPER_ADMIN_FIRST_NAME=${SUPER_ADMIN_FIRST_NAME:-Super}
SUPER_ADMIN_LAST_NAME=${SUPER_ADMIN_LAST_NAME:-Admin}

echo "Super Admin Details:"
echo "  Username: $SUPER_ADMIN_USERNAME"
echo "  Email: $SUPER_ADMIN_EMAIL"
echo "  Name: $SUPER_ADMIN_FIRST_NAME $SUPER_ADMIN_LAST_NAME"
echo ""

# Python script to create super admin
PYTHON_SCRIPT="
import sys
import psycopg2
from werkzeug.security import generate_password_hash
import uuid
from datetime import datetime

# Database connection
try:
    conn = psycopg2.connect(
        host='localhost',
        port=5432,
        database='saas_platform',
        user='${POSTGRES_USER:-postgres}',
        password='${POSTGRES_PASSWORD}'
    )
    cursor = conn.cursor()
    
    # Check if super admin already exists
    cursor.execute('SELECT id FROM users WHERE username = %s OR email = %s', 
                   ('${SUPER_ADMIN_USERNAME}', '${SUPER_ADMIN_EMAIL}'))
    existing = cursor.fetchone()
    
    if existing:
        print('Super admin user already exists!')
        print('User ID:', existing[0])
        
        # Update password
        password_hash = generate_password_hash('${SUPER_ADMIN_PASSWORD}')
        cursor.execute('''
            UPDATE users 
            SET password_hash = %s, is_super_admin = true, is_active = true, updated_at = %s
            WHERE username = %s
        ''', (password_hash, datetime.utcnow(), '${SUPER_ADMIN_USERNAME}'))
        conn.commit()
        print('Password updated successfully!')
    else:
        # Create new super admin
        user_id = str(uuid.uuid4())
        password_hash = generate_password_hash('${SUPER_ADMIN_PASSWORD}')
        
        cursor.execute('''
            INSERT INTO users (
                id, username, email, password_hash, first_name, last_name,
                is_super_admin, is_active, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ''', (
            user_id,
            '${SUPER_ADMIN_USERNAME}',
            '${SUPER_ADMIN_EMAIL}',
            password_hash,
            '${SUPER_ADMIN_FIRST_NAME}',
            '${SUPER_ADMIN_LAST_NAME}',
            True,  # is_super_admin
            True,  # is_active
            datetime.utcnow(),
            datetime.utcnow()
        ))
        conn.commit()
        print('Super admin created successfully!')
        print('User ID:', user_id)
    
    cursor.close()
    conn.close()
    print('')
    print('Login credentials:')
    print('  Username: ${SUPER_ADMIN_USERNAME}')
    print('  Password: ${SUPER_ADMIN_PASSWORD}')
    
except Exception as e:
    print('ERROR:', str(e))
    sys.exit(1)
"

# Execute the Python script inside the postgres container
echo "Creating super admin user in database..."
docker exec -i score_postgres_prod python3 << EOF
$PYTHON_SCRIPT
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Super Admin Created Successfully!"
    echo "=========================================="
    echo ""
    echo "You can now login with:"
    echo "  URL: https://admin.escore.al-hanna.com"
    echo "  Username: $SUPER_ADMIN_USERNAME"
    echo "  Password: $SUPER_ADMIN_PASSWORD"
    echo ""
else
    echo ""
    echo "❌ Failed to create super admin user"
    echo "Please check the error messages above"
    exit 1
fi

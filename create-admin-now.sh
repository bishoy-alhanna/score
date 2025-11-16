#!/bin/bash

# Create Super Admin User - Direct PostgreSQL Method
# This script creates the super admin user using PostgreSQL's built-in functions

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

# Default values
SUPER_ADMIN_USERNAME=${SUPER_ADMIN_USERNAME:-admin}
SUPER_ADMIN_EMAIL=${SUPER_ADMIN_EMAIL:-admin@escore.al-hanna.com}
SUPER_ADMIN_FIRST_NAME=${SUPER_ADMIN_FIRST_NAME:-Super}
SUPER_ADMIN_LAST_NAME=${SUPER_ADMIN_LAST_NAME:-Admin}
SUPER_ADMIN_PASSWORD=${SUPER_ADMIN_PASSWORD:-SuperBishoy@2024!}

echo "Super Admin Details:"
echo "  Username: $SUPER_ADMIN_USERNAME"
echo "  Email: $SUPER_ADMIN_EMAIL"
echo "  Password: $SUPER_ADMIN_PASSWORD"
echo ""

# Use bcrypt-style password hash (Werkzeug compatible)
# We'll use a pre-hashed version or generate it via API call
echo "Creating super admin via API call to auth service..."

# Wait for auth service to be ready
echo "Waiting for auth service to be ready..."
for i in {1..30}; do
    if docker exec score_auth_service_prod curl -sf http://localhost:5001/health > /dev/null 2>&1; then
        echo "Auth service is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Auth service is not responding"
        exit 1
    fi
    sleep 2
done

# Create a temporary Python script in the auth-service container
echo "Generating password hash in auth-service container..."

docker exec -i score_auth_service_prod /bin/sh << 'SCRIPT'
cd /app
cat > /tmp/create_admin.py << 'PYTHON_EOF'
import os
import sys
sys.path.insert(0, '/app')

from werkzeug.security import generate_password_hash
from sqlalchemy import create_engine, text
from datetime import datetime
import uuid

# Get database URL from environment
DATABASE_URL = os.environ.get('DATABASE_URL')
if not DATABASE_URL:
    print("ERROR: DATABASE_URL not set")
    sys.exit(1)

# Get admin details from environment
username = os.environ.get('SUPER_ADMIN_USERNAME', 'admin')
email = os.environ.get('SUPER_ADMIN_EMAIL', 'admin@escore.al-hanna.com')
first_name = os.environ.get('SUPER_ADMIN_FIRST_NAME', 'Super')
last_name = os.environ.get('SUPER_ADMIN_LAST_NAME', 'Admin')
password = os.environ.get('SUPER_ADMIN_PASSWORD', 'SuperBishoy@2024!')

# Generate password hash
password_hash = generate_password_hash(password)

# Connect to database
engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    # Check if user exists
    result = conn.execute(
        text("SELECT id FROM users WHERE username = :username OR email = :email"),
        {"username": username, "email": email}
    )
    existing_user = result.fetchone()
    
    if existing_user:
        # Update existing user
        conn.execute(
            text("""
                UPDATE users 
                SET password_hash = :password_hash,
                    is_super_admin = true,
                    is_active = true,
                    updated_at = NOW()
                WHERE username = :username OR email = :email
            """),
            {
                "password_hash": password_hash,
                "username": username,
                "email": email
            }
        )
        conn.commit()
        print(f"✅ Super admin '{username}' updated successfully!")
        print(f"User ID: {existing_user[0]}")
    else:
        # Create new user
        user_id = str(uuid.uuid4())
        conn.execute(
            text("""
                INSERT INTO users (
                    id, username, email, password_hash, first_name, last_name,
                    is_super_admin, is_active, created_at, updated_at
                ) VALUES (
                    :id, :username, :email, :password_hash, :first_name, :last_name,
                    :is_super_admin, :is_active, NOW(), NOW()
                )
            """),
            {
                "id": user_id,
                "username": username,
                "email": email,
                "password_hash": password_hash,
                "first_name": first_name,
                "last_name": last_name,
                "is_super_admin": True,
                "is_active": True
            }
        )
        conn.commit()
        print(f"✅ Super admin '{username}' created successfully!")
        print(f"User ID: {user_id}")

    # Display user info
    result = conn.execute(
        text("SELECT id, username, email, is_super_admin, is_active FROM users WHERE username = :username"),
        {"username": username}
    )
    user = result.fetchone()
    print(f"\nUser Details:")
    print(f"  ID: {user[0]}")
    print(f"  Username: {user[1]}")
    print(f"  Email: {user[2]}")
    print(f"  Super Admin: {user[3]}")
    print(f"  Active: {user[4]}")

PYTHON_EOF

# Run the Python script with environment variables
python /tmp/create_admin.py
SCRIPT

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Super Admin Created Successfully!"
    echo "=========================================="
    echo ""
    echo "Login at: https://admin.escore.al-hanna.com"
    echo "Username: $SUPER_ADMIN_USERNAME"
    echo "Password: $SUPER_ADMIN_PASSWORD"
    echo ""
else
    echo ""
    echo "❌ Failed to create super admin"
    exit 1
fi

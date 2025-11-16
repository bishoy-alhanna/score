#!/bin/bash

# Fix Admin Password Hash - Use Auth Service Method
# This generates the hash using the exact same code as auth service login

set -e

echo "=========================================="
echo "Fixing Super Admin Password Hash"
echo "=========================================="
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
elif [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
fi

SUPER_ADMIN_USERNAME=${SUPER_ADMIN_USERNAME:-admin}
SUPER_ADMIN_PASSWORD=${SUPER_ADMIN_PASSWORD:-SuperBishoy@2024!}

echo "Fixing password for: $SUPER_ADMIN_USERNAME"
echo ""

# Generate password hash using auth-service's Werkzeug
echo "Generating password hash using auth-service..."

# Create a Python script inside the auth-service container
docker exec -i score_auth_service_prod python << PYSCRIPT
import sys
import os
sys.path.insert(0, '/app')

from werkzeug.security import generate_password_hash, check_password_hash
from sqlalchemy import create_engine, text

# Get credentials
username = '${SUPER_ADMIN_USERNAME}'
password = '${SUPER_ADMIN_PASSWORD}'

# Generate hash with default Werkzeug method
password_hash = generate_password_hash(password)
print(f"Generated hash: {password_hash[:60]}...")

# Connect to database
database_url = os.environ.get('DATABASE_URL')
engine = create_engine(database_url)

with engine.connect() as conn:
    # Update the user's password
    result = conn.execute(
        text("""
            UPDATE users 
            SET password_hash = :password_hash,
                is_super_admin = true,
                is_active = true,
                updated_at = NOW()
            WHERE username = :username
            RETURNING id, username, email
        """),
        {"password_hash": password_hash, "username": username}
    )
    conn.commit()
    
    user = result.fetchone()
    if user:
        print(f"\n✅ Password updated for user: {user[1]} ({user[2]})")
        print(f"   User ID: {user[0]}")
        
        # Verify the hash works
        result = conn.execute(
            text("SELECT password_hash FROM users WHERE username = :username"),
            {"username": username}
        )
        stored_hash = result.fetchone()[0]
        
        if check_password_hash(stored_hash, password):
            print(f"\n✅ Password verification SUCCESSFUL!")
            print(f"   The password '{password}' will work for login")
        else:
            print(f"\n❌ Password verification FAILED!")
            print(f"   Something went wrong with the hash")
            sys.exit(1)
    else:
        print(f"\n❌ User '{username}' not found!")
        sys.exit(1)

print(f"\n{'='*50}")
print(f"✅ SUCCESS! Password is ready to use")
print(f"{'='*50}")
PYSCRIPT

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Password Fixed Successfully!"
    echo "=========================================="
    echo ""
    echo "Test login now:"
    echo ""
    echo "1. From command line:"
    echo "   curl -X POST http://localhost/api/super-admin/login \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"username\":\"$SUPER_ADMIN_USERNAME\",\"password\":\"$SUPER_ADMIN_PASSWORD\"}'"
    echo ""
    echo "2. From web browser:"
    echo "   🌐 https://admin.escore.al-hanna.com"
    echo "   👤 Username: $SUPER_ADMIN_USERNAME"
    echo "   🔑 Password: $SUPER_ADMIN_PASSWORD"
    echo ""
else
    echo ""
    echo "❌ Failed to fix password"
    echo ""
    echo "Make sure auth-service is running:"
    echo "  docker-compose -f docker-compose.prod.yml ps auth-service"
    exit 1
fi

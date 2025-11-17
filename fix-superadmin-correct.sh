#!/bin/bash

# Fix Super Admin Password - Correct Table and Hash Method
# Super admin uses SuperAdminConfig table with bcrypt, not users table with Werkzeug!

set -e

echo "=========================================="
echo "Fixing Super Admin Password (Correct Method)"
echo "=========================================="
echo ""

cd ~/score 2>/dev/null || cd /home/bihannaroot/score 2>/dev/null || cd $(dirname "$0")

if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

SUPER_ADMIN_USERNAME=${SUPER_ADMIN_USERNAME:-superadmin}
SUPER_ADMIN_PASSWORD=${SUPER_ADMIN_PASSWORD:-SuperBishoy@123!}

echo "Updating super admin in SuperAdminConfig table"
echo "Username: $SUPER_ADMIN_USERNAME"
echo "Password: $SUPER_ADMIN_PASSWORD"
echo ""

# Generate bcrypt hash and update SuperAdminConfig table
docker exec -i score_auth_service_prod python << PYSCRIPT
import sys
import os
sys.path.insert(0, '/app')

import bcrypt
from sqlalchemy import create_engine, text

username = '${SUPER_ADMIN_USERNAME}'
password = '${SUPER_ADMIN_PASSWORD}'

# Generate bcrypt hash (same as auth service uses)
password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
print(f"Generated bcrypt hash: {password_hash[:60]}...")

# Connect to database
database_url = os.environ.get('DATABASE_URL')
engine = create_engine(database_url)

with engine.connect() as conn:
    # Check if super_admin_config table exists
    result = conn.execute(text("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_name = 'super_admin_config'
        )
    """))
    table_exists = result.fetchone()[0]
    
    if not table_exists:
        print("Creating super_admin_config table...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS super_admin_config (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                username VARCHAR(255) UNIQUE NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.commit()
        print("✅ Table created")
    
    # Check if admin exists
    result = conn.execute(
        text("SELECT id, username FROM super_admin_config WHERE username = :username"),
        {"username": username}
    )
    existing = result.fetchone()
    
    if existing:
        # Update existing
        conn.execute(
            text("""
                UPDATE super_admin_config 
                SET password_hash = :password_hash,
                    is_active = true,
                    updated_at = NOW()
                WHERE username = :username
            """),
            {"password_hash": password_hash, "username": username}
        )
        conn.commit()
        print(f"\n✅ Updated existing super admin: {existing[1]}")
    else:
        # Create new
        conn.execute(
            text("""
                INSERT INTO super_admin_config (username, password_hash, is_active)
                VALUES (:username, :password_hash, true)
            """),
            {
                "username": username,
                "password_hash": password_hash
            }
        )
        conn.commit()
        print(f"\n✅ Created new super admin: {username}")
    
    # Verify the password works
    result = conn.execute(
        text("SELECT password_hash FROM super_admin_config WHERE username = :username"),
        {"username": username}
    )
    stored_hash = result.fetchone()[0]
    
    if bcrypt.checkpw(password.encode('utf-8'), stored_hash.encode('utf-8')):
        print(f"\n✅ Password verification SUCCESSFUL!")
        print(f"\n{'='*50}")
        print(f"🎉 Super admin is ready!")
        print(f"{'='*50}")
        print(f"\nLogin at: https://admin.escore.al-hanna.com")
        print(f"Username: {username}")
        print(f"Password: {password}")
    else:
        print(f"\n❌ Password verification FAILED!")
        sys.exit(1)
PYSCRIPT

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Failed to update super admin"
    exit 1
fi

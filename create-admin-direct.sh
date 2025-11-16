#!/bin/bash

# Create Super Admin - Direct Database Method
# Works even if auth-service is not running

set -e

echo "=========================================="
echo "Creating Super Admin User (Direct DB)"
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

# Admin details
SUPER_ADMIN_USERNAME=${SUPER_ADMIN_USERNAME:-admin}
SUPER_ADMIN_EMAIL=${SUPER_ADMIN_EMAIL:-admin@escore.al-hanna.com}
SUPER_ADMIN_FIRST_NAME=${SUPER_ADMIN_FIRST_NAME:-Super}
SUPER_ADMIN_LAST_NAME=${SUPER_ADMIN_LAST_NAME:-Admin}
SUPER_ADMIN_PASSWORD=${SUPER_ADMIN_PASSWORD:-SuperBishoy@2024!}

echo "Creating admin user:"
echo "  Username: $SUPER_ADMIN_USERNAME"
echo "  Email: $SUPER_ADMIN_EMAIL"
echo ""

# Generate a Werkzeug-compatible password hash
# Using pbkdf2:sha256 method (Werkzeug default)
echo "Generating password hash..."

# Use Python to generate the hash (most systems have python3)
PASSWORD_HASH=$(python3 << 'PYSCRIPT'
from hashlib import pbkdf2_hmac
import base64
import os

password = os.environ.get('SUPER_ADMIN_PASSWORD', 'SuperBishoy@2024!')
salt = os.urandom(16)
iterations = 260000
key = pbkdf2_hmac('sha256', password.encode('utf-8'), salt, iterations)

# Format as Werkzeug hash: pbkdf2:sha256:iterations$salt$hash
hash_str = f"pbkdf2:sha256:{iterations}${base64.b64encode(salt).decode('ascii')}${base64.b64encode(key).decode('ascii')}"
print(hash_str)
PYSCRIPT
)

if [ -z "$PASSWORD_HASH" ]; then
    echo "ERROR: Failed to generate password hash"
    echo "Make sure Python 3 is installed on the host system"
    exit 1
fi

echo "Password hash generated successfully"
echo ""

# SQL to insert/update admin
SQL="
DO \$\$
DECLARE
    user_exists BOOLEAN;
    user_uuid UUID;
BEGIN
    -- Check if user exists
    SELECT EXISTS(
        SELECT 1 FROM users 
        WHERE username = '${SUPER_ADMIN_USERNAME}' OR email = '${SUPER_ADMIN_EMAIL}'
    ) INTO user_exists;
    
    IF user_exists THEN
        -- Update existing user
        UPDATE users 
        SET password_hash = '${PASSWORD_HASH}',
            is_super_admin = true,
            is_active = true,
            updated_at = NOW()
        WHERE username = '${SUPER_ADMIN_USERNAME}' OR email = '${SUPER_ADMIN_EMAIL}'
        RETURNING id INTO user_uuid;
        
        RAISE NOTICE 'Updated existing super admin user: %', user_uuid;
    ELSE
        -- Create new user
        INSERT INTO users (
            id, username, email, password_hash, first_name, last_name,
            is_super_admin, is_active, created_at, updated_at
        ) VALUES (
            gen_random_uuid(),
            '${SUPER_ADMIN_USERNAME}',
            '${SUPER_ADMIN_EMAIL}',
            '${PASSWORD_HASH}',
            '${SUPER_ADMIN_FIRST_NAME}',
            '${SUPER_ADMIN_LAST_NAME}',
            true,
            true,
            NOW(),
            NOW()
        )
        RETURNING id INTO user_uuid;
        
        RAISE NOTICE 'Created new super admin user: %', user_uuid;
    END IF;
END \$\$;

-- Show the created/updated user
SELECT 
    id, 
    username, 
    email, 
    first_name || ' ' || last_name as full_name,
    is_super_admin,
    is_active,
    created_at
FROM users 
WHERE username = '${SUPER_ADMIN_USERNAME}' OR email = '${SUPER_ADMIN_EMAIL}';
"

# Execute SQL
echo "Executing SQL in PostgreSQL..."
docker exec -i score_postgres_prod psql -U ${POSTGRES_USER:-postgres} -d saas_platform << EOF
$SQL
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Super Admin Created Successfully!"
    echo "=========================================="
    echo ""
    echo "🌐 Login at: https://admin.escore.al-hanna.com"
    echo "👤 Username: $SUPER_ADMIN_USERNAME"
    echo "🔑 Password: $SUPER_ADMIN_PASSWORD"
    echo ""
    echo "Note: If you can't login, make sure auth-service is running:"
    echo "  docker-compose -f docker-compose.prod.yml restart auth-service"
    echo ""
else
    echo ""
    echo "❌ Failed to create super admin user"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check if PostgreSQL is running:"
    echo "   docker-compose -f docker-compose.prod.yml ps postgres"
    echo ""
    echo "2. Check PostgreSQL logs:"
    echo "   docker-compose -f docker-compose.prod.yml logs postgres"
    echo ""
    exit 1
fi

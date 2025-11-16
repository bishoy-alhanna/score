#!/bin/bash

# Create Super Admin User - Simple SQL Version
# This script creates the super admin user directly in PostgreSQL

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

echo "Super Admin Details:"
echo "  Username: $SUPER_ADMIN_USERNAME"
echo "  Email: $SUPER_ADMIN_EMAIL"
echo ""

# Generate password hash using Python (Werkzeug)
echo "Generating password hash..."
PASSWORD_HASH=$(docker exec -i score_auth_service_prod python3 -c "
from werkzeug.security import generate_password_hash
print(generate_password_hash('${SUPER_ADMIN_PASSWORD}'))
")

if [ -z "$PASSWORD_HASH" ]; then
    echo "ERROR: Failed to generate password hash"
    exit 1
fi

# SQL to create or update super admin
SQL="
DO \$\$
DECLARE
    user_exists BOOLEAN;
BEGIN
    -- Check if user exists
    SELECT EXISTS(SELECT 1 FROM users WHERE username = '${SUPER_ADMIN_USERNAME}' OR email = '${SUPER_ADMIN_EMAIL}') INTO user_exists;
    
    IF user_exists THEN
        -- Update existing user
        UPDATE users 
        SET password_hash = '${PASSWORD_HASH}',
            is_super_admin = true,
            is_active = true,
            updated_at = NOW()
        WHERE username = '${SUPER_ADMIN_USERNAME}' OR email = '${SUPER_ADMIN_EMAIL}';
        
        RAISE NOTICE 'Super admin user updated!';
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
        );
        
        RAISE NOTICE 'Super admin user created!';
    END IF;
END \$\$;

-- Display the created user
SELECT id, username, email, first_name, last_name, is_super_admin, is_active, created_at
FROM users 
WHERE username = '${SUPER_ADMIN_USERNAME}' OR email = '${SUPER_ADMIN_EMAIL}';
"

# Execute SQL in postgres container
echo "Executing SQL in database..."
docker exec -i score_postgres_prod psql -U ${POSTGRES_USER:-postgres} -d saas_platform << EOF
$SQL
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Super Admin Ready!"
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

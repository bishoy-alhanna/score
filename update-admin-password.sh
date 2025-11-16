#!/bin/bash

# Update Super Admin Password
# This script updates the admin password with a properly hashed version

set -e

echo "=========================================="
echo "Updating Super Admin Password"
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

SUPER_ADMIN_USERNAME=${SUPER_ADMIN_USERNAME:-admin}
SUPER_ADMIN_PASSWORD=${SUPER_ADMIN_PASSWORD:-SuperBishoy@2024!}

echo "Updating password for: $SUPER_ADMIN_USERNAME"
echo "New password: $SUPER_ADMIN_PASSWORD"
echo ""

# Generate password hash using the auth-service container
echo "Generating Werkzeug password hash..."

PASSWORD_HASH=$(docker exec -i score_auth_service_prod python << 'PYSCRIPT'
import sys
import os
sys.path.insert(0, '/app')

from werkzeug.security import generate_password_hash

password = os.environ.get('SUPER_ADMIN_PASSWORD', 'SuperBishoy@2024!')
hash_value = generate_password_hash(password)
print(hash_value)
PYSCRIPT
)

if [ -z "$PASSWORD_HASH" ]; then
    echo "ERROR: Failed to generate password hash"
    echo "Make sure auth-service container is running:"
    echo "  docker-compose -f docker-compose.prod.yml ps auth-service"
    exit 1
fi

echo "✅ Password hash generated"
echo ""

# Update the user's password in database
echo "Updating password in database..."

docker exec -i score_postgres_prod psql -U ${POSTGRES_USER:-postgres} -d saas_platform << EOF
UPDATE users 
SET password_hash = '${PASSWORD_HASH}',
    is_super_admin = true,
    is_active = true,
    updated_at = NOW()
WHERE username = '${SUPER_ADMIN_USERNAME}';

-- Show the updated user
SELECT id, username, email, is_super_admin, is_active, 
       substring(password_hash, 1, 50) || '...' as password_hash_preview,
       updated_at
FROM users 
WHERE username = '${SUPER_ADMIN_USERNAME}';
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Password Updated Successfully!"
    echo "=========================================="
    echo ""
    echo "You can now login at:"
    echo "  🌐 https://admin.escore.al-hanna.com"
    echo "  👤 Username: $SUPER_ADMIN_USERNAME"
    echo "  🔑 Password: $SUPER_ADMIN_PASSWORD"
    echo ""
    echo "Test login from command line:"
    echo "  curl -X POST http://localhost/api/super-admin/login \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"username\":\"$SUPER_ADMIN_USERNAME\",\"password\":\"$SUPER_ADMIN_PASSWORD\"}'"
    echo ""
else
    echo ""
    echo "❌ Failed to update password"
    exit 1
fi

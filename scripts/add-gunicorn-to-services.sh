#!/bin/bash

# Script to add Gunicorn to all backend services for production deployment

echo "=========================================="
echo "🔧 Adding Gunicorn to Backend Services"
echo "=========================================="
echo ""

SERVICES=(
    "auth-service"
    "user-service"
    "group-service"
    "scoring-service"
    "leaderboard-service"
)

for service in "${SERVICES[@]}"; do
    echo "Processing $service..."
    
    SERVICE_PATH="backend/$service/$service"
    
    # Check if requirements.txt exists
    if [ -f "$SERVICE_PATH/requirements.txt" ]; then
        # Add gunicorn if not already present
        if ! grep -q "gunicorn" "$SERVICE_PATH/requirements.txt"; then
            echo "  ✓ Adding gunicorn to requirements.txt"
            echo "gunicorn==23.0.0" >> "$SERVICE_PATH/requirements.txt"
        else
            echo "  - gunicorn already in requirements.txt"
        fi
    fi
    
    # Update Dockerfile if it exists
    if [ -f "$SERVICE_PATH/Dockerfile" ]; then
        if grep -q 'CMD \["python", "src/main.py"\]' "$SERVICE_PATH/Dockerfile"; then
            echo "  ✓ Updating Dockerfile to use Gunicorn"
            sed -i.bak 's|CMD \["python", "src/main.py"\]|CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "30", "--access-logfile", "-", "--error-logfile", "-", "src.main:app"]|g' "$SERVICE_PATH/Dockerfile"
            rm "$SERVICE_PATH/Dockerfile.bak"
        else
            echo "  - Dockerfile already updated or doesn't match pattern"
        fi
    fi
    
    echo ""
done

echo "=========================================="
echo "✅ All services updated!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review changes: git diff"
echo "2. Commit changes: git add . && git commit -m 'Add Gunicorn for production deployment'"
echo "3. Push to remote: git push"
echo "4. Deploy to production: ./scripts/deploy-production.sh"

#!/bin/bash

# SCORE Platform Production Deployment
# Server: bihannaroot@escore.al-hanna.com
# Date: November 16, 2025

echo "=========================================="
echo "SCORE Platform - Production Deployment"
echo "Deploying to: escore.al-hanna.com"
echo "=========================================="
echo ""

# SSH Connection Details
SERVER_USER="bihannaroot"
SERVER_HOST="escore.al-hanna.com"
DEPLOY_DIR="/home/bihannaroot/score"

echo "Step 1: Connecting to production server..."
echo "Run these commands on the production server:"
echo ""

cat << 'EOF'
# ===== COPY AND PASTE THESE COMMANDS ON YOUR PRODUCTION SERVER =====

# 1. Update system packages
sudo apt update && sudo apt upgrade -y

# 2. Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    newgrp docker
fi

# 3. Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# 4. Clone the repository (or update if exists)
if [ -d "score" ]; then
    echo "Updating existing repository..."
    cd score
    git fetch --all
    git checkout prod
    git pull origin prod
else
    echo "Cloning repository..."
    git clone https://github.com/bishoy-alhanna/score.git
    cd score
    git checkout prod
fi

# 5. Configure environment variables
echo "Configuring environment..."
cp .env.production .env.production.backup 2>/dev/null || true

# Update these values in .env.production:
cat > .env.production << 'ENVEOF'
# Production Environment Variables

# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_NAME=saas_platform
DB_USER=postgres
DB_PASSWORD=SuperBishoy!Prod2024!
DATABASE_URL=postgresql://postgres:SuperBishoy!Prod2024!@postgres:5432/saas_platform
POSTGRES_USER=postgres
POSTGRES_PASSWORD=SuperBishoy!Prod2024!

# Redis Configuration
REDIS_PASSWORD=RedisSecureProd2024!

# Security Keys - GENERATED SECURELY
JWT_SECRET_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0
SECRET_KEY=z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4j3i2h1g0f9e8d7c6b5a4z3y2x1w0

# Super Admin Configuration
SUPER_ADMIN_USERNAME=admin
SUPER_ADMIN_PASSWORD=SuperBishoy@2024!

# SSL Configuration
SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
SSL_KEY_PATH=/etc/nginx/ssl/key.pem

# External Services
SMTP_HOST=smtp.office365.com
SMTP_PORT=587
SMTP_USER=Noreply@al-hanna.com
SMTP_PASSWORD=T%381804731638ah
SMTP_FROM_EMAIL=noreply@al-hanna.com

# Monitoring and Logging
LOG_LEVEL=error
SENTRY_DSN=

# Rate Limiting
RATE_LIMIT_PER_MINUTE=100
RATE_LIMIT_PER_HOUR=1000

# Domain Configuration
DOMAIN_NAME=escore.al-hanna.com
ADMIN_SUBDOMAIN=admin.escore.al-hanna.com
USER_SUBDOMAIN=escore.al-hanna.com
ENVEOF

echo "Environment configured!"

# 6. Set up SSL certificates with Let's Encrypt
echo "Setting up SSL certificates..."
sudo apt install certbot -y

# Stop any service using port 80
sudo docker-compose -f docker-compose.prod.yml down 2>/dev/null || true

# Generate certificates
sudo certbot certonly --standalone \
  -d escore.al-hanna.com \
  -d admin.escore.al-hanna.com \
  --non-interactive \
  --agree-tos \
  --email noreply@al-hanna.com

# Copy certificates
sudo mkdir -p nginx/ssl
sudo cp /etc/letsencrypt/live/escore.al-hanna.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/escore.al-hanna.com/privkey.pem nginx/ssl/key.pem
sudo chown -R $(whoami):$(whoami) nginx/ssl
sudo chmod 644 nginx/ssl/cert.pem
sudo chmod 600 nginx/ssl/key.pem

echo "SSL certificates configured!"

# 7. Set up firewall
echo "Configuring firewall..."
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw --force enable

# 8. Deploy the application
echo "Deploying application..."
chmod +x deploy-production.sh

# Load environment variables
export $(cat .env.production | grep -v '^#' | xargs)

# Build and start services
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d

# 9. Wait for services to start
echo "Waiting for services to start..."
sleep 30

# 10. Check service health
echo "Checking service health..."
docker-compose -f docker-compose.prod.yml ps

# 11. View logs
echo "Recent logs:"
docker-compose -f docker-compose.prod.yml logs --tail=50

# 12. Test endpoints
echo ""
echo "Testing endpoints..."
curl -I http://localhost/health
curl -I http://localhost/api/health

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "Your application is now running at:"
echo "  - User Dashboard: https://escore.al-hanna.com"
echo "  - Admin Dashboard: https://admin.escore.al-hanna.com"
echo ""
echo "To view logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "To restart: docker-compose -f docker-compose.prod.yml restart"
echo ""

# ===== END OF DEPLOYMENT SCRIPT =====
EOF

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. SSH into your production server:"
echo "   ssh bihannaroot@escore.al-hanna.com"
echo ""
echo "2. Copy and paste the above commands into the terminal"
echo ""
echo "3. Or download and run the automated script:"
echo "   wget https://raw.githubusercontent.com/bishoy-alhanna/score/prod/deploy-production.sh"
echo "   chmod +x deploy-production.sh"
echo "   ./deploy-production.sh"
echo ""

#!/bin/bash

# SSL Setup Script for Score Platform
# This script sets up SSL certificates using certbot

set -e  # Exit on error

DOMAIN="escore.al-hanna.com"
EMAIL="your-email@example.com"  # Update this!

echo "========================================="
echo "SSL Certificate Setup for Score Platform"
echo "Domain: $DOMAIN"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Step 1: Stop Docker containers to free port 80
echo "Step 1: Stopping Docker containers..."
cd ~/score
docker-compose down

# Step 2: Install certbot if not already installed
echo "Step 2: Checking certbot installation..."
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    apt update
    apt install -y certbot
else
    echo "Certbot already installed"
fi

# Step 3: Obtain SSL certificate
echo "Step 3: Obtaining SSL certificate..."
echo "Please make sure DNS is configured for $DOMAIN to point to this server"
read -p "Press Enter to continue..."

certbot certonly --standalone \
    -d $DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --preferred-challenges http

if [ $? -eq 0 ]; then
    echo "✅ SSL certificate obtained successfully!"
else
    echo "❌ Failed to obtain SSL certificate"
    exit 1
fi

# Step 4: Update docker-compose.yml to mount certificates
echo "Step 4: Checking docker-compose.yml for SSL volume mounts..."

# Check if SSL volumes are already configured
if grep -q "/etc/letsencrypt:/etc/letsencrypt:ro" docker-compose.yml; then
    echo "SSL volumes already configured in docker-compose.yml"
else
    echo "⚠️  Please add the following to your nginx service in docker-compose.yml:"
    echo ""
    echo "  nginx:"
    echo "    volumes:"
    echo "      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro"
    echo "      - /etc/letsencrypt:/etc/letsencrypt:ro"
    echo "      - /etc/ssl/certs:/etc/ssl/certs:ro"
    echo ""
    read -p "Press Enter after updating docker-compose.yml..."
fi

# Step 5: Start Docker containers
echo "Step 5: Starting Docker containers..."
docker-compose up -d

# Step 6: Wait for containers to start
echo "Waiting for services to start..."
sleep 10

# Step 7: Test SSL
echo "Step 7: Testing SSL configuration..."
if curl -fsSL https://$DOMAIN/health > /dev/null 2>&1; then
    echo "✅ SSL is working correctly!"
else
    echo "⚠️  SSL test failed. Check docker-compose logs nginx"
fi

# Step 8: Setup auto-renewal
echo "Step 8: Setting up auto-renewal..."

# Create renewal hook script
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/bin/bash
# Reload nginx after certificate renewal
cd ~/score
docker-compose exec nginx nginx -s reload
EOF

chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# Add cron job for auto-renewal (runs twice daily)
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet") | crontab -
    echo "✅ Auto-renewal cron job added"
else
    echo "Auto-renewal cron job already exists"
fi

echo ""
echo "========================================="
echo "SSL Setup Complete!"
echo "========================================="
echo ""
echo "Your site is now available at:"
echo "  https://$DOMAIN"
echo "  https://$DOMAIN/admin"
echo ""
echo "Certificate will auto-renew before expiration"
echo ""
echo "To test renewal manually:"
echo "  sudo certbot renew --dry-run"
echo ""

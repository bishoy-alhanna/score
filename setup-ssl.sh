#!/bin/bash

# SSL Setup Script for escore.al-hanna.com
# This script sets up Let's Encrypt SSL certificate for your domain

set -e  # Exit on any error

DOMAIN="escore.al-hanna.com"
EMAIL="your-email@example.com"  # Change this to your email

echo "============================================"
echo "SSL Setup for $DOMAIN"
echo "============================================"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo: sudo ./setup-ssl.sh"
    exit 1
fi

# Step 1: Stop Docker containers to free port 80
echo "Step 1: Stopping Docker containers..."
cd "$(dirname "$0")"
docker-compose down

# Step 2: Install certbot if not installed
echo ""
echo "Step 2: Checking certbot installation..."
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    apt update
    apt install -y certbot
else
    echo "Certbot is already installed"
fi

# Step 3: Get SSL certificate
echo ""
echo "Step 3: Obtaining SSL certificate for $DOMAIN..."
echo "This will verify domain ownership. Make sure DNS is pointing to this server!"
echo ""

# Remove existing certificates if any (optional)
# certbot delete --cert-name $DOMAIN --non-interactive || true

# Get certificate using standalone mode
certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    --preferred-challenges http

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SSL certificate obtained successfully!"
    echo ""
    echo "Certificate files:"
    echo "  - Certificate: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    echo "  - Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
else
    echo ""
    echo "❌ Failed to obtain SSL certificate"
    echo "Please check:"
    echo "  1. DNS is pointing to this server"
    echo "  2. Port 80 is accessible from the internet"
    echo "  3. Domain name is correct"
    exit 1
fi

# Step 4: Set up auto-renewal
echo ""
echo "Step 4: Setting up auto-renewal..."

# Create renewal hook script
cat > /etc/letsencrypt/renewal-hooks/post/restart-docker.sh << 'EOF'
#!/bin/bash
cd /path/to/your/project
docker-compose restart nginx
EOF

# Update the path in the hook script
sed -i "s|/path/to/your/project|$(pwd)|g" /etc/letsencrypt/renewal-hooks/post/restart-docker.sh
chmod +x /etc/letsencrypt/renewal-hooks/post/restart-docker.sh

# Test auto-renewal
echo "Testing certificate renewal..."
certbot renew --dry-run

# Add cron job for auto-renewal (runs twice daily)
CRON_JOB="0 0,12 * * * certbot renew --quiet --post-hook 'cd $(pwd) && docker-compose restart nginx'"
(crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON_JOB") | crontab -

echo "✅ Auto-renewal configured"

# Step 5: Start Docker containers
echo ""
echo "Step 5: Starting Docker containers with HTTPS..."
docker-compose up -d

# Wait for containers to start
echo "Waiting for services to start..."
sleep 10

# Step 6: Verify setup
echo ""
echo "Step 6: Verifying HTTPS setup..."
if curl -k -s -o /dev/null -w "%{http_code}" https://$DOMAIN/health | grep -q "200"; then
    echo "✅ HTTPS is working!"
else
    echo "⚠️  HTTPS might not be working yet. Check logs:"
    echo "    docker-compose logs nginx"
fi

echo ""
echo "============================================"
echo "SSL Setup Complete! 🎉"
echo "============================================"
echo ""
echo "Your site is now available at:"
echo "  - https://$DOMAIN/"
echo "  - https://$DOMAIN/admin/"
echo "  - https://$DOMAIN/api/"
echo ""
echo "HTTP requests will automatically redirect to HTTPS"
echo ""
echo "SSL certificate will auto-renew. Check status with:"
echo "  sudo certbot certificates"
echo ""
echo "Certificate expires in 90 days and will auto-renew."
echo ""

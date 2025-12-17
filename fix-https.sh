#!/bin/bash
# Fix HTTPS on Production Server
# Run this script on the production server

set -e

echo "=========================================="
echo "🔒 Fixing HTTPS Configuration"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.prod.yml" ]; then
    echo "❌ Error: docker-compose.prod.yml not found"
    echo "Please run this script from the score project directory"
    exit 1
fi

# Backup current nginx.conf
echo "Step 1: Backing up current nginx.conf..."
cp nginx/nginx.conf nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup created"
echo ""

# Check if SSL certificates exist
echo "Step 2: Checking SSL certificates..."
if [ ! -f "nginx/ssl/cert.pem" ] || [ ! -f "nginx/ssl/key.pem" ]; then
    echo "⚠️  SSL certificates not found, generating self-signed certificates..."
    mkdir -p nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout nginx/ssl/key.pem \
        -out nginx/ssl/cert.pem \
        -subj "/C=EG/ST=Cairo/L=Cairo/O=Al-Hanna/OU=IT/CN=escore.al-hanna.com"
    echo "✅ Self-signed certificates generated"
else
    echo "✅ SSL certificates found"
fi
echo ""

# Update nginx.conf with HTTPS support
echo "Step 3: Updating nginx.conf with HTTPS configuration..."
cat > nginx/nginx.conf << 'NGINXCONF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 10M;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss;

    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;

    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Admin subdomain
    server {
        listen 80;
        server_name admin.escore.al-hanna.com;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name admin.escore.al-hanna.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        location /health {
            access_log off;
            return 200 "healthy\n";
        }

        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://api-gateway:5000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 300s;
        }

        location / {
            proxy_pass http://admin-dashboard:3000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }

    # User dashboard
    server {
        listen 80;
        server_name escore.al-hanna.com;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name escore.al-hanna.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        location /health {
            access_log off;
            return 200 "healthy\n";
        }

        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://api-gateway:5000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 300s;
        }

        location / {
            proxy_pass http://user-dashboard:3001/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
NGINXCONF

echo "✅ nginx.conf updated"
echo ""

# Restart nginx
echo "Step 4: Restarting nginx..."
docker-compose -f docker-compose.prod.yml --env-file .env.production restart nginx
sleep 5
echo "✅ Nginx restarted"
echo ""

# Check nginx status
echo "Step 5: Checking nginx status..."
docker-compose -f docker-compose.prod.yml ps nginx
echo ""

# Test configuration
echo "Step 6: Testing nginx configuration..."
docker-compose -f docker-compose.prod.yml exec nginx nginx -t
echo ""

echo "=========================================="
echo "✅ HTTPS Fix Complete!"
echo "=========================================="
echo ""
echo "Test your sites:"
echo "  - https://escore.al-hanna.com"
echo "  - https://admin.escore.al-hanna.com"
echo ""
echo "Note: Browser will show 'Not Secure' warning for self-signed certificates."
echo "Click 'Advanced' → 'Proceed to site' to access."
echo ""
echo "To check logs: docker-compose -f docker-compose.prod.yml logs nginx"
echo ""

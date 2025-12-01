# HTTPS Not Working - Quick Fix Guide

## Problem Identified ✅
The current `nginx.conf` only has HTTP (port 80) configuration without SSL/HTTPS support.

## Solution - Update Nginx Configuration

### Option 1: Quick Fix with Self-Signed Certificates (Fastest)

SSH to your production server and run these commands:

```bash
ssh bihannaroot@escore.al-hanna.com
cd /home/bihannaroot/newsystem/score

# Backup current nginx.conf
cp nginx/nginx.conf nginx/nginx.conf.backup

# Update nginx.conf to add HTTPS support
cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 10M;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";

    # ========================================
    # ADMIN SUBDOMAIN - admin.escore.al-hanna.com
    # ========================================

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name admin.escore.al-hanna.com;
        return 301 https://$host$request_uri;
    }

    # HTTPS server for admin
    server {
        listen 443 ssl http2;
        server_name admin.escore.al-hanna.com;

        # Self-signed SSL Certificates
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # API Gateway (all backend APIs)
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
            proxy_connect_timeout 75s;
        }

        # Admin Dashboard
        location / {
            proxy_pass http://admin-dashboard:3000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }
    }

    # ========================================
    # USER DASHBOARD - escore.al-hanna.com
    # ========================================

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name escore.al-hanna.com;
        return 301 https://$host$request_uri;
    }

    # HTTPS server for user dashboard
    server {
        listen 443 ssl http2;
        server_name escore.al-hanna.com;

        # Self-signed SSL Certificates
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # API Gateway (all backend APIs)
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
            proxy_connect_timeout 75s;
        }

        # User Dashboard
        location / {
            proxy_pass http://user-dashboard:3001/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
EOF

# Restart nginx to apply changes
docker-compose -f docker-compose.prod.yml restart nginx

# Check nginx status
docker-compose -f docker-compose.prod.yml ps nginx

# Check logs for any errors
docker-compose -f docker-compose.prod.yml logs --tail=50 nginx
```

### After Running These Commands:

1. **Test HTTPS URLs:**
   - https://escore.al-hanna.com
   - https://admin.escore.al-hanna.com

2. **Expected Result:**
   - Both URLs should work with HTTPS
   - Browser will show "Not Secure" warning (because self-signed cert) - this is normal
   - Click "Advanced" → "Proceed to site" to access

---

## Option 2: Use Real SSL Certificates (Recommended for Production)

If you want proper SSL certificates without browser warnings:

```bash
# On production server
cd /home/bihannaroot/newsystem/score

# Install certbot
sudo apt-get update
sudo apt-get install -y certbot

# Stop nginx temporarily
docker-compose -f docker-compose.prod.yml stop nginx

# Get certificates for both domains
sudo certbot certonly --standalone -d escore.al-hanna.com
sudo certbot certonly --standalone -d admin.escore.al-hanna.com

# Update nginx config to use Let's Encrypt certs
# (Use nginx-ssl.conf as template, update cert paths)

# Start nginx
docker-compose -f docker-compose.prod.yml up -d nginx
```

---

## Quick Verification Commands

After applying the fix:

```bash
# Check if nginx is running
docker-compose -f docker-compose.prod.yml ps nginx

# Check nginx configuration is valid
docker-compose -f docker-compose.prod.yml exec nginx nginx -t

# View nginx logs
docker-compose -f docker-compose.prod.yml logs nginx

# Test HTTPS connectivity
curl -k https://escore.al-hanna.com/health
curl -k https://admin.escore.al-hanna.com/health
```

---

## Troubleshooting

### If nginx won't start:

```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs nginx

# Test config
docker-compose -f docker-compose.prod.yml exec nginx nginx -t

# Restart nginx
docker-compose -f docker-compose.prod.yml restart nginx
```

### If certificates not found:

```bash
# Check if SSL files exist
ls -la nginx/ssl/

# If missing, generate self-signed certs:
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/CN=escore.al-hanna.com"
```

---

## Summary

**The issue:** `nginx.conf` has no HTTPS/SSL configuration  
**The fix:** Update nginx.conf to add SSL support with existing certificates  
**Time required:** 2-3 minutes  

Run **Option 1** commands above to fix immediately! 🚀

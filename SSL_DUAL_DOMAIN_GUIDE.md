# SSL Setup Guide - Dual Domain Configuration

Complete guide for setting up SSL certificates for:
- `score.al-hanna.com` (main user dashboard)
- `admin.score.al-hanna.com` (admin dashboard)

## Quick Start Guide

### Prerequisites
✅ Both domains must point to your server IP (DNS A records)
✅ Docker and Docker Compose installed
✅ Ports 80 and 443 open on firewall
✅ Root/sudo access

### Step-by-Step Setup

**1. Edit the SSL setup script**
```bash
nano setup-ssl-dual-domain.sh
# Change: EMAIL="your-email@example.com"
```

**2. Make it executable**
```bash
chmod +x setup-ssl-dual-domain.sh
```

**3. Run the script**
```bash
sudo ./setup-ssl-dual-domain.sh
```

**4. Update docker-compose.yml**
Add to the nginx service:
```yaml
nginx:
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - /etc/letsencrypt:/etc/letsencrypt:ro
    - /var/www/certbot:/var/www/certbot:ro
```

**5. Use the SSL nginx configuration**
```bash
cp nginx/nginx.conf nginx/nginx.conf.backup
cp nginx/nginx-ssl.conf nginx/nginx.conf
```

**6. Rebuild and restart**
```bash
docker-compose build nginx
docker-compose up -d
```

**7. Test**
- Visit: https://score.al-hanna.com
- Visit: https://admin.score.al-hanna.com

## Certificate Locations

```
/etc/letsencrypt/live/score.al-hanna.com/
├── fullchain.pem      # SSL certificate (use this)
├── privkey.pem        # Private key (use this)
├── chain.pem          # Intermediate certificates
└── cert.pem           # Your certificate only

/etc/letsencrypt/live/admin.score.al-hanna.com/
├── fullchain.pem
├── privkey.pem
├── chain.pem
└── cert.pem
```

## Automatic Renewal

✅ Certificates auto-renew via daily cron job
✅ Certificates expire after 90 days
✅ Auto-renewal happens at 30 days before expiry

**Check certificate status:**
```bash
sudo certbot certificates
```

**Test renewal (dry run):**
```bash
sudo certbot renew --dry-run
```

**Manual renewal:**
```bash
sudo certbot renew
docker exec saas_nginx nginx -s reload
```

## Nginx SSL Configuration Features

### 🔒 Security Features
- TLS 1.2 and 1.3 only
- Strong cipher suites
- HSTS enabled (forces HTTPS for 1 year)
- Security headers (X-Frame-Options, etc.)
- SSL stapling enabled

### 🔄 Auto-Redirect
- All HTTP traffic → HTTPS automatically
- Certbot renewal path (/.well-known/acme-challenge/) preserved

### 📋 Configuration Structure

**For each domain:**
1. HTTP server (port 80) - redirects to HTTPS
2. HTTPS server (port 443) - serves the application

**Example for main domain:**
```nginx
# HTTP → HTTPS redirect
server {
    listen 80;
    server_name score.al-hanna.com;
    
    # Allow certbot
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect everything else
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name score.al-hanna.com;
    
    ssl_certificate /etc/letsencrypt/live/score.al-hanna.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/score.al-hanna.com/privkey.pem;
    
    # Application configuration...
}
```

## Troubleshooting

### ❌ DNS Not Configured
```bash
# Check DNS
nslookup score.al-hanna.com
dig score.al-hanna.com

# Wait for propagation (up to 48 hours)
```

### ❌ Port 80 In Use
```bash
# Find what's using it
sudo lsof -i :80

# Stop containers
docker-compose down

# Run setup again
sudo ./setup-ssl-dual-domain.sh
```

### ❌ Certificate Renewal Fails
```bash
# Check logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
docker logs saas_nginx

# Ensure nginx is running during renewal
docker-compose up -d nginx

# Test manually
sudo certbot renew --verbose
```

### ❌ Browser Shows "Not Secure"
- Clear browser cache
- Check certificate dates: `sudo certbot certificates`
- Verify fullchain.pem is used (not cert.pem)
- Check nginx is using correct cert paths

### ❌ Mixed Content Warnings
- Ensure all resources load via HTTPS
- Check API calls use relative URLs or HTTPS
- Verify `X-Forwarded-Proto` header is set

## Testing SSL

### Online Tools
- **SSL Labs:** https://www.ssllabs.com/ssltest/
  - Test both domains
  - Aim for A+ rating

### Command Line
```bash
# Test SSL connection
openssl s_client -connect score.al-hanna.com:443

# Check expiry
echo | openssl s_client -connect score.al-hanna.com:443 2>/dev/null | \
  openssl x509 -noout -dates

# Test HTTP/2
curl -I --http2 https://score.al-hanna.com

# Check HSTS header
curl -I https://score.al-hanna.com | grep -i strict-transport-security

# Verify redirect
curl -I http://score.al-hanna.com
```

## Manual Setup (If Script Fails)

**1. Install Certbot**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install certbot

# CentOS/RHEL
sudo yum install certbot

# macOS
brew install certbot
```

**2. Stop containers**
```bash
docker-compose down
```

**3. Get certificates**
```bash
# Main domain
sudo certbot certonly --standalone \
  --preferred-challenges http \
  --email your-email@example.com \
  --agree-tos \
  -d score.al-hanna.com

# Admin domain
sudo certbot certonly --standalone \
  --preferred-challenges http \
  --email your-email@example.com \
  --agree-tos \
  -d admin.score.al-hanna.com
```

**4. Setup renewal cron**
```bash
echo '0 0 * * * certbot renew --quiet --deploy-hook "docker exec saas_nginx nginx -s reload"' | \
  sudo crontab -
```

**5. Continue with steps 4-6 from Quick Start**

## Security Best Practices

✅ **Monitor certificate expiration**
- Set up alerts 30 days before expiry
- Check monthly: `sudo certbot certificates`

✅ **Keep strong SSL configuration**
- Only TLS 1.2 and 1.3
- Modern ciphers only
- Regular security audits

✅ **Enable and test HSTS**
- Included in config (max-age=31536000)
- Forces browsers to use HTTPS

✅ **Backup certificates**
```bash
# Backup entire letsencrypt directory
sudo tar -czf letsencrypt-backup.tar.gz /etc/letsencrypt/
```

✅ **Regular SSL testing**
- Monthly SSL Labs scan
- Monitor for vulnerabilities

## Quick Reference

```bash
# Certificate management
sudo certbot certificates              # List all certificates
sudo certbot renew                     # Renew all certificates
sudo certbot delete --cert-name DOMAIN # Delete certificate

# Nginx operations
docker exec saas_nginx nginx -t        # Test configuration
docker exec saas_nginx nginx -s reload # Reload nginx
docker logs saas_nginx -f              # View logs

# SSL testing
openssl s_client -connect score.al-hanna.com:443 -servername score.al-hanna.com
echo | openssl s_client -connect score.al-hanna.com:443 2>/dev/null | openssl x509 -noout -dates

# Container operations
docker-compose build nginx             # Rebuild nginx
docker-compose up -d nginx             # Start nginx
docker-compose restart nginx           # Restart nginx
```

## Files Created

After setup, you'll have:

1. **SSL Certificates:** `/etc/letsencrypt/live/`
2. **Setup Script:** `setup-ssl-dual-domain.sh`
3. **SSL Config:** `nginx/nginx-ssl.conf`
4. **Config Backup:** `nginx/nginx.conf.backup.YYYYMMDD_HHMMSS`
5. **Renewal Cron:** `/etc/cron.daily/certbot-renew`

## Support & Resources

- **Let's Encrypt Docs:** https://letsencrypt.org/docs/
- **Certbot Docs:** https://certbot.eff.org/docs/
- **Nginx SSL Docs:** https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- **SSL Labs:** https://www.ssllabs.com/ssltest/

---

**Version:** 1.0  
**Last Updated:** November 2025  
**Domains:** score.al-hanna.com, admin.score.al-hanna.com

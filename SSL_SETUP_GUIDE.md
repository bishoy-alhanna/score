# SSL/HTTPS Setup for escore.al-hanna.com

## Quick Setup (Ubuntu Server)

### Method 1: Using the Automated Script

```bash
# Make the script executable
chmod +x setup-ssl.sh

# Run it (requires sudo)
sudo ./setup-ssl.sh
```

**Important:** Edit `setup-ssl.sh` first and change `EMAIL="your-email@example.com"` to your actual email address.

---

### Method 2: Manual Setup

#### Step 1: Stop Docker Containers
```bash
cd /path/to/Score/score
docker-compose down
```

#### Step 2: Install Certbot
```bash
sudo apt update
sudo apt install -y certbot
```

#### Step 3: Get SSL Certificate
```bash
sudo certbot certonly --standalone -d escore.al-hanna.com
```

Follow the prompts:
- Enter your email address
- Agree to terms of service
- Choose whether to share email with EFF

The certificates will be saved to:
- Certificate: `/etc/letsencrypt/live/escore.al-hanna.com/fullchain.pem`
- Private Key: `/etc/letsencrypt/live/escore.al-hanna.com/privkey.pem`

#### Step 4: Start Docker with HTTPS
```bash
docker-compose up -d
```

#### Step 5: Verify HTTPS
```bash
curl -I https://escore.al-hanna.com/health
```

You should see `HTTP/2 200` in the response.

---

## Configuration Files

### docker-compose.yml
Already updated with:
```yaml
nginx:
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - /etc/letsencrypt:/etc/letsencrypt:ro
    - /etc/ssl/certs:/etc/ssl/certs:ro
```

### nginx.conf
Already configured with:
- HTTPS server block (port 443)
- HTTP to HTTPS redirect (port 80)
- SSL certificate paths
- Strong SSL/TLS settings

---

## Auto-Renewal Setup

Let's Encrypt certificates expire every 90 days. Set up auto-renewal:

### Test Renewal
```bash
sudo certbot renew --dry-run
```

### Setup Cron Job
```bash
# Edit crontab
sudo crontab -e

# Add this line (renews twice daily)
0 0,12 * * * certbot renew --quiet --post-hook "cd /path/to/Score/score && docker-compose restart nginx"
```

---

## Troubleshooting

### Error: Port 80 already in use
```bash
# Find what's using port 80
sudo lsof -i :80

# If it's system nginx
sudo systemctl stop nginx
sudo systemctl disable nginx

# If it's Docker
docker-compose down
```

### Error: DNS not pointing to server
```bash
# Check DNS
dig escore.al-hanna.com

# Should show your server's IP address
```

### Error: Firewall blocking
```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status
```

### Check Certificate Status
```bash
sudo certbot certificates
```

### View nginx logs
```bash
docker-compose logs nginx
```

### Test HTTPS
```bash
# Check if site is accessible
curl -I https://escore.al-hanna.com

# Check SSL certificate details
openssl s_client -connect escore.al-hanna.com:443 -servername escore.al-hanna.com
```

---

## Security Notes

1. **Strong SSL Configuration**: Using TLS 1.2 and 1.3 only
2. **HSTS Header**: Enforces HTTPS for 1 year
3. **Security Headers**: X-Frame-Options, X-Content-Type-Options, etc.
4. **Auto-renewal**: Certificate renews automatically before expiration

---

## URLs After Setup

✅ **User Dashboard**: https://escore.al-hanna.com/  
✅ **Admin Dashboard**: https://escore.al-hanna.com/admin/  
✅ **API**: https://escore.al-hanna.com/api/

All HTTP requests automatically redirect to HTTPS.

---

## Certificate Renewal

Certificates auto-renew, but you can manually renew:

```bash
# Force renewal
sudo certbot renew --force-renewal

# Restart nginx after renewal
docker-compose restart nginx
```

---

## Backup Certificates

```bash
# Backup Let's Encrypt directory
sudo tar -czf letsencrypt-backup.tar.gz /etc/letsencrypt/

# Restore on new server
sudo tar -xzf letsencrypt-backup.tar.gz -C /
```

---

## Testing Checklist

- [ ] DNS points to server IP
- [ ] Port 80 and 443 are open
- [ ] Docker containers stopped before certbot
- [ ] SSL certificate obtained successfully
- [ ] Docker containers restarted
- [ ] HTTPS site accessible
- [ ] HTTP redirects to HTTPS
- [ ] Admin dashboard works on HTTPS
- [ ] API works on HTTPS
- [ ] Auto-renewal tested

---

## Need Help?

If you encounter issues:

1. Check DNS: `dig escore.al-hanna.com`
2. Check ports: `sudo lsof -i :80` and `sudo lsof -i :443`
3. Check logs: `docker-compose logs nginx`
4. Verify cert: `sudo certbot certificates`
5. Test renewal: `sudo certbot renew --dry-run`

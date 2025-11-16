#!/bin/bash

# SSL Setup Script for Score Platform - Dual Domain Configuration
# This script sets up SSL certificates using Let's Encrypt (Certbot)
# for both score.al-hanna.com and admin.score.al-hanna.com

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN_MAIN="escore.al-hanna.com"
DOMAIN_ADMIN="admin.escore.al-hanna.com"
EMAIL="bishoy@al-hanna.com"  # *** CHANGE THIS TO YOUR EMAIL ***
CERT_PATH="/etc/letsencrypt"
WEBROOT="/var/www/certbot"

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_message "$RED" "Please run this script as root or with sudo"
        print_message "$YELLOW" "Usage: sudo ./setup-ssl-dual-domain.sh"
        exit 1
    fi
}

# Function to check if docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_message "$RED" "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_message "$RED" "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_message "$GREEN" "✓ Docker and Docker Compose are installed"
}

# Function to check DNS configuration
check_dns() {
    print_message "$YELLOW" "Checking DNS configuration..."
    
    local all_dns_ok=true
    
    # Check main domain
    if host "$DOMAIN_MAIN" &> /dev/null; then
        local ip=$(host "$DOMAIN_MAIN" | grep "has address" | awk '{print $4}' | head -1)
        print_message "$GREEN" "✓ $DOMAIN_MAIN resolves to: $ip"
    else
        print_message "$RED" "✗ DNS for $DOMAIN_MAIN is not configured"
        all_dns_ok=false
    fi
    
    # Check admin domain
    if host "$DOMAIN_ADMIN" &> /dev/null; then
        local ip=$(host "$DOMAIN_ADMIN" | grep "has address" | awk '{print $4}' | head -1)
        print_message "$GREEN" "✓ $DOMAIN_ADMIN resolves to: $ip"
    else
        print_message "$RED" "✗ DNS for $DOMAIN_ADMIN is not configured"
        all_dns_ok=false
    fi
    
    if [ "$all_dns_ok" = false ]; then
        print_message "$RED" "Please configure DNS before continuing"
        print_message "$YELLOW" "Both domains must point to this server's IP address"
        exit 1
    fi
}

# Function to create necessary directories
create_directories() {
    print_message "$YELLOW" "Creating necessary directories..."
    
    mkdir -p "$WEBROOT"
    mkdir -p "$CERT_PATH/live"
    mkdir -p "$CERT_PATH/renewal"
    
    print_message "$GREEN" "✓ Directories created"
}

# Function to install certbot
install_certbot() {
    print_message "$YELLOW" "Checking Certbot installation..."
    
    if ! command -v certbot &> /dev/null; then
        print_message "$YELLOW" "Installing Certbot..."
        
        # Detect OS
        if [ -f /etc/debian_version ]; then
            apt-get update
            apt-get install -y certbot
        elif [ -f /etc/redhat-release ]; then
            yum install -y certbot
        elif [ "$(uname)" == "Darwin" ]; then
            print_message "$YELLOW" "On macOS, please install certbot manually:"
            print_message "$YELLOW" "brew install certbot"
            exit 1
        else
            print_message "$RED" "Unsupported OS. Please install Certbot manually."
            exit 1
        fi
        
        print_message "$GREEN" "✓ Certbot installed"
    else
        print_message "$GREEN" "✓ Certbot is already installed"
    fi
}

# Function to stop docker containers
stop_containers() {
    print_message "$YELLOW" "Stopping Docker containers to free port 80..."
    
    cd "$(dirname "$0")"
    docker-compose down
    
    print_message "$GREEN" "✓ Containers stopped"
}

# Function to obtain SSL certificates
obtain_certificates() {
    print_message "$YELLOW" "Obtaining SSL certificates..."
    
    # Obtain certificate for main domain
    if [ ! -d "$CERT_PATH/live/$DOMAIN_MAIN" ]; then
        print_message "$YELLOW" "Obtaining certificate for $DOMAIN_MAIN..."
        
        certbot certonly \
            --standalone \
            --preferred-challenges http \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --non-interactive \
            -d "$DOMAIN_MAIN"
        
        if [ $? -eq 0 ]; then
            print_message "$GREEN" "✓ Certificate obtained for $DOMAIN_MAIN"
        else
            print_message "$RED" "Failed to obtain certificate for $DOMAIN_MAIN"
            exit 1
        fi
    else
        print_message "$GREEN" "✓ Certificate already exists for $DOMAIN_MAIN"
    fi
    
    # Obtain certificate for admin domain
    if [ ! -d "$CERT_PATH/live/$DOMAIN_ADMIN" ]; then
        print_message "$YELLOW" "Obtaining certificate for $DOMAIN_ADMIN..."
        
        certbot certonly \
            --standalone \
            --preferred-challenges http \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --non-interactive \
            -d "$DOMAIN_ADMIN"
        
        if [ $? -eq 0 ]; then
            print_message "$GREEN" "✓ Certificate obtained for $DOMAIN_ADMIN"
        else
            print_message "$RED" "Failed to obtain certificate for $DOMAIN_ADMIN"
            exit 1
        fi
    else
        print_message "$GREEN" "✓ Certificate already exists for $DOMAIN_ADMIN"
    fi
}

# Function to backup nginx configuration
backup_nginx_config() {
    print_message "$YELLOW" "Backing up current nginx configuration..."
    
    if [ -f "nginx/nginx.conf" ]; then
        cp nginx/nginx.conf "nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)"
        print_message "$GREEN" "✓ Backup created"
    fi
}

# Function to update docker-compose for SSL
update_docker_compose() {
    print_message "$YELLOW" "Checking docker-compose.yml for SSL volumes..."
    
    # Check if certbot volumes are already configured
    if grep -q "/etc/letsencrypt:/etc/letsencrypt" docker-compose.yml; then
        print_message "$GREEN" "✓ SSL volumes already configured in docker-compose.yml"
    else
        print_message "$YELLOW" "Please add the following volumes to your nginx service in docker-compose.yml:"
        echo ""
        echo "    volumes:"
        echo "      - /etc/letsencrypt:/etc/letsencrypt:ro"
        echo "      - /var/www/certbot:/var/www/certbot:ro"
        echo ""
    fi
}

# Function to setup automatic renewal
setup_renewal() {
    print_message "$YELLOW" "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > /etc/cron.daily/certbot-renew << 'EOF'
#!/bin/bash
# Renew certificates and reload nginx

certbot renew --quiet --deploy-hook "docker exec saas_nginx nginx -s reload"
EOF
    
    chmod +x /etc/cron.daily/certbot-renew
    
    print_message "$GREEN" "✓ Automatic renewal configured (daily check)"
}

# Function to start containers
start_containers() {
    print_message "$YELLOW" "Starting Docker containers..."
    
    cd "$(dirname "$0")"
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ Containers started successfully"
    else
        print_message "$RED" "Failed to start containers"
        exit 1
    fi
}

# Main execution
main() {
    print_message "$GREEN" "==========================================="
    print_message "$GREEN" "  SSL Setup for Score Platform"
    print_message "$GREEN" "==========================================="
    echo ""
    
    print_message "$YELLOW" "This script will:"
    echo "  1. Verify DNS configuration"
    echo "  2. Install Certbot (if needed)"
    echo "  3. Obtain SSL certificates for:"
    echo "     • $DOMAIN_MAIN"
    echo "     • $DOMAIN_ADMIN"
    echo "  4. Setup automatic certificate renewal"
    echo ""
    
    # Verify email is set
    if [ "$EMAIL" == "your-email@example.com" ]; then
        print_message "$RED" "ERROR: Please edit this script and set your email address"
        print_message "$YELLOW" "Edit the EMAIL variable at the top of this script"
        exit 1
    fi
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "$YELLOW" "Setup cancelled"
        exit 0
    fi
    
    # Check requirements
    check_root
    check_docker
    check_dns
    
    # Run setup steps
    create_directories
    install_certbot
    stop_containers
    obtain_certificates
    backup_nginx_config
    update_docker_compose
    setup_renewal
    
    echo ""
    print_message "$GREEN" "==========================================="
    print_message "$GREEN" "  SSL Certificates Obtained Successfully!"
    print_message "$GREEN" "==========================================="
    echo ""
    print_message "$GREEN" "Certificates are located at:"
    echo "  • $CERT_PATH/live/$DOMAIN_MAIN/"
    echo "  • $CERT_PATH/live/$DOMAIN_ADMIN/"
    echo ""
    print_message "$YELLOW" "NEXT STEPS:"
    echo "  1. Update nginx/nginx.conf with SSL configuration"
    echo "     (see nginx/nginx-ssl.conf for reference)"
    echo "  2. Update docker-compose.yml to mount SSL certificates"
    echo "  3. Run: docker-compose build nginx"
    echo "  4. Run: docker-compose up -d"
    echo "  5. Test your sites:"
    echo "     • https://$DOMAIN_MAIN"
    echo "     • https://$DOMAIN_ADMIN"
    echo ""
    print_message "$GREEN" "Certificates will be automatically renewed every day"
    echo ""
}

# Run main function
main

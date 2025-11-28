#!/bin/bash

# Score Platform - Ubuntu Deployment Script
# This script deploys the Score Platform on Ubuntu server
# Run with: sudo bash deploy-ubuntu.sh

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓ ${NC}$1"; }
print_warning() { echo -e "${YELLOW}⚠ ${NC}$1"; }
print_error() { echo -e "${RED}✗ ${NC}$1"; }
print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Detect Docker Compose command
detect_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    else
        print_error "Docker Compose not found!"
        exit 1
    fi
    export DOCKER_COMPOSE
    print_info "Using: $DOCKER_COMPOSE"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing=0
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please run setup-prerequisites-ubuntu.sh first"
        missing=1
    else
        print_success "Docker found ($(docker --version))"
    fi
    
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found"
        missing=1
    else
        print_success "Python 3 found ($(python3 --version))"
    fi
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found"
        missing=1
    else
        print_success "Node.js found ($(node --version))"
    fi
    
    if [[ $missing -eq 1 ]]; then
        print_error "Missing prerequisites"
        print_info "Run: sudo bash setup-prerequisites-ubuntu.sh"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! systemctl is-active --quiet docker; then
        print_warning "Docker is not running, starting..."
        systemctl start docker
    fi
    print_success "Docker daemon is running"
    
    detect_docker_compose
}

# Setup environment files
setup_environment() {
    print_header "Setting Up Environment"
    
    if [[ ! -f .env.production ]]; then
        print_info "Creating .env.production..."
        
        # Generate secure random passwords
        POSTGRES_PASSWORD=$(openssl rand -base64 32)
        JWT_SECRET=$(openssl rand -base64 64)
        SECRET_KEY=$(openssl rand -base64 64)
        
        cat > .env.production << EOF
# Database Configuration
POSTGRES_DB=saas_platform
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# JWT Configuration
JWT_SECRET_KEY=$JWT_SECRET
SECRET_KEY=$SECRET_KEY

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# Service URLs (internal Docker network)
AUTH_SERVICE_URL=http://auth-service:5001
USER_SERVICE_URL=http://user-service:5002
GROUP_SERVICE_URL=http://group-service:5003
SCORING_SERVICE_URL=http://scoring-service:5004
LEADERBOARD_SERVICE_URL=http://leaderboard-service:5005

# Frontend URLs
ADMIN_FRONTEND_URL=http://localhost:3001
USER_FRONTEND_URL=http://localhost:3000

# Environment
FLASK_ENV=production
NODE_ENV=production
EOF
        
        chmod 600 .env.production
        print_success "Created .env.production with secure passwords"
        print_warning "Passwords have been auto-generated. Keep this file secure!"
    else
        print_success ".env.production already exists"
    fi
}

# Create required directories
create_directories() {
    print_header "Creating Required Directories"
    
    mkdir -p backups
    mkdir -p logs
    mkdir -p data/postgres
    mkdir -p data/redis
    
    # Set proper permissions
    chmod 755 backups logs data
    
    print_success "Directories created"
}

# Pull and build Docker images
build_services() {
    print_header "Building Docker Services"
    
    print_info "This may take several minutes..."
    
    if $DOCKER_COMPOSE -f docker-compose.prod.yml --env-file .env.production build; then
        print_success "Services built successfully"
    else
        print_error "Failed to build services"
        exit 1
    fi
}

# Start services
start_services() {
    print_header "Starting Services"
    
    print_info "Starting all services..."
    
    if $DOCKER_COMPOSE -f docker-compose.prod.yml --env-file .env.production up -d; then
        print_success "Services started"
    else
        print_error "Failed to start services"
        exit 1
    fi
    
    print_info "Waiting for services to initialize (30 seconds)..."
    sleep 30
}

# Check service health
check_services() {
    print_header "Checking Service Health"
    
    $DOCKER_COMPOSE -f docker-compose.prod.yml ps
    
    echo ""
    print_info "Checking individual services..."
    
    # Check if services are running
    services=("postgres" "redis" "auth-service" "user-service" "group-service" "scoring-service" "leaderboard-service" "api-gateway")
    
    for service in "${services[@]}"; do
        if $DOCKER_COMPOSE -f docker-compose.prod.yml ps | grep -q "$service.*Up"; then
            print_success "$service is running"
        else
            print_error "$service is not running"
        fi
    done
}

# Setup systemd service for auto-start
setup_systemd_service() {
    print_header "Setting up Systemd Service (Optional)"
    
    read -p "Would you like to enable auto-start on boot? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipped systemd service setup"
        return
    fi
    
    WORK_DIR=$(pwd)
    
    cat > /etc/systemd/system/score-platform.service << EOF
[Unit]
Description=Score Platform Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$WORK_DIR
ExecStart=$DOCKER_COMPOSE -f docker-compose.prod.yml --env-file .env.production up -d
ExecStop=$DOCKER_COMPOSE -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable score-platform.service
    
    print_success "Systemd service enabled"
    print_info "Services will auto-start on boot"
    print_info "Control with: sudo systemctl {start|stop|restart|status} score-platform"
}

# Setup log rotation
setup_log_rotation() {
    print_header "Setting up Log Rotation"
    
    cat > /etc/logrotate.d/score-platform << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    missingok
    delaycompress
    copytruncate
    notifempty
}
EOF
    
    print_success "Log rotation configured"
}

# Display access information
display_info() {
    print_header "Deployment Complete!"
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "🚀 Score Platform is now running!"
    echo ""
    echo "Access URLs:"
    echo "  • Admin Dashboard: http://$SERVER_IP:3001"
    echo "  • User Dashboard:  http://$SERVER_IP:3000"
    echo "  • API Gateway:     http://$SERVER_IP:5000"
    echo ""
    echo "Database Access (from server):"
    echo "  docker exec -it score_postgres_prod psql -U postgres -d saas_platform"
    echo ""
    echo "Useful Commands:"
    echo "  • View logs:        $DOCKER_COMPOSE -f docker-compose.prod.yml logs -f"
    echo "  • Stop services:    $DOCKER_COMPOSE -f docker-compose.prod.yml down"
    echo "  • Restart services: $DOCKER_COMPOSE -f docker-compose.prod.yml restart"
    echo "  • Check status:     $DOCKER_COMPOSE -f docker-compose.prod.yml ps"
    echo ""
    if systemctl is-enabled score-platform.service &>/dev/null; then
        echo "Systemd Service:"
        echo "  • sudo systemctl status score-platform"
        echo "  • sudo systemctl restart score-platform"
        echo ""
    fi
    print_warning "Next Steps:"
    echo "  1. Run post-deployment setup: bash post-deployment-setup.sh"
    echo "     (Restores database backup and applies schema updates)"
    echo "  2. Create super admin: bash create-super-admin.sh"
    echo "  3. Configure firewall if not done"
    echo "  4. Set up SSL/TLS with nginx reverse proxy (recommended)"
    echo "  5. Configure automated backups"
    echo ""
    print_info "Security Reminders:"
    echo "  • .env.production contains sensitive passwords"
    echo "  • Secure this file: chmod 600 .env.production"
    echo "  • Set up regular database backups"
    echo "  • Configure firewall rules"
    echo "  • Use SSL/TLS in production"
    echo ""
}

# Run post-deployment setup (optional)
run_post_deployment_setup() {
    print_header "Post-Deployment Database Setup (Optional)"
    
    if [ -f "post-deployment-setup.sh" ]; then
        print_info "This will restore database backup and apply schema updates"
        read -p "Run post-deployment setup now? (y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash post-deployment-setup.sh
        else
            print_info "Skipped post-deployment setup"
            print_warning "You can run it later with: bash post-deployment-setup.sh"
        fi
    else
        print_warning "post-deployment-setup.sh not found, skipping"
    fi
}

# Main execution
main() {
    print_header "Score Platform - Ubuntu Deployment"
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    check_prerequisites
    setup_environment
    create_directories
    build_services
    start_services
    check_services
    setup_systemd_service
    setup_log_rotation
    run_post_deployment_setup
    display_info
    
    print_success "Deployment complete!"
}

# Run main function
main

#!/bin/bash

# Score Platform - Project Initialization Script
# Run this after setup-prerequisites.sh to initialize the project
# Usage: bash init-project.sh

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Check if prerequisites are installed
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing=0
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please run setup-prerequisites.sh first"
        missing=1
    else
        print_success "Docker found"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose not found"
        missing=1
    else
        print_success "docker-compose found"
    fi
    
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found. Please run setup-prerequisites.sh first"
        missing=1
    else
        print_success "Python 3 found"
    fi
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found. Please run setup-prerequisites.sh first"
        missing=1
    else
        print_success "Node.js found"
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm not found. Please run setup-prerequisites.sh first"
        missing=1
    else
        print_success "npm found"
    fi
    
    if [[ $missing -eq 1 ]]; then
        print_error "Missing prerequisites. Please run setup-prerequisites.sh first"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker ps &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker Desktop"
        exit 1
    fi
    print_success "Docker daemon is running"
}

# Setup environment files
setup_environment_files() {
    print_header "Setting Up Environment Files"
    
    if [[ ! -f .env.production ]]; then
        print_info "Creating .env.production from template..."
        
        cat > .env.production << 'EOF'
# Database Configuration
POSTGRES_DB=saas_platform
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# JWT Configuration
JWT_SECRET_KEY=your_jwt_secret_key_here_change_in_production
SECRET_KEY=your_secret_key_here_change_in_production

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
        
        print_success "Created .env.production template"
        print_warning "Please edit .env.production and set secure passwords and secret keys!"
    else
        print_success ".env.production already exists"
    fi
}

# Install frontend dependencies
install_frontend_dependencies() {
    print_header "Installing Frontend Dependencies"
    
    # Admin Dashboard
    if [[ -d "frontend/admin-dashboard/admin-dashboard" ]]; then
        print_info "Installing admin dashboard dependencies..."
        cd frontend/admin-dashboard/admin-dashboard
        npm install
        cd ../../..
        print_success "Admin dashboard dependencies installed"
    else
        print_warning "Admin dashboard directory not found"
    fi
    
    # User Dashboard
    if [[ -d "frontend/user-dashboard/user-dashboard" ]]; then
        print_info "Installing user dashboard dependencies..."
        cd frontend/user-dashboard/user-dashboard
        npm install
        cd ../../..
        print_success "User dashboard dependencies installed"
    else
        print_warning "User dashboard directory not found"
    fi
}

# Create Python virtual environments for backend services
setup_python_environments() {
    print_header "Setting Up Python Virtual Environments"
    
    print_info "Note: Python environments are managed by Docker containers"
    print_info "For local development, you can create virtual environments manually"
    print_success "Python environments will be set up by Docker"
}

# Build and start Docker containers
build_docker_containers() {
    print_header "Building Docker Containers"
    
    print_info "This may take several minutes on first run..."
    
    if docker-compose -f docker-compose.prod.yml --env-file .env.production build; then
        print_success "Docker containers built successfully"
    else
        print_error "Failed to build Docker containers"
        exit 1
    fi
}

# Start services
start_services() {
    print_header "Starting Services"
    
    print_info "Starting all services with docker-compose..."
    
    if docker-compose -f docker-compose.prod.yml --env-file .env.production up -d; then
        print_success "Services started successfully"
        
        print_info "Waiting for services to be ready (30 seconds)..."
        sleep 30
        
        print_info "Service status:"
        docker-compose -f docker-compose.prod.yml ps
    else
        print_error "Failed to start services"
        exit 1
    fi
}

# Run database migrations
run_migrations() {
    print_header "Running Database Migrations"
    
    print_info "Waiting for database to be ready..."
    sleep 10
    
    print_info "Database migrations are handled by individual services on startup"
    print_success "Migrations will run automatically"
}

# Display access information
display_access_info() {
    print_header "Installation Complete!"
    
    echo ""
    echo "🚀 Score Platform is now running!"
    echo ""
    echo "Access URLs:"
    echo "  • Admin Dashboard: http://localhost:3001"
    echo "  • User Dashboard:  http://localhost:3000"
    echo "  • API Gateway:     http://localhost:5000"
    echo ""
    echo "Database Access:"
    echo "  Host: localhost"
    echo "  Port: 5432"
    echo "  Database: saas_platform"
    echo "  User: postgres"
    echo ""
    echo "Useful Commands:"
    echo "  • View logs:        docker-compose -f docker-compose.prod.yml logs -f"
    echo "  • Stop services:    docker-compose -f docker-compose.prod.yml down"
    echo "  • Restart services: docker-compose -f docker-compose.prod.yml restart"
    echo "  • Check status:     docker-compose -f docker-compose.prod.yml ps"
    echo ""
    echo "Database Scripts:"
    echo "  • Create admin:     bash create-super-admin.sh"
    echo "  • Check services:   bash check-services.sh"
    echo ""
    print_warning "Remember to:"
    echo "  1. Set secure passwords in .env.production"
    echo "  2. Create a super admin user: bash create-super-admin.sh"
    echo "  3. Review service logs for any errors"
    echo ""
}

# Main execution
main() {
    print_header "Score Platform - Project Initialization"
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    check_prerequisites
    setup_environment_files
    
    print_info "Do you want to install frontend dependencies? (This may take a while)"
    read -p "Install frontend dependencies? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_frontend_dependencies
    else
        print_info "Skipped frontend dependencies installation"
        print_info "You can install them later by running 'npm install' in each frontend directory"
    fi
    
    setup_python_environments
    
    print_info "Do you want to build and start Docker containers now?"
    read -p "Build and start containers? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        build_docker_containers
        start_services
        run_migrations
        display_access_info
    else
        print_info "Skipped Docker container setup"
        print_info "You can build and start containers later with:"
        echo "  docker-compose -f docker-compose.prod.yml --env-file .env.production up -d --build"
    fi
    
    print_success "Project initialization complete!"
}

# Run main function
main

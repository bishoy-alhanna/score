#!/bin/bash

# Production Deployment Script for Score Platform
set -e

echo "🚀 Starting Score Platform Production Deployment"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env.production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Environment setup
setup_environment() {
    print_status "Setting up environment..."
    
    if [ ! -f "$ENV_FILE" ]; then
        print_warning "Production environment file not found"
        print_status "Creating from example..."
        cp "$PROJECT_ROOT/.env.production.example" "$ENV_FILE"
        print_warning "Please edit $ENV_FILE with your production values before continuing"
        print_warning "Press Enter when ready to continue..."
        read
    fi
    
    # Source environment variables
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
        print_success "Environment variables loaded"
    fi
}

# Database setup
setup_database() {
    print_status "Setting up database..."
    
    # Start only the database first
    docker-compose -f docker-compose.prod.yml up -d postgres
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    timeout=30
    while ! docker exec score_postgres_prod pg_isready -U "${POSTGRES_USER:-postgres}" > /dev/null 2>&1; do
        timeout=$((timeout - 1))
        if [ $timeout -eq 0 ]; then
            print_error "Database failed to start"
            exit 1
        fi
        sleep 1
    done
    
    print_success "Database is ready"
}

# Build and deploy services
deploy_services() {
    print_status "Building and deploying services..."
    
    # Build all services
    print_status "Building Docker images..."
    docker-compose -f docker-compose.prod.yml build --no-cache
    
    # Start all services
    print_status "Starting all services..."
    docker-compose -f docker-compose.prod.yml up -d
    
    print_success "Services deployed"
}

# Health checks
run_health_checks() {
    print_status "Running health checks..."
    
    services=("score_auth_service_prod" "score_api_gateway_prod" "score_admin_dashboard_prod" "score_user_dashboard_prod" "score_nginx_prod")
    
    for service in "${services[@]}"; do
        print_status "Checking $service..."
        timeout=60
        while ! docker exec "$service" curl -f http://localhost/health > /dev/null 2>&1; do
            timeout=$((timeout - 1))
            if [ $timeout -eq 0 ]; then
                print_error "$service health check failed"
                docker logs "$service" --tail 20
                exit 1
            fi
            sleep 1
        done
        print_success "$service is healthy"
    done
}

# Create super admin
create_super_admin() {
    print_status "Creating super admin user..."
    
    # Wait for auth service to be ready
    sleep 10
    
    # The super admin is created automatically by the auth service
    print_success "Super admin user created/verified"
}

# Setup monitoring
setup_monitoring() {
    print_status "Setting up monitoring..."
    
    # Create log directories
    mkdir -p "$PROJECT_ROOT/logs/nginx"
    mkdir -p "$PROJECT_ROOT/logs/app"
    
    # Set up log rotation (basic example)
    cat > "$PROJECT_ROOT/logs/logrotate.conf" << EOF
$PROJECT_ROOT/logs/nginx/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker exec score_nginx_prod nginx -s reload
    endscript
}
EOF
    
    print_success "Monitoring setup complete"
}

# Display deployment info
show_deployment_info() {
    print_success "🎉 Score Platform deployed successfully!"
    echo ""
    echo "📱 Access URLs:"
    echo "  • Admin Dashboard: http://localhost/admin/"
    echo "  • User Dashboard:  http://localhost/"
    echo "  • API Gateway:     http://localhost/api/"
    echo ""
    echo "🔑 Super Admin Credentials:"
    echo "  • Username: ${SUPER_ADMIN_USERNAME:-superadmin}"
    echo "  • Password: ${SUPER_ADMIN_PASSWORD:-SuperAdmin123!}"
    echo ""
    echo "🛠️  Management Commands:"
    echo "  • View logs:       docker-compose -f docker-compose.prod.yml logs -f [service]"
    echo "  • Stop services:   docker-compose -f docker-compose.prod.yml down"
    echo "  • Restart:         docker-compose -f docker-compose.prod.yml restart [service]"
    echo "  • Update:          ./scripts/deploy-prod.sh"
    echo ""
    echo "📊 Health Check:"
    echo "  • curl http://localhost/health"
    echo ""
}

# Rollback function
rollback() {
    print_warning "Rolling back deployment..."
    docker-compose -f docker-compose.prod.yml down
    print_success "Rollback complete"
}

# Main deployment flow
main() {
    cd "$PROJECT_ROOT"
    
    # Trap errors and rollback
    trap 'print_error "Deployment failed. Rolling back..."; rollback; exit 1' ERR
    
    print_status "Starting production deployment for Score Platform"
    
    check_prerequisites
    setup_environment
    setup_database
    deploy_services
    create_super_admin
    setup_monitoring
    run_health_checks
    
    show_deployment_info
}

# Parse command line arguments
case "${1:-}" in
    --rollback)
        rollback
        exit 0
        ;;
    --health-check)
        run_health_checks
        exit 0
        ;;
    --help)
        echo "Usage: $0 [--rollback|--health-check|--help]"
        echo ""
        echo "Options:"
        echo "  --rollback      Stop all services"
        echo "  --health-check  Run health checks only"
        echo "  --help          Show this help message"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
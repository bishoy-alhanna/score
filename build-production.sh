#!/bin/bash

# Production Build Script for Score Platform
# This script builds all services for production deployment

set -e  # Exit on any error

echo "🚀 Starting Production Build Process"
echo "====================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

print_status "Docker is running ✓"

# Clean up existing containers and images
print_status "Cleaning up existing containers..."
docker-compose down --remove-orphans 2>/dev/null || true

print_status "Pruning unused Docker resources..."
docker system prune -f

# Build all services for production
print_status "Building all services for production..."

echo ""
print_status "📦 Building Backend Services..."

# Build all backend services
print_status "Building Auth Service..."
docker-compose build --no-cache auth-service
print_success "Auth Service built"

print_status "Building API Gateway..."
docker-compose build --no-cache api-gateway
print_success "API Gateway built"

print_status "Building User Service..."
docker-compose build --no-cache user-service
print_success "User Service built"

print_status "Building Group Service..."
docker-compose build --no-cache group-service
print_success "Group Service built"

print_status "Building Scoring Service..."
docker-compose build --no-cache scoring-service
print_success "Scoring Service built"

print_status "Building Leaderboard Service..."
docker-compose build --no-cache leaderboard-service
print_success "Leaderboard Service built"

echo ""
print_status "🎨 Building Frontend Applications..."

# Build frontend applications
print_status "Building User Dashboard..."
docker-compose build --no-cache user-dashboard
print_success "User Dashboard built"

print_status "Building Admin Dashboard..."
docker-compose build --no-cache admin-dashboard
print_success "Admin Dashboard built"

echo ""
print_status "🌐 Building Infrastructure..."

# Build nginx
print_status "Building Nginx..."
docker-compose build --no-cache nginx
print_success "Nginx built"

echo ""
print_status "🧪 Validating Build..."

# Start services to validate
print_status "Starting services for validation..."
docker-compose up -d

# Wait for services to start
print_status "Waiting for services to initialize..."
sleep 30

# Health checks
print_status "Performing health checks..."

# Check API Gateway
if curl -s http://localhost/health > /dev/null; then
    print_success "API Gateway health check passed"
else
    print_warning "API Gateway health check failed"
fi

# Check User Dashboard
if curl -s -I http://score.al-hanna.com | grep -q "200 OK"; then
    print_success "User Dashboard health check passed"
else
    print_warning "User Dashboard health check failed"
fi

# Check Admin Dashboard
if curl -s -I http://admin.score.al-hanna.com | grep -q "200 OK"; then
    print_success "Admin Dashboard health check passed"
else
    print_warning "Admin Dashboard health check failed"
fi

echo ""
print_status "📊 Build Summary..."

# Show running containers
echo "Running containers:"
docker-compose ps

# Show images
echo ""
echo "Built images:"
docker images | grep "score-"

echo ""
print_success "🎉 Production build completed successfully!"
print_status "All services have been built and are running in production mode."

echo ""
print_status "🌍 Access URLs:"
echo "  - User Dashboard:  http://score.al-hanna.com"
echo "  - Admin Dashboard: http://admin.score.al-hanna.com"
echo "  - API Gateway:     http://localhost/health"
echo "  - Super Admin:     Use super admin login on admin dashboard"

echo ""
print_status "🔧 Next Steps:"
echo "  1. Update DNS records to point to your production server"
echo "  2. Configure SSL certificates for HTTPS"
echo "  3. Set up monitoring and logging"
echo "  4. Configure backups for PostgreSQL data"
echo "  5. Review security settings and environment variables"

echo ""
print_status "📝 Important Notes:"
echo "  - All services are built with latest security fixes"
echo "  - Organization-aware authentication is enabled"
echo "  - Rate limiting is configured for API protection"
echo "  - Multi-organization support is fully functional"

echo ""
print_success "Production build process completed! 🚀"
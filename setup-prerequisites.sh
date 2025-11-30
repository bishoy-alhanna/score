#!/bin/bash

# Score Platform - Prerequisites Setup Script
# This script checks for and installs required development tools on macOS
# Run with: bash setup-prerequisites.sh

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
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

# Check if running on macOS
check_os() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS only."
        print_info "For other operating systems, please install prerequisites manually."
        exit 1
    fi
    print_success "Running on macOS"
}

# Check and install Homebrew
install_homebrew() {
    print_header "Checking Homebrew"
    
    if command -v brew &> /dev/null; then
        print_success "Homebrew is already installed ($(brew --version | head -n1))"
        print_info "Updating Homebrew..."
        brew update
    else
        print_warning "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        print_success "Homebrew installed successfully"
    fi
}

# Check and install Docker Desktop
install_docker() {
    print_header "Checking Docker"
    
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed ($(docker --version))"
        
        # Check if Docker daemon is running
        if docker ps &> /dev/null; then
            print_success "Docker daemon is running"
        else
            print_warning "Docker is installed but not running"
            print_info "Please start Docker Desktop manually"
        fi
    else
        print_warning "Docker not found. Installing Docker Desktop..."
        brew install --cask docker
        print_success "Docker Desktop installed"
        print_info "Please start Docker Desktop from Applications folder"
        print_info "Wait for Docker to start before running docker-compose commands"
    fi
    
    # Check docker-compose
    if command -v docker-compose &> /dev/null; then
        print_success "docker-compose is available ($(docker-compose --version))"
    else
        print_warning "docker-compose not found (usually included with Docker Desktop)"
    fi
}

# Check and install Python
install_python() {
    print_header "Checking Python"
    
    REQUIRED_PYTHON_VERSION="3.11"
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        print_success "Python is already installed (Python $PYTHON_VERSION)"
        
        # Check if version meets requirement
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        
        if [[ $PYTHON_MAJOR -eq 3 ]] && [[ $PYTHON_MINOR -ge 11 ]]; then
            print_success "Python version meets requirement (>= 3.11)"
        else
            print_warning "Python version is older than recommended (3.11)"
            print_info "Consider installing Python 3.11: brew install python@3.11"
        fi
    else
        print_warning "Python 3 not found. Installing Python 3.11..."
        brew install python@3.11
        print_success "Python 3.11 installed"
    fi
    
    # Check pip
    if command -v pip3 &> /dev/null; then
        print_success "pip3 is available ($(pip3 --version | cut -d' ' -f1-2))"
    else
        print_error "pip3 not found. Please reinstall Python"
    fi
}

# Check and install Node.js and npm
install_node() {
    print_header "Checking Node.js and npm"
    
    REQUIRED_NODE_VERSION="18"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js is already installed ($NODE_VERSION)"
        
        # Check if version meets requirement
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'v' -f2 | cut -d'.' -f1)
        
        if [[ $NODE_MAJOR -ge $REQUIRED_NODE_VERSION ]]; then
            print_success "Node.js version meets requirement (>= v18)"
        else
            print_warning "Node.js version is older than recommended (v18)"
            print_info "Consider upgrading: brew upgrade node"
        fi
    else
        print_warning "Node.js not found. Installing..."
        brew install node
        print_success "Node.js installed"
    fi
    
    # Check npm
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        print_success "npm is available (v$NPM_VERSION)"
    else
        print_error "npm not found. Please reinstall Node.js"
    fi
}

# Check and install Git
install_git() {
    print_header "Checking Git"
    
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version)
        print_success "Git is already installed ($GIT_VERSION)"
    else
        print_warning "Git not found. Installing..."
        brew install git
        print_success "Git installed"
    fi
}

# Check and install PostgreSQL client (optional)
install_postgres_client() {
    print_header "Checking PostgreSQL Client (Optional)"
    
    if command -v psql &> /dev/null; then
        PSQL_VERSION=$(psql --version)
        print_success "PostgreSQL client is already installed ($PSQL_VERSION)"
    else
        print_info "PostgreSQL client not found (optional, for database access)"
        read -p "Would you like to install PostgreSQL client? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install postgresql@15
            print_success "PostgreSQL client installed"
        else
            print_info "Skipped PostgreSQL client installation"
        fi
    fi
}

# Install Python packages
install_python_packages() {
    print_header "Python Development Tools"
    
    print_info "Installing/upgrading Python development tools..."
    
    pip3 install --upgrade pip
    pip3 install --upgrade virtualenv
    
    print_success "Python development tools installed"
}

# Print summary
print_summary() {
    print_header "Installation Summary"
    
    echo "Installed versions:"
    echo ""
    
    if command -v brew &> /dev/null; then
        echo "  • Homebrew: $(brew --version | head -n1)"
    fi
    
    if command -v docker &> /dev/null; then
        echo "  • Docker: $(docker --version)"
    fi
    
    if command -v docker-compose &> /dev/null; then
        echo "  • docker-compose: $(docker-compose --version)"
    fi
    
    if command -v python3 &> /dev/null; then
        echo "  • Python: $(python3 --version)"
    fi
    
    if command -v pip3 &> /dev/null; then
        echo "  • pip: $(pip3 --version | cut -d' ' -f1-2)"
    fi
    
    if command -v node &> /dev/null; then
        echo "  • Node.js: $(node --version)"
    fi
    
    if command -v npm &> /dev/null; then
        echo "  • npm: v$(npm --version)"
    fi
    
    if command -v git &> /dev/null; then
        echo "  • Git: $(git --version)"
    fi
    
    if command -v psql &> /dev/null; then
        echo "  • PostgreSQL: $(psql --version)"
    fi
    
    echo ""
    print_success "Prerequisites setup complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Make sure Docker Desktop is running"
    echo "  2. Copy .env.example to .env and configure environment variables"
    echo "  3. Run: docker-compose -f docker-compose.prod.yml --env-file .env.production up -d --build"
    echo ""
}

# Main execution
main() {
    print_header "Score Platform - Prerequisites Setup"
    print_info "This script will check and install required development tools"
    echo ""
    
    check_os
    install_homebrew
    install_docker
    install_python
    install_node
    install_git
    install_postgres_client
    install_python_packages
    print_summary
}

# Run main function
main

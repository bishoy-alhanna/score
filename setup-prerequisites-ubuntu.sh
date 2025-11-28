#!/bin/bash

# Score Platform - Prerequisites Setup Script for Ubuntu
# This script checks for and installs required development tools on Ubuntu
# Run with: sudo bash setup-prerequisites-ubuntu.sh

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

# Check if running with sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run with sudo privileges"
        print_info "Usage: sudo bash setup-prerequisites-ubuntu.sh"
        exit 1
    fi
    print_success "Running with sudo privileges"
}

# Check if running on Ubuntu/Debian
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect OS. This script is designed for Ubuntu/Debian."
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "debian" ]]; then
        print_warning "This script is optimized for Ubuntu/Debian."
        print_info "Detected: $NAME $VERSION"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Running on $NAME $VERSION"
    fi
}

# Update system packages
update_system() {
    print_header "Updating System Packages"
    
    print_info "Updating package lists..."
    apt-get update
    
    print_info "Upgrading installed packages..."
    apt-get upgrade -y
    
    print_success "System packages updated"
}

# Install essential build tools
install_essentials() {
    print_header "Installing Essential Build Tools"
    
    print_info "Installing essential packages..."
    apt-get install -y \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https \
        build-essential \
        vim \
        nano \
        unzip
    
    print_success "Essential build tools installed"
}

# Install Docker
install_docker() {
    print_header "Installing Docker"
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_success "Docker is already installed ($DOCKER_VERSION)"
        
        # Check if Docker daemon is running
        if systemctl is-active --quiet docker; then
            print_success "Docker daemon is running"
        else
            print_warning "Docker is installed but not running"
            print_info "Starting Docker service..."
            systemctl start docker
            systemctl enable docker
            print_success "Docker service started and enabled"
        fi
    else
        print_info "Installing Docker..."
        
        # Remove old versions
        apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Set up the repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        
        print_success "Docker installed successfully"
        print_info "Docker version: $(docker --version)"
    fi
    
    # Check Docker Compose (V2)
    if docker compose version &> /dev/null; then
        print_success "Docker Compose V2 is available ($(docker compose version))"
    else
        print_warning "Docker Compose V2 not found, installing..."
        apt-get install -y docker-compose-plugin
    fi
    
    # Add current user to docker group (if not root)
    if [[ -n "$SUDO_USER" ]]; then
        print_info "Adding user '$SUDO_USER' to docker group..."
        usermod -aG docker "$SUDO_USER"
        print_success "User added to docker group"
        print_warning "Log out and back in for group changes to take effect"
    fi
}

# Install Python
install_python() {
    print_header "Installing Python"
    
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
            print_info "Installing Python 3.11..."
            add-apt-repository -y ppa:deadsnakes/ppa
            apt-get update
            apt-get install -y python3.11 python3.11-venv python3.11-dev
        fi
    else
        print_info "Installing Python 3.11..."
        add-apt-repository -y ppa:deadsnakes/ppa
        apt-get update
        apt-get install -y python3.11 python3.11-venv python3.11-dev
        
        # Set Python 3.11 as default python3
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
        print_success "Python 3.11 installed"
    fi
    
    # Install pip
    if command -v pip3 &> /dev/null; then
        print_success "pip3 is available ($(pip3 --version | cut -d' ' -f1-2))"
    else
        print_info "Installing pip..."
        apt-get install -y python3-pip
        print_success "pip installed"
    fi
    
    # Install virtualenv
    print_info "Installing virtualenv..."
    pip3 install --upgrade virtualenv
    print_success "virtualenv installed"
}

# Install Node.js and npm
install_node() {
    print_header "Installing Node.js and npm"
    
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
            print_info "Upgrading Node.js..."
            install_node_from_source
        fi
    else
        print_info "Installing Node.js..."
        install_node_from_source
    fi
    
    # Check npm
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        print_success "npm is available (v$NPM_VERSION)"
    else
        print_error "npm not found. Please reinstall Node.js"
    fi
}

install_node_from_source() {
    # Install Node.js 18.x from NodeSource
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    print_success "Node.js installed"
}

# Install PostgreSQL client
install_postgres_client() {
    print_header "Installing PostgreSQL Client"
    
    if command -v psql &> /dev/null; then
        PSQL_VERSION=$(psql --version)
        print_success "PostgreSQL client is already installed ($PSQL_VERSION)"
    else
        print_info "Installing PostgreSQL client..."
        
        # Add PostgreSQL repository
        sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
        apt-get update
        
        # Install PostgreSQL 15 client
        apt-get install -y postgresql-client-15
        print_success "PostgreSQL client installed"
    fi
}

# Install additional useful tools
install_additional_tools() {
    print_header "Installing Additional Tools"
    
    print_info "Installing system monitoring and utility tools..."
    apt-get install -y \
        htop \
        ncdu \
        tree \
        jq \
        net-tools \
        dnsutils \
        ufw
    
    print_success "Additional tools installed"
}

# Configure firewall (optional)
configure_firewall() {
    print_header "Configuring Firewall (Optional)"
    
    if command -v ufw &> /dev/null; then
        print_info "UFW firewall is available"
        
        read -p "Would you like to configure firewall rules? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Configuring firewall..."
            
            # Allow SSH
            ufw allow 22/tcp
            print_info "Allowed SSH (port 22)"
            
            # Allow HTTP/HTTPS
            ufw allow 80/tcp
            ufw allow 443/tcp
            print_info "Allowed HTTP (port 80) and HTTPS (port 443)"
            
            # Allow application ports
            ufw allow 3000/tcp  # User Dashboard
            ufw allow 3001/tcp  # Admin Dashboard
            ufw allow 5000/tcp  # API Gateway
            print_info "Allowed application ports (3000, 3001, 5000)"
            
            # Enable firewall
            print_warning "Enabling firewall. Make sure you have SSH access configured!"
            ufw --force enable
            
            print_success "Firewall configured and enabled"
            ufw status
        else
            print_info "Skipped firewall configuration"
        fi
    fi
}

# Setup docker-compose alias for V2
setup_docker_compose_alias() {
    print_header "Setting up Docker Compose Alias"
    
    # Create alias for docker-compose to docker compose
    if [[ -n "$SUDO_USER" ]]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        SHELL_RC="$USER_HOME/.bashrc"
        
        if ! grep -q "alias docker-compose='docker compose'" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Docker Compose V2 alias" >> "$SHELL_RC"
            echo "alias docker-compose='docker compose'" >> "$SHELL_RC"
            print_success "Added docker-compose alias to $SHELL_RC"
            print_info "Run 'source ~/.bashrc' or log out and back in to use the alias"
        else
            print_success "Docker compose alias already exists"
        fi
    fi
}

# Print summary
print_summary() {
    print_header "Installation Summary"
    
    echo "Installed versions:"
    echo ""
    
    if command -v docker &> /dev/null; then
        echo "  • Docker: $(docker --version)"
    fi
    
    if docker compose version &> /dev/null 2>&1; then
        echo "  • Docker Compose: $(docker compose version)"
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
        echo "  • PostgreSQL Client: $(psql --version)"
    fi
    
    echo ""
    print_success "Prerequisites setup complete!"
    echo ""
    print_warning "Important Next Steps:"
    echo "  1. Log out and back in (for docker group changes to take effect)"
    echo "  2. Verify Docker works without sudo: docker ps"
    echo "  3. Clone your project repository"
    echo "  4. Configure environment variables (.env.production)"
    echo "  5. Run: docker compose -f docker-compose.prod.yml up -d --build"
    echo ""
    print_info "Security Recommendations:"
    echo "  • Configure firewall rules (ufw)"
    echo "  • Set up SSH key authentication"
    echo "  • Disable root SSH login"
    echo "  • Keep system updated: sudo apt update && sudo apt upgrade"
    echo ""
}

# Main execution
main() {
    print_header "Score Platform - Prerequisites Setup (Ubuntu)"
    print_info "This script will check and install required development tools"
    echo ""
    
    check_sudo
    check_os
    update_system
    install_essentials
    install_docker
    install_python
    install_node
    install_postgres_client
    install_additional_tools
    setup_docker_compose_alias
    configure_firewall
    print_summary
}

# Run main function
main

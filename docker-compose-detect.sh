#!/bin/bash

# Docker Compose Version Detection Helper
# Source this file in other scripts to get the correct docker-compose command
# Usage: source docker-compose-detect.sh

# Detect docker-compose command (V1 vs V2)
if command -v docker-compose &> /dev/null; then
    export DOCKER_COMPOSE="docker-compose"
    export DOCKER_COMPOSE_VERSION="v1"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    export DOCKER_COMPOSE="docker compose"
    export DOCKER_COMPOSE_VERSION="v2"
else
    echo "❌ Error: Neither 'docker-compose' nor 'docker compose' command found"
    echo ""
    echo "Please install Docker Compose:"
    echo "  - Docker Desktop (includes Compose V2): https://www.docker.com/products/docker-desktop"
    echo "  - Compose V1: pip install docker-compose"
    echo "  - Compose V2: https://docs.docker.com/compose/install/"
    return 1 2>/dev/null || exit 1
fi

# Export the compose file path if not already set
export COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
export ENV_FILE="${ENV_FILE:-.env.production}"

# Helper function to run docker-compose with common flags
dc() {
    if [ -f "$ENV_FILE" ]; then
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
    else
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" "$@"
    fi
}

# Export the function so it can be used in scripts
export -f dc 2>/dev/null || true

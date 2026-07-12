#!/bin/bash
# Wrapper script for docker-compose with production environment file

cd "$(dirname "$0")"

if [ ! -f .env.production ]; then
    echo "Error: .env.production file not found!"
    exit 1
fi

# Run docker-compose with the production env file
docker-compose -f docker-compose.prod.yml --env-file .env.production "$@"

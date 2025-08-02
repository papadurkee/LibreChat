#!/bin/bash

# LibreChat Deployment Script
# This script handles deployment updates for the LibreChat server

set -e  # Exit on any error

echo "🚀 Starting LibreChat deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if we're in the right directory
if [ ! -f "deploy-compose.yml" ]; then
    print_error "deploy-compose.yml not found. Please run this script from the LibreChat directory."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_warning ".env file not found. Please ensure your environment variables are configured."
fi

# Check if SSL certificates exist
if [ ! -f "certs/fullchain.pem" ] || [ ! -f "certs/privkey.pem" ]; then
    print_warning "SSL certificates not found in certs/ directory. HTTPS may not work properly."
fi

# Backup current state
print_status "Creating backup of current configuration..."
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup important files
if [ -f ".env" ]; then
    cp .env "$BACKUP_DIR/"
fi
if [ -d "certs" ]; then
    cp -r certs "$BACKUP_DIR/"
fi
if [ -f "librechat.yaml" ]; then
    cp librechat.yaml "$BACKUP_DIR/"
fi

print_success "Backup created in $BACKUP_DIR"

# Pull latest changes
print_status "Pulling latest changes from repository..."
git pull origin production

# Stop current services
print_status "Stopping current services..."
docker-compose -f deploy-compose.yml down

# Pull latest images
print_status "Pulling latest Docker images..."
docker-compose -f deploy-compose.yml pull

# Start services
print_status "Starting services..."
docker-compose -f deploy-compose.yml up -d

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 10

# Check service status
print_status "Checking service status..."
docker-compose -f deploy-compose.yml ps

# Health check
print_status "Performing health check..."
if curl -f http://localhost:3080 > /dev/null 2>&1; then
    print_success "LibreChat is running successfully!"
    print_status "You can access it at: http://localhost:3080"
else
    print_warning "Health check failed. Checking logs..."
    docker-compose -f deploy-compose.yml logs --tail=20
fi

# Show recent logs
print_status "Recent logs:"
docker-compose -f deploy-compose.yml logs --tail=10

print_success "Deployment completed!"
print_status "To view logs: docker-compose -f deploy-compose.yml logs -f"
print_status "To stop services: docker-compose -f deploy-compose.yml down"

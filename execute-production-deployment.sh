#!/bin/bash
# Production Deployment - Execute on Server
# This script should be run AFTER copying files to the server

echo "=========================================="
echo "🚀 SCORE Platform - Production Deployment"
echo "=========================================="
echo ""

# Step 1: Copy files to server
echo "Step 1: Copying deployment files to server..."
echo "Enter server password when prompted"
echo ""

scp apply-production-migrations.sql production-deploy-server.sh \
  root@escore.al-hanna.com:/root/score/

if [ $? -ne 0 ]; then
    echo "❌ Failed to copy files to server"
    echo ""
    echo "Try manually:"
    echo "  scp apply-production-migrations.sql production-deploy-server.sh root@escore.al-hanna.com:/root/score/"
    exit 1
fi

echo ""
echo "✅ Files copied successfully!"
echo ""

# Step 2: SSH and deploy
echo "Step 2: Connecting to server and deploying..."
echo ""

ssh root@escore.al-hanna.com << 'ENDSSH'
cd /root/score
echo "📁 Current directory: $(pwd)"
echo ""
echo "🔧 Making deployment script executable..."
chmod +x production-deploy-server.sh
echo ""
echo "🚀 Starting deployment..."
./production-deploy-server.sh
ENDSSH

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "Next: Verify deployment by visiting:"
echo "  - User Dashboard: https://escore.al-hanna.com"
echo "  - Admin Dashboard: https://admin.escore.al-hanna.com"
echo ""

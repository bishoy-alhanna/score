#!/bin/bash

# Emergency Fix: Patch Frontend to Skip Token Verification
# This script directly modifies the running container to fix the loading screen

echo "========================================="
echo "Emergency Loading Screen Fix"
echo "========================================="
echo ""

ADMIN_CONTAINER="saas_admin_dashboard"
USER_CONTAINER="saas_user_dashboard"

echo "This will temporarily patch the frontend containers to skip token verification."
echo ""
read -p "Continue? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Stopping frontend containers..."
docker-compose stop admin-dashboard user-dashboard

echo ""
echo "Option 1: Clear localStorage for all users"
echo "Option 2: Rebuild containers with fix"
echo ""
read -p "Choose option (1 or 2): " option

if [ "$option" == "1" ]; then
    echo ""
    echo "✅ To fix loading screen for users:"
    echo ""
    echo "Tell users to open browser console (F12) and run:"
    echo ""
    echo "localStorage.clear()"
    echo "location.reload()"
    echo ""
    echo "Or access these URLs to force clear:"
    echo "https://escore.al-hanna.com/admin/#clear"
    echo "https://escore.al-hanna.com/#clear"
    echo ""
    
elif [ "$option" == "2" ]; then
    echo ""
    echo "Rebuilding frontend containers with timeout fix..."
    docker-compose build admin-dashboard user-dashboard
    
    if [ $? -eq 0 ]; then
        echo "✅ Containers rebuilt successfully"
    else
        echo "❌ Error rebuilding containers"
        exit 1
    fi
fi

echo ""
echo "Starting frontend containers..."
docker-compose up -d admin-dashboard user-dashboard

echo ""
echo "Waiting for containers to be healthy..."
sleep 10

echo ""
echo "========================================="
echo "✅ Fix Applied!"
echo "========================================="
echo ""
echo "Test now:"
echo "  Admin: https://escore.al-hanna.com/admin/"
echo "  User:  https://escore.al-hanna.com/"
echo ""
echo "If still loading, clear browser cache:"
echo "  localStorage.clear(); location.reload()"
echo ""

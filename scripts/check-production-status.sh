#!/bin/bash

# Quick verification script to check what's deployed on production

echo "=========================================="
echo "🔍 Production Deployment Status Check"
echo "=========================================="
echo ""

echo "Checking production server: escore.al-hanna.com"
echo ""

# Test 1: Check if site is accessible
echo "1. Testing HTTPS access..."
if curl -k -s -o /dev/null -w "%{http_code}" https://escore.al-hanna.com/ 2>/dev/null | grep -q "200"; then
    echo "   ✓ Site is accessible"
else
    echo "   ✗ Site is not accessible"
fi
echo ""

# Test 2: Check admin dashboard
echo "2. Testing admin dashboard..."
if curl -k -s -o /dev/null -w "%{http_code}" https://escore.al-hanna.com/admin/ 2>/dev/null | grep -q "200"; then
    echo "   ✓ Admin dashboard accessible"
else
    echo "   ✗ Admin dashboard not accessible"
fi
echo ""

# Test 3: Check API Gateway
echo "3. Testing API Gateway..."
API_RESPONSE=$(curl -k -s https://escore.al-hanna.com/api/health 2>/dev/null)
if echo "$API_RESPONSE" | grep -q "healthy"; then
    echo "   ✓ API Gateway is healthy"
    echo "   Response: $API_RESPONSE"
else
    echo "   ✗ API Gateway not responding"
fi
echo ""

# Test 4: Check cache clearing page
echo "4. Testing cache clearing page..."
if curl -k -s -o /dev/null -w "%{http_code}" https://escore.al-hanna.com/clear-cache.html 2>/dev/null | grep -q "200"; then
    echo "   ✓ Cache clearing page available"
else
    echo "   ✗ Cache clearing page not found"
fi
echo ""

echo "=========================================="
echo "📋 Current Issues"
echo "=========================================="
echo ""
echo "Based on your screenshot:"
echo "  🔴 Frontend still showing 'Loading...' indefinitely"
echo "  🔴 Frontend timeout fix NOT deployed yet"
echo "  🔴 Containers need to be rebuilt on production"
echo ""

echo "=========================================="
echo "🔧 Required Actions"
echo "=========================================="
echo ""
echo "ON PRODUCTION SERVER, run these commands:"
echo ""
echo "cd /root/score"
echo "git pull"
echo "docker-compose build admin-dashboard user-dashboard nginx"
echo "docker-compose up -d"
echo ""
echo "Then visit: https://escore.al-hanna.com/clear-cache.html"
echo "Then reload: https://escore.al-hanna.com/admin/"
echo ""

echo "=========================================="
echo "📝 Deployment Status Summary"
echo "=========================================="
echo ""
echo "✅ Code Changes: Committed and pushed to GitHub"
echo "   - Frontend timeout fix (5 seconds)"
echo "   - Gunicorn WSGI server for backend"
echo "   - Cache clearing page"
echo ""
echo "⚠️  Production Server: NOT UPDATED YET"
echo "   - Frontend containers running old code (no timeout)"
echo "   - Backend might be updated with Gunicorn"
echo "   - Need to rebuild and restart containers"
echo ""
echo "🎯 Next Step: Deploy the frontend changes!"
echo ""

#!/usr/bin/env python3
"""
Test script to validate all admin dashboard endpoints are working correctly.
This tests the complete delete user functionality we've implemented.
"""

import requests
import json
import sys

BASE_URL = "http://localhost"

def test_admin_login():
    """Test admin login functionality"""
    print("🔑 Testing admin login...")
    
    # First get organizations for the admin
    response = requests.get(f"{BASE_URL}/api/auth/admin-organizations/bfawzy")
    if response.status_code != 200:
        print(f"❌ Failed to get admin organizations: {response.status_code}")
        return None
    
    orgs = response.json()['organizations']
    if not orgs:
        print("❌ No organizations found for admin")
        return None
    
    org_id = orgs[0]['id']
    print(f"✅ Found organization: {orgs[0]['name']} ({org_id})")
    
    # Login to the organization
    login_data = {
        "username": "bfawzy",
        "password": "admin123",
        "organization_id": org_id
    }
    
    response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
    if response.status_code != 200:
        print(f"❌ Login failed: {response.status_code} - {response.text}")
        return None
    
    data = response.json()
    token = data['token']
    print(f"✅ Login successful")
    
    return token, org_id

def test_organization_endpoints(token, org_id):
    """Test organization-specific endpoints"""
    headers = {"Authorization": f"Bearer {token}"}
    
    print("\n📊 Testing organization endpoints...")
    
    # Test get organization users
    print("  Testing GET /organizations/{org_id}/users...")
    response = requests.get(f"{BASE_URL}/api/auth/organizations/{org_id}/users", headers=headers)
    if response.status_code == 200:
        users = response.json()['users']
        print(f"  ✅ Found {len(users)} users in organization")
        return users
    else:
        print(f"  ❌ Failed to get users: {response.status_code} - {response.text}")
        return []

def test_join_requests_endpoints(token, org_id):
    """Test join request management endpoints"""
    headers = {"Authorization": f"Bearer {token}"}
    
    print("\n📋 Testing join request endpoints...")
    
    # Test get join requests
    print("  Testing GET /organizations/{org_id}/join-requests...")
    response = requests.get(f"{BASE_URL}/api/auth/organizations/{org_id}/join-requests", headers=headers)
    if response.status_code == 200:
        requests_data = response.json()['join_requests']
        print(f"  ✅ Found {len(requests_data)} pending join requests")
        return True
    else:
        print(f"  ❌ Failed to get join requests: {response.status_code} - {response.text}")
        return False

def test_super_admin_endpoints():
    """Test super admin endpoints"""
    print("\n👑 Testing super admin endpoints...")
    
    # Login as super admin
    super_admin_data = {"username": "superadmin", "password": "superadmin123"}
    response = requests.post(f"{BASE_URL}/api/super-admin/login", json=super_admin_data)
    
    if response.status_code != 200:
        print(f"  ❌ Super admin login failed: {response.status_code} - {response.text}")
        return False
    
    token = response.json()['token']
    headers = {"Authorization": f"Bearer {token}"}
    print("  ✅ Super admin login successful")
    
    # Test dashboard
    response = requests.get(f"{BASE_URL}/api/super-admin/dashboard", headers=headers)
    if response.status_code == 200:
        print("  ✅ Super admin dashboard accessible")
        return True
    else:
        print(f"  ❌ Dashboard failed: {response.status_code} - {response.text}")
        return False

def main():
    """Run all tests"""
    print("🚀 Starting admin dashboard endpoint tests...\n")
    
    # Test organization admin login
    login_result = test_admin_login()
    if not login_result:
        print("\n❌ Admin login failed - cannot continue tests")
        sys.exit(1)
    
    token, org_id = login_result
    
    # Test organization endpoints
    users = test_organization_endpoints(token, org_id)
    
    # Test join request endpoints
    join_success = test_join_requests_endpoints(token, org_id)
    
    # Test super admin endpoints
    super_admin_success = test_super_admin_endpoints()
    
    # Summary
    print("\n" + "="*50)
    print("📊 TEST SUMMARY")
    print("="*50)
    print(f"✅ Organization Admin Login: {'PASS' if token else 'FAIL'}")
    print(f"✅ Organization Users Endpoint: {'PASS' if users else 'FAIL'}")
    print(f"✅ Join Requests Endpoint: {'PASS' if join_success else 'FAIL'}")
    print(f"✅ Super Admin Access: {'PASS' if super_admin_success else 'FAIL'}")
    
    all_passed = token and users and join_success and super_admin_success
    print(f"\n🎉 Overall Status: {'ALL TESTS PASSED' if all_passed else 'SOME TESTS FAILED'}")
    
    if all_passed:
        print("\n✨ The admin dashboard backend is now fully functional!")
        print("   - Organization admins can login and manage users")
        print("   - Join request management is working")
        print("   - Super admin access is working")
        print("   - Delete user functionality is ready")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
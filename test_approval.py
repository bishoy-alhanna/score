#!/usr/bin/env python3
"""
Test script to verify the join request approval functionality
"""

import requests
import json

# Configuration
BASE_URL = "http://localhost/api"
ADMIN_URL = "http://admin.score.al-hanna.com/api"

def test_super_admin_login():
    """Test super admin login"""
    print("🔑 Testing Super Admin Login...")
    
    try:
        response = requests.post(f"{ADMIN_URL}/super-admin/login", 
                               json={
                                   "username": "superadmin",
                                   "password": "SuperAdmin123!"
                               })
        
        if response.status_code == 200:
            data = response.json()
            token = data.get('token')
            print(f"   ✅ Login successful")
            return token
        else:
            print(f"   ❌ Login failed: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        print(f"   ❌ Login error: {e}")
        return None

def test_get_join_requests(token):
    """Test getting join requests"""
    print("\n📋 Testing Get Join Requests...")
    
    if not token:
        print("   ❌ No token available")
        return None
    
    try:
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(f"{ADMIN_URL}/super-admin/join-requests?status=PENDING", 
                              headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            requests_list = data.get('join_requests', [])
            print(f"   ✅ Found {len(requests_list)} pending requests")
            
            if requests_list:
                first_request = requests_list[0]
                print(f"   📝 First request: {first_request.get('user', {}).get('username')} -> {first_request.get('organization_name')}")
                return first_request.get('id')
            else:
                print("   ℹ️  No pending requests found")
                return None
        else:
            print(f"   ❌ Failed to get requests: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        print(f"   ❌ Error getting requests: {e}")
        return None

def test_approve_request(token, request_id):
    """Test approving a join request"""
    print(f"\n✅ Testing Approve Request (ID: {request_id})...")
    
    if not token or not request_id:
        print("   ❌ Missing token or request ID")
        return False
    
    try:
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.put(f"{ADMIN_URL}/super-admin/join-requests/{request_id}/approve", 
                              headers=headers)
        
        print(f"   📡 Response Status: {response.status_code}")
        print(f"   📡 Response Headers: {dict(response.headers)}")
        print(f"   📡 Response Text: {response.text}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Approval successful: {data.get('message')}")
            return True
        else:
            print(f"   ❌ Approval failed: {response.status_code}")
            try:
                error_data = response.json()
                print(f"   ❌ Error details: {error_data}")
            except:
                print(f"   ❌ Raw error: {response.text}")
            return False
            
    except Exception as e:
        print(f"   ❌ Error during approval: {e}")
        return False

def main():
    print("🧪 Testing Join Request Approval Functionality")
    print("=" * 60)
    
    # Step 1: Login as super admin
    token = test_super_admin_login()
    
    # Step 2: Get pending join requests
    request_id = test_get_join_requests(token)
    
    # Step 3: Try to approve a request
    if request_id:
        success = test_approve_request(token, request_id)
        
        if success:
            print("\n🎉 All tests passed! Approval functionality is working.")
        else:
            print("\n❌ Approval test failed!")
    else:
        print("\n⚠️  No pending requests to test approval with.")
    
    print("\n" + "=" * 60)

if __name__ == "__main__":
    main()
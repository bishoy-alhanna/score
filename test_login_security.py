#!/usr/bin/env python3
"""
Test script to verify login security fix - users cannot login to organizations they don't belong to
"""

import requests
import json
import time

API_BASE = "http://score.al-hanna.com/api"

def test_login_security():
    print("🔒 Testing Login Security Fix")
    print("="*50)
    
    # Test 1: Try to login with organization_id that user doesn't belong to
    print("Test 1: Login with invalid organization_id")
    
    # First, let's get available organizations
    try:
        orgs_response = requests.get(f"{API_BASE}/auth/organizations")
        organizations = orgs_response.json().get('organizations', [])
        print(f"Available organizations: {len(organizations)}")
        for org in organizations:
            print(f"  - {org['name']} (ID: {org['id']})")
    except Exception as e:
        print(f"Error fetching organizations: {e}")
        return
    
    if not organizations:
        print("No organizations found!")
        return
    
    # Try to login with a fake organization ID
    fake_org_id = "00000000-0000-0000-0000-000000000000"
    login_data = {
        "username": "testtest",
        "password": "12345678", 
        "organization_id": fake_org_id
    }
    
    print(f"\nAttempting login with fake organization ID: {fake_org_id}")
    
    try:
        response = requests.post(f"{API_BASE}/auth/login", json=login_data)
        result = response.json()
        
        if response.status_code == 403 and 'not a member' in result.get('error', ''):
            print("✅ SECURITY FIX WORKING: Login rejected for invalid organization")
            print(f"   Response: {result.get('error')}")
        elif response.status_code == 401:
            print("ℹ️  Invalid credentials (expected if user doesn't exist)")
        elif response.status_code == 200:
            print("❌ SECURITY ISSUE: Login succeeded with invalid organization!")
            print(f"   Response: {result}")
        else:
            print(f"⚠️  Unexpected response ({response.status_code}): {result}")
            
    except Exception as e:
        print(f"Error during login test: {e}")
    
    # Test 2: Try with organization_name that user doesn't belong to
    print(f"\nTest 2: Login with organization_name user doesn't belong to")
    
    if organizations:
        org_name = organizations[0]['name']
        login_data = {
            "username": "nonexistentuser",
            "password": "wrongpassword",
            "organization_name": org_name
        }
        
        print(f"Attempting login with organization name: {org_name}")
        
        try:
            time.sleep(1)  # Brief delay to avoid rate limiting
            response = requests.post(f"{API_BASE}/auth/login", json=login_data)
            result = response.json()
            
            if response.status_code == 401:
                print("✅ Invalid credentials rejected (as expected)")
            elif response.status_code == 403:
                print("✅ Access denied (as expected for non-member)")
                print(f"   Response: {result.get('error')}")
            else:
                print(f"⚠️  Unexpected response ({response.status_code}): {result}")
                
        except Exception as e:
            print(f"Error during organization name test: {e}")
    
    print("\n🔒 Security test completed!")

if __name__ == "__main__":
    test_login_security()
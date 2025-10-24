#!/usr/bin/env python3

import requests
import json

# Test authentication and profile endpoint
def test_profile_endpoint():
    base_url = "http://localhost/api"
    
    # Login to get fresh token
    login_data = {
        "username": "profiletest",
        "password": "testpass123"
    }
    
    print("1. Testing login...")
    response = requests.post(f"{base_url}/auth/login", json=login_data)
    print(f"Login response status: {response.status_code}")
    
    if response.status_code == 200:
        response_data = response.json()
        token = response_data.get('access_token') or response_data.get('token')
        print(f"Response data: {response_data}")
        
        if token:
            print(f"Got token: {token[:50]}...")
        else:
            print("No token found in response")
            return
        
        # Test profile endpoint
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        print("\n2. Testing GET /profile/me...")
        profile_response = requests.get(f"{base_url}/profile/me", headers=headers)
        print(f"Profile GET status: {profile_response.status_code}")
        
        if profile_response.status_code == 200:
            profile_data = profile_response.json()
            print(f"Profile data keys: {list(profile_data.keys())}")
            print(f"User fields: {list(profile_data.keys()) if isinstance(profile_data, dict) else 'Not a dict'}")
            
            # Try updating profile
            print("\n3. Testing PUT /profile/me...")
            update_data = {
                "first_name": "Bishoy",
                "last_name": "Test",
                "bio": "Updated bio from test script",
                "phone_number": "555-1234",
                "city": "Test City"
            }
            
            update_response = requests.put(f"{base_url}/profile/me", json=update_data, headers=headers)
            print(f"Profile UPDATE status: {update_response.status_code}")
            
            if update_response.status_code == 200:
                updated_data = update_response.json()
                print(f"Updated profile user data: {updated_data.get('user', {}).get('first_name')} {updated_data.get('user', {}).get('last_name')}")
                print("Profile update test PASSED!")
            else:
                print(f"Profile update failed: {update_response.text}")
        else:
            print(f"Profile GET failed: {profile_response.text}")
    else:
        print(f"Login failed: {response.text}")

if __name__ == "__main__":
    test_profile_endpoint()
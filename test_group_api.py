#!/usr/bin/env python3

import requests
import json

# Test the group service API
def test_group_api():
    base_url = "http://localhost"
    group_id = "a45a340d-a545-430c-b959-0a83bf63748d"
    
    print("Testing group service API...")
    
    # Test direct access
    url = f"{base_url}/api/groups/{group_id}"
    print(f"Testing URL: {url}")
    
    response = requests.get(url)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
    
    # Test with headers that leaderboard service would use
    headers = {
        'Authorization': 'Bearer test-token',
        'Content-Type': 'application/json'
    }
    
    print(f"\nTesting with headers: {headers}")
    response = requests.get(url, headers=headers)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")

if __name__ == "__main__":
    test_group_api()
#!/usr/bin/env python3
"""
Test script to check OrganizationJoinRequest relationships
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend/auth-service/auth-service'))

def test_join_request_relationships():
    try:
        from src.models.database_multi_org import db, OrganizationJoinRequest, User, Organization
        from src.main import app
        
        with app.app_context():
            print("🔍 Testing OrganizationJoinRequest relationships...")
            
            # Get a pending request
            join_request = OrganizationJoinRequest.query.filter_by(status='PENDING').first()
            
            if not join_request:
                print("❌ No pending join requests found")
                return
            
            print(f"✅ Found join request: {join_request.id}")
            print(f"   User ID: {join_request.user_id}")
            print(f"   Organization ID: {join_request.organization_id}")
            
            # Test accessing relationships
            try:
                user = join_request.requesting_user
                print(f"✅ requesting_user relationship works: {user.username if user else 'None'}")
            except Exception as e:
                print(f"❌ requesting_user relationship failed: {e}")
            
            try:
                org = join_request.organization_for_join_request
                print(f"✅ organization_for_join_request relationship works: {org.name if org else 'None'}")
            except Exception as e:
                print(f"❌ organization_for_join_request relationship failed: {e}")
            
            # Test to_dict method
            try:
                data = join_request.to_dict()
                print(f"✅ to_dict() works")
                print(f"   User: {data.get('user', {}).get('username') if data.get('user') else 'None'}")
                print(f"   Organization: {data.get('organization_name', 'None')}")
            except Exception as e:
                print(f"❌ to_dict() failed: {e}")
                import traceback
                traceback.print_exc()
            
    except Exception as e:
        print(f"❌ Test setup failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_join_request_relationships()
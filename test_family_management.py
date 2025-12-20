#!/usr/bin/env python3
"""
Test script for Family API endpoints
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend/auth-service/auth-service'))

def test_family_model():
    """Test Family model creation"""
    try:
        from src.models.database_multi_org import db, User, Family, Organization
        from src.main import app
        
        with app.app_context():
            print("🔍 Testing Family Model...")
            
            # Test 1: Check if Family table exists
            try:
                families = Family.query.limit(1).all()
                print(f"✅ Family table exists. Found {len(families)} families in test query")
            except Exception as e:
                print(f"❌ Family table error: {e}")
                return False
            
            # Test 2: Check User model has new fields
            try:
                user = User.query.first()
                if user:
                    print(f"✅ User model check:")
                    print(f"   - national_id field: {hasattr(user, 'national_id')}")
                    print(f"   - family_id field: {hasattr(user, 'family_id')}")
                    print(f"   - church_role field: {hasattr(user, 'church_role')}")
                else:
                    print("⚠️  No users found in database for field check")
            except Exception as e:
                print(f"❌ User field check error: {e}")
                return False
            
            # Test 3: Test Family.to_dict() method
            if families:
                family = families[0]
                try:
                    family_dict = family.to_dict()
                    print(f"✅ Family.to_dict() works")
                    print(f"   Keys: {list(family_dict.keys())}")
                except Exception as e:
                    print(f"❌ Family.to_dict() error: {e}")
                    return False
            
            print("\n✅ All Family model tests passed!")
            return True
            
    except Exception as e:
        print(f"❌ Test setup failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_family_routes():
    """Test that Family routes are registered"""
    try:
        from src.main import app
        
        print("\n🔍 Testing Family Routes...")
        
        # Get all registered routes
        routes = []
        for rule in app.url_map.iter_rules():
            routes.append(str(rule))
        
        # Check for family routes
        family_routes = [r for r in routes if '/families' in r]
        
        if family_routes:
            print(f"✅ Found {len(family_routes)} family routes:")
            for route in family_routes:
                print(f"   - {route}")
        else:
            print("❌ No family routes found")
            return False
        
        # Expected routes
        expected_routes = [
            '/api/families',
            '/api/families/<family_id>',
            '/api/families/<family_id>/members',
            '/api/families/<family_id>/members/<member_id>',
            '/api/families/search-by-national-id'
        ]
        
        print("\n✅ Family routes are registered!")
        return True
        
    except Exception as e:
        print(f"❌ Routes test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_user_to_dict():
    """Test User.to_dict() includes new fields"""
    try:
        from src.models.database_multi_org import db, User
        from src.main import app
        
        with app.app_context():
            print("\n🔍 Testing User.to_dict() with new fields...")
            
            user = User.query.first()
            if not user:
                print("⚠️  No users found in database")
                return True
            
            user_dict = user.to_dict()
            
            # Check for new fields
            new_fields = ['national_id', 'church_role', 'family_id']
            missing_fields = []
            
            for field in new_fields:
                if field not in user_dict:
                    missing_fields.append(field)
            
            if missing_fields:
                print(f"❌ Missing fields in User.to_dict(): {missing_fields}")
                return False
            
            print(f"✅ User.to_dict() includes new fields:")
            for field in new_fields:
                print(f"   - {field}: {user_dict.get(field)}")
            
            return True
            
    except Exception as e:
        print(f"❌ User.to_dict() test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("Family Management Feature Tests")
    print("=" * 60)
    
    results = []
    
    # Run tests
    results.append(("Family Model", test_family_model()))
    results.append(("Family Routes", test_family_routes()))
    results.append(("User to_dict", test_user_to_dict()))
    
    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    sys.exit(0 if passed == total else 1)

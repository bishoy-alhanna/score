from flask import Blueprint, request, jsonify, current_app
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from datetime import datetime, timedelta
from src.models.database_multi_org import (
    db, User, Organization, UserOrganization, 
    OrganizationJoinRequest, OrganizationInvitation
)
import os
import secrets
import requests
import uuid
from decimal import Decimal
import sys

def safe_serialize(obj):
    """Safely serialize objects that might contain UUIDs or datetimes"""
    if isinstance(obj, uuid.UUID):
        return str(obj)
    elif isinstance(obj, (datetime,)):
        return obj.isoformat()
    elif isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, dict):
        return {k: safe_serialize(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [safe_serialize(item) for item in obj]
    elif hasattr(obj, '__dict__'):
        return safe_serialize(obj.__dict__)
    else:
        return obj

def safe_jsonify(data):
    """Safe jsonify that handles UUIDs and datetimes"""
    serialized_data = safe_serialize(data)
    return jsonify(serialized_data)

# STARTUP DEBUG
print("🔥 AUTH_MULTI_ORG.PY LOADED!", flush=True)

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/test-debug', methods=['GET'])
def test_debug():
    """Test endpoint to verify this file is being used"""
    return jsonify({'message': 'AUTH_MULTI_ORG.PY is working!', 'file': 'auth_multi_org.py'}), 200

def generate_jwt_token(user, organization_id=None):
    """Generate JWT token for authenticated user"""
    # Get user's role in the specified organization or primary organization
    if organization_id:
        role = user.get_role_in_organization(organization_id)
        org_id = organization_id
    else:
        # Get first active organization or None
        memberships = user.get_organizations(active_only=True)
        if memberships:
            role = memberships[0].role
            org_id = memberships[0].organization_id
        else:
            role = None
            org_id = None
    
    payload = {
        'user_id': str(user.id),
        'username': user.username,
        'email': user.email,
        'role': role,
        'organization_id': str(org_id) if org_id else None,
        'exp': datetime.utcnow() + timedelta(hours=24),
        'iat': datetime.utcnow()
    }
    
    secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
    return jwt.encode(payload, secret_key, algorithm='HS256')

@auth_bp.route('/register', methods=['POST'])
def register():
    """Register new user"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['username', 'email', 'password', 'first_name', 'last_name']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field} is required'}), 400
        
        # Check if user already exists
        existing_user = User.query.filter(
            (User.username == data['username']) | 
            (User.email == data['email'])
        ).first()
        
        if existing_user:
            return jsonify({'error': 'Username or email already exists'}), 400
        
        # Create new user
        user = User(
            username=data['username'],
            email=data['email'],
            first_name=data['first_name'],
            last_name=data['last_name'],
            is_active=True
        )
        user.set_password(data['password'])
        
        db.session.add(user)
        db.session.commit()
        
        return jsonify({
            'message': 'User registered successfully',
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/debug-user-role/<user_id>', methods=['GET'])
def debug_user_role(user_id):
    """Debug endpoint to check user's current roles"""
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        memberships = UserOrganization.query.filter_by(user_id=user_id, is_active=True).all()
        roles = []
        for membership in memberships:
            roles.append({
                'organization_id': str(membership.organization_id),
                'organization_name': membership.organization.name,
                'role': membership.role,
                'is_active': membership.is_active
            })
        
        return jsonify({
            'user_id': str(user.id),
            'username': user.username,
            'roles': roles
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/admin-organizations/<username>', methods=['GET'])
def get_admin_organizations(username):
    """Get organizations where user has admin privileges"""
    try:
        # Find user by username or email
        user = User.query.filter(
            (User.username == username) | (User.email == username)
        ).first()
        
        if not user:
            return jsonify({'organizations': []}), 200
        
        # Get organizations where user is ORG_ADMIN
        admin_memberships = UserOrganization.query.filter_by(
            user_id=user.id,
            role='ORG_ADMIN',
            is_active=True
        ).join(Organization).filter(Organization.is_active == True).all()
        
        organizations = []
        for membership in admin_memberships:
            organizations.append({
                'id': str(membership.organization_id),
                'name': membership.organization.name,
                'description': membership.organization.description,
                'member_count': UserOrganization.query.filter_by(
                    organization_id=membership.organization_id,
                    is_active=True
                ).count()
            })
        
        return jsonify({'organizations': organizations}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/verify', methods=['POST'])
def verify():
    """Verify JWT token"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authorization header required'}), 401
        
        token = auth_header.split(' ')[1]
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        user = User.query.get(payload['user_id'])
        if not user:
            return jsonify({'error': 'User not found'}), 401
        
        return safe_jsonify({
            'user': user.to_dict(include_organizations=True),
            'current_organization_id': payload.get('organization_id')
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/login', methods=['POST'])
def login():
    """Login endpoint supporting multi-organization selection"""
    try:
        import sys
        print(f"DEBUG: Login endpoint called", file=sys.stderr, flush=True)
        data = request.get_json()
        print(f"DEBUG: Login data received: {data}", file=sys.stderr, flush=True)
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Validate required fields
        username = data.get('username')
        password = data.get('password')
        organization_name = data.get('organization_name')
        
        print(f"DEBUG: Processing login for username: {username}, org: {organization_name}", file=sys.stderr, flush=True)
        
        if not username or not password:
            return jsonify({'error': 'Username and password are required'}), 400
        
        # Find user by username
        user = User.query.filter_by(username=username, is_active=True).first()
        
        if not user or not user.verify_password(password):
            return jsonify({'error': 'Invalid username or password'}), 401
        
        print(f"DEBUG: User authenticated: {user.username}", file=sys.stderr, flush=True)
        
        # Get user's active organization memberships
        user_organizations = UserOrganization.query.filter_by(
            user_id=user.id,
            is_active=True
        ).join(Organization).filter(Organization.is_active == True).all()
        
        print(f"DEBUG: User orgs: {[(uo.organization.name, str(uo.organization_id)) for uo in user_organizations]}", file=sys.stderr, flush=True)
        
        organization_id = None
        
        # If user specified an organization name and is not a member, create join request
        if organization_name and not user_organizations:
            organization = Organization.query.filter_by(name=organization_name, is_active=True).first()
            if organization:
                # Check if there's already a pending request
                existing_request = OrganizationJoinRequest.query.filter_by(
                    user_id=user.id,
                    organization_id=organization.id,
                    status='PENDING'
                ).first()
                
                if not existing_request:
                    # Create new join request
                    join_request = OrganizationJoinRequest(
                        user_id=user.id,
                        organization_id=organization.id,
                        requested_role='USER',
                        message=f'Login join request from {user.first_name} {user.last_name}',
                        status='PENDING'
                    )
                    db.session.add(join_request)
                    db.session.commit()
                    
                    return jsonify({
                        'error': 'You are not a member of this organization. A join request has been submitted and is pending approval. Please contact your administrator.',
                        'join_request_submitted': True,
                        'organization_name': organization_name
                    }), 403
                else:
                    return jsonify({
                        'error': 'You already have a pending join request for this organization. Please wait for approval or contact your administrator.',
                        'join_request_exists': True,
                        'organization_name': organization_name
                    }), 403
            else:
                return jsonify({
                    'error': f'Organization "{organization_name}" not found. Please verify the organization name or contact your administrator.',
                    'organization_not_found': True
                }), 404
        
        # If user specified an organization name and IS a member, find the matching organization
        elif organization_name and user_organizations:
            print(f"DEBUG: Looking for org name match: '{organization_name}'", file=sys.stderr, flush=True)
            # Find the organization by name among user's memberships
            user_org_membership = next(
                (uo for uo in user_organizations if uo.organization.name == organization_name), 
                None
            )
            if user_org_membership:
                organization_id = str(user_org_membership.organization_id)
                print(f"DEBUG: Found matching org by name: {organization_name} -> {organization_id}", file=sys.stderr, flush=True)
            else:
                print(f"DEBUG: No matching org found for name: {organization_name}", file=sys.stderr, flush=True)
                print(f"DEBUG: Available orgs: {[(uo.organization.name, str(uo.organization_id)) for uo in user_organizations]}", file=sys.stderr, flush=True)
                return jsonify({
                    'error': f'You are not a member of "{organization_name}". Please select one of your organizations.',
                    'invalid_organization': True,
                    'debug_searched_name': organization_name,
                    'debug_available_orgs': [(uo.organization.name, str(uo.organization_id)) for uo in user_organizations]
                }), 403
        
        if not user_organizations:
            return jsonify({
                'error': 'Access denied. You are not a member of any active organization. Please specify an organization name to request access or contact your administrator.'
            }), 403
        
        # If organization_id was provided and validated, use it
        # Otherwise, use the first organization the user belongs to
        final_organization_id = organization_id if organization_id else user_organizations[0].organization_id
        
        print(f"DEBUG: Final organization_id: {final_organization_id}", file=sys.stderr, flush=True)
        
        # Generate JWT token with the validated organization ID
        token = generate_jwt_token(user, final_organization_id)
        
        return jsonify({
            'message': 'Login successful',
            'token': token,
            'user': user.to_dict(include_organizations=True),
            'organization_id': str(final_organization_id),
            'debug_org_name': organization_name,
            'debug_org_id': organization_id,
            'debug_final': str(final_organization_id),
            'debug_available_orgs': [(uo.organization.name, str(uo.organization_id)) for uo in user_organizations]
        }), 200
        
    except Exception as e:
        print(f"DEBUG: Login error: {str(e)}", file=sys.stderr, flush=True)
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/create-organization', methods=['POST'])
def create_organization():
    """Create new organization and make user an admin"""
    try:
        data = request.get_json()
        
        # Get user from token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authorization header required'}), 401
        
        token = auth_header.split(' ')[1]
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        user = User.query.get(payload['user_id'])
        if not user:
            return jsonify({'error': 'User not found'}), 401
        
        # Validate required fields
        organization_name = data.get('organization_name')
        if not organization_name:
            return jsonify({'error': 'Organization name is required'}), 400
        
        # Check if organization name already exists
        existing_org = Organization.query.filter_by(name=organization_name).first()
        if existing_org:
            return jsonify({'error': 'Organization name already exists'}), 400
        
        # Create new organization
        organization = Organization(
            name=organization_name,
            description=data.get('description')
        )
        db.session.add(organization)
        db.session.flush()  # Get the organization ID
        
        # Add user as organization admin
        user_org = UserOrganization(
            user_id=user.id,
            organization_id=organization.id,
            role='ORG_ADMIN',
            department=data.get('department'),
            title=data.get('title', 'Organization Administrator')
        )
        db.session.add(user_org)
        db.session.commit()
        
        # Create predefined categories for the new organization
        try:
            scoring_service_url = os.environ.get('SCORING_SERVICE_URL', 'http://scoring-service:5000')
            response = requests.post(
                f"{scoring_service_url}/scores/create-predefined-categories",
                json={
                    'organization_id': str(organization.id),
                    'created_by': str(user.id)
                },
                timeout=5
            )
            if response.status_code != 201:
                print(f"Warning: Failed to create predefined categories: {response.text}")
        except Exception as e:
            print(f"Warning: Could not create predefined categories: {str(e)}")
        
        # Generate new JWT token with organization context
        token = generate_jwt_token(user, organization.id)
        
        return jsonify({
            'message': 'Organization created successfully',
            'token': token,
            'organization': organization.to_dict(),
            'user': user.to_dict(include_organizations=True)
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/organizations', methods=['GET'])
def get_organizations():
    """Get list of organizations available for joining"""
    try:
        # Get all active organizations
        organizations = Organization.query.filter_by(is_active=True).all()
        
        org_list = []
        for org in organizations:
            org_list.append({
                'id': str(org.id),
                'name': org.name,
                'description': org.description,
                'member_count': UserOrganization.query.filter_by(
                    organization_id=org.id,
                    is_active=True
                ).count()
            })
        
        return jsonify({'organizations': org_list}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/user-organizations', methods=['GET'])
def get_user_organizations():
    """Get organizations that the current user is a member of (for login dropdown)"""
    try:
        # Check if we have a token (for logged-in users)
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
            
            try:
                payload = jwt.decode(token, secret_key, algorithms=['HS256'])
                user = User.query.get(payload['user_id'])
                
                if user and user.is_active:
                    # Return only organizations the user is a member of
                    user_organizations = UserOrganization.query.filter_by(
                        user_id=user.id,
                        is_active=True
                    ).join(Organization).filter(Organization.is_active == True).all()
                    
                    org_list = []
                    for membership in user_organizations:
                        org_list.append({
                            'id': str(membership.organization_id),
                            'name': membership.organization.name,
                            'description': membership.organization.description,
                            'role': membership.role
                        })
                    
                    return jsonify({'organizations': org_list}), 200
            except jwt.InvalidTokenError:
                pass
        
        # If no valid token, return all organizations (for initial registration/join requests)
        organizations = Organization.query.filter_by(is_active=True).all()
        
        org_list = []
        for org in organizations:
            org_list.append({
                'id': str(org.id),
                'name': org.name,
                'description': org.description,
                'member_count': UserOrganization.query.filter_by(
                    organization_id=org.id,
                    is_active=True
                ).count()
            })
        
        return jsonify({'organizations': org_list}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
@auth_bp.route('/organizations/<organization_id>/users', methods=['GET'])
def get_organization_users(organization_id):
    """Get all users in a specific organization"""
    try:
        # Verify token and get current user
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Authorization token required'}), 401
        
        # Remove 'Bearer ' prefix if present
        if token.startswith('Bearer '):
            token = token[7:]
        
        try:
            secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            current_user = User.query.get(payload['user_id'])
            
            if not current_user:
                return jsonify({'error': 'Invalid token'}), 401
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Check if current user has admin rights in this organization
        user_org = UserOrganization.query.filter_by(
            user_id=current_user.id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not user_org or user_org.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Access denied - admin rights required'}), 403
        
        # Get all users in the organization
        user_orgs = UserOrganization.query.filter_by(
            organization_id=organization_id,
            is_active=True
        ).all()
        
        users = []
        for user_org in user_orgs:
            user = user_org.user
            user_data = user.to_dict()
            user_data['role'] = user_org.role
            user_data['joined_at'] = user_org.joined_at.isoformat() if user_org.joined_at else None
            users.append(user_data)
        
        return safe_jsonify({'users': users}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/users/<user_id>', methods=['PUT'])
def update_user(user_id):
    """Update user information"""
    try:
        # Verify token and get current user
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Authorization token required'}), 401
        
        if token.startswith('Bearer '):
            token = token[7:]
        
        try:
            secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            current_user = User.query.get(payload['user_id'])
            
            if not current_user:
                return jsonify({'error': 'Invalid token'}), 401
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Get the user to update
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Check if current user has admin rights
        current_org_id = payload.get('organization_id')
        if current_org_id:
            current_user_org = UserOrganization.query.filter_by(
                user_id=current_user.id,
                organization_id=current_org_id,
                is_active=True
            ).first()
            
            if not current_user_org or current_user_org.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
                return jsonify({'error': 'Access denied - admin rights required'}), 403
        
        data = request.get_json()
        
        # Update user fields
        if 'username' in data:
            # Check if username is already taken
            existing = User.query.filter(
                User.username == data['username'],
                User.id != user_id
            ).first()
            if existing:
                return jsonify({'error': 'Username already taken'}), 400
            user.username = data['username']
        
        if 'email' in data:
            # Check if email is already taken
            existing = User.query.filter(
                User.email == data['email'],
                User.id != user_id
            ).first()
            if existing:
                return jsonify({'error': 'Email already taken'}), 400
            user.email = data['email']
        
        if 'first_name' in data:
            user.first_name = data['first_name']
        
        if 'last_name' in data:
            user.last_name = data['last_name']
        
        if 'is_active' in data:
            user.is_active = data['is_active']
        
        db.session.commit()
        
        return safe_jsonify({'message': 'User updated successfully', 'user': user.to_dict()}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/users/<user_id>/password', methods=['PUT'])
def reset_user_password(user_id):
    """Reset user password"""
    try:
        # Verify token and get current user
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Authorization token required'}), 401
        
        if token.startswith('Bearer '):
            token = token[7:]
        
        try:
            secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            current_user = User.query.get(payload['user_id'])
            
            if not current_user:
                return jsonify({'error': 'Invalid token'}), 401
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Get the user to update
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Check if current user has admin rights
        current_org_id = payload.get('organization_id')
        if current_org_id:
            current_user_org = UserOrganization.query.filter_by(
                user_id=current_user.id,
                organization_id=current_org_id,
                is_active=True
            ).first()
            
            if not current_user_org or current_user_org.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
                return jsonify({'error': 'Access denied - admin rights required'}), 403
        
        data = request.get_json()
        new_password = data.get('new_password')
        
        if not new_password or len(new_password) < 6:
            return jsonify({'error': 'Password must be at least 6 characters long'}), 400
        
        user.set_password(new_password)
        db.session.commit()
        
        return jsonify({'message': 'Password reset successfully'}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/organizations/<organization_id>/users/<user_id>/role', methods=['PUT'])
def update_user_role(organization_id, user_id):
    """Update user role in organization"""
    try:
        # Verify token and get current user
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Authorization token required'}), 401
        
        if token.startswith('Bearer '):
            token = token[7:]
        
        try:
            secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            current_user = User.query.get(payload['user_id'])
            
            if not current_user:
                return jsonify({'error': 'Invalid token'}), 401
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Check if current user has admin rights in this organization
        current_user_org = UserOrganization.query.filter_by(
            user_id=current_user.id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not current_user_org or current_user_org.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Access denied - admin rights required'}), 403
        
        # Get the user organization relationship to update
        user_org = UserOrganization.query.filter_by(
            user_id=user_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not user_org:
            return jsonify({'error': 'User not found in organization'}), 404
        
        data = request.get_json()
        new_role = data.get('role')
        
        if new_role not in ['USER', 'ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Invalid role'}), 400
        
        user_org.role = new_role
        db.session.commit()
        
        return jsonify({'message': 'User role updated successfully'}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/organizations/<organization_id>/users/<user_id>', methods=['DELETE'])
def remove_user_from_organization(organization_id, user_id):
    """Remove user from organization"""
    try:
        # Verify token and get current user
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Authorization token required'}), 401
        
        if token.startswith('Bearer '):
            token = token[7:]
        
        try:
            secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            current_user = User.query.get(payload['user_id'])
            
            if not current_user:
                return jsonify({'error': 'Invalid token'}), 401
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Check if current user has admin rights in this organization
        current_user_org = UserOrganization.query.filter_by(
            user_id=current_user.id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not current_user_org or current_user_org.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Access denied - admin rights required'}), 403
        
        # Prevent self-removal
        if current_user.id == user_id:
            return jsonify({'error': 'Cannot remove yourself from the organization'}), 400
        
        # Get the user organization relationship to remove
        user_org = UserOrganization.query.filter_by(
            user_id=user_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not user_org:
            return jsonify({'error': 'User not found in organization'}), 404
        
        # Remove user from organization (soft delete)
        user_org.is_active = False
        user_org.left_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({'message': 'User removed from organization successfully'}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/organizations/<organization_id>/join-requests', methods=['GET'])
def get_organization_join_requests(organization_id):
    """Get all pending join requests for an organization"""
    try:
        # Verify user is authenticated
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authentication required'}), 401
        
        token = auth_header.split(' ')[1]
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            current_user_id = payload['user_id']
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Check if user is admin of this organization
        current_user_org = UserOrganization.query.filter_by(
            user_id=current_user_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not current_user_org or current_user_org.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Access denied - admin rights required'}), 403
        
        # Get all pending join requests for the organization
        join_requests = OrganizationJoinRequest.query.filter_by(
            organization_id=organization_id,
            status='PENDING'
        ).all()
        
        requests_data = []
        for request_obj in join_requests:
            # Get user info separately to avoid join ambiguity
            user = User.query.get(request_obj.user_id)
            requests_data.append({
                'id': str(request_obj.id),
                'user_id': str(request_obj.user_id),
                'user': {
                    'id': str(user.id),
                    'username': user.username,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                } if user else None,
                'requested_role': request_obj.requested_role,
                'message': request_obj.message,
                'created_at': request_obj.created_at.isoformat() if request_obj.created_at else None
            })
        
        return safe_jsonify({
            'join_requests': requests_data
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/organizations/<organization_id>/join-requests/<request_id>/approve', methods=['POST'])
def approve_join_request(organization_id, request_id):
    """Approve a join request"""
    try:
        # Verify user is authenticated
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authentication required'}), 401
        
        token = auth_header.split(' ')[1]
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            current_user_id = payload['user_id']
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Check if user is admin of this organization
        current_user_org = UserOrganization.query.filter_by(
            user_id=current_user_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not current_user_org or current_user_org.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Access denied - admin rights required'}), 403
        
        # Find the join request
        join_request = OrganizationJoinRequest.query.filter_by(
            id=request_id,
            organization_id=organization_id,
            status='PENDING'
        ).first()
        
        if not join_request:
            return jsonify({'error': 'Join request not found or already processed'}), 404
        
        # Get request data
        data = request.get_json() or {}
        review_message = data.get('message', '')
        
        # Update the join request
        join_request.status = 'APPROVED'
        join_request.reviewed_by = current_user_id
        join_request.reviewed_at = datetime.utcnow()
        join_request.review_message = review_message
        
        # Create user organization relationship
        user_org = UserOrganization(
            user_id=join_request.user_id,
            organization_id=organization_id,
            role=join_request.requested_role,
            is_active=True
        )
        db.session.add(user_org)
        
        db.session.commit()
        
        return jsonify({'message': 'Join request approved successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/organizations/<organization_id>/join-requests/<request_id>/reject', methods=['POST'])
def reject_join_request(organization_id, request_id):
    """Reject a join request"""
    try:
        # Verify user is authenticated
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authentication required'}), 401
        
        token = auth_header.split(' ')[1]
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            current_user_id = payload['user_id']
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Check if user is admin of this organization
        current_user_org = UserOrganization.query.filter_by(
            user_id=current_user_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not current_user_org or current_user_org.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Access denied - admin rights required'}), 403
        
        # Find the join request
        join_request = OrganizationJoinRequest.query.filter_by(
            id=request_id,
            organization_id=organization_id,
            status='PENDING'
        ).first()
        
        if not join_request:
            return jsonify({'error': 'Join request not found or already processed'}), 404
        
        # Get request data
        data = request.get_json() or {}
        review_message = data.get('message', '')
        
        # Update the join request
        join_request.status = 'REJECTED'
        join_request.reviewed_by = current_user_id
        join_request.reviewed_at = datetime.utcnow()
        join_request.review_message = review_message
        
        db.session.commit()
        
        return jsonify({'message': 'Join request rejected successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/verify-qr', methods=['POST'])
def verify_qr_code():
    """Verify QR code and return user information"""
    try:
        # Verify the requesting user
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authorization required'}), 401
        
        token = auth_header.split(' ')[1]
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            scanner_user_id = payload['user_id']
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid authorization token'}), 401
        
        # Get the scanner user
        scanner = User.query.get(scanner_user_id)
        if not scanner:
            return jsonify({'error': 'Scanner user not found'}), 404
        
        # Get QR token from request
        data = request.get_json()
        qr_token = data.get('qr_token')
        
        if not qr_token:
            return jsonify({'error': 'QR token is required'}), 400
        
        # Decode QR token
        try:
            qr_payload = jwt.decode(qr_token, secret_key, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'QR code has expired'}), 400
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid QR code'}), 400
        
        # Get the user from QR code
        qr_user_id = qr_payload['user_id']
        qr_user = User.query.get(qr_user_id)
        
        if not qr_user or not qr_user.is_active:
            return jsonify({'error': 'QR code user not found'}), 404
        
        # Check if scanner has permission to scan this user
        scanner_org_id = payload.get('organization_id')
        if scanner_org_id:
            # Check if scanned user is in the same organization
            qr_user_membership = UserOrganization.query.filter_by(
                user_id=qr_user.id,
                organization_id=scanner_org_id,
                is_active=True
            ).first()
            
            if not qr_user_membership:
                return jsonify({'error': 'User not found in your organization'}), 403
        
        # Return user information
        return jsonify({
            'user': qr_user.to_dict(include_organizations=False, include_sensitive=False),
            'message': 'QR code verified successfully'
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

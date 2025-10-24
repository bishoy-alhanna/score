from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from datetime import datetime, timedelta
from src.models.database_multi_org import (
    db, User, Organization, UserOrganization, 
    OrganizationJoinRequest, OrganizationInvitation
)
import os
import secrets
import uuid
from decimal import Decimal

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

auth_bp = Blueprint('auth', __name__)

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
    """Authenticate user and return JWT token"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['username', 'password']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field} is required'}), 400
        
        username = data['username']
        password = data['password']
        organization_name = data.get('organization_name')  # Organization name for join request
        organization_id = data.get('organization_id')  # Optional: specific org login
        
        # Find user by username or email
        user = User.query.filter(
            (User.username == username) | (User.email == username)
        ).first()
        
        if not user or not user.verify_password(password):
            return jsonify({'error': 'Invalid credentials'}), 401
        
        if not user.is_active:
            return jsonify({'error': 'Account is deactivated'}), 401
        
        # Check if user belongs to any active organization
        user_organizations = UserOrganization.query.filter_by(
            user_id=user.id, 
            is_active=True
        ).join(Organization).filter(Organization.is_active == True).all()
        
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
        
        if not user_organizations:
            return jsonify({
                'error': 'Access denied. You are not a member of any active organization. Please specify an organization name to request access or contact your administrator.'
            }), 403
        
        # Generate JWT token
        token = generate_jwt_token(user, organization_id)
        
        return safe_jsonify({
            'message': 'Login successful',
            'token': token,
            'user': user.to_dict(include_organizations=True),
            'organization_id': organization_id
        }), 200
        
    except Exception as e:
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
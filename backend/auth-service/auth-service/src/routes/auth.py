from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from datetime import datetime, timedelta
from src.models.database import db, User, Organization
import os

auth_bp = Blueprint('auth', __name__)

def generate_jwt_token(user):
    """Generate JWT token for authenticated user"""
    payload = {
        'user_id': user.id,
        'username': user.username,
        'email': user.email,
        'role': user.role,
        'organization_id': user.organization_id,
        'exp': datetime.utcnow() + timedelta(hours=24),
        'iat': datetime.utcnow()
    }
    
    secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
    return jwt.encode(payload, secret_key, algorithm='HS256')

@auth_bp.route('/register', methods=['POST'])
def register():
    """Register new user and organization"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['username', 'email', 'password', 'organization_name']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field} is required'}), 400
        
        username = data['username']
        email = data['email']
        password = data['password']
        organization_name = data['organization_name']
        
        # Check if organization already exists
        existing_org = Organization.query.filter_by(name=organization_name).first()
        if existing_org:
            return jsonify({'error': 'Organization name already exists'}), 400
        
        # Create new organization
        organization = Organization(name=organization_name)
        db.session.add(organization)
        db.session.flush()  # Get the organization ID
        
        # Check if user already exists in this organization
        existing_user = User.query.filter_by(
            username=username, 
            organization_id=organization.id
        ).first()
        if existing_user:
            return jsonify({'error': 'Username already exists in this organization'}), 400
        
        existing_email = User.query.filter_by(
            email=email, 
            organization_id=organization.id
        ).first()
        if existing_email:
            return jsonify({'error': 'Email already exists in this organization'}), 400
        
        # Create new user as ORG_ADMIN (first user in organization)
        password_hash = generate_password_hash(password)
        user = User(
            username=username,
            email=email,
            password_hash=password_hash,
            role='ORG_ADMIN',
            organization_id=organization.id
        )
        
        db.session.add(user)
        db.session.commit()
        
        # Generate JWT token
        token = generate_jwt_token(user)
        
        return jsonify({
            'message': 'Registration successful',
            'token': token,
            'user': user.to_dict(),
            'organization': organization.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/login', methods=['POST'])
def login():
    """Authenticate user and return JWT token"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('username') or not data.get('password'):
            return jsonify({'error': 'Username and password are required'}), 400
        
        username = data['username']
        password = data['password']
        organization_name = data.get('organization_name')
        
        # Find user by username and organization
        query = User.query.filter_by(username=username, is_active=True)
        
        if organization_name:
            # Join with organization to filter by name
            query = query.join(Organization).filter(Organization.name == organization_name)
        
        user = query.first()
        
        if not user or not check_password_hash(user.password_hash, password):
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Generate JWT token
        token = generate_jwt_token(user)
        
        return jsonify({
            'message': 'Login successful',
            'token': token,
            'user': user.to_dict(),
            'organization': user.organization.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/verify', methods=['POST'])
def verify_token():
    """Verify JWT token and return user info"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authorization header required'}), 401
        
        token = auth_header.split(' ')[1]
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Get user from database
        user = User.query.get(payload['user_id'])
        if not user or not user.is_active:
            return jsonify({'error': 'User not found or inactive'}), 401
        
        return jsonify({
            'valid': True,
            'user': user.to_dict(),
            'organization': user.organization.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/invite-user', methods=['POST'])
def invite_user():
    """Invite new user to existing organization"""
    try:
        # Get token from header
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Authorization header required'}), 401
        
        token = auth_header.split(' ')[1]
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        # Check if user is ORG_ADMIN
        if payload.get('role') != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can invite users'}), 403
        
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['username', 'email', 'password']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field} is required'}), 400
        
        username = data['username']
        email = data['email']
        password = data['password']
        role = data.get('role', 'USER')  # Default to USER role
        organization_id = payload['organization_id']
        
        # Validate role
        if role not in ['USER', 'ORG_ADMIN']:
            return jsonify({'error': 'Invalid role'}), 400
        
        # Check if user already exists in this organization
        existing_user = User.query.filter_by(
            username=username, 
            organization_id=organization_id
        ).first()
        if existing_user:
            return jsonify({'error': 'Username already exists in this organization'}), 400
        
        existing_email = User.query.filter_by(
            email=email, 
            organization_id=organization_id
        ).first()
        if existing_email:
            return jsonify({'error': 'Email already exists in this organization'}), 400
        
        # Create new user
        password_hash = generate_password_hash(password)
        user = User(
            username=username,
            email=email,
            password_hash=password_hash,
            role=role,
            organization_id=organization_id
        )
        
        db.session.add(user)
        db.session.commit()
        
        return jsonify({
            'message': 'User invited successfully',
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


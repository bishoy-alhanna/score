from flask import Blueprint, request, jsonify
import jwt
from src.models.database import db, Organization, User
import os

organization_bp = Blueprint('organization', __name__)

def verify_token_and_get_user():
    """Helper function to verify JWT token and return user"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None, {'error': 'Authorization header required'}, 401
    
    token = auth_header.split(' ')[1]
    secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
    
    try:
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
    except jwt.InvalidTokenError:
        return None, {'error': 'Invalid token'}, 401
    
    user = User.query.get(payload['user_id'])
    if not user or not user.is_active:
        return None, {'error': 'User not found or inactive'}, 401
    
    return user, None, None

@organization_bp.route('/', methods=['GET'])
def get_organization():
    """Get current user's organization details"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization = user.organization
        return jsonify({
            'organization': organization.to_dict(),
            'user_count': len(organization.users)
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@organization_bp.route('/', methods=['PUT'])
def update_organization():
    """Update organization details (ORG_ADMIN only)"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        if user.role != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can update organization'}), 403
        
        data = request.get_json()
        organization = user.organization
        
        if 'name' in data:
            # Check if new name is already taken
            existing_org = Organization.query.filter(
                Organization.name == data['name'],
                Organization.id != organization.id
            ).first()
            if existing_org:
                return jsonify({'error': 'Organization name already exists'}), 400
            
            organization.name = data['name']
        
        db.session.commit()
        
        return jsonify({
            'message': 'Organization updated successfully',
            'organization': organization.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@organization_bp.route('/users', methods=['GET'])
def get_organization_users():
    """Get all users in the organization"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Get all users in the same organization
        users = User.query.filter_by(
            organization_id=user.organization_id,
            is_active=True
        ).all()
        
        return jsonify({
            'users': [u.to_dict() for u in users]
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@organization_bp.route('/stats', methods=['GET'])
def get_organization_stats():
    """Get organization statistics"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization = user.organization
        
        # Count users by role
        total_users = User.query.filter_by(
            organization_id=organization.id,
            is_active=True
        ).count()
        
        admin_users = User.query.filter_by(
            organization_id=organization.id,
            role='ORG_ADMIN',
            is_active=True
        ).count()
        
        regular_users = User.query.filter_by(
            organization_id=organization.id,
            role='USER',
            is_active=True
        ).count()
        
        return jsonify({
            'organization': organization.to_dict(),
            'stats': {
                'total_users': total_users,
                'admin_users': admin_users,
                'regular_users': regular_users
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


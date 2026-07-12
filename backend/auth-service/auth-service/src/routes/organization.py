from flask import Blueprint, request, jsonify
import jwt
from src.models.database_multi_org import db, Organization, User
import os
from datetime import datetime as dt

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
        
        # Get user's current organization from membership
        current_membership = user.organization_memberships[0] if user.organization_memberships else None
        if not current_membership:
            return jsonify({'error': 'User is not a member of any organization'}), 400
        
        organization = current_membership.organization
        return jsonify({
            'organization': organization.to_dict(),
            'user_count': len([m for m in organization.user_memberships if m.is_active])
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
        
        # Get user's current organization membership and check role
        current_membership = user.organization_memberships[0] if user.organization_memberships else None
        if not current_membership:
            return jsonify({'error': 'User is not a member of any organization'}), 400
        
        if current_membership.role != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can update organization'}), 403
        
        data = request.get_json()
        organization = current_membership.organization
        
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
        
        # Get user's current organization from membership
        current_membership = user.organization_memberships[0] if user.organization_memberships else None
        if not current_membership:
            return jsonify({'error': 'User is not a member of any organization'}), 400
        
        organization_id = current_membership.organization_id
        
        # Get all users in the same organization through UserOrganization relationships
        from src.models.database_multi_org import UserOrganization
        
        organization_users = db.session.query(User).join(UserOrganization).filter(
            UserOrganization.organization_id == organization_id,
            UserOrganization.is_active == True,
            User.is_active == True
        ).all()
        
        return jsonify({
            'users': [u.to_dict() for u in organization_users]
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@organization_bp.route('/filter-settings', methods=['PUT'])
def update_filter_settings():
    """Update organization leaderboard date filter settings (ORG_ADMIN only)"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code

        current_membership = user.organization_memberships[0] if user.organization_memberships else None
        if not current_membership:
            return jsonify({'error': 'User is not a member of any organization'}), 400

        if current_membership.role != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can update filter settings'}), 403

        data = request.get_json()
        organization = current_membership.organization

        filter_enabled = data.get('filter_enabled', False)
        start_date_str = data.get('filter_start_date')
        end_date_str = data.get('filter_end_date')

        start_date = dt.strptime(start_date_str, '%Y-%m-%d').date() if start_date_str else None
        end_date = dt.strptime(end_date_str, '%Y-%m-%d').date() if end_date_str else None

        if filter_enabled:
            if not start_date or not end_date:
                return jsonify({'error': 'Both start date and end date are required when filter is enabled'}), 400
            if start_date >= end_date:
                return jsonify({'error': 'Start date must be before end date'}), 400

        organization.filter_enabled = filter_enabled
        organization.filter_start_date = start_date
        organization.filter_end_date = end_date

        db.session.commit()

        return jsonify({
            'message': 'Filter settings updated successfully',
            'organization': organization.to_dict()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@organization_bp.route('/stats', methods=['GET'])
def get_organization_stats():
    """Get organization statistics"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Get user's current organization from membership
        current_membership = user.organization_memberships[0] if user.organization_memberships else None
        if not current_membership:
            return jsonify({'error': 'User is not a member of any organization'}), 400
        
        organization = current_membership.organization
        organization_id = organization.id
        
        # Count users by role using UserOrganization relationships
        from src.models.database_multi_org import UserOrganization
        
        total_users = db.session.query(User).join(UserOrganization).filter(
            UserOrganization.organization_id == organization_id,
            UserOrganization.is_active == True,
            User.is_active == True
        ).count()
        
        admin_users = db.session.query(User).join(UserOrganization).filter(
            UserOrganization.organization_id == organization_id,
            UserOrganization.role == 'ORG_ADMIN',
            UserOrganization.is_active == True,
            User.is_active == True
        ).count()
        
        regular_users = db.session.query(User).join(UserOrganization).filter(
            UserOrganization.organization_id == organization_id,
            UserOrganization.role == 'USER',
            UserOrganization.is_active == True,
            User.is_active == True
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


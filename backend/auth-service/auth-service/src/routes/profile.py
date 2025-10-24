from flask import Blueprint, request, jsonify
import jwt
from src.models.database_multi_org import db, User, UserOrganization
import os
from datetime import datetime, date
from sqlalchemy.exc import IntegrityError

profile_bp = Blueprint('profile', __name__)

def verify_token():
    """Verify JWT token and return user"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None
    
    token = auth_header.split(' ')[1]
    
    try:
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        
        user = User.query.get(payload['user_id'])
        if not user or not user.is_active:
            return None
            
        return user
    except jwt.InvalidTokenError:
        return None

@profile_bp.route('/me', methods=['GET'])
def get_profile():
    """Get current user's profile"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    organization_id = request.args.get('organization_id')
    if organization_id:
        # Check if user is member of the organization
        membership = UserOrganization.query.filter_by(
            user_id=user.id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not membership:
            return jsonify({'error': 'Access denied'}), 403
    
    # Include sensitive information only for the user themselves
    return jsonify(user.to_dict(include_organizations=True, include_sensitive=True))

@profile_bp.route('/me', methods=['PUT'])
def update_profile():
    """Update current user's profile"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    try:
        data = request.get_json()
        
        # Fields that can be updated
        updatable_fields = [
            'first_name', 'last_name', 'phone_number', 'bio', 'gender',
            'school_year', 'student_id', 'major', 'gpa', 'graduation_year',
            'address_line1', 'address_line2', 'city', 'state', 'postal_code', 'country',
            'emergency_contact_name', 'emergency_contact_phone', 'emergency_contact_relationship',
            'linkedin_url', 'github_url', 'personal_website',
            'timezone', 'language', 'notification_preferences'
        ]
        
        # Update only provided fields
        for field in updatable_fields:
            if field in data:
                if field == 'birthdate' and data[field]:
                    # Parse birthdate string to date object
                    try:
                        setattr(user, field, datetime.strptime(data[field], '%Y-%m-%d').date())
                    except ValueError:
                        return jsonify({'error': f'Invalid date format for {field}. Use YYYY-MM-DD'}), 400
                else:
                    setattr(user, field, data[field])
        
        # Handle birthdate separately
        if 'birthdate' in data and data['birthdate']:
            try:
                user.birthdate = datetime.strptime(data['birthdate'], '%Y-%m-%d').date()
            except ValueError:
                return jsonify({'error': 'Invalid date format for birthdate. Use YYYY-MM-DD'}), 400
        
        user.updated_at = datetime.utcnow()
        db.session.commit()
        
        return jsonify({
            'message': 'Profile updated successfully',
            'user': user.to_dict(include_organizations=True, include_sensitive=True)
        })
        
    except IntegrityError:
        db.session.rollback()
        return jsonify({'error': 'Failed to update profile. Please check your data.'}), 400
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': 'Failed to update profile'}), 500

@profile_bp.route('/users/<user_id>', methods=['GET'])
def get_user_profile(user_id):
    """Get another user's public profile"""
    current_user = verify_token()
    if not current_user:
        return jsonify({'error': 'Authentication required'}), 401
    
    organization_id = request.args.get('organization_id')
    if not organization_id:
        return jsonify({'error': 'Organization ID required'}), 400
    
    # Check if current user is member of the organization
    current_membership = UserOrganization.query.filter_by(
        user_id=current_user.id,
        organization_id=organization_id,
        is_active=True
    ).first()
    
    if not current_membership:
        return jsonify({'error': 'Access denied'}), 403
    
    # Get target user
    target_user = User.query.get(user_id)
    if not target_user or not target_user.is_active:
        return jsonify({'error': 'User not found'}), 404
    
    # Check if target user is also member of the organization
    target_membership = UserOrganization.query.filter_by(
        user_id=target_user.id,
        organization_id=organization_id,
        is_active=True
    ).first()
    
    if not target_membership:
        return jsonify({'error': 'User not found in this organization'}), 404
    
    # Return public profile (no sensitive information)
    return jsonify(target_user.to_dict(include_organizations=False, include_sensitive=False))

@profile_bp.route('/search', methods=['GET'])
def search_users():
    """Search users within an organization"""
    current_user = verify_token()
    if not current_user:
        return jsonify({'error': 'Authentication required'}), 401
    
    organization_id = request.args.get('organization_id')
    if not organization_id:
        return jsonify({'error': 'Organization ID required'}), 400
    
    # Check if current user is member of the organization
    membership = UserOrganization.query.filter_by(
        user_id=current_user.id,
        organization_id=organization_id,
        is_active=True
    ).first()
    
    if not membership:
        return jsonify({'error': 'Access denied'}), 403
    
    query = request.args.get('q', '').strip()
    school_year = request.args.get('school_year')
    major = request.args.get('major')
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    # Build search query
    user_query = User.query.join(UserOrganization).filter(
        UserOrganization.organization_id == organization_id,
        UserOrganization.is_active == True,
        User.is_active == True
    )
    
    if query:
        user_query = user_query.filter(
            db.or_(
                User.first_name.ilike(f'%{query}%'),
                User.last_name.ilike(f'%{query}%'),
                User.username.ilike(f'%{query}%'),
                User.email.ilike(f'%{query}%')
            )
        )
    
    if school_year:
        user_query = user_query.filter(User.school_year == school_year)
    
    if major:
        user_query = user_query.filter(User.major.ilike(f'%{major}%'))
    
    users = user_query.paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    return jsonify({
        'users': [user.to_dict(include_organizations=False, include_sensitive=False) for user in users.items],
        'pagination': {
            'page': users.page,
            'per_page': users.per_page,
            'total': users.total,
            'pages': users.pages,
            'has_next': users.has_next,
            'has_prev': users.has_prev
        }
    })

@profile_bp.route('/upload-picture', methods=['POST'])
def upload_profile_picture():
    """Upload profile picture (placeholder for file upload)"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    # This is a placeholder - you would integrate with a file storage service
    # like AWS S3, Google Cloud Storage, or local file storage
    
    return jsonify({'error': 'File upload not implemented yet'}), 501
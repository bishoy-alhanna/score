from flask import Blueprint, request, jsonify, current_app
import jwt
from werkzeug.security import generate_password_hash
from werkzeug.utils import secure_filename
from src.models.database import db, User, GroupMember
import os
import uuid
from datetime import datetime

users_bp = Blueprint('users', __name__)

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

@users_bp.route('/', methods=['GET'])
def get_users():
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

@users_bp.route('/<user_id>', methods=['GET'])
def get_user(user_id):
    """Get specific user details"""
    try:
        current_user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Get user in the same organization
        user = User.query.filter_by(
            id=user_id,
            organization_id=current_user.organization_id,
            is_active=True
        ).first()
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@users_bp.route('/<user_id>', methods=['PUT'])
def update_user(user_id):
    """Update user details"""
    try:
        current_user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Get user in the same organization
        user = User.query.filter_by(
            id=user_id,
            organization_id=current_user.organization_id,
            is_active=True
        ).first()
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Check permissions - users can update themselves, admins can update anyone
        if current_user.id != user.id and current_user.role != 'ORG_ADMIN':
            return jsonify({'error': 'Permission denied'}), 403
        
        data = request.get_json()
        
        # Update allowed fields
        if 'first_name' in data:
            user.first_name = data['first_name']
        if 'last_name' in data:
            user.last_name = data['last_name']
        if 'department' in data:
            user.department = data['department']
        if 'university_name' in data:
            user.university_name = data['university_name']
        if 'faculty_name' in data:
            user.faculty_name = data['faculty_name']
        
        # Only admins can update role and email
        if current_user.role == 'ORG_ADMIN':
            if 'role' in data and data['role'] in ['USER', 'ORG_ADMIN']:
                user.role = data['role']
            if 'email' in data:
                # Check if email is unique in organization
                existing_email = User.query.filter(
                    User.email == data['email'],
                    User.organization_id == user.organization_id,
                    User.id != user.id
                ).first()
                if existing_email:
                    return jsonify({'error': 'Email already exists in organization'}), 400
                user.email = data['email']
        
        db.session.commit()
        
        return jsonify({
            'message': 'User updated successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@users_bp.route('/<user_id>', methods=['DELETE'])
def deactivate_user(user_id):
    """Deactivate user (ORG_ADMIN only)"""
    try:
        current_user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        if current_user.role != 'ORG_ADMIN':
            return jsonify({'error': 'Only organization admins can deactivate users'}), 403
        
        # Get user in the same organization
        user = User.query.filter_by(
            id=user_id,
            organization_id=current_user.organization_id
        ).first()
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Don't allow deactivating yourself
        if current_user.id == user.id:
            return jsonify({'error': 'Cannot deactivate yourself'}), 400
        
        user.is_active = False
        db.session.commit()
        
        return jsonify({
            'message': 'User deactivated successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@users_bp.route('/<user_id>/groups', methods=['GET'])
def get_user_groups(user_id):
    """Get groups that user belongs to"""
    try:
        current_user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        # Get user in the same organization
        user = User.query.filter_by(
            id=user_id,
            organization_id=current_user.organization_id,
            is_active=True
        ).first()
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Get group memberships
        memberships = GroupMember.query.filter_by(
            user_id=user_id,
            organization_id=current_user.organization_id
        ).all()
        
        return jsonify({
            'user_id': user_id,
            'groups': [m.to_dict() for m in memberships]
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@users_bp.route('/search', methods=['GET'])
def search_users():
    """Search users by username or email"""
    try:
        current_user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        query = request.args.get('q', '').strip()
        if not query:
            return jsonify({'error': 'Search query required'}), 400
        
        # Search users in the same organization
        users = User.query.filter(
            User.organization_id == current_user.organization_id,
            User.is_active == True,
            db.or_(
                User.username.ilike(f'%{query}%'),
                User.email.ilike(f'%{query}%'),
                User.first_name.ilike(f'%{query}%'),
                User.last_name.ilike(f'%{query}%')
            )
        ).limit(20).all()
        
        return jsonify({
            'query': query,
            'users': [u.to_dict() for u in users]
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@users_bp.route('/profile', methods=['GET'])
def get_profile():
    """Get current user's profile"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        return jsonify({
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@users_bp.route('/profile', methods=['PUT'])
def update_profile():
    """Update current user's profile"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        data = request.get_json()
        
        # Basic Personal Information
        if 'first_name' in data:
            user.first_name = data['first_name']
        if 'last_name' in data:
            user.last_name = data['last_name']
        if 'birthdate' in data:
            user.birthdate = data['birthdate']
        if 'phone_number' in data:
            user.phone_number = data['phone_number']
        if 'bio' in data:
            user.bio = data['bio']
        if 'gender' in data:
            user.gender = data['gender']
        if 'profile_picture_url' in data:
            user.profile_picture_url = data['profile_picture_url']
        
        # Academic Information
        if 'university_name' in data:
            user.university_name = data['university_name']
        if 'faculty_name' in data:
            user.faculty_name = data['faculty_name']
        if 'school_year' in data:
            user.school_year = data['school_year']
        if 'student_id' in data:
            user.student_id = data['student_id']
        if 'major' in data:
            user.major = data['major']
        if 'gpa' in data:
            # Validate GPA range
            try:
                gpa_value = float(data['gpa'])
                if 0.0 <= gpa_value <= 4.0:
                    user.gpa = gpa_value
            except (ValueError, TypeError):
                pass  # Invalid GPA, skip
        if 'graduation_year' in data:
            user.graduation_year = data['graduation_year']
        
        # Contact Information
        if 'address_line1' in data:
            user.address_line1 = data['address_line1']
        if 'address_line2' in data:
            user.address_line2 = data['address_line2']
        if 'city' in data:
            user.city = data['city']
        if 'state' in data:
            user.state = data['state']
        if 'postal_code' in data:
            user.postal_code = data['postal_code']
        if 'country' in data:
            user.country = data['country']
        
        # Emergency Contact Information
        if 'emergency_contact_name' in data:
            user.emergency_contact_name = data['emergency_contact_name']
        if 'emergency_contact_phone' in data:
            user.emergency_contact_phone = data['emergency_contact_phone']
        if 'emergency_contact_relationship' in data:
            user.emergency_contact_relationship = data['emergency_contact_relationship']
        
        # Social Media & Links
        if 'linkedin_url' in data:
            user.linkedin_url = data['linkedin_url']
        if 'github_url' in data:
            user.github_url = data['github_url']
        if 'personal_website' in data:
            user.personal_website = data['personal_website']
        
        # User Preferences
        if 'timezone' in data:
            user.timezone = data['timezone']
        if 'language' in data:
            user.language = data['language']
        if 'notification_preferences' in data:
            user.notification_preferences = data['notification_preferences']
        
        db.session.commit()
        
        return jsonify({
            'message': 'Profile updated successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@users_bp.route('/profile/upload-picture', methods=['POST'])
def upload_profile_picture():
    """Upload and update user profile picture"""
    try:
        user, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Validate file type
        allowed_extensions = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
        filename = file.filename.lower()
        if not any(filename.endswith('.' + ext) for ext in allowed_extensions):
            return jsonify({'error': 'Invalid file type. Allowed: png, jpg, jpeg, gif, webp'}), 400
        
        # Create secure filename with UUID to avoid collisions
        file_extension = filename.rsplit('.', 1)[1]
        unique_filename = f"{uuid.uuid4().hex}_{secure_filename(filename)}"
        
        # Create upload directory if it doesn't exist
        upload_dir = os.path.join(os.getcwd(), 'uploads', 'profile_pictures')
        os.makedirs(upload_dir, exist_ok=True)
        
        # Save file
        file_path = os.path.join(upload_dir, unique_filename)
        file.save(file_path)
        
        # Update user's profile picture URL
        user.profile_picture_url = f"/uploads/profile_pictures/{unique_filename}"
        db.session.commit()
        
        return jsonify({
            'message': 'Profile picture uploaded successfully',
            'profile_picture_url': user.profile_picture_url
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


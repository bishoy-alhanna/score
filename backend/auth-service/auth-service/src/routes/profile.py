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
            'timezone', 'language', 'notification_preferences', 'profile_picture_url'
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
    """Upload profile picture"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    print(f"DEBUG: request.files keys: {list(request.files.keys())}")
    print(f"DEBUG: request.form keys: {list(request.form.keys())}")
    print(f"DEBUG: request content type: {request.content_type}")
    
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    # Validate file type
    allowed_extensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'}
    if not file.filename.lower().split('.')[-1] in allowed_extensions:
        return jsonify({'error': 'Invalid file type. Allowed: jpg, jpeg, png, gif, webp'}), 400
    
    # Validate file size (max 5MB)
    file.seek(0, 2)  # Seek to end of file
    file_size = file.tell()
    file.seek(0)  # Reset file pointer
    
    if file_size > 5 * 1024 * 1024:  # 5MB
        return jsonify({'error': 'File too large. Maximum size is 5MB'}), 400
    
    try:
        from PIL import Image
        import uuid
        import os
        
        # Create uploads directory if it doesn't exist
        uploads_dir = '/app/uploads/profile_pictures'
        os.makedirs(uploads_dir, exist_ok=True)
        
        # Generate unique filename
        file_extension = file.filename.lower().split('.')[-1]
        filename = f"{user.id}_{uuid.uuid4().hex}.{file_extension}"
        file_path = os.path.join(uploads_dir, filename)
        
        # Open and process the image
        image = Image.open(file.stream)
        
        # Convert to RGB if necessary (for JPEG)
        if image.mode in ('RGBA', 'P'):
            image = image.convert('RGB')
        
        # Resize image to max 512x512 while maintaining aspect ratio
        image.thumbnail((512, 512), Image.Resampling.LANCZOS)
        
        # Save the processed image
        image.save(file_path, optimize=True, quality=85)
        
        # Update user's profile picture URL
        profile_picture_url = f'/uploads/profile_pictures/{filename}'
        user.profile_picture_url = profile_picture_url
        user.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            'message': 'Profile picture uploaded successfully',
            'profile_picture_url': profile_picture_url
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error uploading profile picture: {str(e)}")
        return jsonify({'error': 'Failed to process image'}), 500

@profile_bp.route('/picture/<filename>', methods=['GET'])
def serve_profile_picture(filename):
    """Serve profile picture files"""
    try:
        from flask import send_from_directory
        import os
        
        uploads_dir = '/app/uploads/profile_pictures'
        return send_from_directory(uploads_dir, filename)
    except Exception as e:
        return jsonify({'error': 'Image not found'}), 404

@profile_bp.route('/organization-users', methods=['GET'])
def get_organization_users():
    """Get all users in organization (admin only)"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    organization_id = request.args.get('organization_id')
    if not organization_id:
        return jsonify({'error': 'Organization ID is required'}), 400
    
    # Check if user is admin of the organization
    membership = UserOrganization.query.filter_by(
        user_id=user.id,
        organization_id=organization_id,
        is_active=True
    ).first()
    
    if not membership or membership.role != 'ORG_ADMIN':
        return jsonify({'error': 'Admin access required'}), 403
    
    try:
        # Get pagination parameters
        page = int(request.args.get('page', 1))
        per_page = min(int(request.args.get('per_page', 50)), 100)  # Max 100 users per page
        search = request.args.get('search', '').strip()
        
        # Build query for users in the organization
        users_query = db.session.query(User).join(UserOrganization).filter(
            UserOrganization.organization_id == organization_id,
            UserOrganization.is_active == True,
            User.is_active == True
        )
        
        # Apply search filter if provided
        if search:
            users_query = users_query.filter(
                db.or_(
                    User.first_name.ilike(f'%{search}%'),
                    User.last_name.ilike(f'%{search}%'),
                    User.username.ilike(f'%{search}%'),
                    User.email.ilike(f'%{search}%')
                )
            )
        
        # Get paginated results
        users_pagination = users_query.paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        # Format user data with ALL profile information
        users_data = []
        for user_obj in users_pagination.items:
            user_membership = UserOrganization.query.filter_by(
                user_id=user_obj.id,
                organization_id=organization_id
            ).first()
            
            # Create comprehensive user data dictionary with all available fields
            user_data = {
                'id': str(user_obj.id),
                'username': user_obj.username,
                'email': user_obj.email,
                'first_name': user_obj.first_name,
                'last_name': user_obj.last_name,
                'profile_picture_url': user_obj.profile_picture_url,
                'is_active': user_obj.is_active,
                'created_at': user_obj.created_at.isoformat() if user_obj.created_at else None,
                'updated_at': user_obj.updated_at.isoformat() if user_obj.updated_at else None,
                'birthdate': user_obj.birthdate.isoformat() if user_obj.birthdate else None,
                'phone_number': user_obj.phone_number,
                'bio': user_obj.bio,
                'gender': user_obj.gender,
                'school_year': user_obj.school_year,
                'student_id': user_obj.student_id,
                'major': user_obj.major,
                'gpa': user_obj.gpa,
                'graduation_year': user_obj.graduation_year,
                # Address information
                'address_line1': user_obj.address_line1,
                'address_line2': user_obj.address_line2,
                'city': user_obj.city,
                'state': user_obj.state,
                'postal_code': user_obj.postal_code,
                'country': user_obj.country,
                # Emergency contact
                'emergency_contact_name': user_obj.emergency_contact_name,
                'emergency_contact_phone': user_obj.emergency_contact_phone,
                'emergency_contact_relationship': user_obj.emergency_contact_relationship,
                # Social links
                'linkedin_url': user_obj.linkedin_url,
                'github_url': user_obj.github_url,
                'personal_website': user_obj.personal_website,
                # System settings
                'timezone': user_obj.timezone,
                'language': user_obj.language,
                'notification_preferences': user_obj.notification_preferences,
                'is_verified': user_obj.is_verified,
                'email_verified_at': user_obj.email_verified_at.isoformat() if user_obj.email_verified_at else None,
                'last_login_at': user_obj.last_login_at.isoformat() if user_obj.last_login_at else None,
                'has_qr_code': bool(user_obj.qr_code_token),
                # Organization-specific data
                'role': user_membership.role if user_membership else 'USER',
                'department': user_membership.department if user_membership else None,
                'title': user_membership.title if user_membership else None,
                'joined_at': user_membership.joined_at.isoformat() if user_membership and user_membership.joined_at else None,
            }
            
            users_data.append(user_data)
        
        return jsonify({
            'users': users_data,
            'pagination': {
                'page': users_pagination.page,
                'per_page': users_pagination.per_page,
                'total': users_pagination.total,
                'pages': users_pagination.pages,
                'has_next': users_pagination.has_next,
                'has_prev': users_pagination.has_prev
            }
        })
        
    except Exception as e:
        print(f"Error fetching organization users: {str(e)}")
        return jsonify({'error': 'Failed to fetch users'}), 500
from flask import Blueprint, request, jsonify
import jwt
from src.models.database_multi_org import db, User, Family, UserOrganization
import os
from datetime import datetime
from sqlalchemy.exc import IntegrityError
from sqlalchemy import or_

family_bp = Blueprint('family', __name__)

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

def get_user_organization_role(user_id, organization_id):
    """Get user's role in organization"""
    membership = UserOrganization.query.filter_by(
        user_id=user_id,
        organization_id=organization_id,
        is_active=True
    ).first()
    return membership.role if membership else None

@family_bp.route('', methods=['POST'])
def create_family():
    """Create a new family"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    try:
        data = request.get_json()
        
        organization_id = data.get('organization_id')
        if not organization_id:
            return jsonify({'error': 'Organization ID is required'}), 400
        
        # Check if user has permission in this organization
        role = get_user_organization_role(user.id, organization_id)
        if not role or role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Admin access required'}), 403
        
        # Validate required fields
        family_name = data.get('family_name')
        if not family_name:
            return jsonify({'error': 'Family name is required'}), 400
        
        # Create new family
        new_family = Family(
            family_name=family_name,
            head_of_family_id=data.get('head_of_family_id'),
            contact_info=data.get('contact_info'),
            organization_id=organization_id
        )
        
        db.session.add(new_family)
        db.session.commit()
        
        return jsonify({
            'message': 'Family created successfully',
            'family': new_family.to_dict()
        }), 201
        
    except IntegrityError as e:
        db.session.rollback()
        return jsonify({'error': 'Failed to create family. Please check your data.'}), 400
    except Exception as e:
        db.session.rollback()
        print(f"Error creating family: {str(e)}")
        return jsonify({'error': 'Failed to create family'}), 500

@family_bp.route('', methods=['GET'])
def list_families():
    """List all families in an organization"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    organization_id = request.args.get('organization_id')
    if not organization_id:
        return jsonify({'error': 'Organization ID is required'}), 400
    
    # Check if user is member of the organization
    role = get_user_organization_role(user.id, organization_id)
    if not role:
        return jsonify({'error': 'Access denied'}), 403
    
    try:
        # Get pagination parameters
        page = int(request.args.get('page', 1))
        per_page = min(int(request.args.get('per_page', 20)), 100)
        search = request.args.get('search', '').strip()
        include_members = request.args.get('include_members', 'false').lower() == 'true'
        
        # Build query
        families_query = Family.query.filter_by(
            organization_id=organization_id,
            is_active=True
        )
        
        # Apply search filter if provided
        if search:
            families_query = families_query.filter(
                Family.family_name.ilike(f'%{search}%')
            )
        
        # Get paginated results
        families_pagination = families_query.paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        return jsonify({
            'families': [family.to_dict(include_members=include_members) for family in families_pagination.items],
            'pagination': {
                'page': families_pagination.page,
                'per_page': families_pagination.per_page,
                'total': families_pagination.total,
                'pages': families_pagination.pages,
                'has_next': families_pagination.has_next,
                'has_prev': families_pagination.has_prev
            }
        })
        
    except Exception as e:
        print(f"Error listing families: {str(e)}")
        return jsonify({'error': 'Failed to fetch families'}), 500

@family_bp.route('/<family_id>', methods=['GET'])
def get_family(family_id):
    """Get family details"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    organization_id = request.args.get('organization_id')
    if not organization_id:
        return jsonify({'error': 'Organization ID is required'}), 400
    
    # Check if user is member of the organization
    role = get_user_organization_role(user.id, organization_id)
    if not role:
        return jsonify({'error': 'Access denied'}), 403
    
    try:
        family = Family.query.filter_by(
            id=family_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not family:
            return jsonify({'error': 'Family not found'}), 404
        
        include_members = request.args.get('include_members', 'true').lower() == 'true'
        return jsonify(family.to_dict(include_members=include_members))
        
    except Exception as e:
        print(f"Error fetching family: {str(e)}")
        return jsonify({'error': 'Failed to fetch family'}), 500

@family_bp.route('/<family_id>', methods=['PUT'])
def update_family(family_id):
    """Update family details"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    try:
        data = request.get_json()
        
        organization_id = data.get('organization_id')
        if not organization_id:
            return jsonify({'error': 'Organization ID is required'}), 400
        
        # Check if user has admin permission
        role = get_user_organization_role(user.id, organization_id)
        if not role or role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Admin access required'}), 403
        
        # Get family
        family = Family.query.filter_by(
            id=family_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not family:
            return jsonify({'error': 'Family not found'}), 404
        
        # Update fields
        if 'family_name' in data:
            family.family_name = data['family_name']
        if 'head_of_family_id' in data:
            family.head_of_family_id = data['head_of_family_id']
        if 'contact_info' in data:
            family.contact_info = data['contact_info']
        
        family.updated_at = datetime.utcnow()
        db.session.commit()
        
        return jsonify({
            'message': 'Family updated successfully',
            'family': family.to_dict(include_members=True)
        })
        
    except IntegrityError:
        db.session.rollback()
        return jsonify({'error': 'Failed to update family. Please check your data.'}), 400
    except Exception as e:
        db.session.rollback()
        print(f"Error updating family: {str(e)}")
        return jsonify({'error': 'Failed to update family'}), 500

@family_bp.route('/<family_id>', methods=['DELETE'])
def delete_family(family_id):
    """Soft delete a family"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    organization_id = request.args.get('organization_id')
    if not organization_id:
        return jsonify({'error': 'Organization ID is required'}), 400
    
    # Check if user has admin permission
    role = get_user_organization_role(user.id, organization_id)
    if not role or role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
        return jsonify({'error': 'Admin access required'}), 403
    
    try:
        family = Family.query.filter_by(
            id=family_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not family:
            return jsonify({'error': 'Family not found'}), 404
        
        # Soft delete: mark as inactive
        family.is_active = False
        family.updated_at = datetime.utcnow()
        
        # Optionally: Remove family_id from all members
        for member in family.members:
            member.family_id = None
        
        db.session.commit()
        
        return jsonify({'message': 'Family deleted successfully'})
        
    except Exception as e:
        db.session.rollback()
        print(f"Error deleting family: {str(e)}")
        return jsonify({'error': 'Failed to delete family'}), 500

@family_bp.route('/<family_id>/members', methods=['POST'])
def add_family_member(family_id):
    """Add a member to a family - creates new user or links existing user by national_id"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    try:
        data = request.get_json()
        
        organization_id = data.get('organization_id')
        if not organization_id:
            return jsonify({'error': 'Organization ID is required'}), 400
        
        # Check if user has admin permission
        role = get_user_organization_role(user.id, organization_id)
        if not role or role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Admin access required'}), 403
        
        # Get family
        family = Family.query.filter_by(
            id=family_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not family:
            return jsonify({'error': 'Family not found'}), 404
        
        national_id = data.get('national_id')
        existing_user = None
        
        # Check if national_id exists
        if national_id:
            existing_user = User.query.filter_by(
                national_id=national_id,
                is_active=True
            ).first()
        
        if existing_user:
            # Link existing user to family
            existing_user.family_id = family_id
            existing_user.updated_at = datetime.utcnow()
            
            # Check if user is member of this organization, if not add them
            membership = UserOrganization.query.filter_by(
                user_id=existing_user.id,
                organization_id=organization_id
            ).first()
            
            if not membership:
                new_membership = UserOrganization(
                    user_id=existing_user.id,
                    organization_id=organization_id,
                    role='USER'
                )
                db.session.add(new_membership)
            elif not membership.is_active:
                membership.is_active = True
            
            db.session.commit()
            
            return jsonify({
                'message': 'Existing member linked to family successfully',
                'member': existing_user.to_dict(),
                'linked_existing': True
            })
        else:
            # Create new user
            from werkzeug.security import generate_password_hash
            import secrets
            
            # Generate temporary username and password
            username = data.get('username')
            if not username:
                # Generate username from name or national_id
                if data.get('first_name') and data.get('last_name'):
                    username = f"{data.get('first_name').lower()}.{data.get('last_name').lower()}"
                elif national_id:
                    username = f"user_{national_id}"
                else:
                    username = f"user_{secrets.token_hex(4)}"
            
            email = data.get('email')
            if not email:
                # Generate temporary email if not provided
                email = f"{username}@temp.local"
            
            # Generate temporary password
            temp_password = secrets.token_urlsafe(12)
            
            new_user = User(
                username=username,
                email=email,
                password_hash=generate_password_hash(temp_password),
                first_name=data.get('first_name'),
                last_name=data.get('last_name'),
                national_id=national_id,
                gender=data.get('gender'),
                birthdate=datetime.strptime(data.get('birthdate'), '%Y-%m-%d').date() if data.get('birthdate') else None,
                phone_number=data.get('phone_number'),
                church_role=data.get('church_role'),
                family_id=family_id
            )
            
            db.session.add(new_user)
            db.session.flush()  # Get the user ID
            
            # Add user to organization
            new_membership = UserOrganization(
                user_id=new_user.id,
                organization_id=organization_id,
                role='USER'
            )
            db.session.add(new_membership)
            
            db.session.commit()
            
            return jsonify({
                'message': 'New family member created successfully',
                'member': new_user.to_dict(),
                'linked_existing': False,
                # NOTE: Temporary password should be securely delivered to the user
                # Consider sending via email or secure channel instead of returning in response
                'temporary_password': temp_password
            }), 201
            
    except IntegrityError as e:
        db.session.rollback()
        print(f"IntegrityError adding family member: {str(e)}")
        return jsonify({'error': 'Failed to add family member. User with this username or email may already exist.'}), 400
    except Exception as e:
        db.session.rollback()
        print(f"Error adding family member: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': 'Failed to add family member'}), 500

@family_bp.route('/<family_id>/members/<member_id>', methods=['DELETE'])
def remove_family_member(family_id, member_id):
    """Remove a member from a family (unlink only, doesn't delete user)"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    organization_id = request.args.get('organization_id')
    if not organization_id:
        return jsonify({'error': 'Organization ID is required'}), 400
    
    # Check if user has admin permission
    role = get_user_organization_role(user.id, organization_id)
    if not role or role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
        return jsonify({'error': 'Admin access required'}), 403
    
    try:
        # Get family
        family = Family.query.filter_by(
            id=family_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not family:
            return jsonify({'error': 'Family not found'}), 404
        
        # Get member
        member = User.query.filter_by(
            id=member_id,
            family_id=family_id,
            is_active=True
        ).first()
        
        if not member:
            return jsonify({'error': 'Member not found in this family'}), 404
        
        # Remove family link
        member.family_id = None
        member.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({'message': 'Member removed from family successfully'})
        
    except Exception as e:
        db.session.rollback()
        print(f"Error removing family member: {str(e)}")
        return jsonify({'error': 'Failed to remove family member'}), 500

@family_bp.route('/search-by-national-id', methods=['GET'])
def search_by_national_id():
    """Search for a user by national_id"""
    user = verify_token()
    if not user:
        return jsonify({'error': 'Authentication required'}), 401
    
    national_id = request.args.get('national_id')
    organization_id = request.args.get('organization_id')
    
    if not national_id:
        return jsonify({'error': 'National ID is required'}), 400
    
    if not organization_id:
        return jsonify({'error': 'Organization ID is required'}), 400
    
    # Check if user has permission in this organization
    role = get_user_organization_role(user.id, organization_id)
    if not role or role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
        return jsonify({'error': 'Admin access required'}), 403
    
    try:
        # Search for user by national_id
        existing_user = User.query.filter_by(
            national_id=national_id,
            is_active=True
        ).first()
        
        if not existing_user:
            return jsonify({
                'found': False,
                'message': 'No user found with this national ID'
            })
        
        # Check if user already has a family
        has_family = existing_user.family_id is not None
        
        return jsonify({
            'found': True,
            'user': existing_user.to_dict(),
            'has_family': has_family,
            'family_id': str(existing_user.family_id) if existing_user.family_id else None
        })
        
    except Exception as e:
        print(f"Error searching by national ID: {str(e)}")
        return jsonify({'error': 'Failed to search by national ID'}), 500

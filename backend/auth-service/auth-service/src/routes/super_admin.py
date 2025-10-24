from flask import Blueprint, request, jsonify
import jwt
from sqlalchemy.orm import joinedload
from src.models.database_multi_org import (
    db, User, Organization, UserOrganization, 
    OrganizationJoinRequest, SuperAdminConfig
)
import os
import uuid
from datetime import datetime
import bcrypt

super_admin_bp = Blueprint('super_admin', __name__)

def safe_serialize(obj):
    """Safely serialize objects that might contain UUIDs or datetimes"""
    if isinstance(obj, uuid.UUID):
        return str(obj)
    elif isinstance(obj, (datetime,)):
        return obj.isoformat()
    elif isinstance(obj, dict):
        return {k: safe_serialize(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [safe_serialize(item) for item in obj]
    else:
        return obj

def safe_jsonify(data):
    """Safe jsonify that handles UUIDs and datetimes"""
    serialized_data = safe_serialize(data)
    return jsonify(serialized_data)

def verify_super_admin_token():
    """Verify super admin token and return admin user"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None
    
    token = auth_header.split(' ')[1]
    
    try:
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        
        # Check if it's a super admin token
        if payload.get('type') != 'super_admin':
            return None
            
        admin = SuperAdminConfig.query.get(payload['admin_id'])
        if not admin or not admin.is_active:
            return None
            
        return admin
    except jwt.InvalidTokenError:
        return None

@super_admin_bp.route('/login', methods=['POST'])
def super_admin_login():
    """Super admin login"""
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return jsonify({'error': 'Username and password are required'}), 400
        
        # Find super admin
        admin = SuperAdminConfig.query.filter_by(username=username).first()
        if not admin:
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Verify password
        if not bcrypt.checkpw(password.encode('utf-8'), admin.password_hash.encode('utf-8')):
            return jsonify({'error': 'Invalid credentials'}), 401
            
        if not admin.is_active:
            return jsonify({'error': 'Account is deactivated'}), 401
        
        # Generate super admin JWT token
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        payload = {
            'admin_id': str(admin.id),
            'username': admin.username,
            'type': 'super_admin',
            'exp': datetime.utcnow().timestamp() + (24 * 60 * 60)  # 24 hours
        }
        token = jwt.encode(payload, secret_key, algorithm='HS256')
        
        return safe_jsonify({
            'message': 'Super admin login successful',
            'token': token,
            'admin': admin.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/dashboard', methods=['GET'])
def super_admin_dashboard():
    """Get super admin dashboard data"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        # Get platform statistics
        total_users = User.query.count()
        total_organizations = Organization.query.count()
        active_organizations = Organization.query.filter_by(is_active=True).count()
        pending_requests = OrganizationJoinRequest.query.filter_by(status='PENDING').count()
        
        # Get recent organizations
        recent_orgs = Organization.query.order_by(Organization.created_at.desc()).limit(5).all()
        
        # Get recent users
        recent_users = User.query.order_by(User.created_at.desc()).limit(5).all()
        
        return safe_jsonify({
            'stats': {
                'total_users': total_users,
                'total_organizations': total_organizations,
                'active_organizations': active_organizations,
                'pending_requests': pending_requests
            },
            'recent_organizations': [org.to_dict() for org in recent_orgs],
            'recent_users': [user.to_dict() for user in recent_users]
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/organizations', methods=['GET'])
def get_all_organizations():
    """Get all organizations"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        
        organizations = Organization.query.order_by(Organization.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        org_list = []
        for org in organizations.items:
            org_dict = org.to_dict()
            # Add member count
            org_dict['member_count'] = UserOrganization.query.filter_by(organization_id=org.id).count()
            org_list.append(org_dict)
        
        return safe_jsonify({
            'organizations': org_list,
            'pagination': {
                'page': organizations.page,
                'pages': organizations.pages,
                'per_page': organizations.per_page,
                'total': organizations.total,
                'has_next': organizations.has_next,
                'has_prev': organizations.has_prev
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/organizations', methods=['POST'])
def create_organization():
    """Create a new organization"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('name'):
            return jsonify({'error': 'Organization name is required'}), 400
        
        if not data.get('admin_email'):
            return jsonify({'error': 'Admin email is required'}), 400
        
        # Check if organization with this name already exists
        existing_org = Organization.query.filter_by(name=data['name']).first()
        if existing_org:
            return jsonify({'error': 'Organization with this name already exists'}), 400
        
        # Create organization
        organization = Organization(
            id=str(uuid.uuid4()),
            name=data['name'],
            description=data.get('description', ''),
            is_active=True,
            created_at=datetime.utcnow()
        )
        
        db.session.add(organization)
        db.session.flush()  # To get the organization ID
        
        # Create or get admin user
        admin_user = User.query.filter_by(email=data['admin_email']).first()
        if not admin_user:
            # Create new admin user
            admin_user = User(
                id=str(uuid.uuid4()),
                username=data.get('admin_username', data['admin_email'].split('@')[0]),
                email=data['admin_email'],
                first_name=data.get('admin_first_name', ''),
                last_name=data.get('admin_last_name', ''),
                password_hash=User.hash_password(data.get('admin_password', 'DefaultPassword123!')),
                is_active=True,
                created_at=datetime.utcnow()
            )
            db.session.add(admin_user)
            db.session.flush()
        
        # Add admin to organization
        user_org = UserOrganization(
            user_id=admin_user.id,
            organization_id=organization.id,
            role='ORG_ADMIN',
            joined_at=datetime.utcnow()
        )
        db.session.add(user_org)
        
        db.session.commit()
        
        return safe_jsonify({
            'message': 'Organization created successfully',
            'organization': organization.to_dict(),
            'admin_user': admin_user.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/debug-test', methods=['GET'])
def debug_test():
    """Simple debug test route"""
    return jsonify({'message': 'Debug test works!', 'timestamp': str(datetime.now())}), 200

@super_admin_bp.route('/organizations/<organization_id>/details', methods=['GET'])
def get_organization_details(organization_id):
    """Get detailed organization information with members"""
    print(f"DEBUG: Details endpoint hit with organization_id: {organization_id}")
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        # Debug logging
        print(f"DEBUG: Looking for organization with ID: {organization_id}")
        
        # Try to find organization by ID (handles both UUID and string)
        organization = Organization.query.filter_by(id=organization_id).first()
        if not organization:
            print(f"DEBUG: Organization not found with ID: {organization_id}")
            return jsonify({'error': 'Organization not found'}), 404
        
        print(f"DEBUG: Found organization: {organization.name}")
        
        # Get organization members with their roles
        members = db.session.query(
            User.id,
            User.username,
            User.email,
            User.first_name,
            User.last_name,
            User.is_active,
            UserOrganization.role,
            UserOrganization.joined_at
        ).join(
            UserOrganization, User.id == UserOrganization.user_id
        ).filter(
            UserOrganization.organization_id == organization_id
        ).all()
        
        members_list = []
        for member in members:
            members_list.append({
                'id': str(member.id),
                'username': member.username,
                'email': member.email,
                'first_name': member.first_name,
                'last_name': member.last_name,
                'is_active': member.is_active,
                'role': member.role,
                'joined_at': member.joined_at.isoformat() if member.joined_at else None
            })
        
        org_dict = organization.to_dict()
        org_dict['members'] = members_list
        org_dict['member_count'] = len(members_list)
        
        return safe_jsonify({
            'organization': org_dict
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/organizations/<organization_id>/toggle-status', methods=['POST'])
def toggle_organization_status(organization_id):
    """Toggle organization active status"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        organization = Organization.query.get(organization_id)
        if not organization:
            return jsonify({'error': 'Organization not found'}), 404
        
        organization.is_active = not organization.is_active
        organization.updated_at = datetime.utcnow()
        db.session.commit()
        
        return safe_jsonify({
            'message': f'Organization {"activated" if organization.is_active else "deactivated"} successfully',
            'organization': organization.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/users', methods=['GET'])
def get_all_users():
    """Get all users for super admin"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        
        users = User.query.paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        user_list = []
        for user in users.items:
            user_dict = user.to_dict(include_organizations=True)
            user_list.append(user_dict)
        
        return safe_jsonify({
            'users': user_list,
            'pagination': {
                'page': users.page,
                'pages': users.pages,
                'per_page': users.per_page,
                'total': users.total,
                'has_next': users.has_next,
                'has_prev': users.has_prev
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/users/<user_id>/toggle-status', methods=['POST'])
def toggle_user_status(user_id):
    """Toggle user active status"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        user.is_active = not user.is_active
        user.updated_at = datetime.utcnow()
        db.session.commit()
        
        return safe_jsonify({
            'message': f'User {"activated" if user.is_active else "deactivated"} successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/users/<user_id>', methods=['PUT'])
def update_user(user_id):
    """Update user information"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        
        # Update allowed fields
        if 'is_active' in data:
            user.is_active = data['is_active']
        
        if 'first_name' in data:
            user.first_name = data['first_name']
        
        if 'last_name' in data:
            user.last_name = data['last_name']
        
        if 'email' in data:
            # Check if email is already taken by another user
            existing_user = User.query.filter(
                User.email == data['email'],
                User.id != user_id
            ).first()
            if existing_user:
                return jsonify({'error': 'Email already taken'}), 400
            user.email = data['email']
        
        if 'username' in data:
            # Check if username is already taken by another user
            existing_user = User.query.filter(
                User.username == data['username'],
                User.id != user_id
            ).first()
            if existing_user:
                return jsonify({'error': 'Username already taken'}), 400
            user.username = data['username']
        
        user.updated_at = datetime.utcnow()
        db.session.commit()
        
        return safe_jsonify({
            'message': 'User updated successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/join-requests', methods=['GET'])
def get_all_join_requests():
    """Get all organization join requests"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        status = request.args.get('status', 'PENDING')
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        
        query = OrganizationJoinRequest.query.options(
            db.joinedload(OrganizationJoinRequest.requesting_user),
            db.joinedload(OrganizationJoinRequest.organization_for_join_request),
            db.joinedload(OrganizationJoinRequest.reviewer)
        )
        if status:
            query = query.filter(OrganizationJoinRequest.status == status)
        
        requests = query.order_by(OrganizationJoinRequest.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        request_list = []
        for req in requests.items:
            request_list.append(req.to_dict())
        
        return safe_jsonify({
            'requests': request_list,
            'pagination': {
                'page': requests.page,
                'pages': requests.pages,
                'per_page': requests.per_page,
                'total': requests.total,
                'has_next': requests.has_next,
                'has_prev': requests.has_prev
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@super_admin_bp.route('/join-requests/<request_id>/approve', methods=['POST'])
def super_admin_approve_join_request(request_id):
    """Approve a join request (super admin)"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        join_request = OrganizationJoinRequest.query.get(request_id)
        if not join_request:
            return jsonify({'error': 'Join request not found'}), 404
        
        if join_request.status != 'PENDING':
            return jsonify({'error': 'Join request is not pending'}), 400
        
        # Get the user and organization
        user = User.query.get(join_request.user_id)
        organization = Organization.query.get(join_request.organization_id)
        
        if not user or not organization:
            return jsonify({'error': 'User or organization not found'}), 404
        
        # Check if user already has membership (avoid duplicate)
        existing_membership = UserOrganization.query.filter_by(
            user_id=user.id,
            organization_id=organization.id
        ).first()
        
        if existing_membership:
            return jsonify({'error': 'User is already a member of this organization'}), 400
        
        # Update request status
        join_request.status = 'APPROVED'
        join_request.reviewed_at = datetime.utcnow()
        join_request.reviewed_by = None  # Super admin review, not a regular user
        join_request.review_message = f'Approved by Super Admin: {admin.username}'
        
        # Add user to organization
        user_org = UserOrganization(
            user_id=user.id,
            organization_id=organization.id,
            role='USER',  # Changed from 'MEMBER' to 'USER' to match schema
            joined_at=datetime.utcnow()
        )
        
        db.session.add(user_org)
        db.session.commit()
        
        return safe_jsonify({
            'message': 'Join request approved successfully',
            'request': join_request.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@super_admin_bp.route('/join-requests/<request_id>/reject', methods=['POST'])
def super_admin_reject_join_request(request_id):
    """Reject a join request (super admin)"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        data = request.get_json() or {}
        rejection_reason = data.get('reason', '')
        
        join_request = OrganizationJoinRequest.query.get(request_id)
        if not join_request:
            return jsonify({'error': 'Join request not found'}), 404
        
        if join_request.status != 'PENDING':
            return jsonify({'error': 'Join request is not pending'}), 400
        
        # Update request status
        join_request.status = 'REJECTED'
        join_request.reviewed_at = datetime.utcnow()
        join_request.reviewed_by = None  # Super admin review, not a regular user
        join_request.review_message = f'Rejected by Super Admin: {admin.username}. Reason: {rejection_reason}' if rejection_reason else f'Rejected by Super Admin: {admin.username}'
        join_request.rejection_reason = rejection_reason
        
        db.session.commit()
        
        return safe_jsonify({
            'message': 'Join request rejected',
            'request': join_request.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/test-route', methods=['GET'])
def test_route():
    """Test route to check if routes are working"""
    return jsonify({'message': 'Test route works!'}), 200

@super_admin_bp.route('/organizations/<organization_id>/members', methods=['POST'])
def add_organization_member(organization_id):
    """Add a user to an organization"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        role = data.get('role', 'USER')
        
        if not user_id:
            return jsonify({'error': 'User ID is required'}), 400
        
        organization = Organization.query.get(organization_id)
        if not organization:
            return jsonify({'error': 'Organization not found'}), 404
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Check if user is already a member
        existing_membership = UserOrganization.query.filter_by(
            user_id=user_id,
            organization_id=organization_id
        ).first()
        
        if existing_membership:
            return jsonify({'error': 'User is already a member of this organization'}), 400
        
        # Add user to organization
        user_org = UserOrganization(
            user_id=user_id,
            organization_id=organization_id,
            role=role,
            joined_at=datetime.utcnow()
        )
        
        db.session.add(user_org)
        db.session.commit()
        
        return safe_jsonify({
            'message': 'User added to organization successfully',
            'membership': {
                'user_id': str(user_id),
                'organization_id': str(organization_id),
                'role': role,
                'joined_at': user_org.joined_at.isoformat()
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/organizations/<organization_id>/members/<user_id>', methods=['DELETE'])
def remove_organization_member(organization_id, user_id):
    """Remove a user from an organization"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        organization = Organization.query.get(organization_id)
        if not organization:
            return jsonify({'error': 'Organization not found'}), 404
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Find the membership
        membership = UserOrganization.query.filter_by(
            user_id=user_id,
            organization_id=organization_id
        ).first()
        
        if not membership:
            return jsonify({'error': 'User is not a member of this organization'}), 404
        
        # Remove membership
        db.session.delete(membership)
        db.session.commit()
        
        return safe_jsonify({
            'message': 'User removed from organization successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/organizations/<organization_id>/members/<user_id>/role', methods=['PUT'])
def update_member_role(organization_id, user_id):
    """Update a member's role in an organization"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        data = request.get_json()
        new_role = data.get('role')
        
        if not new_role:
            return jsonify({'error': 'Role is required'}), 400
        
        if new_role not in ['USER', 'ORG_ADMIN']:
            return jsonify({'error': 'Invalid role'}), 400
        
        organization = Organization.query.get(organization_id)
        if not organization:
            return jsonify({'error': 'Organization not found'}), 404
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Find the membership
        membership = UserOrganization.query.filter_by(
            user_id=user_id,
            organization_id=organization_id
        ).first()
        
        if not membership:
            return jsonify({'error': 'User is not a member of this organization'}), 404
        
        # Update role
        membership.role = new_role
        db.session.commit()
        
        return safe_jsonify({
            'message': 'Member role updated successfully',
            'membership': {
                'user_id': str(user_id),
                'organization_id': str(organization_id),
                'role': new_role,
                'joined_at': membership.joined_at.isoformat() if membership.joined_at else None
            }
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/users/search', methods=['GET'])
def search_users():
    """Search users for adding to organizations"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        query = request.args.get('q', '')
        organization_id = request.args.get('organization_id')
        
        if len(query) < 2:
            return jsonify({'users': []}), 200
        
        # Search users by username, email, first_name, or last_name
        users_query = User.query.filter(
            db.or_(
                User.username.ilike(f'%{query}%'),
                User.email.ilike(f'%{query}%'),
                User.first_name.ilike(f'%{query}%'),
                User.last_name.ilike(f'%{query}%')
            )
        ).filter(User.is_active == True)
        
        # If organization_id is provided, exclude users who are already members
        if organization_id:
            existing_member_ids = db.session.query(UserOrganization.user_id).filter_by(
                organization_id=organization_id
            ).subquery()
            
            users_query = users_query.filter(
                User.id.notin_(existing_member_ids)
            )
        
        users = users_query.limit(20).all()
        
        users_list = []
        for user in users:
            users_list.append({
                'id': str(user.id),
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'full_name': f"{user.first_name} {user.last_name}".strip() or user.username
            })
        
        return safe_jsonify({
            'users': users_list
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/users/<user_id>/delete', methods=['POST'])
def delete_user_endpoint(user_id):
    """Delete a user (soft delete by deactivating)"""
    admin = verify_super_admin_token()
    if not admin:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Soft delete: deactivate user and remove from all organizations
        user.is_active = False
        user.updated_at = datetime.utcnow()
        
        # Remove user from all organizations
        UserOrganization.query.filter_by(user_id=user_id).update({
            'is_active': False,
            'updated_at': datetime.utcnow()
        })
        
        db.session.commit()
        
        return safe_jsonify({
            'message': 'User deleted successfully',
            'user': user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@super_admin_bp.route('/test-delete', methods=['GET'])
def test_delete_route():
    """Test route to see if routes can be registered here"""
    return jsonify({'message': 'Test delete route works'}), 200
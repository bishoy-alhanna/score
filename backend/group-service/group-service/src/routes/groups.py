from flask import Blueprint, request, jsonify
import jwt
from src.models.database import db, Group, GroupMember
import os

groups_bp = Blueprint('groups', __name__)

def verify_token_and_get_user():
    """Helper function to verify JWT token and return user info"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None, {'error': 'Authorization header required'}, 401
    
    token = auth_header.split(' ')[1]
    secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
    
    try:
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
    except jwt.InvalidTokenError:
        return None, {'error': 'Invalid token'}, 401
    
    return payload, None, None

@groups_bp.route('/', methods=['GET'])
def get_groups():
    """Get all groups in the organization"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        
        # Get all groups in the organization
        groups = Group.query.filter_by(
            organization_id=organization_id,
            is_active=True
        ).all()
        
        return jsonify({
            'groups': [g.to_dict() for g in groups]
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@groups_bp.route('/', methods=['POST'])
def create_group():
    """Create new group"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        data = request.get_json()
        
        # Validate required fields
        if not data.get('name'):
            return jsonify({'error': 'Group name is required'}), 400
        
        name = data['name']
        description = data.get('description', '')
        organization_id = user_payload['organization_id']
        created_by = user_payload['user_id']
        
        # Check if group name already exists in organization
        existing_group = Group.query.filter_by(
            name=name,
            organization_id=organization_id,
            is_active=True
        ).first()
        if existing_group:
            return jsonify({'error': 'Group name already exists in organization'}), 400
        
        # Create new group
        group = Group(
            name=name,
            description=description,
            organization_id=organization_id,
            created_by=created_by
        )
        
        db.session.add(group)
        db.session.flush()  # Get the group ID
        
        # Add creator as group admin
        group_member = GroupMember(
            group_id=group.id,
            user_id=created_by,
            organization_id=organization_id,
            role='ADMIN'
        )
        
        db.session.add(group_member)
        db.session.commit()
        
        return jsonify({
            'message': 'Group created successfully',
            'group': group.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@groups_bp.route('/<group_id>', methods=['GET'])
def get_group(group_id):
    """Get specific group details"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        
        # Get group in the same organization
        group = Group.query.filter_by(
            id=group_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not group:
            return jsonify({'error': 'Group not found'}), 404
        
        # Get group members
        members = GroupMember.query.filter_by(
            group_id=group_id,
            organization_id=organization_id
        ).all()
        
        group_dict = group.to_dict()
        group_dict['members'] = [m.to_dict() for m in members]
        
        return jsonify({
            'group': group_dict
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@groups_bp.route('/<group_id>', methods=['PUT'])
def update_group(group_id):
    """Update group details"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        user_id = user_payload['user_id']
        
        # Get group in the same organization
        group = Group.query.filter_by(
            id=group_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not group:
            return jsonify({'error': 'Group not found'}), 404
        
        # Check if user is group admin or org admin
        is_group_admin = GroupMember.query.filter_by(
            group_id=group_id,
            user_id=user_id,
            role='ADMIN'
        ).first() is not None
        
        is_org_admin = user_payload.get('role') == 'ORG_ADMIN'
        
        if not (is_group_admin or is_org_admin):
            return jsonify({'error': 'Permission denied'}), 403
        
        data = request.get_json()
        
        # Update allowed fields
        if 'name' in data:
            # Check if new name is unique in organization
            existing_group = Group.query.filter(
                Group.name == data['name'],
                Group.organization_id == organization_id,
                Group.id != group_id,
                Group.is_active == True
            ).first()
            if existing_group:
                return jsonify({'error': 'Group name already exists in organization'}), 400
            
            group.name = data['name']
        
        if 'description' in data:
            group.description = data['description']
        
        db.session.commit()
        
        return jsonify({
            'message': 'Group updated successfully',
            'group': group.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@groups_bp.route('/<group_id>', methods=['DELETE'])
def delete_group(group_id):
    """Delete group (soft delete)"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        user_id = user_payload['user_id']
        
        # Get group in the same organization
        group = Group.query.filter_by(
            id=group_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not group:
            return jsonify({'error': 'Group not found'}), 404
        
        # Check if user is group admin or org admin
        is_group_admin = GroupMember.query.filter_by(
            group_id=group_id,
            user_id=user_id,
            role='ADMIN'
        ).first() is not None
        
        is_org_admin = user_payload.get('role') == 'ORG_ADMIN'
        
        if not (is_group_admin or is_org_admin):
            return jsonify({'error': 'Permission denied'}), 403
        
        # Soft delete the group
        group.is_active = False
        db.session.commit()
        
        return jsonify({
            'message': 'Group deleted successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@groups_bp.route('/<group_id>/members', methods=['POST'])
def add_member(group_id):
    """Add member to group"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        current_user_id = user_payload['user_id']
        
        # Get group in the same organization
        group = Group.query.filter_by(
            id=group_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not group:
            return jsonify({'error': 'Group not found'}), 404
        
        # Check if user is group admin or org admin
        is_group_admin = GroupMember.query.filter_by(
            group_id=group_id,
            user_id=current_user_id,
            role='ADMIN'
        ).first() is not None
        
        is_org_admin = user_payload.get('role') == 'ORG_ADMIN'
        
        if not (is_group_admin or is_org_admin):
            return jsonify({'error': 'Permission denied'}), 403
        
        data = request.get_json()
        
        if not data.get('user_id'):
            return jsonify({'error': 'User ID is required'}), 400
        
        user_id = data['user_id']
        role = data.get('role', 'MEMBER')
        
        if role not in ['MEMBER', 'ADMIN']:
            return jsonify({'error': 'Invalid role'}), 400
        
        # Check if user is already a member
        existing_member = GroupMember.query.filter_by(
            group_id=group_id,
            user_id=user_id
        ).first()
        
        if existing_member:
            return jsonify({'error': 'User is already a member of this group'}), 400
        
        # Add member
        group_member = GroupMember(
            group_id=group_id,
            user_id=user_id,
            organization_id=organization_id,
            role=role
        )
        
        db.session.add(group_member)
        db.session.commit()
        
        return jsonify({
            'message': 'Member added successfully',
            'member': group_member.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@groups_bp.route('/<group_id>/members/<user_id>', methods=['DELETE'])
def remove_member(group_id, user_id):
    """Remove member from group"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        current_user_id = user_payload['user_id']
        
        # Get group in the same organization
        group = Group.query.filter_by(
            id=group_id,
            organization_id=organization_id,
            is_active=True
        ).first()
        
        if not group:
            return jsonify({'error': 'Group not found'}), 404
        
        # Check if user is group admin or org admin or removing themselves
        is_group_admin = GroupMember.query.filter_by(
            group_id=group_id,
            user_id=current_user_id,
            role='ADMIN'
        ).first() is not None
        
        is_org_admin = user_payload.get('role') == 'ORG_ADMIN'
        is_self_removal = current_user_id == user_id
        
        if not (is_group_admin or is_org_admin or is_self_removal):
            return jsonify({'error': 'Permission denied'}), 403
        
        # Get member
        member = GroupMember.query.filter_by(
            group_id=group_id,
            user_id=user_id,
            organization_id=organization_id
        ).first()
        
        if not member:
            return jsonify({'error': 'Member not found'}), 404
        
        # Don't allow removing the last admin
        if member.role == 'ADMIN':
            admin_count = GroupMember.query.filter_by(
                group_id=group_id,
                role='ADMIN'
            ).count()
            
            if admin_count <= 1:
                return jsonify({'error': 'Cannot remove the last admin from group'}), 400
        
        db.session.delete(member)
        db.session.commit()
        
        return jsonify({
            'message': 'Member removed successfully'
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@groups_bp.route('/my-groups', methods=['GET'])
def get_my_groups():
    """Get groups that current user belongs to"""
    try:
        user_payload, error, status_code = verify_token_and_get_user()
        if error:
            return jsonify(error), status_code
        
        organization_id = user_payload['organization_id']
        user_id = user_payload['user_id']
        
        # Get user's group memberships
        memberships = GroupMember.query.filter_by(
            user_id=user_id,
            organization_id=organization_id
        ).all()
        
        # Get group details
        group_ids = [m.group_id for m in memberships]
        groups = Group.query.filter(
            Group.id.in_(group_ids),
            Group.is_active == True
        ).all()
        
        # Combine group info with membership info
        result = []
        for group in groups:
            membership = next(m for m in memberships if m.group_id == group.id)
            group_dict = group.to_dict()
            group_dict['my_role'] = membership.role
            group_dict['joined_at'] = membership.joined_at.isoformat() if membership.joined_at else None
            result.append(group_dict)
        
        return jsonify({
            'groups': result
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


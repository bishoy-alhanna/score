from flask import Blueprint, request, jsonify
from src.models.database import db, User, Group, ServantGroupAssignment
import uuid
import jwt
import os
from functools import wraps

servant_bp = Blueprint('servant', __name__)

def verify_jwt_token():
    """Verify JWT token from request header"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None
    
    token = auth_header.split(' ')[1]
    secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
    
    try:
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        return payload
    except jwt.InvalidTokenError:
        return None

def get_current_user(payload):
    """Get current user from JWT payload"""
    if not payload:
        return None
    
    user_id = payload.get('user_id')
    if not user_id:
        return None
    
    return User.query.get(user_id)

def check_role(required_roles):
    """Check if user has one of the required roles"""
    payload = verify_jwt_token()
    if not payload:
        return None, jsonify({'error': 'Authentication required'}), 401
    
    user = get_current_user(payload)
    if not user:
        return None, jsonify({'error': 'User not found'}), 404
    
    role = payload.get('role')
    if role not in required_roles:
        return None, jsonify({'error': 'Insufficient permissions'}), 403
    
    return user, None, None

@servant_bp.route('/servants', methods=['GET'])
def get_servants():
    """Get all servants in the organization"""
    user, error_response, error_code = check_role(['ORG_ADMIN', 'SUPER_ADMIN'])
    if error_response:
        return error_response, error_code
    
    try:
        organization_id = request.args.get('organization_id') or user.organization_id
        
        if not user.can_manage_organization(organization_id):
            return jsonify({'error': 'Unauthorized'}), 403
        
        servants = User.query.filter_by(
            organization_id=organization_id,
            role='SERVANT',
            is_active=True
        ).all()
        
        # Get group assignments for each servant
        servants_data = []
        for servant in servants:
            assignments = ServantGroupAssignment.query.filter_by(
                servant_user_id=servant.id,
                is_active=True
            ).all()
            
            servant_dict = servant.to_dict()
            servant_dict['assigned_groups'] = [
                {
                    'id': a.group_id,
                    'name': a.group.name if a.group else None,
                    'assignment_id': a.id
                } for a in assignments
            ]
            servants_data.append(servant_dict)
        
        return jsonify({'servants': servants_data}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@servant_bp.route('/servants/<servant_id>/groups', methods=['GET'])
def get_servant_groups(servant_id):
    """Get all groups assigned to a servant"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    user = get_current_user(payload)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    try:
        # Check if user can view this information
        if user.id != servant_id and not user.is_org_admin() and not user.is_super_admin():
            return jsonify({'error': 'Unauthorized'}), 403
        
        assignments = ServantGroupAssignment.query.filter_by(
            servant_user_id=servant_id,
            is_active=True
        ).all()
        
        # Include full group details in the response
        assignments_with_groups = []
        for assignment in assignments:
            assignment_dict = {
                'id': assignment.id,
                'servant_user_id': assignment.servant_user_id,
                'group_id': assignment.group_id,
                'organization_id': assignment.organization_id,
                'is_active': assignment.is_active,
                'created_at': assignment.created_at.isoformat() if assignment.created_at else None,
                'group': {
                    'id': assignment.group.id,
                    'name': assignment.group.name,
                    'description': assignment.group.description,
                    'organization_id': assignment.group.organization_id
                } if assignment.group else None
            }
            assignments_with_groups.append(assignment_dict)
        
        return jsonify({'assignments': assignments_with_groups}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@servant_bp.route('/servants/<servant_id>/groups', methods=['POST'])
def assign_servant_to_group(servant_id):
    """Assign a servant to a group"""
    user, error_response, error_code = check_role(['ORG_ADMIN', 'SUPER_ADMIN'])
    if error_response:
        return error_response, error_code
    
    try:
        data = request.get_json()
        group_id = data.get('group_id')
        
        if not group_id:
            return jsonify({'error': 'group_id is required'}), 400
        
        # Verify servant exists and is a servant
        servant = User.query.filter_by(id=servant_id, role='SERVANT').first()
        if not servant:
            return jsonify({'error': 'Servant not found'}), 404
        
        # Verify group exists
        group = Group.query.filter_by(id=group_id).first()
        if not group:
            return jsonify({'error': 'Group not found'}), 404
        
        # Check authorization
        if not user.can_manage_organization(group.organization_id):
            return jsonify({'error': 'Unauthorized'}), 403
        
        # Check if assignment already exists
        existing = ServantGroupAssignment.query.filter_by(
            servant_user_id=servant_id,
            group_id=group_id
        ).first()
        
        if existing:
            if existing.is_active:
                return jsonify({'error': 'Servant already assigned to this group'}), 400
            # Reactivate if inactive
            existing.is_active = True
            existing.assigned_by_user_id = user.id
            db.session.commit()
            return jsonify({'assignment': existing.to_dict()}), 200
        
        # Create new assignment
        assignment = ServantGroupAssignment(
            id=str(uuid.uuid4()),
            servant_user_id=servant_id,
            group_id=group_id,
            organization_id=group.organization_id,
            assigned_by_user_id=user.id
        )
        
        db.session.add(assignment)
        db.session.commit()
        
        return jsonify({'assignment': assignment.to_dict()}), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@servant_bp.route('/servants/<servant_id>/groups/<group_id>', methods=['DELETE'])
def remove_servant_from_group(servant_id, group_id):
    """Remove a servant from a group"""
    user, error_response, error_code = check_role(['ORG_ADMIN', 'SUPER_ADMIN'])
    if error_response:
        return error_response, error_code
    
    try:
        assignment = ServantGroupAssignment.query.filter_by(
            servant_user_id=servant_id,
            group_id=group_id,
            is_active=True
        ).first()
        
        if not assignment:
            return jsonify({'error': 'Assignment not found'}), 404
        
        # Check authorization
        if not user.can_manage_organization(assignment.organization_id):
            return jsonify({'error': 'Unauthorized'}), 403
        
        assignment.is_active = False
        db.session.commit()
        
        return jsonify({'message': 'Servant removed from group successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@servant_bp.route('/groups/<group_id>/servants', methods=['GET'])
def get_group_servants(group_id):
    """Get all servants assigned to a group"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    user = get_current_user(payload)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    try:
        group = Group.query.filter_by(id=group_id).first()
        if not group:
            return jsonify({'error': 'Group not found'}), 404
        
        # Check authorization
        if not user.can_manage_organization(group.organization_id) and not user.can_manage_group(group_id):
            return jsonify({'error': 'Unauthorized'}), 403
        
        assignments = ServantGroupAssignment.query.filter_by(
            group_id=group_id,
            is_active=True
        ).all()
        
        return jsonify({'servants': [a.to_dict() for a in assignments]}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@servant_bp.route('/users/<user_id>/promote-to-servant', methods=['POST'])
def promote_to_servant(user_id):
    """Promote a regular user to SERVANT role"""
    user, error_response, error_code = check_role(['ORG_ADMIN', 'SUPER_ADMIN'])
    if error_response:
        return error_response, error_code
    
    try:
        target_user = User.query.filter_by(id=user_id).first()
        if not target_user:
            return jsonify({'error': 'User not found'}), 404
        
        # Check authorization
        if not user.can_manage_organization(target_user.organization_id):
            return jsonify({'error': 'Unauthorized'}), 403
        
        if target_user.role == 'SERVANT':
            return jsonify({'error': 'User is already a servant'}), 400
        
        if target_user.role == 'ORG_ADMIN':
            return jsonify({'error': 'Cannot change role of organization admin'}), 400
        
        target_user.role = 'SERVANT'
        db.session.commit()
        
        return jsonify({
            'message': 'User promoted to SERVANT successfully',
            'user': target_user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@servant_bp.route('/users/<user_id>/demote-from-servant', methods=['POST'])
def demote_from_servant(user_id):
    """Demote a SERVANT back to regular USER role"""
    user, error_response, error_code = check_role(['ORG_ADMIN', 'SUPER_ADMIN'])
    if error_response:
        return error_response, error_code
    
    try:
        target_user = User.query.filter_by(id=user_id, role='SERVANT').first()
        if not target_user:
            return jsonify({'error': 'Servant not found'}), 404
        
        # Check authorization
        if not user.can_manage_organization(target_user.organization_id):
            return jsonify({'error': 'Unauthorized'}), 403
        
        # Deactivate all group assignments
        ServantGroupAssignment.query.filter_by(
            servant_user_id=user_id,
            is_active=True
        ).update({'is_active': False})
        
        target_user.role = 'USER'
        db.session.commit()
        
        return jsonify({
            'message': 'User demoted from SERVANT successfully',
            'user': target_user.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

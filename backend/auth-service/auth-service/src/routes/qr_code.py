from flask import Blueprint, request, jsonify
from src.models.database import db, User, Group, Score, QRScanLog, GroupMember
import qrcode
import io
import base64
import json
from datetime import datetime
import jwt
import os
import uuid

qr_bp = Blueprint('qr', __name__)

def safe_serialize(obj):
    """Safely serialize objects that might contain UUIDs or datetimes"""
    import uuid
    from datetime import datetime, date
    from decimal import Decimal
    
    if isinstance(obj, uuid.UUID):
        return str(obj)
    elif isinstance(obj, (datetime, date)):
        return obj.isoformat()
    elif isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, dict):
        return {k: safe_serialize(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [safe_serialize(item) for item in obj]
    elif hasattr(obj, '__dict__'):
        return safe_serialize(obj.__dict__)
    else:
        return obj

def safe_jsonify(data):
    """Safe jsonify that handles UUIDs and datetimes"""
    serialized_data = safe_serialize(data)
    return jsonify(serialized_data)

def ensure_string_id(id_value):
    """Ensure ID is a string, converting from UUID if necessary"""
    if isinstance(id_value, uuid.UUID):
        return str(id_value)
    elif isinstance(id_value, str):
        return id_value
    else:
        return str(id_value)

def verify_token():
    """Verify JWT token from request"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None
    
    token = auth_header.split(' ')[1]
    try:
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        return payload
    except:
        return None

@qr_bp.route('/generate', methods=['POST'])
def generate_qr_code():
    """Generate QR code for the authenticated user"""
    try:
        # Verify authentication
        payload = verify_token()
        if not payload:
            return jsonify({'error': 'Authentication required'}), 401
        
        # Get user - ensure proper ID handling
        user_id_str = ensure_string_id(payload['user_id'])
        user = User.query.filter_by(id=user_id_str).first()
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Only regular users can generate QR codes for themselves
        if user.role == 'SUPER_ADMIN':
            return jsonify({'error': 'Super admin cannot generate QR codes'}), 403
        
        data = request.get_json() or {}
        expires_in_hours = data.get('expires_in_hours', 24)
        
        # Generate QR token
        qr_payload = {
            'user_id': ensure_string_id(user.id),
            'username': user.username,
            'organization_id': ensure_string_id(user.organization_id),
            'exp': datetime.utcnow().timestamp() + (expires_in_hours * 3600),
            'iat': datetime.utcnow().timestamp(),
            'type': 'qr_code'
        }
        
        secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
        qr_token = jwt.encode(qr_payload, secret_key, algorithm='HS256')
        
        # Create QR code data
        qr_data = {
            'token': qr_token,
            'user_id': ensure_string_id(user.id),
            'username': user.username,
            'organization_id': ensure_string_id(user.organization_id)
        }
        
        # Generate QR code image
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(json.dumps(qr_data))
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Convert to base64
        buffer = io.BytesIO()
        img.save(buffer, format='PNG')
        img_str = base64.b64encode(buffer.getvalue()).decode()
        
        return safe_jsonify({
            'qr_code': f"data:image/png;base64,{img_str}",
            'qr_token': qr_token,
            'expires_at': datetime.utcfromtimestamp(qr_payload['exp']).isoformat(),
            'user': {
                'id': ensure_string_id(user.id),
                'username': user.username,
                'organization_id': ensure_string_id(user.organization_id)
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@qr_bp.route('/scan', methods=['POST'])
def scan_qr_code():
    """Scan and validate QR code"""
    try:
        # Verify authentication
        payload = verify_token()
        if not payload:
            return jsonify({'error': 'Authentication required'}), 401
        
        # Get scanner user - ensure proper ID handling
        scanner_id_str = ensure_string_id(payload['user_id'])
        scanner = User.query.filter_by(id=scanner_id_str).first()
        if not scanner:
            return jsonify({'error': 'Scanner not found'}), 404
        
        # Only org admins and super admins can scan QR codes
        if scanner.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Insufficient permissions to scan QR codes'}), 403
        
        data = request.get_json()
        if not data.get('qr_token'):
            return jsonify({'error': 'QR token is required'}), 400
        
        qr_token = data['qr_token']
        
        # Decode QR token
        try:
            secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
            qr_payload = jwt.decode(qr_token, secret_key, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'QR code has expired'}), 400
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid QR code'}), 400
        
        # Get the user from QR code - ensure proper UUID string handling
        qr_user_id_str = ensure_string_id(qr_payload['user_id'])
        qr_user = User.query.filter_by(id=qr_user_id_str).first()
        if not qr_user:
            return jsonify({'error': 'QR code user not found'}), 404
        
        # Check organization access for org admins
        if scanner.role == 'ORG_ADMIN' and ensure_string_id(scanner.organization_id) != ensure_string_id(qr_user.organization_id):
            return jsonify({'error': 'Cannot scan QR codes from other organizations'}), 403
        
        # Get user's groups
        user_groups = []
        group_memberships = GroupMember.query.filter_by(user_id=qr_user_id_str).all()
        for membership in group_memberships:
            group_id_str = ensure_string_id(membership.group_id)
            group = Group.query.filter_by(id=group_id_str).first()
            if group:
                user_groups.append({
                    'id': ensure_string_id(group.id),
                    'name': group.name,
                    'description': group.description
                })
        
        # Log the scan
        scan_log = QRScanLog(
            scanned_user_id=qr_user_id_str,
            scanner_user_id=scanner_id_str,
            organization_id=ensure_string_id(qr_user.organization_id),
            qr_token=qr_token,
            scan_result='success',
            scan_ip=request.remote_addr,
            user_agent=request.headers.get('User-Agent')
        )
        db.session.add(scan_log)
        db.session.commit()
        
        return safe_jsonify({
            'message': 'QR code scanned successfully',
            'user': {
                'id': ensure_string_id(qr_user.id),
                'username': qr_user.username,
                'email': qr_user.email,
                'organization_id': ensure_string_id(qr_user.organization_id)
            },
            'groups': user_groups,
            'scan_timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@qr_bp.route('/assign-score', methods=['POST'])
def assign_score_via_qr():
    """Assign score to user or group via QR scan"""
    try:
        # Verify authentication
        payload = verify_token()
        if not payload:
            return jsonify({'error': 'Authentication required'}), 401
        
        # Get scanner user - ensure proper ID handling
        scanner_id_str = ensure_string_id(payload['user_id'])
        scanner = User.query.filter_by(id=scanner_id_str).first()
        if not scanner:
            return jsonify({'error': 'Scanner not found'}), 404
        
        # Only org admins and super admins can assign scores
        if scanner.role not in ['ORG_ADMIN', 'SUPER_ADMIN']:
            return jsonify({'error': 'Insufficient permissions to assign scores'}), 403
        
        data = request.get_json()
        required_fields = ['qr_token', 'score_value', 'category', 'assignment_type']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field} is required'}), 400
        
        qr_token = data['qr_token']
        score_value = data['score_value']
        category = data['category']
        assignment_type = data['assignment_type']  # 'user' or 'group'
        group_id = data.get('group_id')
        description = data.get('description', '')
        
        # Decode QR token
        try:
            secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
            qr_payload = jwt.decode(qr_token, secret_key, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'QR code has expired'}), 400
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid QR code'}), 400
        
        # Get the user from QR code - ensure proper UUID string handling
        qr_user_id_str = ensure_string_id(qr_payload['user_id'])
        qr_user = User.query.filter_by(id=qr_user_id_str).first()
        if not qr_user:
            return jsonify({'error': 'QR code user not found'}), 404
        
        # Check organization access for org admins
        if scanner.role == 'ORG_ADMIN' and ensure_string_id(scanner.organization_id) != ensure_string_id(qr_user.organization_id):
            return jsonify({'error': 'Cannot assign scores to users from other organizations'}), 403
        
        # Create score record
        if assignment_type == 'user':
            score = Score(
                user_id=qr_user_id_str,
                assigned_by_id=scanner_id_str,
                organization_id=ensure_string_id(qr_user.organization_id),
                score_value=score_value,
                category=category,
                description=description,
                assigned_via='qr_scan'
            )
        elif assignment_type == 'group':
            if not group_id:
                return jsonify({'error': 'group_id is required for group scoring'}), 400
            
            # Verify group exists and user is a member - ensure proper ID handling
            group_id_str = ensure_string_id(group_id)
            group = Group.query.filter_by(id=group_id_str).first()
            if not group:
                return jsonify({'error': 'Group not found'}), 404
            
            membership = GroupMember.query.filter_by(user_id=qr_user_id_str, group_id=group_id_str).first()
            if not membership:
                return jsonify({'error': 'User is not a member of this group'}), 400
            
            score = Score(
                user_id=qr_user_id_str,
                group_id=group_id_str,
                assigned_by_id=scanner_id_str,
                organization_id=ensure_string_id(qr_user.organization_id),
                score_value=score_value,
                category=category,
                description=description,
                assigned_via='qr_scan'
            )
        else:
            return jsonify({'error': 'Invalid assignment_type. Must be "user" or "group"'}), 400
        
        db.session.add(score)
        
        # Update scan log with score information
        scan_log = QRScanLog(
            scanned_user_id=qr_user_id_str,
            scanner_user_id=scanner_id_str,
            organization_id=ensure_string_id(qr_user.organization_id),
            qr_token=qr_token,
            scan_result='score_assigned',
            score_assigned=score_value,
            score_type=assignment_type,
            scan_ip=request.remote_addr,
            user_agent=request.headers.get('User-Agent')
        )
        db.session.add(scan_log)
        
        db.session.commit()
        
        return safe_jsonify({
            'message': 'Score assigned successfully',
            'score': {
                'id': ensure_string_id(score.id),
                'score_value': score.score_value,
                'category': score.category,
                'description': score.description,
                'assignment_type': assignment_type,
                'assigned_at': score.created_at.isoformat()
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


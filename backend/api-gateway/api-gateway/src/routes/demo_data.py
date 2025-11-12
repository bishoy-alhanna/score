"""
Super Admin - Demo Data Management Routes
Endpoints for managing demo data (create/delete)
"""

from flask import Blueprint, jsonify, request, current_app
from functools import wraps
import jwt
import os
import requests

demo_bp = Blueprint('demo', __name__)

def require_super_admin(f):
    """Decorator to require super admin authentication"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not token:
            return jsonify({'error': 'No token provided'}), 401
        
        try:
            payload = jwt.decode(token, os.getenv('JWT_SECRET_KEY', 'your-secret-key'), algorithms=['HS256'])
            if payload.get('role') != 'super_admin':
                return jsonify({'error': 'Super admin access required'}), 403
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(*args, **kwargs)
    
    return decorated


@demo_bp.route('/check', methods=['GET'])
@require_super_admin
def check_demo_data():
    """Check if demo data exists"""
    try:
        # Check if system_flags table exists
        check_table_query = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_name = 'system_flags'
        );
        """
        result = db.session.execute(check_table_query).scalar()
        
        if not result:
            return jsonify({
                'demo_data_exists': False,
                'message': 'System flags table does not exist'
            }), 200
        
        # Check if demo data flag exists
        check_flag_query = """
        SELECT value FROM system_flags WHERE key = 'demo_data_loaded';
        """
        demo_exists = db.session.execute(check_flag_query).scalar()
        
        if demo_exists:
            # Get demo data statistics
            stats_query = """
            SELECT 
                (SELECT COUNT(*) FROM organizations WHERE id = 'demo1111-1111-1111-1111-111111111111') as demo_org_count,
                (SELECT COUNT(*) FROM users WHERE organization_id = 'demo1111-1111-1111-1111-111111111111') as demo_user_count,
                (SELECT COUNT(*) FROM score_categories WHERE organization_id = 'demo1111-1111-1111-1111-111111111111') as demo_category_count,
                (SELECT COUNT(*) FROM scores WHERE organization_id = 'demo1111-1111-1111-1111-111111111111') as demo_score_count
            """
            stats = db.session.execute(stats_query).fetchone()
            
            return jsonify({
                'demo_data_exists': True,
                'statistics': {
                    'organizations': stats[0] if stats else 0,
                    'users': stats[1] if stats else 0,
                    'categories': stats[2] if stats else 0,
                    'scores': stats[3] if stats else 0
                }
            }), 200
        else:
            return jsonify({
                'demo_data_exists': False,
                'message': 'Demo data has not been loaded'
            }), 200
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@demo_bp.route('/delete', methods=['DELETE'])
@require_super_admin
def delete_demo_data():
    """Delete all demo data"""
    try:
        # Delete in correct order to respect foreign keys
        delete_queries = [
            "DELETE FROM qr_scan_logs WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM score_aggregates WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM scores WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM group_members WHERE group_id IN (SELECT id FROM groups WHERE organization_id = 'demo1111-1111-1111-1111-111111111111')",
            "DELETE FROM groups WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM organization_invitations WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM organization_join_requests WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM user_organizations WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM score_categories WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM users WHERE organization_id = 'demo1111-1111-1111-1111-111111111111'",
            "DELETE FROM organizations WHERE id = 'demo1111-1111-1111-1111-111111111111'",
            "UPDATE system_flags SET value = false, updated_at = NOW() WHERE key = 'demo_data_loaded'"
        ]
        
        deleted_counts = {}
        for query in delete_queries:
            result = db.session.execute(query)
            # Extract table name from query
            table_name = query.split('FROM')[1].split('WHERE')[0].strip()
            deleted_counts[table_name] = result.rowcount
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Demo data has been successfully deleted',
            'deleted': deleted_counts
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@demo_bp.route('/recreate', methods=['POST'])
@require_super_admin
def recreate_demo_data():
    """Delete and recreate demo data"""
    try:
        # First delete existing demo data
        delete_demo_data()
        
        # Then run the seed script
        import subprocess
        result = subprocess.run(
            ['docker', 'exec', '-i', 'saas_postgres', 'psql', '-U', 'postgres', '-d', 'saas_platform'],
            input=open('/app/database/seed_demo_data.sql', 'rb').read(),
            capture_output=True
        )
        
        if result.returncode == 0:
            return jsonify({
                'success': True,
                'message': 'Demo data has been recreated successfully'
            }), 200
        else:
            return jsonify({
                'error': 'Failed to recreate demo data',
                'details': result.stderr.decode()
            }), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

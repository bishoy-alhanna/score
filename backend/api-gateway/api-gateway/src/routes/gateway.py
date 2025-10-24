from flask import Blueprint, request, jsonify, current_app
import requests
import jwt
import os
from functools import wraps
import time

gateway_bp = Blueprint('gateway', __name__)

# Rate limiting storage (in production, use Redis)
rate_limit_storage = {}

def rate_limit(max_requests=100, window=3600):
    """Rate limiting decorator"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Get client identifier (IP address)
            client_id = request.remote_addr
            current_time = time.time()
            
            # Clean old entries
            if client_id in rate_limit_storage:
                rate_limit_storage[client_id] = [
                    timestamp for timestamp in rate_limit_storage[client_id]
                    if current_time - timestamp < window
                ]
            else:
                rate_limit_storage[client_id] = []
            
            # Check rate limit
            if len(rate_limit_storage[client_id]) >= max_requests:
                return jsonify({'error': 'Rate limit exceeded'}), 429
            
            # Add current request
            rate_limit_storage[client_id].append(current_time)
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def verify_jwt_token():
    """Verify JWT token and return payload"""
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

def verify_super_admin_token():
    """Verify super admin token (matches auth service logic)"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None
    
    token = auth_header.split(' ')[1]
    secret_key = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
    
    try:
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        
        # Check if it's a super admin token (matches auth service logic)
        if payload.get('type') != 'super_admin':
            return None
            
        # For API gateway, we'll trust the token if it has the right type
        # The auth service already validated the admin exists when creating the token
        return payload
    except jwt.InvalidTokenError:
        return None

def proxy_request(service_url, path='', method=None):
    """Proxy request to microservice"""
    if method is None:
        method = request.method
    
    url = f"{service_url}{path}"
    headers = dict(request.headers)
    
    # Remove host header to avoid conflicts
    headers.pop('Host', None)
    
    try:
        if method == 'GET':
            response = requests.get(url, headers=headers, params=request.args, timeout=30)
        elif method == 'POST':
            # Handle both JSON and non-JSON POST requests
            try:
                json_data = request.get_json()
                response = requests.post(url, headers=headers, json=json_data, timeout=30)
            except:
                # If no JSON body, send empty JSON or raw data
                response = requests.post(url, headers=headers, json={}, timeout=30)
        elif method == 'PUT':
            try:
                json_data = request.get_json()
                response = requests.put(url, headers=headers, json=json_data, timeout=30)
            except:
                response = requests.put(url, headers=headers, json={}, timeout=30)
        elif method == 'DELETE':
            response = requests.delete(url, headers=headers, timeout=30)
        else:
            return jsonify({'error': 'Method not allowed'}), 405
        
        return response.json(), response.status_code
    except requests.exceptions.RequestException as e:
        return jsonify({'error': f'Service unavailable: {str(e)}'}), 503

# Auth service routes (no authentication required)
@gateway_bp.route('/auth/register', methods=['POST'])
@rate_limit(max_requests=10, window=3600)  # 10 registrations per hour
def auth_register():
    """Proxy registration to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/auth/register')

@gateway_bp.route('/auth/login', methods=['POST'])
@rate_limit(max_requests=20, window=3600)  # 20 login attempts per hour
def auth_login():
    """Proxy login to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/auth/login')

@gateway_bp.route('/auth/verify', methods=['POST'])
@rate_limit()
def auth_verify():
    """Proxy token verification to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/auth/verify')

@gateway_bp.route('/auth/admin-organizations/<username>', methods=['GET'])
@rate_limit()
def auth_admin_organizations(username):
    """Proxy admin organizations lookup to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], f'/api/auth/admin-organizations/{username}')

@gateway_bp.route('/auth/organizations', methods=['GET'])
@rate_limit()
def auth_organizations():
    """Proxy organizations list to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/auth/organizations')

@gateway_bp.route('/auth/user-organizations', methods=['GET'])
@rate_limit()
def auth_user_organizations():
    """Proxy user organizations list to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/auth/user-organizations')

# Organization-specific auth routes
@gateway_bp.route('/auth/organizations/<organization_id>/users', methods=['GET'])
@rate_limit()
def auth_organization_users(organization_id):
    """Proxy organization users to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], f'/api/auth/organizations/{organization_id}/users')

@gateway_bp.route('/auth/organizations/<organization_id>/join-requests', methods=['GET'])
@rate_limit()
def auth_organization_join_requests(organization_id):
    """Proxy organization join requests to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], f'/api/auth/organizations/{organization_id}/join-requests')

@gateway_bp.route('/auth/organizations/<organization_id>/join-requests/<request_id>/approve', methods=['POST'])
@rate_limit()
def auth_approve_join_request(organization_id, request_id):
    """Proxy join request approval to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], f'/api/auth/organizations/{organization_id}/join-requests/{request_id}/approve')

@gateway_bp.route('/auth/organizations/<organization_id>/join-requests/<request_id>/reject', methods=['POST'])
@rate_limit()
def auth_reject_join_request(organization_id, request_id):
    """Proxy join request rejection to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], f'/api/auth/organizations/{organization_id}/join-requests/{request_id}/reject')

@gateway_bp.route('/auth/organizations/<organization_id>/users/<user_id>', methods=['DELETE'])
@rate_limit()
def auth_remove_organization_user(organization_id, user_id):
    """Proxy user removal from organization to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], f'/api/auth/organizations/{organization_id}/users/{user_id}')

# Auth user management routes
@gateway_bp.route('/auth/users/<user_id>', methods=['PUT'])
@rate_limit()
def auth_update_user(user_id):
    """Proxy user update to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], f'/api/auth/users/{user_id}')

@gateway_bp.route('/auth/users/<user_id>/password', methods=['PUT'])
@rate_limit()
def auth_reset_user_password(user_id):
    """Proxy user password reset to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], f'/api/auth/users/{user_id}/password')

# Organization routes
@gateway_bp.route('/organizations/', methods=['GET'])
@rate_limit()
def organizations_get():
    """Proxy organization get to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/organizations/')

@gateway_bp.route('/organizations/', methods=['PUT'])
@rate_limit()
def organizations_update():
    """Proxy organization update to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/organizations/')

@gateway_bp.route('/organizations/users', methods=['GET'])
@rate_limit()
def organizations_users():
    """Proxy organization users to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/organizations/users')

@gateway_bp.route('/organizations/stats', methods=['GET'])
@rate_limit()
def organizations_stats():
    """Proxy organization stats to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/organizations/stats')

# Super Admin routes (no authentication required for login)
@gateway_bp.route('/super-admin/login', methods=['POST'])
@rate_limit(max_requests=10, window=3600)  # 10 login attempts per hour
def super_admin_login():
    """Proxy super admin login to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/super-admin/login')

@gateway_bp.route('/super-admin/dashboard', methods=['GET'])
@rate_limit()
def super_admin_dashboard():
    """Proxy super admin dashboard to auth service"""
    payload = verify_super_admin_token()
    if not payload:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/super-admin/dashboard')

@gateway_bp.route('/super-admin/organizations', methods=['GET', 'POST'])
@gateway_bp.route('/super-admin/organizations/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def super_admin_organizations(path=''):
    """Proxy super admin organization requests to auth service"""
    payload = verify_super_admin_token()
    if not payload:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    full_path = f'/api/super-admin/organizations/{path}' if path else '/api/super-admin/organizations'
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], full_path)

@gateway_bp.route('/super-admin/users', methods=['GET', 'POST'])
@gateway_bp.route('/super-admin/users/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def super_admin_users(path=''):
    """Proxy super admin user requests to auth service"""
    payload = verify_super_admin_token()
    if not payload:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    full_path = f'/api/super-admin/users/{path}' if path else '/api/super-admin/users'
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], full_path)

@gateway_bp.route('/super-admin/join-requests', methods=['GET', 'POST'])
@gateway_bp.route('/super-admin/join-requests/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def super_admin_join_requests(path=''):
    """Proxy super admin join request operations to auth service"""
    payload = verify_super_admin_token()
    if not payload:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    full_path = f'/api/super-admin/join-requests/{path}' if path else '/api/super-admin/join-requests'
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], full_path)

# Catch-all route for other super-admin endpoints
@gateway_bp.route('/super-admin/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def super_admin_catchall(path=''):
    """Proxy other super admin requests to auth service"""
    payload = verify_super_admin_token()
    if not payload:
        return jsonify({'error': 'Super admin authentication required'}), 401
    
    full_path = f'/api/super-admin/{path}'
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], full_path)

# Microservice routes (require authentication)

# User service routes
@gateway_bp.route('/users', methods=['GET', 'POST'])
@gateway_bp.route('/users/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def users_routes(path=''):
    """Proxy user requests to user service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/users/{path}' if path else '/api/users'
    return proxy_request(current_app.config['USER_SERVICE_URL'], full_path)

# Group service routes
@gateway_bp.route('/groups', methods=['GET', 'POST'])
@gateway_bp.route('/groups/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def groups_routes(path=''):
    """Proxy group requests to group service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/groups/{path}' if path else '/api/groups'
    return proxy_request(current_app.config['GROUP_SERVICE_URL'], full_path)

# Scoring service routes
@gateway_bp.route('/scores', methods=['GET', 'POST'])
@gateway_bp.route('/scores/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def scores_routes(path=''):
    """Proxy scoring requests to scoring service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/scores/{path}' if path else '/api/scores'
    return proxy_request(current_app.config['SCORING_SERVICE_URL'], full_path)

# Leaderboard service routes
@gateway_bp.route('/leaderboards', methods=['GET', 'POST'])
@gateway_bp.route('/leaderboards/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def leaderboards_routes(path=''):
    """Proxy leaderboard requests to leaderboard service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/leaderboards/{path}' if path else '/api/leaderboards'
    return proxy_request(current_app.config['LEADERBOARD_SERVICE_URL'], full_path)

# Protected routes (require authentication)
@gateway_bp.route('/auth/invite-user', methods=['POST'])
@rate_limit()
def auth_invite_user():
    """Proxy user invitation to auth service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/auth/invite-user')

@gateway_bp.route('/profile', methods=['GET', 'PUT'])
@gateway_bp.route('/profile/<path:path>', methods=['GET', 'PUT', 'POST', 'DELETE'])
@rate_limit()
def profile_proxy(path=''):
    """Proxy profile requests to auth service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/profile/{path}' if path else '/api/profile'
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], full_path)

@gateway_bp.route('/health')
def health_check():
    """Basic health check"""
    return jsonify({'status': 'healthy', 'service': 'api-gateway'})

# Health check endpoints for services
@gateway_bp.route('/health/services', methods=['GET'])
def health_check_services():
    """Check health of all services"""
    services = {
        'auth': current_app.config['AUTH_SERVICE_URL'],
        'user': current_app.config['USER_SERVICE_URL'],
        'group': current_app.config['GROUP_SERVICE_URL'],
        'scoring': current_app.config['SCORING_SERVICE_URL'],
        'leaderboard': current_app.config['LEADERBOARD_SERVICE_URL']
    }
    
    health_status = {}
    
    for service_name, service_url in services.items():
        try:
            response = requests.get(f"{service_url}/health", timeout=5)
            health_status[service_name] = {
                'status': 'healthy' if response.status_code == 200 else 'unhealthy',
                'response_time': response.elapsed.total_seconds(),
                'url': service_url
            }
        except requests.exceptions.RequestException:
            health_status[service_name] = {
                'status': 'unreachable',
                'url': service_url
            }
    
    overall_status = 'healthy' if all(
        service['status'] == 'healthy' for service in health_status.values()
    ) else 'degraded'
    
    return jsonify({
        'overall_status': overall_status,
        'services': health_status
    }), 200

# QR verification endpoint
@gateway_bp.route('/auth/verify-qr', methods=['POST'])
@rate_limit()
def qr_verify_proxy():
    """Proxy QR verification to auth service"""
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/auth/verify-qr')


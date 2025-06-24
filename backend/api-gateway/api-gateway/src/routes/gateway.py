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
            response = requests.post(url, headers=headers, json=request.get_json(), timeout=30)
        elif method == 'PUT':
            response = requests.put(url, headers=headers, json=request.get_json(), timeout=30)
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

# Protected routes (require authentication)
@gateway_bp.route('/auth/invite-user', methods=['POST'])
@rate_limit()
def auth_invite_user():
    """Proxy user invitation to auth service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], '/api/auth/invite-user')

@gateway_bp.route('/organizations', methods=['GET', 'PUT'])
@gateway_bp.route('/organizations/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
@rate_limit()
def organizations_proxy(path=''):
    """Proxy organization requests to auth service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/organizations/{path}' if path else '/api/organizations'
    return proxy_request(current_app.config['AUTH_SERVICE_URL'], full_path)

@gateway_bp.route('/users', methods=['GET', 'POST'])
@gateway_bp.route('/users/<path:path>', methods=['GET', 'PUT', 'DELETE'])
@rate_limit()
def users_proxy(path=''):
    """Proxy user requests to user service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/users/{path}' if path else '/api/users'
    return proxy_request(current_app.config['USER_SERVICE_URL'], full_path)

@gateway_bp.route('/groups', methods=['GET', 'POST'])
@gateway_bp.route('/groups/<path:path>', methods=['GET', 'PUT', 'DELETE', 'POST'])
@rate_limit()
def groups_proxy(path=''):
    """Proxy group requests to group service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/groups/{path}' if path else '/api/groups'
    return proxy_request(current_app.config['GROUP_SERVICE_URL'], full_path)

@gateway_bp.route('/scores', methods=['GET', 'POST'])
@gateway_bp.route('/scores/<path:path>', methods=['GET', 'PUT', 'DELETE'])
@rate_limit()
def scores_proxy(path=''):
    """Proxy scoring requests to scoring service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/scores/{path}' if path else '/api/scores'
    return proxy_request(current_app.config['SCORING_SERVICE_URL'], full_path)

@gateway_bp.route('/leaderboards', methods=['GET', 'POST'])
@gateway_bp.route('/leaderboards/<path:path>', methods=['GET', 'POST'])
@rate_limit()
def leaderboards_proxy(path=''):
    """Proxy leaderboard requests to leaderboard service"""
    payload = verify_jwt_token()
    if not payload:
        return jsonify({'error': 'Authentication required'}), 401
    
    full_path = f'/api/leaderboards/{path}' if path else '/api/leaderboards'
    return proxy_request(current_app.config['LEADERBOARD_SERVICE_URL'], full_path)

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


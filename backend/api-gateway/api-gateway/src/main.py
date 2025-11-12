import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from flask import Flask
from flask_cors import CORS
from src.routes.gateway import gateway_bp
# from src.routes.demo_data import demo_bp  # Commented out - has database dependencies

app = Flask(__name__)
CORS(app, origins="*")  # Enable CORS for all origins

app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')

# Service URLs
app.config['AUTH_SERVICE_URL'] = os.environ.get('AUTH_SERVICE_URL', 'http://localhost:5001')
app.config['USER_SERVICE_URL'] = os.environ.get('USER_SERVICE_URL', 'http://localhost:5002')
app.config['GROUP_SERVICE_URL'] = os.environ.get('GROUP_SERVICE_URL', 'http://localhost:5003')
app.config['SCORING_SERVICE_URL'] = os.environ.get('SCORING_SERVICE_URL', 'http://localhost:5004')
app.config['LEADERBOARD_SERVICE_URL'] = os.environ.get('LEADERBOARD_SERVICE_URL', 'http://localhost:5005')

# Register blueprints
app.register_blueprint(gateway_bp, url_prefix='/api')
# app.register_blueprint(demo_bp, url_prefix='/api/super-admin/demo')  # Commented out - has database dependencies

@app.route('/health')
def health_check():
    return {'status': 'healthy', 'service': 'api-gateway'}

@app.route('/')
def index():
    return {
        'message': 'Multi-Tenant SaaS Platform API Gateway',
        'version': '1.0.0',
        'services': {
            'auth': '/api/auth',
            'users': '/api/users',
            'groups': '/api/groups',
            'scores': '/api/scores',
            'leaderboards': '/api/leaderboards',
            'organizations': '/api/organizations'
        }
    }

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)


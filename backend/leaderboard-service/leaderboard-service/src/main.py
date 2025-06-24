import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from flask import Flask
from flask_cors import CORS
import redis
from src.models.database import db
from src.routes.leaderboards import leaderboards_bp

app = Flask(__name__)
CORS(app, origins="*")  # Enable CORS for all origins

app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')

# Database configuration
database_url = os.environ.get('DATABASE_URL', 'postgresql://postgres:password@localhost:5432/saas_platform')
app.config['SQLALCHEMY_DATABASE_URI'] = database_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Redis configuration
redis_url = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')
try:
    redis_client = redis.from_url(redis_url)
    redis_client.ping()  # Test connection
    app.config['REDIS_CLIENT'] = redis_client
except:
    print("Warning: Redis connection failed, using in-memory cache")
    app.config['REDIS_CLIENT'] = None

# Initialize database
db.init_app(app)

# Register blueprints
app.register_blueprint(leaderboards_bp, url_prefix='/api/leaderboards')

@app.route('/health')
def health_check():
    return {'status': 'healthy', 'service': 'leaderboard-service'}

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5005, debug=True)


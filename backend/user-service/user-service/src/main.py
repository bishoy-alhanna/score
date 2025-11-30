import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from flask import Flask, send_from_directory
from flask_cors import CORS
from src.models.database import db
from src.routes.users import users_bp

app = Flask(__name__)
CORS(app, origins="*")  # Enable CORS for all origins

app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')

# Upload configuration
app.config['UPLOAD_FOLDER'] = os.path.join(os.getcwd(), 'uploads')
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024  # 5MB max file size

# Database configuration
database_url = os.environ.get('DATABASE_URL', 'postgresql://postgres:password@localhost:5432/saas_platform')
app.config['SQLALCHEMY_DATABASE_URI'] = database_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db.init_app(app)

# Register blueprints
app.register_blueprint(users_bp, url_prefix='/api/users')

# Serve uploaded files
@app.route('/uploads/<path:filename>')
def serve_upload(filename):
    """Serve uploaded files"""
    upload_dir = app.config['UPLOAD_FOLDER']
    return send_from_directory(upload_dir, filename)

@app.route('/health')
def health_check():
    return {'status': 'healthy', 'service': 'user-service'}

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5002, debug=True)


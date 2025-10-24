import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from flask import Flask, jsonify, request
from flask_cors import CORS
from src.models.database_multi_org import db, SuperAdminConfig
from src.simple_json_encoder import SimpleJSONEncoder
import bcrypt
import json
import uuid
from datetime import datetime, date
from decimal import Decimal

app = Flask(__name__)

# Set the custom JSON encoder for the Flask app
app.json_encoder = SimpleJSONEncoder

CORS(app, origins="*")  # Enable CORS for all origins

app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')

# Database configuration
database_url = os.environ.get('DATABASE_URL', 'postgresql://postgres:password@localhost:5432/saas_platform')
app.config['SQLALCHEMY_DATABASE_URI'] = database_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db.init_app(app)

def safe_serialize(obj):
    """Safely serialize objects that might contain UUIDs or datetimes"""
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

# Import routes after app is created
from src.routes.auth_multi_org import auth_bp
from src.routes.organization import organization_bp
from src.routes.super_admin import super_admin_bp
from src.routes.profile import profile_bp
# from src.routes.qr_code import qr_bp  # TODO: Update for multi-org

# Register blueprints
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(organization_bp, url_prefix='/api/organizations')
app.register_blueprint(super_admin_bp, url_prefix='/api/super-admin')
app.register_blueprint(profile_bp, url_prefix='/api/profile')
# app.register_blueprint(qr_bp, url_prefix='/api/qr')  # TODO: Enable when updated

@app.route('/health')
def health_check():
    return jsonify({'status': 'healthy', 'service': 'auth-service'})

def create_super_admin():
    """Create the hardcoded super admin user if it doesn't exist"""
    try:
        with app.app_context():
            # Check if super admin already exists
            existing_super_admin = SuperAdminConfig.query.filter_by(username='superadmin').first()
            
            if not existing_super_admin:
                # Create super admin
                password_hash = bcrypt.hashpw('SuperAdmin123!'.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
                
                super_admin = SuperAdminConfig(
                    username='superadmin',
                    password_hash=password_hash,
                    is_active=True
                )
                
                db.session.add(super_admin)
                db.session.commit()
                print("✅ Super admin created successfully")
            else:
                print("✅ Super admin already exists")
                
    except Exception as e:
        print(f"❌ Error creating super admin: {e}")

if __name__ == '__main__':
    with app.app_context():
        # Create tables
        db.create_all()
        
        # Create super admin
        create_super_admin()
    
    # Run the application
    app.run(host='0.0.0.0', port=5001, debug=True)


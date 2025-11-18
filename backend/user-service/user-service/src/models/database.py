from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid

db = SQLAlchemy()

class User(db.Model):
    __tablename__ = 'users'
    
    # Core fields
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = db.Column(db.String(255), nullable=False, unique=True)
    email = db.Column(db.String(255), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    
    # Basic info
    first_name = db.Column(db.String(255))
    last_name = db.Column(db.String(255))
    profile_picture_url = db.Column(db.String(500))
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Personal information
    birthdate = db.Column(db.Date)
    phone_number = db.Column(db.String(50))
    bio = db.Column(db.Text)
    gender = db.Column(db.String(50))
    
    # Academic information
    school_year = db.Column(db.String(50))
    student_id = db.Column(db.String(100))
    major = db.Column(db.String(255))
    gpa = db.Column(db.Numeric(3, 2))
    graduation_year = db.Column(db.Integer)
    university_name = db.Column(db.String(255))
    faculty_name = db.Column(db.String(255))
    
    # Address
    address_line1 = db.Column(db.String(500))
    address_line2 = db.Column(db.String(500))
    city = db.Column(db.String(255))
    state = db.Column(db.String(255))
    postal_code = db.Column(db.String(50))
    country = db.Column(db.String(100))
    
    # Emergency contact
    emergency_contact_name = db.Column(db.String(255))
    emergency_contact_phone = db.Column(db.String(50))
    emergency_contact_relationship = db.Column(db.String(100))
    
    # Social links
    linkedin_url = db.Column(db.String(500))
    github_url = db.Column(db.String(500))
    personal_website = db.Column(db.String(500))
    
    # Preferences
    timezone = db.Column(db.String(100), default='UTC')
    language = db.Column(db.String(10), default='en')
    notification_preferences = db.Column(db.JSON, default={'push': False, 'email': True})
    
    # Verification & admin
    is_verified = db.Column(db.Boolean, default=False)
    email_verified_at = db.Column(db.DateTime)
    last_login_at = db.Column(db.DateTime)
    is_super_admin = db.Column(db.Boolean, default=False)
    
    # QR code
    qr_code_token = db.Column(db.String(255), unique=True)
    qr_code_generated_at = db.Column(db.DateTime)
    qr_code_expires_at = db.Column(db.DateTime)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'profile_picture_url': self.profile_picture_url,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'birthdate': self.birthdate.isoformat() if self.birthdate else None,
            'phone_number': self.phone_number,
            'bio': self.bio,
            'gender': self.gender,
            'school_year': self.school_year,
            'student_id': self.student_id,
            'major': self.major,
            'gpa': float(self.gpa) if self.gpa else None,
            'graduation_year': self.graduation_year,
            'university_name': self.university_name,
            'faculty_name': self.faculty_name,
            'address_line1': self.address_line1,
            'address_line2': self.address_line2,
            'city': self.city,
            'state': self.state,
            'postal_code': self.postal_code,
            'country': self.country,
            'emergency_contact_name': self.emergency_contact_name,
            'emergency_contact_phone': self.emergency_contact_phone,
            'emergency_contact_relationship': self.emergency_contact_relationship,
            'linkedin_url': self.linkedin_url,
            'github_url': self.github_url,
            'personal_website': self.personal_website,
            'timezone': self.timezone,
            'language': self.language,
            'notification_preferences': self.notification_preferences,
            'is_verified': self.is_verified,
            'email_verified_at': self.email_verified_at.isoformat() if self.email_verified_at else None,
            'last_login_at': self.last_login_at.isoformat() if self.last_login_at else None,
            'has_qr_code': bool(self.qr_code_token and self.qr_code_expires_at and self.qr_code_expires_at > datetime.utcnow()),
            'is_super_admin': self.is_super_admin
        }

class GroupMember(db.Model):
    __tablename__ = 'group_members'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    group_id = db.Column(db.String(36), nullable=False)
    user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)
    organization_id = db.Column(db.String(36), nullable=False)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    user = db.relationship('User', backref='group_memberships')
    
    def to_dict(self):
        return {
            'id': self.id,
            'group_id': self.group_id,
            'user_id': self.user_id,
            'organization_id': self.organization_id,
            'joined_at': self.joined_at.isoformat() if self.joined_at else None
        }


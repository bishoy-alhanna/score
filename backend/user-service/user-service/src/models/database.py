from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid

db = SQLAlchemy()

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(255), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    first_name = db.Column(db.String(255))
    last_name = db.Column(db.String(255))
    profile_picture_url = db.Column(db.String(500))
    birthdate = db.Column(db.Date)
    phone_number = db.Column(db.String(50))
    bio = db.Column(db.Text)
    gender = db.Column(db.String(50))
    school_year = db.Column(db.String(50))
    student_id = db.Column(db.String(100))
    major = db.Column(db.String(255))
    gpa = db.Column(db.Numeric(3, 2))
    graduation_year = db.Column(db.Integer)
    university_name = db.Column(db.String(255))
    faculty_name = db.Column(db.String(255))
    address_line1 = db.Column(db.String(500))
    address_line2 = db.Column(db.String(500))
    city = db.Column(db.String(255))
    state = db.Column(db.String(255))
    postal_code = db.Column(db.String(50))
    country = db.Column(db.String(100))
    emergency_contact_name = db.Column(db.String(255))
    emergency_contact_phone = db.Column(db.String(50))
    emergency_contact_relationship = db.Column(db.String(100))
    linkedin_url = db.Column(db.String(500))
    github_url = db.Column(db.String(500))
    personal_website = db.Column(db.String(500))
    timezone = db.Column(db.String(100), default='UTC')
    language = db.Column(db.String(10), default='en')
    is_verified = db.Column(db.Boolean, default=False)
    is_super_admin = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'is_active': self.is_active,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'profile_picture_url': self.profile_picture_url,
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
            'is_verified': self.is_verified,
            'is_super_admin': self.is_super_admin,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class UserOrganization(db.Model):
    __tablename__ = 'user_organizations'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)
    organization_id = db.Column(db.String(36), nullable=False)
    role = db.Column(db.String(50), nullable=False, default='USER')
    department = db.Column(db.String(255))
    title = db.Column(db.String(255))
    is_active = db.Column(db.Boolean, default=True)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    left_at = db.Column(db.DateTime)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'organization_id': self.organization_id,
            'role': self.role,
            'department': self.department,
            'title': self.title,
            'is_active': self.is_active,
            'joined_at': self.joined_at.isoformat() if self.joined_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'left_at': self.left_at.isoformat() if self.left_at else None
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


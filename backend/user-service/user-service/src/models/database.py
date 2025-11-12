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
    role = db.Column(db.String(50), nullable=False, default='USER')  # USER, ORG_ADMIN
    organization_id = db.Column(db.String(36), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    first_name = db.Column(db.String(255))
    last_name = db.Column(db.String(255))
    department = db.Column(db.String(255))
    university_name = db.Column(db.String(255))
    faculty_name = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Unique constraint for username within organization
    __table_args__ = (db.UniqueConstraint('username', 'organization_id', name='unique_username_per_org'),
                      db.UniqueConstraint('email', 'organization_id', name='unique_email_per_org'))
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'role': self.role,
            'organization_id': self.organization_id,
            'is_active': self.is_active,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'department': self.department,
            'university_name': self.university_name,
            'faculty_name': self.faculty_name,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
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


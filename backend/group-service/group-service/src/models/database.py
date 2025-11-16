from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid

db = SQLAlchemy()

class Group(db.Model):
    __tablename__ = 'groups'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text)
    organization_id = db.Column(db.String(36), nullable=False)
    created_by = db.Column(db.String(36), nullable=False)  # User ID who created the group
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    members = db.relationship('GroupMember', backref='group', lazy=True, cascade='all, delete-orphan')
    
    # Unique constraint for group name within organization
    __table_args__ = (db.UniqueConstraint('name', 'organization_id', name='unique_group_name_per_org'),)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'organization_id': self.organization_id,
            'created_by': self.created_by,
            'is_active': self.is_active,
            'member_count': len(self.members),
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class GroupMember(db.Model):
    __tablename__ = 'group_members'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    group_id = db.Column(db.String(36), db.ForeignKey('groups.id'), nullable=False)
    user_id = db.Column(db.String(36), nullable=False)
    organization_id = db.Column(db.String(36), nullable=False)
    role = db.Column(db.String(20), default='MEMBER')  # MEMBER, ADMIN, MODERATOR
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)
    
    # Unique constraint for user in group
    __table_args__ = (db.UniqueConstraint('group_id', 'user_id', name='unique_user_per_group'),)
    
    def to_dict(self):
        return {
            'id': self.id,
            'group_id': self.group_id,
            'user_id': self.user_id,
            'organization_id': self.organization_id,
            'role': self.role,
            'joined_at': self.joined_at.isoformat() if self.joined_at else None,
            'is_active': self.is_active
        }


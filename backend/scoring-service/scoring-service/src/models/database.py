from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid

db = SQLAlchemy()

class Score(db.Model):
    __tablename__ = 'scores'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), nullable=True)  # Either user_id or group_id, not both
    group_id = db.Column(db.String(36), nullable=True)  # Either user_id or group_id, not both
    score_value = db.Column(db.Integer, nullable=False)
    category = db.Column(db.String(255), default='general')  # Category for multi-dimensional scoring
    description = db.Column(db.Text)
    organization_id = db.Column(db.String(36), nullable=False)
    assigned_by = db.Column(db.String(36), nullable=False)  # User ID who assigned the score
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'group_id': self.group_id,
            'score_value': self.score_value,
            'category': self.category,
            'description': self.description,
            'organization_id': self.organization_id,
            'assigned_by': self.assigned_by,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class ScoreAggregate(db.Model):
    __tablename__ = 'score_aggregates'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), nullable=True)  # Either user_id or group_id, not both
    group_id = db.Column(db.String(36), nullable=True)  # Either user_id or group_id, not both
    category = db.Column(db.String(255), default='general')
    total_score = db.Column(db.Integer, default=0)
    score_count = db.Column(db.Integer, default=0)
    average_score = db.Column(db.Float, default=0.0)
    organization_id = db.Column(db.String(36), nullable=False)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Unique constraint for entity-category combination
    __table_args__ = (
        db.UniqueConstraint('user_id', 'category', 'organization_id', name='unique_user_category_org'),
        db.UniqueConstraint('group_id', 'category', 'organization_id', name='unique_group_category_org'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'group_id': self.group_id,
            'category': self.category,
            'total_score': self.total_score,
            'score_count': self.score_count,
            'average_score': self.average_score,
            'organization_id': self.organization_id,
            'last_updated': self.last_updated.isoformat() if self.last_updated else None
        }


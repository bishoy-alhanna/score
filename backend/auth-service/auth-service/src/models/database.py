from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid
import secrets

db = SQLAlchemy()

class Organization(db.Model):
    __tablename__ = 'organizations'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = db.Column(db.String(255), unique=True, nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    users = db.relationship('User', backref='organization', lazy=True, cascade='all, delete-orphan')
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'user_count': len(self.users) if self.users else 0
        }

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(255), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(50), nullable=False, default='USER')  # USER, ORG_ADMIN, SUPER_ADMIN
    organization_id = db.Column(db.String(36), db.ForeignKey('organizations.id'), nullable=True)  # Nullable for SUPER_ADMIN
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # QR Code fields
    qr_code_token = db.Column(db.String(255), unique=True, nullable=True)
    qr_code_generated_at = db.Column(db.DateTime, nullable=True)
    qr_code_expires_at = db.Column(db.DateTime, nullable=True)
    
    # Unique constraint for username within organization (excluding SUPER_ADMIN)
    __table_args__ = (
        db.UniqueConstraint('username', 'organization_id', name='unique_username_per_org'),
        db.UniqueConstraint('email', 'organization_id', name='unique_email_per_org'),
        db.Index('idx_user_role', 'role'),
        db.Index('idx_user_org', 'organization_id'),
        db.Index('idx_qr_token', 'qr_code_token'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'role': self.role,
            'organization_id': self.organization_id,
            'organization_name': self.organization.name if self.organization else None,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'has_qr_code': bool(self.qr_code_token and self.qr_code_expires_at and self.qr_code_expires_at > datetime.utcnow())
        }
    
    def is_super_admin(self):
        """Check if user is a super admin"""
        return self.role == 'SUPER_ADMIN'
    
    def is_org_admin(self):
        """Check if user is an organization admin"""
        return self.role == 'ORG_ADMIN'
    
    def can_manage_organization(self, org_id):
        """Check if user can manage a specific organization"""
        if self.is_super_admin():
            return True
        if self.is_org_admin() and str(self.organization_id) == str(org_id):
            return True
        return False
    
    def generate_qr_code_token(self, expires_in_hours=24):
        """Generate a new QR code token for the user"""
        self.qr_code_token = secrets.token_urlsafe(32)
        self.qr_code_generated_at = datetime.utcnow()
        self.qr_code_expires_at = datetime.utcnow() + datetime.timedelta(hours=expires_in_hours)
        return self.qr_code_token
    
    def is_qr_code_valid(self):
        """Check if the user's QR code is still valid"""
        return (self.qr_code_token and 
                self.qr_code_expires_at and 
                self.qr_code_expires_at > datetime.utcnow())
    
    def get_qr_code_data(self):
        """Get QR code data for generating QR image"""
        if not self.is_qr_code_valid():
            return None
        
        return {
            'user_id': self.id,
            'username': self.username,
            'organization_id': self.organization_id,
            'organization_name': self.organization.name if self.organization else None,
            'token': self.qr_code_token,
            'expires_at': self.qr_code_expires_at.isoformat()
        }

class Group(db.Model):
    __tablename__ = 'groups'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    organization_id = db.Column(db.String(36), db.ForeignKey('organizations.id'), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    members = db.relationship('GroupMember', backref='group', lazy=True, cascade='all, delete-orphan')
    
    # Unique constraint for group name within organization
    __table_args__ = (
        db.UniqueConstraint('name', 'organization_id', name='unique_group_name_per_org'),
        db.Index('idx_group_org', 'organization_id'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'organization_id': self.organization_id,
            'is_active': self.is_active,
            'member_count': len(self.members) if self.members else 0,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class GroupMember(db.Model):
    __tablename__ = 'group_members'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    group_id = db.Column(db.String(36), db.ForeignKey('groups.id'), nullable=False)
    user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)
    role = db.Column(db.String(50), default='MEMBER')  # MEMBER, LEADER
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    user = db.relationship('User', backref='group_memberships')
    
    # Unique constraint for user in group
    __table_args__ = (
        db.UniqueConstraint('group_id', 'user_id', name='unique_user_per_group'),
        db.Index('idx_group_member', 'group_id', 'user_id'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'group_id': self.group_id,
            'user_id': self.user_id,
            'username': self.user.username if self.user else None,
            'role': self.role,
            'joined_at': self.joined_at.isoformat() if self.joined_at else None
        }

class Score(db.Model):
    __tablename__ = 'scores'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)
    group_id = db.Column(db.String(36), db.ForeignKey('groups.id'), nullable=True)
    organization_id = db.Column(db.String(36), db.ForeignKey('organizations.id'), nullable=False)
    score_value = db.Column(db.Float, nullable=False)  # Changed from 'score' to 'score_value'
    category = db.Column(db.String(100), default='general')
    description = db.Column(db.Text, nullable=True)
    assigned_by_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)  # Admin who assigned the score
    assigned_via = db.Column(db.String(50), default='manual')  # manual, qr_scan, api
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user = db.relationship('User', foreign_keys=[user_id], backref='scores')
    group = db.relationship('Group', backref='scores')
    assigned_by_user = db.relationship('User', foreign_keys=[assigned_by_id])
    
    # Indexes for performance
    __table_args__ = (
        db.Index('idx_score_user', 'user_id'),
        db.Index('idx_score_group', 'group_id'),
        db.Index('idx_score_org', 'organization_id'),
        db.Index('idx_score_category', 'category'),
        db.Index('idx_score_date', 'created_at'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'username': self.user.username if self.user else None,
            'group_id': self.group_id,
            'group_name': self.group.name if self.group else None,
            'organization_id': self.organization_id,
            'score_value': self.score_value,  # Updated field name
            'category': self.category,
            'description': self.description,
            'assigned_by_id': self.assigned_by_id,  # Updated field name
            'assigned_by_username': self.assigned_by_user.username if self.assigned_by_user else None,
            'assigned_via': self.assigned_via,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class QRScanLog(db.Model):
    """Log QR code scans for analytics and security"""
    __tablename__ = 'qr_scan_logs'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    scanned_user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)  # User whose QR was scanned
    scanner_user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)  # Admin who scanned
    organization_id = db.Column(db.String(36), db.ForeignKey('organizations.id'), nullable=False)
    qr_token = db.Column(db.String(255), nullable=False)
    scan_result = db.Column(db.String(50), nullable=False)  # success, expired, invalid, unauthorized
    score_assigned = db.Column(db.Float, nullable=True)  # Score assigned during this scan (if any)
    score_type = db.Column(db.String(50), nullable=True)  # user, group
    scan_ip = db.Column(db.String(45), nullable=True)  # IP address of scanner
    user_agent = db.Column(db.Text, nullable=True)  # Browser/device info
    scanned_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    scanned_user = db.relationship('User', foreign_keys=[scanned_user_id])
    scanner_user = db.relationship('User', foreign_keys=[scanner_user_id])
    
    # Indexes for analytics
    __table_args__ = (
        db.Index('idx_scan_user', 'scanned_user_id'),
        db.Index('idx_scan_scanner', 'scanner_user_id'),
        db.Index('idx_scan_org', 'organization_id'),
        db.Index('idx_scan_date', 'scanned_at'),
        db.Index('idx_scan_result', 'scan_result'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'scanned_user_id': self.scanned_user_id,
            'scanned_username': self.scanned_user.username if self.scanned_user else None,
            'scanner_user_id': self.scanner_user_id,
            'scanner_username': self.scanner_user.username if self.scanner_user else None,
            'organization_id': self.organization_id,
            'scan_result': self.scan_result,
            'score_assigned': self.score_assigned,
            'score_type': self.score_type,
            'scanned_at': self.scanned_at.isoformat() if self.scanned_at else None
        }

# Super Admin configuration
class SuperAdminConfig:
    """Configuration for super admin account"""
    USERNAME = "superadmin"
    EMAIL = "superadmin@al-hanna.com"
    PASSWORD = "SuperAdmin123!"  # Change this in production
    ROLE = "SUPER_ADMIN"
    
    @classmethod
    def create_super_admin_if_not_exists(cls):
        """Create super admin user if it doesn't exist"""
        from werkzeug.security import generate_password_hash
        
        # Check if super admin already exists
        super_admin = User.query.filter_by(username=cls.USERNAME, role=cls.ROLE).first()
        
        if not super_admin:
            # Create super admin user
            super_admin = User(
                username=cls.USERNAME,
                email=cls.EMAIL,
                password_hash=generate_password_hash(cls.PASSWORD),
                role=cls.ROLE,
                organization_id=None,  # Super admin doesn't belong to any organization
                is_active=True
            )
            
            db.session.add(super_admin)
            db.session.commit()
            print(f"Super admin created: {cls.USERNAME}")
        else:
            print(f"Super admin already exists: {cls.USERNAME}")
        
        return super_admin

